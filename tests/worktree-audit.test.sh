#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
audit_script=${PSTACK_AUDIT_SCRIPT:-$root/plugins/pstack-codex/skills/poteto-mode/scripts/worktree-audit.sh}
failures=0
fixture=$(mktemp -d "${TMPDIR:-/tmp}/pstack-worktree-audit-test.XXXXXX")
fixture=$(cd "$fixture" && pwd -P)
trap 'rm -rf "$fixture"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_ALLOW_PROTOCOL=file
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
mkdir "$fixture/bin"
cat > "$fixture/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "$PSTACK_TEST_CLI_LOG"
[ "${PSTACK_TEST_GH_STATUS:-0}" = 0 ] || exit "$PSTACK_TEST_GH_STATUS"
case " $* " in
  *' --repo github.com/upstream/project '*) printf '%s\n' "${PSTACK_TEST_UPSTREAM_PRS:-[]}" ;;
  ' repo view --json url,defaultBranchRef --jq [.url, .defaultBranchRef.name] | @tsv ') printf 'https://github.com/upstream/project\tmain\n' ;;
  ' repo view --json defaultBranchRef --jq .defaultBranchRef.name // empty ') printf 'main\n' ;;
  ' pr list --author '*)
    if [ "${GH_REPO:-}" = upstream/project ] || [ "$(git config --get remote.origin.gh-resolved)" = upstream/project ]; then
      printf '%s\n' "${PSTACK_TEST_UPSTREAM_PRS:-[]}"
    else
      printf '%s\n' "${PSTACK_TEST_PRS:-[]}"
    fi ;;
  *) printf '%s\n' "${PSTACK_TEST_PRS:-[]}" ;;
esac
EOF
cat > "$fixture/bin/origin" <<'EOF'
#!/usr/bin/env bash
printf 'origin %s\n' "$*" >> "$PSTACK_TEST_CLI_LOG"
printf '%s\n' '[]'
EOF
chmod +x "$fixture/bin/gh" "$fixture/bin/origin"
export PSTACK_TEST_CLI_LOG="$fixture/cli-log"
export PATH="$fixture/bin:$PATH"

assert_equal() {
  if [ "$2" = "$3" ]; then
    printf 'PASS %s: %s\n' "$1" "$3"
  else
    printf 'FAIL %s: expected %s, got %s\n' "$1" "$2" "$3" >&2
    failures=$((failures + 1))
  fi
}

assert_row() {
  actual=$(awk -F '\t' -v path="$fixture/$1" -v column="$2" '$9 == path { print $column }' "$fixture/report")
  assert_equal "$1 $3" "$4" "$actual"
}

assert_unchanged() {
  if cmp -s "$2" "$3"; then
    printf 'PASS %s unchanged\n' "$1"
  else
    printf 'FAIL %s changed during audit\n' "$1" >&2
    failures=$((failures + 1))
  fi
}

for branch in master main trunk unresolved; do
  source_repo="$fixture/$branch-source"
  repo="$fixture/$branch-repo"
  git init -q -b "$branch" "$source_repo"
  git -C "$source_repo" commit -qm baseline --allow-empty
  git clone -q "$source_repo" "$repo"
  git -C "$repo" worktree add -q -b merged "$fixture/$branch-merged"
  git -C "$repo" worktree add -q -b unmerged "$fixture/$branch-unmerged"
  git -C "$fixture/$branch-unmerged" commit -qm unmerged --allow-empty
  remote=origin
  if [ "$branch" = main ]; then
    git -C "$repo" remote add a-other "$source_repo"
  fi
  if [ "$branch" = trunk ]; then
    git -C "$repo" remote rename origin upstream
    remote=upstream
  fi
  if [ "$branch" != master ]; then
    git -C "$repo" symbolic-ref --delete "refs/remotes/$remote/HEAD"
  fi
  if [ "$branch" = unresolved ]; then
    git -C "$repo" update-ref -d "refs/remotes/$remote/$branch"
  fi
  git -C "$source_repo" commit -qm newer-remote --allow-empty
  git -C "$repo" show-ref > "$fixture/before-refs"
  bash "$audit_script" "$repo" \
    > "$fixture/report" 2> "$fixture/stderr"
  assert_equal "$branch primary worktree excluded" 0 "$(awk -F '\t' -v path="$repo" '$9 == path { count++ } END { print count+0 }' "$fixture/report")"
  for state in merged unmerged; do
    expected=YES
    if [ "$state" = unmerged ]; then expected=no; fi
    if [ "$branch" = unresolved ]; then expected='?'; fi
    assert_row "$branch-$state" 3 MERGED "$expected"
  done
  git -C "$repo" show-ref > "$fixture/after-refs"
  assert_unchanged "$branch local refs" "$fixture/before-refs" "$fixture/after-refs"
  test ! -e "$repo/.git/FETCH_HEAD"
  printf 'PASS %s: merged=%s, unmerged=%s, local refs unchanged, no fetch\n' \
    "$branch" "$(awk -F '\t' -v path="$fixture/$branch-merged" '$9 == path { print $3 }' "$fixture/report")" "$actual"
