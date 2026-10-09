#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(node -p 'JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8")).version' "$root/plugins/pstack-codex/.codex-plugin/plugin.json")
[[ -f "$root/plugins/pstack-codex/skills/poteto-mode/scripts/dist/watch-pr.mjs" ]] || { printf 'Run bash scripts/build.sh first.\n' >&2; exit 1; }
staging=$(mktemp -d "${TMPDIR:-/tmp}/pstack-package.XXXXXX")
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/pstack-codex" "$root/dist"
plugin=plugins/pstack-codex
inputs=(
  .agents/plugins/marketplace.json
  LICENSE
  "$plugin/.codex-plugin/plugin.json"
  "$plugin/config/models.defaults.json"
  "$plugin/licenses"
  "$plugin/skills/poteto-mode/scripts/check-plan.mjs"
  "$plugin/skills/poteto-mode/scripts/read-thread.mjs"
  "$plugin/skills/poteto-mode/scripts/worktree-audit.sh"
  "$plugin/skills/poteto-mode/scripts/dist/watch-pr.mjs"
  "$plugin/skills/show-me-your-work/scripts/log.sh"
)
for skill in "$root/$plugin/skills/"*/SKILL.md; do
  skill=${skill#"$root/"}
  skill=${skill%/SKILL.md}
  inputs+=("$skill/SKILL.md" "$skill/agents/openai.yaml")
  for resource in references playbooks assets; do
    if [[ -d "$root/$skill/$resource" ]]; then inputs+=("$skill/$resource"); fi
  done
done
tar -C "$root" --exclude=node_modules --exclude=.DS_Store -cf - "${inputs[@]}" | tar -xf - -C "$staging/pstack-codex"
archive="$root/dist/pstack-codex-$version.zip"
if [[ -e "$archive" ]]; then rm "$archive"; fi
cd "$staging"
zip -qr "$archive" pstack-codex
printf '%s\n' "$archive"
