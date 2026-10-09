#!/usr/bin/env bash
set -Eeuo pipefail
trap 'exit 1' ERR

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
lock="$root/upstream.lock.json"
usage() {
  cat <<'EOF'
Usage: bash scripts/upstream.sh check
       bash scripts/upstream.sh prepare --commit <full SHA>

Compare the last synced upstream commit with main, or prepare three-way materials.
Neither command edits plugin files or advances upstream.lock.json.
Exit status: 0 no adapted-file impact, 2 human review required, 1 inspection failed.
PSTACK_UPSTREAM_WORKDIR overrides the cache/materials directory.
PSTACK_UPSTREAM_REPOSITORY optionally selects a Git mirror (also used by tests).
EOF
}
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
field() {
  local value
  value=$(sed -nE 's/^[[:space:]]*"'"$1"'"[[:space:]]*:[[:space:]]*"([^"\\]*)"[[:space:]]*,?[[:space:]]*$/\1/p' "$lock")
  [[ -n "$value" && "$value" != *$'\n'* ]] || die "Invalid or repeated $1 in $lock"
  printf '%s' "$value"
}
command_name=${1:-help}
case "$command_name" in
  help|-h|--help) usage; exit 0 ;;
  check) [[ $# == 1 ]] || die 'check accepts no arguments' ;;
  prepare) [[ $# == 3 && "$2" == --commit ]] || die 'prepare requires --commit <full SHA>' ;;
  *) usage >&2; exit 1 ;;
esac
[[ -f "$lock" ]] || die "Missing $lock"
repository=${PSTACK_UPSTREAM_REPOSITORY:-$(field repository)}
branch=$(field branch)
base=$(field last_synced_commit)
initial=$(field initial_commit)
[[ "$base" =~ ^[0-9a-f]{40}$ && "$initial" =~ ^[0-9a-f]{40}$ ]] || die 'Expected full 40-character commit IDs'
git check-ref-format "refs/heads/$branch" >/dev/null || die 'Invalid upstream branch'
workdir=${PSTACK_UPSTREAM_WORKDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/pstack-codex/upstream}
mkdir -p "$workdir"
workdir=$(cd "$workdir" && pwd)
cache="$workdir/repository.git"
if [[ ! -d "$cache" ]]; then git init --bare -q "$cache"; fi
g() { git --git-dir="$cache" "$@"; }
if g remote get-url origin >/dev/null 2>&1; then
  [[ "$(g remote get-url origin)" == "$repository" ]] || die 'Cache belongs to a different repository; select another PSTACK_UPSTREAM_WORKDIR'
else
  g remote add origin "$repository"
fi
g fetch --quiet origin "+refs/heads/$branch:refs/remotes/origin/$branch"
if ! g cat-file -e "$base^{commit}" 2>/dev/null; then g fetch --quiet origin "$base"; fi
g cat-file -e "$base^{commit}" || die 'Synced baseline is not a commit'
if [[ "$command_name" == prepare ]]; then
  target=$3
  [[ "$target" =~ ^[0-9a-f]{40}$ ]] || die 'prepare requires a full 40-character commit ID'
  if ! g cat-file -e "$target^{commit}" 2>/dev/null; then g fetch --quiet origin "$target"; fi
  [[ "$(g rev-parse "$target^{commit}")" == "$target" ]] || die 'Target is not a commit'
else
  target=$(g rev-parse "refs/remotes/origin/$branch^{commit}")
fi
scratch=$(mktemp -d "$workdir/inspection.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
paths=(pstack cursor-team-kit/skills/deslop cursor-team-kit/skills/control-cli cursor-team-kit/skills/control-ui cursor-team-kit/LICENSE)
classify() {
  local path=$1 relative name
  case "$path" in
    pstack/skills/poteto-mode/scripts/orch/*|pstack/skills/poteto-mode/playbooks/orchestrate.md|pstack/skills/poteto-mode/playbooks/autopilot-full.md|pstack/skills/poteto-mode/playbooks/autopilot-stack.md) printf 'excluded-cloud'; return ;;
    pstack/skills/*)
      relative=${path#pstack/skills/}; name=${relative%%/*}
      if [[ -f "$root/plugins/pstack-codex/skills/$name/SKILL.md" ]]; then printf 'migrated'; else printf 'new-or-out-of-scope'; fi ;;
    cursor-team-kit/skills/deslop/*|cursor-team-kit/skills/control-cli/*|cursor-team-kit/skills/control-ui/*|pstack/agents/poteto-agent.md|pstack/agents/comment-sicko.md|pstack/LICENSE|cursor-team-kit/LICENSE) printf 'migrated' ;;
    *) printf 'new-or-out-of-scope' ;;
  esac
}
g diff --name-status -z --find-renames "$base" "$target" -- "${paths[@]}" > "$scratch/changes.nul"
[[ -f "$root/scripts/check-adaptation-impact.py" && -r "$root/scripts/check-adaptation-impact.py" ]] || die 'Missing or unreadable adaptation impact checker'
impact_status=0
python3 "$root/scripts/check-adaptation-impact.py" --git-dir "$cache" --base "$base" --target "$target" > "$scratch/adaptations.txt" || impact_status=$?
case "$impact_status" in
  0|2) ;;
  *) exit 1 ;;
esac
report() {
  local status first second
  printf 'Repository: %s\nBaseline: %s\nTarget: %s\n\nRelevant commits:\n' "$repository" "$base" "$target"
  g log --oneline "$base..$target" -- "${paths[@]}"
  printf '\nChanges (category, status, path):\n'
  while IFS= read -r -d '' status; do
    IFS= read -r -d '' first || die 'Incomplete Git diff'
    case "$status" in
      R*|C*)
        IFS= read -r -d '' second || die 'Incomplete Git rename'
        printf '%s -> %s\t%s\t%q -> %q\n' "$(classify "$first")" "$(classify "$second")" "$status" "$first" "$second" ;;
      *) printf '%s\t%s\t%q\n' "$(classify "$first")" "$status" "$first" ;;
    esac
  done < "$scratch/changes.nul"
  printf '\n'
  cat "$scratch/adaptations.txt"
}
report > "$scratch/report.txt"
cat "$scratch/report.txt"
if [[ "$command_name" == prepare ]]; then
  mkdir -p "$workdir/prepared"
  material=$(mktemp -d "$workdir/prepared/${base:0:12}-${target:0:12}.XXXXXX")
  export_snapshot() {
    local revision=$1 destination=$2 path
    local available=()
    mkdir -p "$destination"
    g ls-tree --name-only -z "$revision" -- "${paths[@]}" > "$scratch/snapshot-paths.nul"
    while IFS= read -r -d '' path; do
      available+=("$path")
    done < "$scratch/snapshot-paths.nul"
    if [[ ${#available[@]} -gt 0 ]]; then
      g archive "$revision" -- "${available[@]}" | tar -xf - -C "$destination"
    fi
  }
  export_snapshot "$base" "$material/base-upstream"
  export_snapshot "$target" "$material/target-upstream"
  mkdir -p "$material/local-codex"
  tar -C "$root/plugins" --exclude=node_modules --exclude=.DS_Store -cf - pstack-codex | tar -xf - -C "$material/local-codex"
  cp "$scratch/report.txt" "$material/changes.txt"
  printf '%s\n' 'Read UPSTREAM.md for path mappings. These are comparison materials, not an automatic merge.' > "$material/README.txt"
  printf '\nPrepared: %s\n' "$material"
fi
printf '\nPlugin files and synced baseline were not modified.\n'
exit "$impact_status"