done

repo="$fixture/main-repo"
git -C "$repo" update-ref refs/remotes/origin/integration unmerged
printf 'existing fetch record\n' > "$repo/.git/FETCH_HEAD"
git -C "$repo" show-ref > "$fixture/before-refs"
cp "$repo/.git/FETCH_HEAD" "$fixture/before-fetch-head"
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row main-unmerged 3 'default base excludes integration commit' no
assert_equal 'default base diagnostic' \
  'Merge base: refs/remotes/origin/main (local snapshot; this audit does not fetch)' \
  "$(sed -n '/^Merge base:/p' "$fixture/stderr")"
bash "$audit_script" -b origin/integration "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row main-unmerged 3 '-b integration base includes commit' YES
assert_equal 'explicit base diagnostic' \
  'Merge base: origin/integration (local snapshot; this audit does not fetch)' \
  "$(sed -n '/^Merge base:/p' "$fixture/stderr")"
assert_equal 'explicit base TSV has nine columns' 9 "$(awk -F '\t' '{ print NF }' "$fixture/report" | sort -u)"
assert_equal 'explicit base has one header and two worktrees' 3 "$(awk 'END { print NR }' "$fixture/report")"
bash "$audit_script" --base origin/integration "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row main-unmerged 3 '--base overrides the default base' YES
git -C "$repo" show-ref > "$fixture/after-refs"
assert_unchanged 'explicit base local refs' "$fixture/before-refs" "$fixture/after-refs"
assert_unchanged 'explicit base FETCH_HEAD' "$fixture/before-fetch-head" "$repo/.git/FETCH_HEAD"
bash "$audit_script" -b unresolved "$fixture/unresolved-repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row unresolved-merged 3 'explicit local base resolves unknown automatic base' YES
assert_row unresolved-unmerged 3 'explicit local base excludes later commit' no

for option in -h --help; do
  (cd "$fixture" && bash "$audit_script" "$option") > "$fixture/report" 2> "$fixture/stderr"
  assert_equal "$option works outside a repository" \
    'Usage: worktree-audit.sh [-b|--base <ref>] [repo-path]' \
    "$(sed -n '/^Usage:/p' "$fixture/report")"
  assert_equal "$option has no stderr" '' "$(cat "$fixture/stderr")"
done
for option in -b --base --unknown; do
  if bash "$audit_script" "$option" > "$fixture/report" 2> "$fixture/stderr"; then
    status=0
  else
    status=$?
  fi
  assert_equal "$option usage error exit" 2 "$status"
  case "$option" in
    --unknown) expected='error: unknown option: --unknown' ;;
    *) expected="error: $option needs a ref" ;;
  esac
  assert_equal "$option usage error message" "$expected" "$(cat "$fixture/stderr")"
  assert_equal "$option usage error has no report" '' "$(cat "$fixture/report")"
done
bash "$audit_script" --base origin/missing "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_equal 'missing explicit base diagnostic' \
  'warn: base ref origin/missing is unavailable locally; MERGED is unknown' \
  "$(sed -n '1p' "$fixture/stderr")"
