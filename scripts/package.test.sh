#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/pstack-package-test.XXXXXX")
fixture=$(cd "$fixture" && pwd -P)
trap 'rm -rf "$fixture"' EXIT
project="$fixture/project with spaces"
mkdir -p "$project/scripts"
tar -C "$root" --exclude=node_modules --exclude=.DS_Store -cf - \
  .agents/plugins/marketplace.json plugins/pstack-codex \
  README.md AGENTS.md UPSTREAM.md upstream.lock.json LICENSE .gitignore \
  scripts/package.sh | tar -xf - -C "$project"
plugin=plugins/pstack-codex
skill="$plugin/skills/poteto-mode"
unrelated=(
  scripts/maintenance.sh docs/development.md .agents/private.json
  plugins/other-plugin/SKILL.md "$plugin/notes.md"
  "$plugin/.codex-plugin/private.json" "$plugin/config/private.json"
  "$skill/notes.md" "$skill/agents/other.yaml" "$skill/scripts/scratch.mjs"
  "$skill/scripts/dist/scratch.mjs" "$skill/scripts/node_modules/example/index.js"
  "$skill/references/.DS_Store" "$skill/references/node_modules/example/index.js"
)
for path in "${unrelated[@]}"; do
  mkdir -p "$project/$(dirname "$path")"
  printf 'unrelated fixture\n' > "$project/$path"
done
mkdir -p "$project/$skill/assets"
printf 'runtime asset\n' > "$project/$skill/assets/example.txt"
archive=$(bash "$project/scripts/package.sh")
unzip -q "$archive" -d "$fixture/extracted"
unzip -Z1 "$archive" > "$fixture/entries.txt"
node - "$project" "$fixture/extracted/pstack-codex" "$fixture/entries.txt" "$archive" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const [source, extracted, entriesFile, archive] = process.argv.slice(2);
const plugin = 'plugins/pstack-codex';
const scripts = `${plugin}/skills/poteto-mode/scripts`;
const required = [
  '.agents/plugins/marketplace.json', 'LICENSE',
  `${plugin}/.codex-plugin/plugin.json`, `${plugin}/config/models.defaults.json`,
  `${scripts}/check-plan.mjs`, `${scripts}/read-thread.mjs`,
  `${scripts}/worktree-audit.sh`, `${scripts}/dist/watch-pr.mjs`,
  `${plugin}/skills/show-me-your-work/scripts/log.sh`,
];
const expectedFiles = [...required];
const resourceFiles = (relative) => {
  for (const entry of fs.readdirSync(path.join(source, relative), { withFileTypes: true })) {
    if (entry.name === 'node_modules' || entry.name === '.DS_Store') continue;
    const file = `${relative}/${entry.name}`;
    if (entry.isDirectory()) resourceFiles(file);
    else expectedFiles.push(file);
  }
};
resourceFiles(`${plugin}/licenses`);
const skills = fs.readdirSync(path.join(source, plugin, 'skills'));
assert.equal(skills.length, 49, 'fixture contains all 49 shipped skills');
for (const skill of skills) {
  const dir = `${plugin}/skills/${skill}`;
  expectedFiles.push(`${dir}/SKILL.md`, `${dir}/agents/openai.yaml`);
  for (const resource of ['references', 'playbooks', 'assets']) {
    if (fs.existsSync(path.join(source, dir, resource))) resourceFiles(`${dir}/${resource}`);
  }
}
const actualFiles = fs.readFileSync(entriesFile, 'utf8').trim().split('\n')
  .filter(entry => !entry.endsWith('/'))
  .map(entry => {
    assert.ok(entry.startsWith('pstack-codex/'), `archive root: ${entry}`);
    return entry.slice('pstack-codex/'.length);
  });
const expected = new Set(expectedFiles);
const unexpected = actualFiles.filter(file => !expected.has(file));
assert.deepEqual(unexpected, [], 'ZIP must exclude repository, development, and unrelated files');
assert.deepEqual(actualFiles.sort(), expectedFiles.sort(), 'ZIP contains every runtime file');
for (const file of expectedFiles) {
  assert.deepEqual(fs.readFileSync(path.join(extracted, file)), fs.readFileSync(path.join(source, file)), file);
}
const marketplace = JSON.parse(fs.readFileSync(path.join(extracted, '.agents/plugins/marketplace.json')));
assert.equal(marketplace.plugins[0].source.path, './plugins/pstack-codex');
const manifest = JSON.parse(fs.readFileSync(path.join(extracted, marketplace.plugins[0].source.path, '.codex-plugin/plugin.json')));
assert.equal(manifest.name, 'pstack-codex');
assert.equal(path.basename(archive), `pstack-codex-${manifest.version}.zip`);
console.log('PASS: ZIP preserves marketplace, licenses, all 49 skills, resources, and runtime scripts; excludes unrelated files.');
NODE
node "$fixture/extracted/pstack-codex/$skill/scripts/dist/watch-pr.mjs" --help > "$fixture/watch-pr-help.txt"
grep -q 'Usage: watch-pr' "$fixture/watch-pr-help.txt"
node "$fixture/extracted/pstack-codex/$skill/scripts/read-thread.mjs" --help > "$fixture/read-thread-help.txt"
grep -q 'Usage: node read-thread.mjs' "$fixture/read-thread-help.txt"
printf 'PASS: extracted watch-pr and read-thread helpers run without development dependencies.\n'
