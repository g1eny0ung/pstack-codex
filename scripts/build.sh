#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tool_dir="$root/plugins/pstack-codex/skills/poteto-mode/scripts"
command -v bun >/dev/null || { printf 'Bun is required to build; release users only need Node.js.\n' >&2; exit 1; }
cd "$tool_dir"
bun install --frozen-lockfile
mkdir -p dist
entry="$tool_dir/watch-pr/.build-entry.ts"
trap 'rm -f "$entry"' EXIT
cp ./watch-pr/watch-pr "$entry"
bun build --target=node "$entry" --outfile ./dist/watch-pr.mjs
mkdir -p "$root/plugins/pstack-codex/licenses"
cp node_modules/commander/LICENSE "$root/plugins/pstack-codex/licenses/commander-MIT.txt"
printf 'Built %s\n' "$tool_dir/dist/watch-pr.mjs"
