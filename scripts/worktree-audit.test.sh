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
printf '%s\n' "${PSTACK_TEST_PRS:-[]}"
EOF
cat > "$fixture/bin/origin" <<'EOF'
#!/usr/bin/env bash
printf 'origin %s\n' "$*" >> "$PSTACK_TEST_CLI_LOG"
[ "${PSTACK_TEST_ORIGIN_AVAILABLE:-no}" = yes ] || exit 1
printf '%s\n' "${PSTACK_TEST_ORIGIN_PRS:-[]}"
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
for option in -b --base; do
  bash "$audit_script" "$option" origin/integration "$repo" > "$fixture/report" 2> "$fixture/stderr"
  assert_row main-unmerged 3 "$option integration base includes commit" YES
  assert_equal "$option base diagnostic" \
    'Merge base: origin/integration (local snapshot; this audit does not fetch)' \
    "$(sed -n '/^Merge base:/p' "$fixture/stderr")"
  assert_equal "$option TSV has nine columns" 9 "$(awk -F '\t' '{ print NF }' "$fixture/report" | sort -u)"
  assert_equal "$option one header and two worktrees" 3 "$(awk 'END { print NR }' "$fixture/report")"
  bash "$audit_script" "$option" origin/main "$repo" > "$fixture/report" 2> "$fixture/stderr"
  assert_row main-unmerged 3 "$option main base excludes commit" no
done
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
if bash "$audit_script" --base origin/missing "$repo" > "$fixture/report" 2> "$fixture/stderr"; then
  status=0
else
  status=$?
fi
assert_equal 'missing explicit base exit' 1 "$status"
assert_equal 'missing explicit base diagnostic' 'error: base ref not found: origin/missing' "$(cat "$fixture/stderr")"
assert_equal 'missing explicit base has no report' '' "$(cat "$fixture/report")"
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
for state in clean tracked untracked ignored mixed corrupt closed merged-pr open-pr draft-pr; do
  wt="$fixture/$state"
  git -C "$repo" worktree add -q -b "$state" "$wt"
  case "$state" in
    tracked|mixed) printf 'valuable tracked edits\n' > "$wt/tracked" ;;
    closed|merged-pr|open-pr|draft-pr) git -C "$wt" commit -qm branch-work --allow-empty ;;
  esac
  case "$state" in
    untracked|mixed) mkdir "$wt/notes"; printf 'valuable notes\n' > "$wt/notes/draft" ;;
  esac
  case "$state" in
    ignored|mixed) mkdir "$wt/ignored-data"; printf 'valuable ignored data\n' > "$wt/ignored-data/local.db" ;;
  esac
  index=$(git -C "$wt" rev-parse --git-path index)
  if [ "$state" = corrupt ]; then printf 'invalid index\n' > "$index"; fi
  touch -t 200101010101 "$wt/tracked"
  cp "$index" "$fixture/$state-index-before"
  cp -R "$wt" "$fixture/$state-before"
done
export PSTACK_TEST_PRS='[{"number":1,"state":"CLOSED","headRefName":"closed"},{"number":2,"state":"MERGED","headRefName":"merged-pr"},{"number":3,"state":"OPEN","headRefName":"open-pr"}]'
: > "$PSTACK_TEST_CLI_LOG"
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row clean 4 DIRTY clean
assert_row clean 8 BUCKET safe
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
assert_equal 'unavailable Origin falls back to gh' \
  $'origin pr list --author @me --state all --limit 1000 --json number,status,headRef\ngh pr list --author @me --state all --limit 1000 --json number,state,headRefName' \
  "$(cat "$PSTACK_TEST_CLI_LOG")"
assert_row closed 6 'gh closed state normalized' '#1/closed'
assert_row merged-pr 6 'gh merged state normalized' '#2/merged'
assert_row open-pr 6 'gh open state normalized' '#3/open'
assert_row draft-pr 8 'unmerged without PR evidence' review
assert_row closed 8 BUCKET review
assert_row merged-pr 8 BUCKET safe
assert_row open-pr 8 BUCKET hold-open-pr
assert_equal 'TSV has nine columns' 9 "$(awk -F '\t' '{ print NF }' "$fixture/report" | sort -u)"
for state in clean tracked untracked ignored mixed corrupt closed merged-pr open-pr draft-pr; do
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
export PSTACK_TEST_ORIGIN_AVAILABLE=yes
export PSTACK_TEST_ORIGIN_PRS='[{"number":11,"status":"closed","headRef":"closed"},{"number":12,"status":"merged","headRef":"merged-pr"},{"number":13,"status":"open","headRef":"open-pr"},{"number":14,"status":"draft","headRef":"draft-pr"}]'
: > "$PSTACK_TEST_CLI_LOG"
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_equal 'usable Origin is preferred over gh' \
  'origin pr list --author @me --state all --limit 1000 --json number,status,headRef' \
  "$(cat "$PSTACK_TEST_CLI_LOG")"
