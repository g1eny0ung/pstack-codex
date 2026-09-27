# Upstream tracking

Repository: `https://github.com/cursor/plugins.git`

Branch: `main`

Initial and last synced commit: `ecc249f1e306fc64ddf83c7bed16cacf7c2239db`

`upstream.lock.json` is the machine-readable baseline. `initial_commit` is immutable. Update `last_synced_commit` only after actually integrating and validating a chosen revision. Merely checking upstream never advances it.

## Source mappings

| Upstream | Local |
|---|---|
| `pstack/skills/<selected-skill>/` | `plugins/pstack-codex/skills/<selected-skill>/` |
| `cursor-team-kit/skills/deslop/` | `plugins/pstack-codex/skills/deslop/` |
| `cursor-team-kit/skills/control-cli/` | `plugins/pstack-codex/skills/control-cli/` |
| `cursor-team-kit/skills/control-ui/` | `plugins/pstack-codex/skills/control-ui/` |
| `pstack/agents/poteto-agent.md` | `plugins/pstack-codex/skills/poteto-mode/references/poteto-agent.md` |
| `pstack/agents/comment-sicko.md` | `plugins/pstack-codex/skills/no-comments/references/comment-sicko.md` |
| `pstack/LICENSE` | `plugins/pstack-codex/licenses/pstack-MIT.txt` |
| `cursor-team-kit/LICENSE` | `plugins/pstack-codex/licenses/cursor-team-kit-MIT.txt` |

Selected pstack entries are `poteto-mode`, `how`, `why`, `architect`, `arena`, `swarm`, `interrogate`, `figure-it-out`, `show-me-your-work`, `reflect`, `tdd`, `no-comments`, `typescript-best-practices`, `technical-writing`, `unslop`, `setup-pstack`, and the following 23 principles:

- `principle-attack-the-premise`
- `principle-boundary-discipline`
- `principle-build-the-lever`
- `principle-encode-lessons-in-structure`
- `principle-exhaust-the-design-space`
- `principle-experience-first`
- `principle-fix-root-causes`
- `principle-foundational-thinking`
- `principle-guard-the-context-window`
- `principle-laziness-protocol`
- `principle-make-operations-idempotent`
- `principle-migrate-callers-then-delete-legacy-apis`
- `principle-minimize-reader-load`
- `principle-model-the-domain`
- `principle-never-block-on-the-human`
- `principle-outcome-oriented-execution`
- `principle-prove-it-works`
- `principle-redesign-from-first-principles`
- `principle-separate-before-serializing-shared-state`
- `principle-sequence-verifiable-units`
- `principle-subtract-before-you-add`
- `principle-test-behavior-not-implementation`
- `principle-type-system-discipline`

## Exclusions

Do not reintroduce these cloud orchestration resources:

- `pstack/skills/poteto-mode/playbooks/orchestrate.md`
- `pstack/skills/poteto-mode/playbooks/autopilot-full.md`
- `pstack/skills/poteto-mode/playbooks/autopilot-stack.md`
- `pstack/skills/poteto-mode/scripts/orch/`

The standalone skills `automate-me`, `blast-radius`, `bro`, `create-verification-skill`, `maintain-verification-skill`, `make-bot-ui`, `recall`, and `teach` are outside this port's scope. Other cursor-team-kit skills are also excluded. New upstream skills must be reported for selection, not added automatically.

## Adaptation rules to preserve

- Native Codex local subagents replace Cursor Task APIs. Role instructions are references, not global agent installations.
- Explicit-only `agents/openai.yaml` metadata applies to all 42 entries.
- Model defaults remain GPT-6 Astra; interrogate uses `ultra/xhigh/high`, writing `medium`, normal work `high`, complex synthesis and judges `xhigh`. User overrides remain outside the cache.
- Review findings are adjudicated by evidence, without vote counting or tier precedence.
- The 20 retained playbooks use local execution, actual available tools, and task-specific concurrency.
- Read session history through `read-thread.mjs`; do not restore Cursor paths or scan unrelated conversations.
- Keep `worktree-audit.sh` and `scripts/upstream.sh` in Bash. Preserve portable quoting and command choices.
- Bundle watch-pr with Bun at release time for Node; do not install runtime dependencies in the plugin cache.
- Preserve the user's authorization boundaries. Skills do not grant themselves permission to publish, message others, schedule work, or mutate unrelated resources.
- Keep source and dependency license notices. Mentions of Cursor in attribution or bot recognition are not runtime dependencies.

## Check and prepare

`bash scripts/upstream.sh check` fetches the selected upstream branch and compares it with `last_synced_commit`. It watches all of pstack, the three selected cursor-team-kit directories, and their license. Output labels migrated content, excluded cloud content, and new/out-of-scope content; deletions and renames remain visible. The Git cache defaults to `${XDG_CACHE_HOME:-$HOME/.cache}/pstack-codex/upstream` and can be set with `PSTACK_UPSTREAM_WORKDIR`.

`bash scripts/upstream.sh prepare --commit <full-SHA>` creates three directories in that maintenance cache:

1. `base-upstream`: the last synced upstream version.
2. `target-upstream`: the requested upstream version.
3. `local-codex`: the current migrated plugin, excluding development dependencies.

`changes.txt` records the comparison. Upstream snapshots intentionally include excluded content for review; they are not installable plugin output. The script never overwrites source files or edits the lock. Repeated preparation creates a separate directory rather than overwriting earlier work.

Review changes using the mappings above, port selected fixes, check renames/deletions and references, rebuild changed runtime code, and validate the affected behavior. Update the lock and this log only when synchronization is complete. If interrupted, leave the previous baseline in place. No scheduled upstream monitor is installed.

## Synchronization log

| Date | Baseline | Result |
|---|---|---|
| 2026-09-26 | `ecc249f1e306fc64ddf83c7bed16cacf7c2239db` | Initial local-workflow Codex port. |
