#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/pstack-upstream-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
upstream="$fixture/upstream"
project="$fixture/project with spaces"
mkdir -p "$upstream" "$project/scripts" "$project/plugins/pstack-codex/skills/poteto-mode"
cp "$root/scripts/upstream.sh" "$project/scripts/"
cp "$root/scripts/check-adaptation-impact.py" "$project/scripts/"
expect_status() {
  local expected=$1 output=$2 actual=0
  shift 2
  "$@" > "$output" 2>&1 || actual=$?
  if [[ "$actual" != "$expected" ]]; then
    cat "$output" >&2
    printf 'Expected status %s, got %s for %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  fi
  printf 'Passed %s (exit %s)\n' "${output##*/}" "$actual"
}
commit_changes() {
  git -C "$upstream" add -A
  git -C "$upstream" commit -qm "$1"
}
reset_upstream() { git -C "$upstream" reset --hard -q "$base"; }
touch "$project/plugins/pstack-codex/skills/poteto-mode/SKILL.md"
git init -q -b main "$upstream"
git -C "$upstream" config user.name Fixture
git -C "$upstream" config user.email fixture@example.invalid
mkdir -p "$upstream/pstack/skills/poteto-mode/scripts/orch"
printf 'before\n' > "$upstream/pstack/skills/poteto-mode/SKILL.md"
printf 'delete\n' > "$upstream/pstack/skills/poteto-mode/delete.md"
printf 'rename\n' > "$upstream/pstack/skills/poteto-mode/old name.md"
mkdir -p "$upstream/pstack/skills/benchmark-checklist"
printf 'benchmark original\nunchanged advice\n' > "$upstream/pstack/skills/benchmark-checklist/SKILL.md"
printf '#!/bin/bash\naudit original\n' > "$upstream/pstack/skills/poteto-mode/scripts/worktree-audit.sh"
commit_changes baseline
base=$(git -C "$upstream" rev-parse HEAD)
cat > "$project/upstream.lock.json" <<EOF
{
  "repository": "https://github.com/cursor/plugins.git",
  "branch": "main",
  "initial_commit": "$base",
  "last_synced_commit": "$base"
}
EOF
cp "$project/upstream.lock.json" "$fixture/original.lock"
python3 - "$upstream" "$project" "$base" <<'PYTHON'
import hashlib
import json
import sys
from pathlib import Path
upstream, project = map(Path, sys.argv[1:3])
files = []
for name, reason in (
    ('benchmark-checklist/SKILL.md', 'Preserve benchmark evidence for Codex.'),
    ('poteto-mode/scripts/worktree-audit.sh', 'Preserve portable Bash worktree audit.'),
    ('poteto-mode/SKILL.md', None),
):
    source = 'pstack/skills/' + name
    files.append(dict(source=source, target='skills/' + name,
                      source_sha256=hashlib.sha256((upstream / source).read_bytes()).hexdigest(),
                      edits=[] if reason is None else [dict(old='original', new='adapted', count=1, kind='host', reason=reason)]))
(project / 'scripts/port-adaptations.json').write_text(json.dumps(dict(version=1, upstream_commit=sys.argv[3], files=files)))
PYTHON
cp "$project/scripts/port-adaptations.json" "$fixture/original.manifest"
cp -R "$project/plugins" "$fixture/original-plugins"
printf 'after\n' > "$upstream/pstack/skills/poteto-mode/SKILL.md"
rm "$upstream/pstack/skills/poteto-mode/delete.md"
mv "$upstream/pstack/skills/poteto-mode/old name.md" "$upstream/pstack/skills/poteto-mode/new name.md"
printf 'excluded\n' > "$upstream/pstack/skills/poteto-mode/scripts/orch/new.ts"
mkdir -p "$upstream/pstack/skills/new-skill"
printf 'new\n' > "$upstream/pstack/skills/new-skill/SKILL.md"
git -C "$upstream" add .
git -C "$upstream" commit -qm changes
target=$(git -C "$upstream" rev-parse HEAD)
export PSTACK_UPSTREAM_REPOSITORY="$upstream" PSTACK_UPSTREAM_WORKDIR="$fixture/cache with spaces"
expect_status 0 "$fixture/report" bash "$project/scripts/upstream.sh" check
grep -q 'No recorded adaptations affected' "$fixture/report"
grep -q 'migrated.*M.*SKILL.md' "$fixture/report"
grep -q 'migrated.*D.*delete.md' "$fixture/report"
grep -q 'R100.*old.*new' "$fixture/report"
grep -q 'excluded-cloud.*orch/new.ts' "$fixture/report"
grep -q 'new-or-out-of-scope.*new-skill' "$fixture/report"
cmp "$project/upstream.lock.json" "$fixture/original.lock"
bash "$project/scripts/upstream.sh" prepare --commit "$target" > "$fixture/prepare-report"
material=$(sed -n 's/^Prepared: //p' "$fixture/prepare-report")
test -f "$material/base-upstream/pstack/skills/poteto-mode/delete.md"
test ! -f "$material/target-upstream/pstack/skills/poteto-mode/delete.md"
test -f "$material/target-upstream/pstack/skills/poteto-mode/new name.md"
test -f "$material/local-codex/pstack-codex/skills/poteto-mode/SKILL.md"
cmp "$project/upstream.lock.json" "$fixture/original.lock"
if bash "$project/scripts/upstream.sh" prepare --commit invalid >/dev/null 2>&1; then
  printf 'Invalid commit unexpectedly accepted\n' >&2; exit 1
