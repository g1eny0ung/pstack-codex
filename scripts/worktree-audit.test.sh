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
printf '%s\n' "${PSTACK_TEST_PRS:-[]}"
EOF
chmod +x "$fixture/bin/gh"
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
for state in clean tracked untracked ignored mixed corrupt closed merged-pr open-pr; do
  wt="$fixture/$state"
  git -C "$repo" worktree add -q -b "$state" "$wt"
  case "$state" in
    tracked|mixed) printf 'valuable tracked edits\n' > "$wt/tracked" ;;
    closed|merged-pr|open-pr) git -C "$wt" commit -qm branch-work --allow-empty ;;
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
assert_row closed 8 BUCKET review
assert_row merged-pr 8 BUCKET safe
assert_row open-pr 8 BUCKET hold-open-pr
assert_equal 'TSV has nine columns' 9 "$(awk -F '\t' '{ print NF }' "$fixture/report" | sort -u)"
for state in clean tracked untracked ignored mixed corrupt closed merged-pr open-pr; do
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
unset PSTACK_TEST_PRS

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
