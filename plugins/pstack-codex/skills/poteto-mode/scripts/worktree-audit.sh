#!/usr/bin/env bash
# Read-only worktree prune audit. Classifies every git worktree by size, merge
# state, uncommitted work, remote/PR state, and the most recent chat that
# operated in it. Emits a table sorted by size with a suggested bucket. Never
# deletes anything; deletion stays a human-gated step in the playbook.
# Codex chat ownership must be checked through the host before cleanup.
#
# Usage: worktree-audit.sh [repo-path]   (defaults to the current repo)
set -u
export GIT_OPTIONAL_LOCKS=0

repo="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$repo" ] && { echo "not in a git repo; pass a repo path" >&2; exit 1; }
cd "$repo" || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $repo" >&2; exit 1; }

# Main worktree is the first entry; everything else is a candidate.
main_wt=""

preferred_remote=$(git remote | sed -n '1p')
if git remote | grep -qx origin; then preferred_remote=origin; fi
default_ref=""
if [ -n "$preferred_remote" ]; then
	default_ref=$(git symbolic-ref --quiet "refs/remotes/$preferred_remote/HEAD" 2>/dev/null || true)
	if [ -z "$default_ref" ]; then
		default_branch=$(git ls-remote --symref "$preferred_remote" HEAD 2>/dev/null | awk '$1 == "ref:" && $3 == "HEAD" { sub(/^refs\/heads\//, "", $2); print $2; exit }')
		if [ -n "$default_branch" ]; then default_ref="refs/remotes/$preferred_remote/$default_branch"; fi
	fi
fi
if [ -z "$default_ref" ] || ! git rev-parse --verify "$default_ref^{commit}" >/dev/null 2>&1; then
	default_ref=""
	echo "warn: default branch could not be resolved locally; MERGED is unknown" >&2
else
	printf 'Merge base: %s (local snapshot; this audit does not fetch)\n' "$default_ref" >&2
fi

# PR state by branch, fetched once. Empty if gh is unavailable.
prs=$(mktemp)
gh pr list --author "@me" --state all --limit 1000 \
	--json number,state,headRefName 2>/dev/null > "$prs" || echo "[]" > "$prs"

now=$(date +%s)

printf "SIZE\tAGE\tMERGED\tDIRTY\tREMOTE\tPR\tLAST_CHAT\tBUCKET\tWORKTREE\n"

git worktree list --porcelain -z | while IFS= read -r -d '' field; do
	case "$field" in worktree\ *) wt=${field#worktree } ;; *) continue ;; esac
	if [ -z "$main_wt" ]; then main_wt=$wt; continue; fi

	size=$(du -sh "$wt" 2>/dev/null | awk 'NR == 1 {print $1; exit}')
	head=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
	head_ts=$(git -C "$wt" log -1 --format='%ct' HEAD 2>/dev/null || echo 0)
	age=$([ "$head_ts" -gt 0 ] 2>/dev/null && echo "$(( (now - head_ts) / 86400 ))d" || echo "?")

	# Squash-merged branches are not ancestors of the default branch, so PR state is the
	# real signal; merge-base only catches fast-forward/rebase merges.
	merged="?"
	if [ -n "$default_ref" ] && [ -n "$head" ]; then
		git merge-base --is-ancestor "$head" "$default_ref" 2>/dev/null && merged=YES || merged=no
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
		'.[] | select(.headRefName==$b) | "#\(.number)/\(.state)"' "$prs" 2>/dev/null | head -1)
	[ -z "$pr" ] && pr="-"

	last="unknown"; recent=unknown

	case "$dirty" in
		unknown) bucket=hold-unknown ;;
		wip:*) bucket=hold-wip ;;
		*ignored:*) bucket=hold-ignored ;;
		untracked:*) bucket=hold-untracked ;;
		clean)
		case "$pr" in *OPEN*) bucket=hold-open-pr ;; *)
			if [ "$recent" = yes ]; then bucket=verify-recent-chat
			elif [ "$merged" = YES ] || [[ "$pr" == */MERGED ]]; then bucket=safe
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
