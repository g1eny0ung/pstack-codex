#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(node -p 'JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8")).version' "$root/plugins/pstack-codex/.codex-plugin/plugin.json")
[[ -f "$root/plugins/pstack-codex/skills/poteto-mode/scripts/dist/watch-pr.mjs" ]] || { printf 'Run bash scripts/build.sh first.\n' >&2; exit 1; }
staging=$(mktemp -d "${TMPDIR:-/tmp}/pstack-package.XXXXXX")
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/pstack-codex" "$root/dist"
tar -C "$root" --exclude=node_modules --exclude=.DS_Store -cf - .agents plugins scripts README.md AGENTS.md UPSTREAM.md upstream.lock.json LICENSE .gitignore | tar -xf - -C "$staging/pstack-codex"
archive="$root/dist/pstack-codex-$version.zip"
if [[ -e "$archive" ]]; then rm "$archive"; fi
cd "$staging"
zip -qr "$archive" pstack-codex
printf '%s\n' "$archive"
