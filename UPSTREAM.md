# Upstream tracking

See [upstream.lock.json](upstream.lock.json) for the repository, branch, and synchronized baseline. `initial_commit` is immutable. Update `last_synced_commit` only after actually integrating and validating a chosen revision. Merely checking upstream never advances it.

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

The selected skills are the directories under [plugins/pstack-codex/skills](plugins/pstack-codex/skills/). Exact source mappings and adaptations are recorded in [scripts/port/port-adaptations.json](scripts/port/port-adaptations.json).

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
- Explicit-only `agents/openai.yaml` metadata applies to all retained entries. When a skill changes, check its display name, short description, and default prompt against the current workflow. Describe configurable reviewer or candidate counts without fixing a number in the metadata.
- Preserve upstream configuration roles one-to-one. Normalize punctuation and spaces to underscores in JSON keys. Use the GPT model and effort pairs in `plugins/pstack-codex/config/models.defaults.json`. Preserve the two-entry defaults for candidates, reviewers, and the cross-judge pool. Keep configurable list lengths, budgets, and `auto` / `inherit-parent`. Personal overrides remain outside the cache.
- Preserve upstream task-sensitive effort adjustments, the `xhigh` ceiling, fallback order, and verification exceptions. See the [task effort contract](plugins/pstack-codex/skills/poteto-mode/references/codex-runtime.md#choose-effort-for-the-job).
- Preserve Arena's `arena cross-judge pool` as the `arena_cross_judge_pool` array. Keep the independent review in both [Arena](plugins/pstack-codex/skills/arena/SKILL.md) and [show-me-your-work](plugins/pstack-codex/skills/show-me-your-work/SKILL.md). Prefer a different model or reasoning effort when available.
- Preserve upstream review evidence and synthesis rules. Interrogate keeps findings only after a run proves them and the parent reruns the command. Follow [Codex runtime](plugins/pstack-codex/skills/poteto-mode/references/codex-runtime.md#launch-and-supervise-local-subagents) to isolate repros that write state.
- The retained playbooks use local execution and actual available tools. Batch work within host concurrency limits without changing the upstream scenario count or evidence requirements.
- Map explicitly requested `/loop until <condition>` continuation to Codex Goal tools. Keep timed checks for a specific run in the active task. Use native automation for requested reminders and recurring work. Preserve completion predicates, event watchers, verification, and checkpoints. Follow the [Codex runtime](plugins/pstack-codex/skills/poteto-mode/references/codex-runtime.md#goals-tools-and-authorization) for authorization and lifecycle handling.
- Read session history through `read-thread.mjs`; do not restore Cursor paths or scan unrelated conversations.
- Keep `worktree-audit.sh` and `scripts/upstream/upstream.sh` in Bash. Preserve portable quoting and command choices.
- Keep the worktree audit read-only. `-b` or `--base` selects the target branch or a local ref. For a local branch that tracks a remote branch, use the tracked repository and branch to match PRs. Automatic resolution uses the default branch of the repository selected by `gh repo set-default` when configured, otherwise preferring `origin`. When `gh` stores an `owner/repo` selection, resolve its repository and default branch through `gh` and use the matching remote-tracking ref if present. If Git cannot resolve the default branch, query it through `gh` for the same repository used to list PRs. The `REMOTE` column compares the checkout to the local tracking ref for its push destination. If Git cannot resolve a push ref, use the same-named `origin` tracking ref when present. If the local base ref is unavailable, leave `MERGED` unknown and check for a PR with a matching head, target repository, and target branch. Do not fetch during the audit. Report the base on stderr to preserve the TSV format.
- Bundle watch-pr with Bun at release time for Node; do not install runtime dependencies in the plugin cache.
- Preserve the user's authorization boundaries. Skills do not grant themselves permission to publish, message others, schedule work, or mutate unrelated resources.
- Keep source and dependency license notices. Mentions of Cursor in attribution or bot recognition are not runtime dependencies.

## Check and prepare

`bash scripts/upstream/upstream.sh check` fetches the selected upstream branch and compares it with `last_synced_commit`. It watches all of pstack, the three selected cursor-team-kit directories, and their license. Output labels migrated content, excluded cloud content, and new/out-of-scope content; deletions and renames remain visible. The Git cache defaults to `${XDG_CACHE_HOME:-$HOME/.cache}/pstack-codex/upstream` and can be set with `PSTACK_UPSTREAM_WORKDIR`.

Both `check` and `prepare` report the upstream changes and try the recorded replacements against changed files. If the replacements still apply, inspect the surrounding diff for changes to their meaning. Exit code 2 flags replacements that no longer match and adapted files that were renamed, deleted, or changed mode or type. Exit code 1 reports an inspection failure.

Ask the user to decide when an adaptation is flagged or the surrounding diff changes its meaning. Show the relevant upstream change and recorded replacement. `prepare` writes the comparison materials while the decision is pending.

`bash scripts/upstream/upstream.sh prepare --commit <full-SHA>` creates three directories in that maintenance cache:

1. `base-upstream`: the last synced upstream version.
2. `target-upstream`: the requested upstream version.
3. `local-codex`: the current migrated plugin, excluding development dependencies.

`changes.txt` records the comparison. Upstream snapshots intentionally include excluded content for review; they are not installable plugin output. The script never overwrites source files or edits the lock. Repeated preparation creates a separate directory rather than overwriting earlier work.

Review the changes using the mappings above. Port the selected fixes, check file moves, deletions, and references, rebuild changed runtime code, and validate the affected behavior before updating the lock.

## Verify the copy and adaptations

`scripts/port/port-adaptations.json` maps every retained upstream file to its local file. Each necessary replacement records the exact old and new text, its category, and its reason. It also records excluded files and Codex-only adapters. The source hashes are pinned to `last_synced_commit`.

After preparing the upstream snapshot, run:

```bash
python3 scripts/port/check-port.py --upstream <prepared-directory>/base-upstream
python3 scripts/port/check-port.test.py --upstream <prepared-directory>/base-upstream
bash scripts/release/package.test.sh
```

The package test checks that each skill still requires explicit invocation.

The checker reconstructs each file from upstream plus its recorded replacements. It rejects unrecorded edits, missing files, unexpected additions, changed source hashes, and reintroduced exclusions. Review each replacement against the source before updating the manifest. Passing reconstruction proves that all textual differences are accounted for; it does not by itself prove that an adaptation is necessary or behaviorally equivalent.

For a new upstream revision, copy its selected files first, reapply only necessary adaptations, inspect each remaining difference, and update source hashes and replacements together with the synchronized baseline. Keep generated review reports in ignored `.work/`.