assert_row closed 6 'Origin closed PR' '#11/closed'
assert_row closed 8 'Origin closed unmerged PR' review
assert_row merged-pr 6 'Origin merged PR' '#12/merged'
assert_row merged-pr 8 'Origin merged clean PR' safe
assert_row open-pr 6 'Origin open PR' '#13/open'
assert_row open-pr 8 'Origin open PR holds' hold-open-pr
assert_row draft-pr 6 'Origin draft PR' '#14/draft'
assert_row draft-pr 8 'Origin draft PR holds' hold-open-pr
assert_row tracked 8 'Origin preserves tracked hold' hold-wip
assert_row untracked 8 'Origin preserves untracked hold' hold-untracked
assert_row ignored 8 'Origin preserves ignored hold' hold-ignored
assert_row corrupt 8 'Origin preserves unknown hold' hold-unknown
unset PSTACK_TEST_PRS PSTACK_TEST_ORIGIN_AVAILABLE PSTACK_TEST_ORIGIN_PRS

git -C "$repo" remote add alternate "$source_repo"
git -C "$repo" fetch -q alternate
for state in pushed ahead behind diverged missing-upstream no-upstream detached; do
  wt="$fixture/remote-$state"
  if [ "$state" = detached ]; then
    git -C "$repo" worktree add -q --detach "$wt" main
  else
    git -C "$repo" worktree add -q -b "local-$state" "$wt" main
    if [ "$state" != no-upstream ]; then
      git -C "$wt" branch -q --set-upstream-to=alternate/main
    fi
  fi
  case "$state" in ahead|diverged) git -C "$wt" commit -qm local-work --allow-empty ;; esac
done
git -C "$source_repo" commit -qm remote-work --allow-empty
git -C "$repo" fetch -q alternate
git -C "$fixture/remote-pushed" reset -q --hard alternate/main
git -C "$fixture/remote-ahead" rebase -q alternate/main
git -C "$repo" update-ref refs/remotes/alternate/deleted main
git -C "$fixture/remote-missing-upstream" branch -q --set-upstream-to=alternate/deleted
git -C "$repo" update-ref -d refs/remotes/alternate/deleted
git -C "$repo" update-ref refs/remotes/origin/local-no-upstream main
git -C "$repo" update-ref refs/remotes/origin/local-behind main
git -C "$repo" show-ref > "$fixture/before-refs"
cp "$repo/.git/FETCH_HEAD" "$fixture/before-fetch-head"
bash "$audit_script" "$repo" > "$fixture/report" 2> "$fixture/stderr"
assert_row remote-pushed 5 REMOTE pushed
assert_row remote-ahead 5 REMOTE ahead1/behind0
assert_row remote-behind 5 REMOTE ahead0/behind1
assert_row remote-diverged 5 REMOTE ahead1/behind1
assert_row remote-missing-upstream 5 REMOTE no-upstream
assert_row remote-no-upstream 5 REMOTE no-upstream
assert_row remote-detached 5 REMOTE detached
git -C "$repo" show-ref > "$fixture/after-refs"
assert_unchanged 'configured upstream refs' "$fixture/before-refs" "$fixture/after-refs"
assert_unchanged FETCH_HEAD "$fixture/before-fetch-head" "$repo/.git/FETCH_HEAD"

for primary in newline tab trailing-newline; do
  case "$primary" in
    newline) repo="$fixture/"$'primary\nnewline' ;;
    tab) repo="$fixture/"$'primary\ttab' ;;
    trailing-newline) repo="$fixture/"$'primary-trailing\n' ;;
  esac
  git clone -q "$source_repo" "$repo"
  for linked in newline tab trailing-newline space; do
    case "$linked" in
      newline) wt="$fixture/$primary-"$'linked\nnewline' ;;
      tab) wt="$fixture/$primary-"$'linked\ttab' ;;
      trailing-newline) wt="$fixture/$primary-"$'linked-trailing\n' ;;
      space) wt="$fixture/$primary-linked space" ;;
    esac
    git -C "$repo" worktree add -q -b "$linked" "$wt"
    dirty=clean
    bucket=safe
    case "$linked" in
      tab) printf 'changed\n' > "$wt/tracked"; dirty=wip:1; bucket=hold-wip ;;
      trailing-newline) printf 'notes\n' > "$wt/notes"; dirty=untracked:1; bucket=hold-untracked ;;
    esac
    case "$linked" in
      newline) displayed="\$'$fixture/$primary-linked\\nnewline'" ;;
      tab) displayed="\$'$fixture/$primary-linked\\ttab'" ;;
      trailing-newline) displayed="\$'$fixture/$primary-linked-trailing\\n'" ;;
      space) displayed="$wt" ;;
    esac
    printf 'YES\t%s\tno-upstream\t-\tunknown\t%s\t%s\n' "$dirty" "$bucket" "$displayed"
  done > "$fixture/expected-path-rows"
  bash "$audit_script" "$wt" > "$fixture/report" 2> "$fixture/stderr"
  assert_equal "$primary primary excluded, four linked rows" 5 "$(awk 'END { print NR }' "$fixture/report")"
  assert_equal "$primary paths have nine TSV cells" 9 "$(awk -F '\t' '{ print NF }' "$fixture/report" | sort -u)"
  assert_equal "$primary sizes contain only a size" 0 "$(awk -F '\t' 'NR > 1 && $1 !~ /^[0-9]+([.][0-9]+)?[[:alpha:]]*$/ { bad++ } END { print bad+0 }' "$fixture/report")"
  actual=$(awk -F '\t' 'BEGIN { OFS="\t" } NR > 1 { print $3, $4, $5, $6, $7, $8, $9 }' "$fixture/report" | sort)
  assert_equal "$primary linked path identities and statuses" "$(sort "$fixture/expected-path-rows")" "$actual"
done
printf 'Failures: %s\n' "$failures"
[ "$failures" -eq 0 ]
