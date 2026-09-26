#!/usr/bin/env bash
# Read-only audit. A merged branch is evidence to review, never permission to
# remove a worktree. Check ownership with the host before archiving it.
# Usage: worktree-audit.sh [repo-path]
set -u
export GIT_OPTIONAL_LOCKS=0

invocation_wt=$(git rev-parse --show-toplevel 2>/dev/null || true)
repo="${1:-$invocation_wt}"
[ -n "$repo" ] || { echo "not in a git repo; pass a repo path" >&2; exit 1; }
cd -- "$repo" || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $repo" >&2; exit 1; }

preferred_remote=$(git remote | sed -n '1p')
if git remote | grep -qx origin; then preferred_remote=origin; fi
default_ref=""
if [ -n "$preferred_remote" ]; then
	default_ref=$(git symbolic-ref --quiet "refs/remotes/$preferred_remote/HEAD" 2>/dev/null || true)
	if [ -z "$default_ref" ]; then
		default_branch=$(git ls-remote --symref "$preferred_remote" HEAD 2>/dev/null | awk '$1 == "ref:" && $3 == "HEAD" { sub(/^refs\/heads\//, "", $2); print $2; exit }')
		if [ -n "$default_branch" ]; then default_ref="refs/remotes/$preferred_remote/$default_branch"; fi
	fi
else
	default_branch=$(git config --get init.defaultBranch || true)
	if [ -n "$default_branch" ]; then default_ref="refs/heads/$default_branch"; fi
fi
if [ -z "$default_ref" ] || ! git rev-parse --verify "$default_ref^{commit}" >/dev/null 2>&1; then
	default_ref=""
	echo "warn: default branch could not be resolved locally; MERGED is unknown" >&2
else
	printf 'Merge base: %s (local snapshot; this audit does not fetch)\n' "$default_ref" >&2
fi

# gh performs its own JSON filtering, so jq is not a separate dependency.
prs=""
if command -v gh >/dev/null 2>&1; then
	prs=$(gh pr list --author "@me" --state all --limit 1000 \
		--json number,state,headRefName \
		--jq '.[] | [.headRefName, ("#" + (.number | tostring) + "/" + .state)] | @tsv' 2>/dev/null) \
		|| echo "warn: PR metadata unavailable; PR state is unknown" >&2
fi
now=$(date +%s)
records=$(mktemp "${TMPDIR:-/tmp}/pstack-worktree-audit.XXXXXX") || exit 1
trap 'rm -f -- "$records"' EXIT HUP INT TERM
printf 'SIZE\tAGE\tMERGED\tDIRTY\tREMOTE\tPR\tLAST_CHAT\tBUCKET\tWORKTREE\n'

# NUL-delimited porcelain preserves spaces, tabs, backslashes, and newlines.
git worktree list --porcelain -z | while IFS= read -r -d '' field; do
	case "$field" in worktree\ *) wt=${field#worktree } ;; *) continue ;; esac
	if [ "${main_seen:-no}" = no ]; then main_seen=yes; continue; fi

	size_kb=$(du -sk "$wt" 2>/dev/null | awk 'NR == 1 { print $1 }')
	case "$size_kb" in ''|*[!0-9]*) size_kb=0 ;; esac
	head=$(git -C "$wt" rev-parse --verify HEAD 2>/dev/null || true)
	head_ts=$(git -C "$wt" log -1 --format='%ct' HEAD 2>/dev/null || echo 0)
	age="?"
	if [ "$head_ts" -gt 0 ] 2>/dev/null; then age="$(( (now - head_ts) / 86400 ))d"; fi

	merged="?"
	if [ -n "$default_ref" ] && [ -n "$head" ]; then
		if git merge-base --is-ancestor "$head" "$default_ref" 2>/dev/null; then merged=YES; else merged=no; fi
	fi

	if porcelain=$(git -C "$wt" status --porcelain --untracked-files=normal 2>/dev/null); then
		if [ -z "$porcelain" ]; then dirty=clean
		elif printf '%s\n' "$porcelain" | grep -qv '^??'; then dirty=wip
		else dirty=untracked; fi
	else dirty=unknown; fi

	branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
	upstream=$(git -C "$wt" rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null || true)
	if [ -z "$branch" ]; then remote=detached
	elif [ -n "$upstream" ] && git -C "$wt" rev-parse --verify "$upstream^{commit}" >/dev/null 2>&1; then
		remote_head=$(git -C "$wt" rev-parse "$upstream" 2>/dev/null || true)
		if [ "$remote_head" = "$head" ]; then remote=pushed
		else remote="ahead$(git -C "$wt" rev-list --count "$upstream..HEAD" 2>/dev/null)/behind$(git -C "$wt" rev-list --count "HEAD..$upstream" 2>/dev/null)"; fi
	else remote=no-upstream; fi

	pr="-"
	if [ -n "$branch" ] && [ -n "$prs" ]; then
		match=$(printf '%s\n' "$prs" | awk -F '\t' -v branch="$branch" '$1 == branch { print $2; exit }')
		if [ -n "$match" ]; then pr=$match; fi
	fi
	last=unknown
	if [ "$wt" = "$invocation_wt" ] && [ -n "${CODEX_THREAD_ID:-}" ]; then last=$CODEX_THREAD_ID; fi

	if [ "$dirty" != clean ]; then bucket=hold-changes
	else
		case "$pr" in
			*OPEN*) bucket=hold-open-pr ;;
			*MERGED*) bucket=verify-owner ;;
			*) if [ "$merged" = YES ]; then bucket=verify-owner; else bucket=review; fi ;;
		esac
	fi
	printf -v display_path '%q' "$wt"
	printf '%s\t%sK\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$size_kb" "$size_kb" "$age" "$merged" "$dirty" "$remote" "$pr" "$last" "$bucket" "$display_path" >> "$records"
done
sort -t$'\t' -k1,1nr "$records" | cut -f2-
echo "LAST_CHAT is unknown unless this process identifies it. Check active tasks and managed-worktree ownership with the host before cleanup." >&2