assert_row main-merged 3 'missing explicit base has unknown ancestry' '?'
assert_row main-merged 8 'missing explicit base without matching PR' review
git -C "$repo" show-ref > "$fixture/after-refs"
assert_unchanged 'missing base local refs' "$fixture/before-refs" "$fixture/after-refs"
assert_unchanged 'missing base FETCH_HEAD' "$fixture/before-fetch-head" "$repo/.git/FETCH_HEAD"

mkdir "$fixture/not-a-repo"
if bash "$audit_script" "$fixture/not-a-repo" > "$fixture/report" 2> "$fixture/stderr"; then
  printf 'FAIL invalid repository reported success\n' >&2
  failures=$((failures + 1))
else
  printf 'PASS invalid repository rejected\n'
fi

source_repo="$fixture/status-source"
repo="$fixture/status-repo"
git init -q -b main "$source_repo"
printf 'baseline\n' > "$source_repo/tracked"
printf 'ignored*\n' > "$source_repo/.gitignore"
git -C "$source_repo" add .
git -C "$source_repo" commit -qm baseline
git clone -q "$source_repo" "$repo"
git -C "$repo" remote set-url origin https://github.com/fork/project.git
for state in clean tracked untracked ignored mixed corrupt closed merged-pr stale-pr open-pr draft-pr; do
  wt="$fixture/$state"
  git -C "$repo" worktree add -q -b "$state" "$wt"
  case "$state" in
    tracked|mixed) printf 'valuable tracked edits\n' > "$wt/tracked" ;;
    closed|merged-pr|stale-pr|open-pr|draft-pr) git -C "$wt" commit -qm branch-work --allow-empty ;;
  esac
  if [ "$state" = stale-pr ]; then
    stale_pr_head=$(git -C "$wt" rev-parse HEAD)
    git -C "$wt" commit -qm later-work --allow-empty
  fi
  case "$state" in
    untracked|mixed) mkdir "$wt/notes"; printf 'valuable notes\n' > "$wt/notes/draft" ;;
  esac
  case "$state" in
    ignored|mixed)
      mkdir "$wt/ignored-data"
      printf 'valuable ignored data\n' > "$wt/ignored-data/local.db"
      printf 'another ignored file\n' > "$wt/ignored-data/other.db"
      ;;
  esac
  index=$(git -C "$wt" rev-parse --git-path index)
  if [ "$state" = corrupt ]; then printf 'invalid index\n' > "$index"; fi
  touch -t 200101010101 "$wt/tracked"
  cp "$index" "$fixture/$state-index-before"
  cp -R "$wt" "$fixture/$state-before"
done
merged_pr_head=$(git -C "$fixture/merged-pr" rev-parse HEAD)
clean_head=$(git -C "$fixture/clean" rev-parse HEAD)
PSTACK_TEST_PRS=$(jq -nc --arg merged "$merged_pr_head" --arg stale "$stale_pr_head" '[
  {number: 1, state: "CLOSED", headRefName: "closed"},
  {number: 5, state: "CLOSED", headRefName: "merged-pr"},
  {number: 6, state: "MERGED", headRefName: "merged-pr", headRefOid: $merged, baseRefName: "integration"},
  {number: 2, state: "MERGED", headRefName: "merged-pr", headRefOid: $merged, baseRefName: "main"},
  {number: 3, state: "OPEN", headRefName: "open-pr"},
  {number: 4, state: "MERGED", headRefName: "stale-pr", headRefOid: $stale, baseRefName: "main"},
  {number: 7, state: "OPEN", headRefName: "clean", headRefOid: $stale}
]')
export PSTACK_TEST_PRS
: > "$PSTACK_TEST_CLI_LOG"
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row clean 4 DIRTY clean
assert_row clean 8 'same-name PR with another head does not veto established ancestry' safe
assert_row tracked 4 DIRTY wip:1
assert_row tracked 8 BUCKET hold-wip
assert_row untracked 4 DIRTY untracked:1
assert_row untracked 8 BUCKET hold-untracked
assert_row ignored 4 DIRTY ignored:1
assert_row ignored 8 BUCKET hold-ignored
assert_row mixed 4 DIRTY wip:1,untracked:1,ignored:1
assert_row mixed 8 BUCKET hold-wip
assert_row corrupt 4 DIRTY unknown
assert_row corrupt 8 BUCKET hold-unknown
assert_equal 'GitHub-only audit never invokes installed Origin' \
  'gh pr list --repo github.com/fork/project --author @me --state all --limit 1000 --json number,state,headRefName,headRefOid,baseRefName' \
  "$(cat "$PSTACK_TEST_CLI_LOG")"
