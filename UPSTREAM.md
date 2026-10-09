# Upstream tracking

Repository: `https://github.com/cursor/plugins.git`

Branch: `main`

Initial commit: `ecc249f1e306fc64ddf83c7bed16cacf7c2239db`

Last synced commit: `d0ef80d86795816da932a153458c5dbe192d294e`

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

Selected pstack entries are `poteto-mode`, `poteto-help`, `correct`, `how`, `why`, `architect`, `arena`, `swarm`, `interrogate`, `figure-it-out`, `show-me-your-work`, `reflect`, `tdd`, `no-comments`, `typescript-best-practices`, `technical-writing`, `unslop`, `setup-pstack`, `benchmark-checklist`, and the following 24 principles:

- `principle-attack-the-premise`
- `principle-boundary-discipline`
- `principle-build-the-lever`
- `principle-encode-lessons-in-structure`
- `principle-exhaust-the-design-space`
- `principle-experience-first`
- `principle-explain-the-number`
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

Within the selected port scope, copy the upstream files first. Preserve their wording, order, examples, workflow steps, role boundaries, counts, verification gates, and review responsibilities. Change only the exact text required for GPT model substitution, Codex host interfaces, explicit invocation metadata, and the exclusions above. Do not paraphrase or reorganize the remaining text. A tool limit changes scheduling, not required coverage. Do not weaken a workflow or add roles as part of model substitution.

- Native Codex local subagents replace Cursor Task APIs. Role instructions are references, not global agent installations.
- Explicit-only `agents/openai.yaml` metadata applies to all 46 entries.
- Preserve all 17 upstream configuration roles one-to-one. Normalize punctuation and spaces to underscores in JSON keys. Use the GPT model and effort pairs in `plugins/pstack-codex/config/models.defaults.json`; the current mapping uses Sol for exploration, explanation, cause investigation, judgment, prose, and tooling reflection, and Astra for implementation, complex synthesis, and review. Preserve the two-entry defaults for candidates, reviewers, and the cross-judge pool. Keep configurable list lengths, budgets, and `auto` / `inherit-parent`. Personal overrides remain outside the cache.
- Preserve Arena's `arena cross-judge pool` as the `arena_cross_judge_pool` array and select one judge from it. Map upstream's different model families to different GPT-6 Astra reasoning efforts. Arena prefers a different effort from its parent. `show-me-your-work` requires a different effort from the work agent, without adding a named reviewer role or fixed effort.
- Preserve upstream review synthesis, including its treatment of consensus and individual findings. Model substitution does not authorize a different judgment policy.
- The 20 retained playbooks use local execution and actual available tools. Batch work within host concurrency limits without changing the upstream scenario count or evidence requirements.
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

## Verify the copy and adaptations

`scripts/port-adaptations.json` maps every retained upstream file to its local file. Each necessary replacement records the exact old and new text, its category, and its reason. It also records excluded files and Codex-only adapters. The source hashes are pinned to `last_synced_commit`.

After preparing the upstream snapshot, run:

```bash
python3 scripts/check-port.py --upstream <prepared-directory>/base-upstream
python3 scripts/check-port.test.py --upstream <prepared-directory>/base-upstream
```

The checker reconstructs each file from upstream plus its recorded replacements. It rejects unrecorded edits, missing files, unexpected additions, changed source hashes, and reintroduced exclusions. Review each replacement against the source before updating the manifest. Passing reconstruction proves that all textual differences are accounted for; it does not by itself prove that an adaptation is necessary or behaviorally equivalent.

For a new upstream revision, copy its selected files first, reapply only necessary adaptations, inspect each remaining difference, and update source hashes and replacements together with the synchronized baseline. Keep generated review reports in ignored `.work/`.

## Synchronization log

| Date | Baseline | Result |
|---|---|---|
| 2026-09-26 | `ecc249f1e306fc64ddf83c7bed16cacf7c2239db` | Initial local-workflow Codex port. |
| 2026-10-03 | `23e4138daa01c42d4969f7a5465f82704e64f798` | Synced pstack 0.15.6. Added the selected `benchmark-checklist` and `principle-explain-the-number` skills. Ported fresh-subagent rules, PR guidance, writing cleanup, and schema-first TypeScript examples. Preserved local plan checks and cloud exclusions. |
| 2026-10-07 | `d0ef80d86795816da932a153458c5dbe192d294e` | Synced pstack 0.15.15. Added the selected `correct` and `poteto-help` skills with Codex instructions and examples. Ported agent-aware design checks and ordered performance strategies. Preserved Codex model roles, local execution, and cloud exclusions. |
