#!/usr/bin/env bash
# Read-only worktree prune audit. Classifies every git worktree by size, merge
# state, uncommitted work, remote/PR state, and the most recent chat that
# operated in it. Emits a table sorted by size with a suggested bucket. Never
# deletes anything; deletion stays a human-gated step in the playbook.
# Codex chat ownership must be checked through the host before cleanup.
#
# Usage: worktree-audit.sh [-b|--base <ref>] [repo-path]
#   repo-path defaults to the current repo.
#   -b sets the branch or local ref to check (e.g. origin/integration).
#   Without it the base is the default branch of the repository selected by
#   gh repo set-default, or origin (then the first remote). Unknown bases leave
#   MERGED unknown; pass -b when PRs target another repository or branch.
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
pr_base=""
pr_remote=""
allow_pr_merge=true

github_repository_from_url() {
	local url=$1 address="" host ssh_host
	if [[ "$url" =~ ^(https?|ssh):// ]]; then
		address=${url#*://}
	elif [[ "$url" =~ ^[^/:]+: ]]; then
		address=${url/:/\/}
	fi
	if [[ "$address" =~ ^([^/@]+@)?([[:alnum:].-]+)(:[0-9]+)?(/[[:alnum:]_.-]+/[[:alnum:]_.-]+)/?$ ]]; then
		host=${BASH_REMATCH[2]}
		if [[ "$url" != http://* && "$url" != https://* ]]; then
			ssh_host=$(ssh -G "$host" 2>/dev/null | awk '$1 == "hostname" { print $2; exit }')
			host=${ssh_host:-$host}
			if [[ "$host" == ssh.github.com ]]; then host=github.com; fi
		fi
		printf '%s%s\n' "$host" "${BASH_REMATCH[4]%.git}"
	else
		return 1
	fi
}

if [ -z "$base" ]; then
	IFS=' ' read -r resolution_key gh_target < <(git config --get-regexp '^remote\..*\.gh-resolved$' | sed -n '1p')
	case "$gh_target" in
	base)
		pr_remote=${resolution_key#remote.}
		pr_remote=${pr_remote%.gh-resolved} ;;
	*/*)
		IFS=$'\t' read -r selected_url pr_base < <(
			gh repo view --json url,defaultBranchRef --jq '[.url, .defaultBranchRef.name] | @tsv' 2>/dev/null
		)
		if [ -n "$pr_base" ] && selected_repository=$(github_repository_from_url "$selected_url"); then
			selected_repository=$(printf '%s' "$selected_repository" | tr '[:upper:]' '[:lower:]')
			while IFS= read -r remote_name; do
				remote_repository=$(github_repository_from_url "$(git remote get-url "$remote_name")" | tr '[:upper:]' '[:lower:]')
				candidate="refs/remotes/$remote_name/$pr_base"
				if [[ "$remote_repository" == "$selected_repository" ]] &&
					git show-ref --verify --quiet "$candidate"; then
					base=$candidate
					break
				fi
			done < <(git remote)
		else
			allow_pr_merge=false
		fi ;;
	*)
		pr_remote=$(git remote | sed -n '1p')
		if git remote | grep -qx origin; then pr_remote=origin; fi ;;
	esac
	if [ -n "$pr_remote" ]; then
		base=$(git symbolic-ref --quiet "refs/remotes/$pr_remote/HEAD" 2>/dev/null || true)
		if [ -z "$base" ]; then
			default_branch=$(git ls-remote --symref "$pr_remote" HEAD 2>/dev/null | awk '$1 == "ref:" && $3 == "HEAD" { sub(/^refs\/heads\//, "", $2); print $2; exit }')
			if [ -n "$default_branch" ]; then base="refs/remotes/$pr_remote/$default_branch"; fi
		fi
		pr_base=${base#"refs/remotes/$pr_remote/"}
	fi
	if [ -z "$base" ] || ! git rev-parse --verify "$base^{commit}" >/dev/null 2>&1; then
		base=""
		echo "warn: default branch could not be resolved locally; MERGED is unknown" >&2
	fi
else
	if git rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1; then
		base_ref=$(git rev-parse --symbolic-full-name "$base")
	else
		base_ref=$base
		base=""
	fi
	remote_ref=""
	case "$base_ref" in
		refs/heads/*)
			pr_base=${base_ref#refs/heads/}
			IFS=$'\t' read -r tracking_remote tracking_ref < <(
				git for-each-ref --format='%(upstream:remotename)%09%(upstream:remoteref)' "$base_ref"
			)
			if [[ "$tracking_remote" != . && "$tracking_ref" == refs/heads/* ]]; then
				pr_remote=$tracking_remote
				pr_base=${tracking_ref#refs/heads/}
			fi ;;
		refs/remotes/*) remote_ref=${base_ref#refs/remotes/} ;;
		refs/*|"") allow_pr_merge=false ;;
		*) remote_ref=$base_ref ;;
	esac
	if [ -n "$remote_ref" ]; then
		pr_base=$remote_ref
		while IFS= read -r remote_name; do
			if [[ "$remote_ref" == "$remote_name/"* ]]; then
				pr_remote=$remote_name
				pr_base=${remote_ref#"$remote_name/"}
				break
			fi
		done < <(git remote | LC_ALL=C sort -r)
	fi
	if [ -z "$base" ]; then
		if [ "$allow_pr_merge" = false ] || ! git check-ref-format "refs/heads/$pr_base" >/dev/null; then
			echo "error: invalid or unavailable base: $base_ref" >&2
			exit 1
		fi
		echo "warn: base ref $base_ref is unavailable locally; MERGED is unknown" >&2
	fi
	if [[ "$base_ref" == refs/remotes/* && -z "$pr_remote" ]]; then allow_pr_merge=false; fi
fi

pr_repository=""
if [ -n "$pr_remote" ] &&
	! pr_repository=$(github_repository_from_url "$(git remote get-url "$pr_remote" 2>/dev/null)"); then
	allow_pr_merge=false
fi

prs=$(mktemp)
if raw=$(gh pr list ${pr_repository:+--repo "$pr_repository"} --author "@me" --state all --limit 1000 \
	--json number,state,headRefName,headRefOid,baseRefName 2>/dev/null); then
	printf '%s' "$raw" | jq '[.[] | .state |= ascii_downcase]' > "$prs" 2>/dev/null
	if [ "$allow_pr_merge" = true ] && [ -z "$pr_base" ]; then
		pr_base=$(gh repo view ${pr_repository:+"$pr_repository"} --json defaultBranchRef \
			--jq '.defaultBranchRef.name // empty' 2>/dev/null)
	fi
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

	# Squash and rebase merges can leave the original head outside the base's history.
	merged="?"
	if [ -n "$base" ] && [ -n "$head" ]; then
		git merge-base --is-ancestor "$head" "$base" 2>/dev/null && merged=YES || merged=no
	fi

	if porcelain=$(git -C "$wt" status --porcelain=v1 --untracked-files=normal --ignored=matching 2>/dev/null); then
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

	branch=$(git -C "$wt" branch --show-current 2>/dev/null || echo "")
	if [ -z "$branch" ]; then remote=detached
	else
		# A branch published with an explicit push may have no implicit push target.
		push_ref=$(git -C "$wt" rev-parse --symbolic-full-name --verify '@{push}' 2>/dev/null ||
			git -C "$wt" -c push.default=current rev-parse --symbolic-full-name --verify '@{push}' 2>/dev/null)
		if [[ "$push_ref" != refs/remotes/* ]] &&
			git -C "$wt" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
			push_ref="refs/remotes/origin/$branch"
		fi
		if [[ "$push_ref" != refs/remotes/* ]]; then remote=no-remote
		elif counts=$(git -C "$wt" rev-list --left-right --count "HEAD...$push_ref" 2>/dev/null); then
			read -r ahead behind <<< "$counts"
			if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then remote=pushed
			else remote="ahead$ahead/behind$behind"; fi
		else remote=unknown; fi
	fi

	IFS=$'\t' read -r pr pr_merged pr_open < <(
		[ -n "$branch" ] && jq -r --arg branch "$branch" --arg oid "$head" --arg base "$pr_base" \
			--arg merged "$merged" --argjson allow_merge "$allow_pr_merge" '
			def pending: .state == "open" or .state == "draft";
			def matching_merge:
				$allow_merge and .state == "merged" and $oid != "" and .headRefOid == $oid
				and $base != "" and .baseRefName == $base;
			map(select(.headRefName == $branch)) as $matches
			| first($matches[] | select(pending and (.headRefOid == null or .headRefOid == $oid)))
				// first($matches[] | select(matching_merge))
				// first($matches[] | select(pending))
				// ($matches[0] // empty)
			| ["#\(.number)/\(.state)", matching_merge,
				(pending and ($merged != "YES" or .headRefOid == null or .headRefOid == $oid))]
			| @tsv
		' "$prs" 2>/dev/null
	)
	[ -z "$pr" ] && pr="-"

	last="unknown"

	case "$dirty" in
		unknown) bucket=hold-unknown ;;
		wip:*) bucket=hold-wip ;;
		*ignored:*) bucket=hold-ignored ;;
		untracked:*) bucket=hold-untracked ;;
		clean)
			if [ "$pr_open" = true ]; then bucket=hold-open-pr
			elif [ "$merged" = YES ] || [ "$pr_merged" = true ]; then bucket=safe
			else bucket=review; fi ;;
	esac

	display_wt=$wt
	if [[ "$wt" == *$'\n'* || "$wt" == *$'\t'* ]]; then printf -v display_wt '%q' "$wt"; fi
	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$size" "$age" "$merged" "$dirty" "$remote" "$pr" "$last" "$bucket" "$display_wt"
done | sort -t$'\t' -k1,1 -rh
echo "LAST_CHAT is unknown. Check active and pinned tasks and managed-worktree ownership with the host before cleanup." >&2

rm -f "$prs"
