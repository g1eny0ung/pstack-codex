# Upstream tracking

Repository: `https://github.com/cursor/plugins.git`

Branch: `main`

Initial commit: `ecc249f1e306fc64ddf83c7bed16cacf7c2239db`

Last synced commit: `c742dd61706fbacc1b95f1a20b7b988cf096ce6c`

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

Selected pstack entries are `poteto-mode`, `poteto-help`, `correct`, `in-your-own-words`, `sharpen`, `how`, `why`, `blast-radius`, `bro`, `ketchup`, `teach`, `architect`, `arena`, `swarm`, `interrogate`, `figure-it-out`, `show-me-your-work`, `reflect`, `tdd`, `no-comments`, `typescript-best-practices`, `technical-writing`, `unslop`, `setup-pstack`, `benchmark-checklist`, `create-formal-verification-skill`, `maintain-formal-verification-skill`, and the following 24 principles:

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

The standalone skills `automate-me`, `create-verification-skill`, `maintain-verification-skill`, `make-bot-ui`, and `recall` are outside this port's scope. Other cursor-team-kit skills are also excluded. New upstream skills must be reported for selection, not added automatically.

Adoption of `statechart` is deferred. Its expected usage does not yet justify the additional Java, TLC, and PNG rendering dependencies.

Adoption of `ketchup-video` is deferred. Its video workflow needs rendering and frame inspection tools that are not bundled with the plugin.

Origin CLI integration is excluded under this port's Codex compatibility standard. Retained PR workflows and worktree PR audits use GitHub CLI (`gh`). During upstream synchronization, remove Origin CLI detection, commands, and workflow branches instead of importing them. Git remote names such as `origin` remain valid and are unrelated to this exclusion.

## Adaptation rules to preserve

Within the selected port scope, copy the upstream files first. Preserve their wording, order, examples, workflow steps, role boundaries, counts, verification gates, and review responsibilities. Change only the exact text required for GPT model substitution, Codex host interfaces, explicit invocation metadata, and the exclusions above. Do not paraphrase or reorganize the remaining text. A tool limit changes scheduling, not required coverage. Do not weaken a workflow or add roles as part of model substitution.