assert_row closed 6 'gh closed state normalized' '#1/closed'
assert_row merged-pr 6 'merge matches HEAD and base behind earlier PRs' '#2/merged'
assert_row open-pr 6 'gh open state normalized' '#3/open'
assert_row draft-pr 8 'unmerged without PR evidence' review
assert_row closed 8 BUCKET review
assert_row merged-pr 8 BUCKET safe
assert_row stale-pr 3 MERGED no
assert_row stale-pr 6 'old PR remains visible' '#4/merged'
assert_row stale-pr 8 'new commit after merged PR needs review' review
assert_row open-pr 8 BUCKET hold-open-pr
bash "$audit_script" -b origin/integration "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 3 'explicit base missing locally' '?'
assert_row merged-pr 6 'merge matches explicit destination' '#6/merged'
assert_row merged-pr 8 'exact PR can establish merge without the explicit local base' safe
git -C "$repo" remote add upstream git@github.com:upstream/project.git
bash "$audit_script" -b upstream/main "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 8 'fork merge cannot certify a missing upstream/main' review
git -C "$repo" update-ref refs/remotes/upstream/main main
git -C "$repo" symbolic-ref refs/remotes/upstream/HEAD refs/remotes/upstream/main
git -C "$repo" config remote.upstream.gh-resolved base
PSTACK_TEST_UPSTREAM_PRS=$(jq -nc --arg head "$(git -C "$fixture/open-pr" rev-parse HEAD)" \
  '[{number: 9, state: "OPEN", headRefName: "open-pr", headRefOid: $head, baseRefName: "main"}]')
export PSTACK_TEST_UPSTREAM_PRS
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row open-pr 6 'gh default selects upstream when both remotes use main' '#9/open'
assert_row open-pr 8 'upstream open PR holds the worktree' hold-open-pr
bash "$audit_script" -b origin/main "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row open-pr 6 'explicit base selects the fork' '#3/open'
git -C "$repo" remote set-url upstream "$source_repo"
bash "$audit_script" -b upstream/main "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 8 'unidentified upstream repository cannot use a fork merge' review
git -C "$repo" remote remove upstream
git -C "$repo" config remote.origin.gh-resolved upstream/project
PSTACK_TEST_UPSTREAM_PRS=$(jq -cn --argjson open "$PSTACK_TEST_UPSTREAM_PRS" --arg head "$merged_pr_head" \
  '$open + [{number: 6, state: "MERGED", headRefName: "merged-pr", headRefOid: $head, baseRefName: "integration"}]')
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row open-pr 3 'unmapped gh default has no local merge base' '?'
assert_row open-pr 6 'unmapped gh default selects upstream PRs' '#9/open'
assert_row open-pr 8 'unmapped gh default holds an open upstream PR' hold-open-pr
assert_row merged-pr 8 'merge into another upstream branch does not qualify' review
bash "$audit_script" -b origin/main "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row open-pr 6 'explicit fork base overrides unmapped gh default' '#3/open'
git -C "$repo" remote add upstream git@github.com:upstream/project.git
git -C "$repo" update-ref refs/remotes/upstream/main main
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row clean 3 'gh default uses the upstream tracking ref once it is available' YES
assert_row clean 8 'local upstream ancestry establishes the merge' safe
assert_row open-pr 6 'gh default still uses upstream PRs' '#9/open'
git -C "$repo" remote remove upstream
git -C "$repo" config --unset remote.origin.gh-resolved
git -C "$repo" remote add team/fork ssh://git@github.com/upstream/project.git
git -C "$repo" update-ref refs/remotes/team/fork/release/v1 main
PSTACK_TEST_UPSTREAM_PRS=$(jq -nc --arg head "$merged_pr_head" '[{number: 8, state: "MERGED", headRefName: "merged-pr", headRefOid: $head, baseRefName: "release/v1"}]')
export PSTACK_TEST_UPSTREAM_PRS
bash "$audit_script" -b team/fork/release/v1 "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 6 'slash-named remote and destination branch match the upstream PR' '#8/merged'
assert_row merged-pr 8 'exact upstream PR qualifies with a slash-named remote' safe
git -C "$repo" branch --track stable team/fork/release/v1 >/dev/null
bash "$audit_script" -b stable "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 8 'local base uses its tracked PR repository and branch' safe
git -C "$repo" remote set-url team/fork https://github.com:443/upstream/project.git
bash "$audit_script" -b team/fork/release/v1 "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 8 'exact upstream PR qualifies with an explicit port in the remote URL' safe
git -C "$repo" remote remove team/fork
git -C "$repo" branch other
bash "$audit_script" -b other "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 8 'merge to another base does not qualify' review
git -C "$repo" tag review-point
bash "$audit_script" -b review-point "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 8 'explicit non-branch ref uses local ancestry' review
git -C "$repo" remote remove origin
GH_REPO=upstream/project bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 3 'unresolved automatic base' '?'
assert_row merged-pr 6 'PR merged to a different branch is visible' '#8/merged'
assert_row merged-pr 8 'GH_REPO default branch must match the merged PR' review
PSTACK_TEST_UPSTREAM_PRS=$(jq --arg head "$merged_pr_head" \
  '. + [{number: 10, state: "MERGED", headRefName: "merged-pr", headRefOid: $head, baseRefName: "main"}]' \
  <<< "$PSTACK_TEST_UPSTREAM_PRS")
