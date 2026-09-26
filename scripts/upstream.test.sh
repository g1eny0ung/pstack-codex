#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/pstack-upstream-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
upstream="$fixture/upstream"
project="$fixture/project with spaces"
mkdir -p "$upstream" "$project/scripts" "$project/plugins/pstack-codex/skills/poteto-mode"
cp "$root/scripts/upstream.sh" "$project/scripts/"
touch "$project/plugins/pstack-codex/skills/poteto-mode/SKILL.md"
git init -q -b main "$upstream"
git -C "$upstream" config user.name Fixture
git -C "$upstream" config user.email fixture@example.invalid
mkdir -p "$upstream/pstack/skills/poteto-mode/scripts/orch"
printf 'before\n' > "$upstream/pstack/skills/poteto-mode/SKILL.md"
printf 'delete\n' > "$upstream/pstack/skills/poteto-mode/delete.md"
printf 'rename\n' > "$upstream/pstack/skills/poteto-mode/old name.md"
git -C "$upstream" add .
git -C "$upstream" commit -qm baseline
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
bash "$project/scripts/upstream.sh" check > "$fixture/report"
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
printf 'Upstream change, deletion, rename, preparation and baseline checks passed.\n'
