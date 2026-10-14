#!/usr/bin/env bash
# Read-only worktree prune audit. Classifies every git worktree by size, merge
# state, uncommitted work, remote/PR state, and the most recent chat that
# operated in it. Emits a table sorted by size with a suggested bucket. Never
# deletes anything; deletion stays a human-gated step in the playbook.
# Codex chat ownership must be checked through the host before cleanup.
#
# Usage: worktree-audit.sh [-b|--base <ref>] [repo-path]
#   repo-path defaults to the current repo.
#   -b sets the ref the MERGED column checks against (e.g. origin/integration).
#   Without it the base is the preferred remote's default branch, using a
#   local snapshot. origin is preferred when configured. Unknown bases leave
#   MERGED unknown; pass -b when PRs merge into a different branch.
set -u
export GIT_OPTIONAL_LOCKS=0

base=""
while [ $# -gt 0 ]; do
	case "$1" in
	-b|--base) [ $# -ge 2 ] || { echo "error: $1 needs a ref" >&2; exit 2; }; base="$2"; shift 2 ;;
	-h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	-*) echo "error: unknown option: $1" >&2; exit 2 ;;
	*) break ;;
	esac
done

repo="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$repo" ] && { echo "not in a git repo; pass a repo path" >&2; exit 1; }
cd "$repo" || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "error: not a git repo: $repo" >&2; exit 1; }

# Main worktree is the first entry; everything else is a candidate.
main_wt=""

if [ -z "$base" ]; then
	preferred_remote=$(git remote | sed -n '1p')
	if git remote | grep -qx origin; then preferred_remote=origin; fi
	if [ -n "$preferred_remote" ]; then
		base=$(git symbolic-ref --quiet "refs/remotes/$preferred_remote/HEAD" 2>/dev/null || true)
		if [ -z "$base" ]; then
			default_branch=$(git ls-remote --symref "$preferred_remote" HEAD 2>/dev/null | awk '$1 == "ref:" && $3 == "HEAD" { sub(/^refs\/heads\//, "", $2); print $2; exit }')
			if [ -n "$default_branch" ]; then base="refs/remotes/$preferred_remote/$default_branch"; fi
		fi
	fi
	if [ -z "$base" ] || ! git rev-parse --verify "$base^{commit}" >/dev/null 2>&1; then
		base=""
		echo "warn: default branch could not be resolved locally; MERGED is unknown" >&2
	fi
else
	git rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || { echo "error: base ref not found: $base" >&2; exit 1; }
fi

# PR state by branch, fetched once as [{number, state, head}] with a lowercase
# state. Empty when gh cannot read this repo's PRs.
prs=$(mktemp)
if raw=$(gh pr list --author "@me" --state all --limit 1000 \
	--json number,state,headRefName 2>/dev/null); then
	printf '%s' "$raw" | jq '[.[] | {number, state: (.state | ascii_downcase), head: .headRefName}]' > "$prs" 2>/dev/null
fi
[ -s "$prs" ] || echo "[]" > "$prs"

now=$(date +%s)

printf 'Merge base: %s (local snapshot; this audit does not fetch)\n' "${base:-unknown}" >&2
printf "SIZE\tAGE\tMERGED\tDIRTY\tREMOTE\tPR\tLAST_CHAT\tBUCKET\tWORKTREE\n"

git worktree list --porcelain -z | while IFS= read -r -d '' field; do
	case "$field" in worktree\ *) wt=${field#worktree } ;; *) continue ;; esac
	if [ -z "$main_wt" ]; then main_wt=$wt; continue; fi

	size=$(du -sh "$wt" 2>/dev/null | awk 'NR == 1 {print $1; exit}')
	head=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
	head_ts=$(git -C "$wt" log -1 --format='%ct' HEAD 2>/dev/null || echo 0)
	age=$([ "$head_ts" -gt 0 ] 2>/dev/null && echo "$(( (now - head_ts) / 86400 ))d" || echo "?")

	# Squash-merged branches are not ancestors of the base, so PR state is the
	# real signal; merge-base only catches fast-forward/rebase merges.
	merged="?"
	if [ -n "$base" ] && [ -n "$head" ]; then
		git merge-base --is-ancestor "$head" "$base" 2>/dev/null && merged=YES || merged=no
	fi

	if porcelain=$(git -C "$wt" status --porcelain=v1 --untracked-files=all --ignored 2>/dev/null); then
		dirty=clean
		if [ -n "$porcelain" ]; then
			tracked=$(printf '%s\n' "$porcelain" | grep -Ecv '^(\?\?|!!)')
			untracked=$(printf '%s\n' "$porcelain" | grep -c '^??')
			ignored=$(printf '%s\n' "$porcelain" | grep -c '^!!')
			dirty=""
			[ "$tracked" -eq 0 ] || dirty="wip:$tracked"
			[ "$untracked" -eq 0 ] || dirty="${dirty:+$dirty,}untracked:$untracked"
			[ "$ignored" -eq 0 ] || dirty="${dirty:+$dirty,}ignored:$ignored"
		fi
	else dirty=unknown; fi

	branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "")
	upstream=$(git -C "$wt" rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null || true)
	if [ -z "$branch" ]; then remote=detached
	elif [ -n "$upstream" ] && git -C "$wt" rev-parse --verify "$upstream^{commit}" >/dev/null 2>&1; then
		if counts=$(git -C "$wt" rev-list --left-right --count "HEAD...$upstream" 2>/dev/null); then
			read -r ahead behind <<< "$counts"
			if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then remote=pushed
			else remote="ahead$ahead/behind$behind"; fi
		else remote=unknown; fi
	else remote=no-upstream; fi

	pr=$([ -n "$branch" ] && jq -r --arg b "$branch" \
		'.[] | select(.head==$b) | "#\(.number)/\(.state)"' "$prs" 2>/dev/null | head -1)
	[ -z "$pr" ] && pr="-"

	last="unknown"; recent=unknown

	case "$dirty" in
		unknown) bucket=hold-unknown ;;
		wip:*) bucket=hold-wip ;;
		*ignored:*) bucket=hold-ignored ;;
		untracked:*) bucket=hold-untracked ;;
		clean)
		case "$pr" in */open|*/draft) bucket=hold-open-pr ;; *)
			if [ "$recent" = yes ]; then bucket=verify-recent-chat
			elif [ "$merged" = YES ] || [[ "$pr" == */merged ]]; then bucket=safe
			else bucket=review; fi ;;
		esac ;;
	esac

	display_wt=$wt
	if [[ "$wt" == *$'\n'* || "$wt" == *$'\t'* ]]; then printf -v display_wt '%q' "$wt"; fi
	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$size" "$age" "$merged" "$dirty" "$remote" "$pr" "$last" "$bucket" "$display_wt"
done | sort -t$'\t' -k1,1 -rh
echo "LAST_CHAT is unknown. Check active and pinned tasks and managed-worktree ownership with the host before cleanup." >&2

rm -f "$prs"