GH_REPO=upstream/project bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row merged-pr 6 'merged PR matches GH_REPO default branch' '#10/merged'
assert_row merged-pr 8 'exact merged PR can establish merge without a local base' safe
assert_equal 'TSV has nine columns' 9 "$(awk -F '\t' '{ print NF }' "$fixture/report" | sort -u)"
for state in clean tracked untracked ignored mixed corrupt closed merged-pr stale-pr open-pr draft-pr; do
  wt="$fixture/$state"
  index=$(git -C "$wt" rev-parse --git-path index)
  assert_unchanged "$state index" "$fixture/$state-index-before" "$index"
  if diff -r "$fixture/$state-before" "$wt" > "$fixture/content-diff"; then
    printf 'PASS %s content preserved\n' "$state"
  else
    cat "$fixture/content-diff"
    failures=$((failures + 1))
  fi
done
export PSTACK_TEST_GH_STATUS=1
: > "$PSTACK_TEST_CLI_LOG"
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_equal 'unavailable gh does not switch to Origin' \
  'gh pr list --author @me --state all --limit 1000 --json number,state,headRefName,headRefOid,baseRefName' \
  "$(cat "$PSTACK_TEST_CLI_LOG")"
assert_row merged-pr 6 'unavailable GitHub PR evidence' '-'
assert_row merged-pr 8 'unmerged work without GitHub evidence' review
assert_row open-pr 8 'unavailable GitHub PR stays unverified' review
assert_row mixed 8 'GitHub failure preserves the hold on local edits' hold-wip
unset PSTACK_TEST_PRS PSTACK_TEST_GH_STATUS

git -C "$repo" remote add alternate "$source_repo"
git -C "$repo" fetch -q alternate
for state in pushed ahead behind diverged tracking-main no-upstream detached; do
  wt="$fixture/remote-$state"
  if [ "$state" = detached ]; then
    git -C "$repo" worktree add -q --detach "$wt" main
  else
    branch="local-$state"
    git -C "$repo" worktree add -q -b "$branch" "$wt" main
    case "$state" in
      tracking-main) git -C "$wt" branch -q --set-upstream-to=alternate/main ;;
      no-upstream) git -C "$wt" push -q alternate "$branch" ;;
      *) git -C "$wt" push -q -u alternate "$branch" ;;
    esac
  fi
  case "$state" in ahead|diverged) git -C "$wt" commit -qm local-work --allow-empty ;; esac