fi
cmp "$project/upstream.lock.json" "$fixture/original.lock"
reset_upstream
expect_status 0 "$fixture/unchanged" bash "$project/scripts/upstream.sh" check
grep -q 'No recorded adaptations affected' "$fixture/unchanged"

printf 'upstream advice changed\n' >> "$upstream/pstack/skills/benchmark-checklist/SKILL.md"
commit_changes 'adapted modification outside replacement'
expect_status 2 "$fixture/adapted-modification" bash "$project/scripts/upstream.sh" check
grep -q 'ADAPTATION_REVIEW_REQUIRED' "$fixture/adapted-modification"
grep -q 'pstack/skills/benchmark-checklist/SKILL.md' "$fixture/adapted-modification"
grep -q 'plugins/pstack-codex/skills/benchmark-checklist/SKILL.md' "$fixture/adapted-modification"
grep -q 'Preserve benchmark evidence for Codex.' "$fixture/adapted-modification"
target=$(git -C "$upstream" rev-parse HEAD)
expect_status 2 "$fixture/adapted-prepare" bash "$project/scripts/upstream.sh" prepare --commit "$target"
material=$(sed -n 's/^Prepared: //p' "$fixture/adapted-prepare")
test -f "$material/base-upstream/pstack/skills/benchmark-checklist/SKILL.md"
grep -q 'upstream advice changed' "$material/target-upstream/pstack/skills/benchmark-checklist/SKILL.md"
test -f "$material/local-codex/pstack-codex/skills/poteto-mode/SKILL.md"
grep -q 'Changes (category, status, path)' "$material/changes.txt"
grep -q 'ADAPTATION_REVIEW_REQUIRED' "$material/changes.txt"
grep -q 'Preserve benchmark evidence for Codex.' "$material/changes.txt"
python3 - "$fixture/adapted-modification" "$material/changes.txt" <<'PYTHON'
import sys
from pathlib import Path
report = Path(sys.argv[1]).read_text()
impact = report[report.index('ADAPTATION_REVIEW_REQUIRED'):report.index('\nPlugin files and synced baseline')].strip()
assert impact in Path(sys.argv[2]).read_text(), 'Prepared changes must contain the exact adaptation report'
PYTHON

reset_upstream
rm "$upstream/pstack/skills/poteto-mode/scripts/worktree-audit.sh"
commit_changes 'adapted deletion'
expect_status 2 "$fixture/adapted-deletion" bash "$project/scripts/upstream.sh" check
grep -q 'Preserve portable Bash worktree audit.' "$fixture/adapted-deletion"
grep -q 'D.*pstack/skills/poteto-mode/scripts/worktree-audit.sh' "$fixture/adapted-deletion"

reset_upstream
mkdir -p "$upstream/outside watched roots"
mv "$upstream/pstack/skills/poteto-mode/scripts/worktree-audit.sh" "$upstream/outside watched roots/audit renamed.sh"
commit_changes 'adapted rename outside watched roots'
expect_status 2 "$fixture/adapted-rename" bash "$project/scripts/upstream.sh" check
grep -q 'R100.*pstack/skills/poteto-mode/scripts/worktree-audit.sh.*outside watched roots/audit renamed.sh' "$fixture/adapted-rename"
grep -q 'Preserve portable Bash worktree audit.' "$fixture/adapted-rename"