- Native Codex local subagents replace Cursor Task APIs. Role instructions are references, not global agent installations.
- Explicit-only `agents/openai.yaml` metadata applies to all 54 entries. When a skill changes, check its display name, short description, and default prompt against the current workflow. Describe configurable reviewer or candidate counts without fixing a number in the metadata.
- Preserve all 17 upstream configuration roles one-to-one. Normalize punctuation and spaces to underscores in JSON keys. Use the GPT model and effort pairs in `plugins/pstack-codex/config/models.defaults.json`; the current mapping uses Sol for exploration, explanation, cause investigation, judgment, prose, and tooling reflection, and Astra for implementation, complex synthesis, and review. Preserve the two-entry defaults for candidates, reviewers, and the cross-judge pool. Keep configurable list lengths, budgets, and `auto` / `inherit-parent`. Personal overrides remain outside the cache.
- Role settings are launch starting points. Preserve upstream task-sensitive effort adjustments, direct fallback after an adjusted launch is rejected, verification model and speed exceptions, and cross-review effort differences. Keep GPT model names unchanged when adjusting effort. Use a speed field only if the native API supports it; otherwise report the capability gap and keep host speed. Follow the [task effort contract](plugins/pstack-codex/skills/poteto-mode/references/codex-runtime.md#choose-effort-and-speed-for-the-job).
- Preserve Arena's `arena cross-judge pool` as the `arena_cross_judge_pool` array and select at most one judge from it. Map upstream's different model families to different GPT-6 Astra reasoning efforts. Arena requires a different final effort from its parent when that effort is known. Preserve pool order, alias exclusion, default-pool fallback, explicit skipping, and disclosure when the parent effort is unknown. `show-me-your-work` requires a different effort from the work agent, without adding a named reviewer role or fixed effort.
- Preserve upstream review evidence and synthesis rules. Interrogate keeps findings only after a run proves them and the parent reruns the command. Reviewers may create repro material in isolated worktrees, but must not fix the reviewed code or mutate external records. Model substitution does not authorize a different judgment policy.
- The 20 retained playbooks use local execution and actual available tools. Batch work within host concurrency limits without changing the upstream scenario count or evidence requirements.
- Map explicitly requested `/loop until <condition>` continuation to Codex Goal tools. Map timed checks such as `/loop 1h` to native automation. Preserve completion predicates, event watchers, verification, and checkpoints. Follow the [Codex runtime](plugins/pstack-codex/skills/poteto-mode/references/codex-runtime.md#goals-tools-and-authorization) for authorization and lifecycle handling.
- Read session history through `read-thread.mjs`; do not restore Cursor paths or scan unrelated conversations.
- Keep `worktree-audit.sh` and `scripts/upstream.sh` in Bash. Preserve portable quoting and command choices.
- Keep the worktree audit read-only. `-b` or `--base` selects an existing local ref; automatic resolution supports the configured remote's default branch. Do not fetch during the audit. An unresolved automatic base leaves `MERGED` unknown. Report the base on stderr to preserve the TSV format.
- Bundle watch-pr with Bun at release time for Node; do not install runtime dependencies in the plugin cache.
- Preserve the user's authorization boundaries. Skills do not grant themselves permission to publish, message others, schedule work, or mutate unrelated resources.
- Keep source and dependency license notices. Mentions of Cursor in attribution or bot recognition are not runtime dependencies.

## Check and prepare

`bash scripts/upstream.sh check` fetches the selected upstream branch and compares it with `last_synced_commit`. It watches all of pstack, the three selected cursor-team-kit directories, and their license. Output labels migrated content, excluded cloud content, and new/out-of-scope content; deletions and renames remain visible. The Git cache defaults to `${XDG_CACHE_HOME:-$HOME/.cache}/pstack-codex/upstream` and can be set with `PSTACK_UPSTREAM_WORKDIR`.

Both `check` and `prepare` read `scripts/port-adaptations.json`. When an upstream file with recorded adaptations changes, they list the affected source, local target, and adaptation reasons. Detection covers the whole file, including changes outside the replaced text, deletions, and renames. A pending adaptation review returns exit code 2. Exit code 0 means no recorded adaptation was affected, not that the upstream update is safe to integrate. Invalid or unavailable comparison inputs fail with exit code 1.

For each affected file, show the user the upstream change and the recorded adaptations. Wait for the user's decision to retain, revise, or remove those adaptations before editing the affected plugin files, changing their adaptation records, or advancing the synchronized baseline. Do not clear the review by automatically updating hashes or replacement text. `prepare` still writes the comparison materials when review is pending.

`bash scripts/upstream.sh prepare --commit <full-SHA>` creates three directories in that maintenance cache:

1. `base-upstream`: the last synced upstream version.
2. `target-upstream`: the requested upstream version.
3. `local-codex`: the current migrated plugin, excluding development dependencies.

`changes.txt` records the comparison. Upstream snapshots intentionally include excluded content for review; they are not installable plugin output. The script never overwrites source files or edits the lock. Repeated preparation creates a separate directory rather than overwriting earlier work.

Review changes using the mappings above and obtain the user's decisions for affected adaptations. Then port the selected fixes, check renames/deletions and references, rebuild changed runtime code, and validate the affected behavior. Update the lock and this log only when synchronization is complete. If interrupted, leave the previous baseline in place. No scheduled upstream monitor is installed.

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
| 2026-10-12 | `c49b37a2c0e7bede60a71ad7322e3f12c337a3da` | Synced pstack 0.15.19 after the user approved the affected adaptations. Ported review-thread pagination, plan fence checks, explicit worktree bases, main-chat workflow ownership, and skill instruction changes. Preserved Codex model roles, authorization and read-only audit behavior. Excluded `ketchup`. |
| 2026-10-12 | `c49b37a2c0e7bede60a71ad7322e3f12c337a3da` | Selected `ketchup` at the user's request from the existing baseline. Added explicit Codex invocation, current-thread history and native status access, and the help route. Preserved the read-only summary and visual comparison requirements. |
| 2026-10-14 | `1e5c90a4b6f249917bd21fe361b3a2a7deb741b8` | Synced pstack 0.15.24 after the user approved affected adaptations and selected `in-your-own-words` and `sharpen`. Ported task-sensitive subagent effort, short visual ketchup replies, Shipping and verification-frequency changes, Code Review Gate classification, Origin worktree audit support, and delegate skill lookup. Preserved explicit invocation, role defaults, local execution, audit safeguards, and cloud exclusions. |
| 2026-10-16 | `99743e9c151c8537cbbf1f98bb38f34ef3368453` | Synced pstack 0.15.25 after the user approved all affected adaptations. Ported screenshot and video ketchup summaries, revised reasoning principles, and upstream instruction removals. Preserved 63 existing adaptations in changed files and removed two obsolete swarm substitutions. |
| 2026-10-19 | `8838150c6b4829ea3c01782631213776d86df14a` | Synced pstack 0.15.27 after the user approved affected adaptations and selected `create-formal-verification-skill`. Added formal verification setup and help routes, complete pending-item ketchup summaries, type-guard branding examples, and sharpen guidance. Preserved Codex model roles, explicit invocation, local execution, and existing exclusions. Removed the obsolete poteto-mode name adaptation. |
| 2026-10-20 | `88d47514b82e7c44f00f2b2a72ff6dd12158038c` | Synced pstack 0.15.29 after the user approved affected adaptations and selected `maintain-formal-verification-skill`. Added verification maintenance and help routes, coverage and sync-commit records, TLA+ defaults and generated-input fallback, and prompt-only sharpen behavior. Preserved Codex invocation, model roles, local execution, and existing exclusions. |
| 2026-10-22 | `eb4db2b55b2b7dec3d9282754cddf0a56bf4ff10` | Synced the selected scope of pstack 0.15.30. Deferred `statechart` and its help route because the skill's expected usage does not yet justify the additional tool dependencies. Retained all existing Codex adaptations. Plugin files are unchanged. |
| 2026-10-26 | `99b609a72323b70204eab407c622f436e858e112` | Synced pstack 0.15.32 after the user approved affected adaptations. Ported matching inline-code delimiters, fork-aware PR stack discovery, polling deadline sleep limits, Reflect edit destinations, and Swarm instruction fixes. Deferred `ketchup-video` and retained the `statechart` deferral, including their help and generated-skill routes. Preserved Codex models, local execution, read-only audit behavior, and existing exclusions. |
| 2026-10-28 | `c742dd61706fbacc1b95f1a20b7b988cf096ce6c` | Synced pstack 0.15.36 after the user approved affected adaptations. Ported run-proven Interrogate findings, removed four obsolete review references, and adopted ordered Arena fallbacks with required cross-judge effort differences. Updated goal communication, measurement prerequisites, and planning rules. Preserved all model settings, local execution, authorization boundaries, cloud exclusions, and both skill deferrals. |