done
git -C "$source_repo" commit -qm remote-work --allow-empty
git -C "$source_repo" fetch -q . main:local-behind main:local-diverged
git -C "$repo" fetch -q alternate
git -C "$repo" worktree add -q --track -b local-tracking "$fixture/remote-local-tracking" main
git -C "$repo" tag local-tracking refs/heads/local-tracking
git -C "$repo" show-ref > "$fixture/before-refs"
cp "$repo/.git/FETCH_HEAD" "$fixture/before-fetch-head"
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row remote-pushed 5 REMOTE pushed
assert_row remote-ahead 5 REMOTE ahead1/behind0
assert_row remote-behind 5 REMOTE ahead0/behind1
assert_row remote-diverged 5 REMOTE ahead1/behind1
assert_row remote-tracking-main 5 'tracking a different branch does not establish push status' no-remote
assert_row remote-no-upstream 5 'push without -u is visible' pushed
assert_row remote-local-tracking 5 'local tracking does not establish push status' no-remote
assert_row remote-detached 5 REMOTE detached
git -C "$repo" show-ref > "$fixture/after-refs"
assert_unchanged 'local refs' "$fixture/before-refs" "$fixture/after-refs"
assert_unchanged FETCH_HEAD "$fixture/before-fetch-head" "$repo/.git/FETCH_HEAD"

fork_source="$fixture/fork-source.git"
git clone --quiet --bare "$source_repo" "$fork_source"
git -C "$repo" remote add origin "$fork_source"
git -C "$repo" worktree add -q --track -b fork-topic "$fixture/fork-topic" alternate/main
git -C "$fixture/fork-topic" commit -qm topic --allow-empty
git -C "$fixture/fork-topic" push -q origin fork-topic
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row fork-topic 5 'topic tracking upstream main and explicitly pushed to fork' pushed
git -C "$repo" remote remove origin

repo="$fixture/"$'primary-trailing\n'
git clone -q "$source_repo" "$repo"
for linked in newline tab trailing-newline space; do
  case "$linked" in
    newline) wt="$fixture/"$'linked\nnewline' ;;
    tab) wt="$fixture/"$'linked\ttab' ;;
    trailing-newline) wt="$fixture/"$'linked-trailing\n' ;;
    space) wt="$fixture/linked space" ;;
  esac
  git -C "$repo" worktree add -q -b "$linked" "$wt"
  dirty=clean
  bucket=safe
  case "$linked" in
    tab) printf 'changed\n' > "$wt/tracked"; dirty=wip:1; bucket=hold-wip ;;
    trailing-newline) printf 'notes\n' > "$wt/notes"; dirty=untracked:1; bucket=hold-untracked ;;
  esac
  case "$linked" in
    newline) displayed="\$'$fixture/linked\\nnewline'" ;;
    tab) displayed="\$'$fixture/linked\\ttab'" ;;
    trailing-newline) displayed="\$'$fixture/linked-trailing\\n'" ;;
    space) displayed="$wt" ;;
  esac
  printf 'YES\t%s\tno-remote\t-\tunknown\t%s\t%s\n' "$dirty" "$bucket" "$displayed"
done > "$fixture/expected-path-rows"
bash "$audit_script" "$wt" > "$fixture/report" 2> "$fixture/stderr"
assert_equal 'primary excluded, four linked rows' 5 "$(awk 'END { print NR }' "$fixture/report")"
assert_equal 'paths have nine TSV cells' 9 "$(awk -F '\t' '{ print NF }' "$fixture/report" | sort -u)"
assert_equal 'sizes contain only a size' 0 "$(awk -F '\t' 'NR > 1 && $1 !~ /^[0-9]+([.][0-9]+)?[[:alpha:]]*$/ { bad++ } END { print bad+0 }' "$fixture/report")"
actual=$(awk -F '\t' 'BEGIN { OFS="\t" } NR > 1 { print $3, $4, $5, $6, $7, $8, $9 }' "$fixture/report" | sort)
assert_equal 'linked path identities and statuses' "$(sort "$fixture/expected-path-rows")" "$actual"
printf 'Failures: %s\n' "$failures"
[ "$failures" -eq 0 ]