reset_upstream
chmod +x "$upstream/pstack/skills/poteto-mode/scripts/worktree-audit.sh"
git -C "$upstream" update-index --chmod=+x pstack/skills/poteto-mode/scripts/worktree-audit.sh
commit_changes 'adapted mode change'
expect_status 2 "$fixture/adapted-mode" bash "$project/scripts/upstream.sh" check

reset_upstream
rm "$upstream/pstack/skills/poteto-mode/scripts/worktree-audit.sh"
ln -s ../SKILL.md "$upstream/pstack/skills/poteto-mode/scripts/worktree-audit.sh"
commit_changes 'adapted type change'
expect_status 2 "$fixture/adapted-type" bash "$project/scripts/upstream.sh" check
grep -q 'T.*pstack/skills/poteto-mode/scripts/worktree-audit.sh' "$fixture/adapted-type"
reset_upstream

for problem in missing malformed version baseline hash reason files empty edits source target duplicate; do
  cp "$fixture/original.manifest" "$project/scripts/port-adaptations.json"
  python3 - "$project/scripts/port-adaptations.json" "$problem" <<'PYTHON'
import json
import sys
from pathlib import Path
path, problem = Path(sys.argv[1]), sys.argv[2]
manifest = json.loads(path.read_text())
if problem == 'missing':
    path.unlink()
elif problem == 'malformed':
    path.write_text('{')
else:
    if problem == 'version': manifest['version'] = 2
    elif problem == 'baseline': manifest['upstream_commit'] = '0' * 40
    elif problem == 'hash': manifest['files'][0]['source_sha256'] = '0' * 64
    elif problem == 'reason': manifest['files'][0]['edits'][0]['reason'] = ' '
    elif problem == 'files': manifest['files'] = {}
    elif problem == 'empty': manifest['files'] = []
    elif problem == 'edits': manifest['files'][0]['edits'] = None
    elif problem == 'source': manifest['files'][0]['source'] = 'missing/source'
    elif problem == 'target': manifest['files'][0]['target'] = '../escape'
    elif problem == 'duplicate': manifest['files'].append(manifest['files'][0])
    path.write_text(json.dumps(manifest))
PYTHON
  expect_status 1 "$fixture/invalid-$problem" bash "$project/scripts/upstream.sh" check
  grep -q 'Error:' "$fixture/invalid-$problem"
  expect_status 1 "$fixture/invalid-prepare-$problem" bash "$project/scripts/upstream.sh" prepare --commit "$base"
done
cp "$fixture/original.manifest" "$project/scripts/port-adaptations.json"

mv "$project/scripts/check-adaptation-impact.py" "$fixture/saved-impact-checker.py"
expect_status 1 "$fixture/missing-checker" bash "$project/scripts/upstream.sh" check
expect_status 1 "$fixture/missing-prepare-checker" bash "$project/scripts/upstream.sh" prepare --commit "$base"
grep -q 'Missing or unreadable adaptation impact checker' "$fixture/missing-checker"
grep -q 'Missing or unreadable adaptation impact checker' "$fixture/missing-prepare-checker"
mv "$fixture/saved-impact-checker.py" "$project/scripts/check-adaptation-impact.py"

mkdir -p "$fixture/bin"
real_git=$(command -v git)
cat > "$fixture/bin/git" <<'EOF_GIT'
#!/usr/bin/env bash
for arg in "$@"; do
  if [[ "$arg" == "$FAIL_GIT_COMMAND" ]]; then
    printf 'injected Git failure\n' >&2
    exit 73
  fi
done
exec "$REAL_GIT" "$@"
EOF_GIT
chmod +x "$fixture/bin/git"
for failure in diff log ls-tree archive; do
  expect_status 1 "$fixture/git-$failure" env PATH="$fixture/bin:$PATH" REAL_GIT="$real_git" FAIL_GIT_COMMAND="$failure" bash "$project/scripts/upstream.sh" prepare --commit "$base"
  grep -q 'injected Git failure' "$fixture/git-$failure"
done
cmp "$project/upstream.lock.json" "$fixture/original.lock"
expect_status 1 "$fixture/git-archive-pending-review" env PATH="$fixture/bin:$PATH" REAL_GIT="$real_git" FAIL_GIT_COMMAND=archive bash "$project/scripts/upstream.sh" prepare --commit "$target"
cmp "$project/scripts/port-adaptations.json" "$fixture/original.manifest"
diff -r "$project/plugins" "$fixture/original-plugins"
printf 'Upstream classification, adaptation review, preparation, invalid-input and Git-failure checks passed.\n'
