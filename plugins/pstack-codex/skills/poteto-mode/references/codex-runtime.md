# Codex runtime

Read this reference when a pstack-codex skill uses subagents, model roles, session history, or local worktrees. It applies whether the caller invoked poteto-mode or a sibling skill directly.

## Paths and skill lookup

Resolve paths from the loaded skill file, never a hard-coded checkout or user name. `PSTACK_PLUGIN_ROOT` is the plugin directory containing `config/` and `skills/`. `POTETO_SKILL_ROOT` is its `skills/poteto-mode` directory. These are task-local shell variables to set to the resolved absolute paths before executing examples, not installation requirements. Quote paths in shell commands. Keep task artifacts outside the installed plugin, which may be read-only. Apply authorized skill edits to a maintained source checkout, never the installed plugin cache.

A sibling skill named `how` means `skills/how/SKILL.md` in this plugin. Resolve every relative file reference from the document containing it, and every sibling-skill directory from this plugin’s `skills/` directory. Read a referenced skill when its workflow is needed; invoking one skill does not globally enable poteto-mode. All shipped skills have explicit invocation policy, and an invoked workflow can deliberately read its declared dependencies. If the user only activates `$poteto-mode` without a task, confirm the current-task scope and wait for a concrete request; activation alone does not start a playbook, launch agents, or open a PR.

## Resolve model roles

1. Read `config/models.defaults.json` from the plugin root.
2. Read `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` when present. Do not change `CODEX_HOME` or `HOME` to resolve it.
3. Both files use `{ "version": 1, "roles": { ... } }`. Personal settings may also record `"budget": "unlimited"`, `"large"`, `"medium"`, or `"small"`. The saved role values determine launches; the budget records the choice made by **setup-pstack** and does not overwrite later per-role edits. Unknown versions or role names, malformed JSON, and invalid values are errors to report before launching affected roles. Missing override files mean use defaults.
4. A scalar role is a configuration object or the string `"inherit-parent"` or `"auto"`. For an object, merge its optional `model` and `reasoning_effort` fields over the default. Both aliases mean inherit the parent configuration: omit both launch fields. An array override replaces the entire ordered list; each entry is a complete object or either alias. All arrays must be nonempty. `arena_runners`, `architect_runners`, and `interrogate_reviewers` start with one seat per entry, including aliases. Follow the calling skill's seat removal and replacement rules after launch rejection. `arena_cross_judge_pool` supplies one selected judge, not one per entry. Reject other entry fields.
5. Validate explicit model/effort pairs against the current native subagent tool. Configured model names must be GPT models. Model and effort remain separate fields. Aliases do not need to appear in a model inventory. Record rejected configurations for the task. A native rejection rules out that model/effort/speed configuration; an error that excludes a model from the supported list rules out every configuration of that model. Never retry either through another fallback. Follow the calling skill's fallback, skipping already rejected choices. An explicit drop, skip, or stop rule takes precedence over a generic fallback. Without a calling-skill fallback, use the closest supported configuration of the role's GPT model from the error. If none is available, omit both launch fields to inherit the parent and disclose it. Do the same when a calling-skill fallback runs out of choices without specifying a next step. Configuration-time validation and budget fallback follow **setup-pstack**.

The 17 role keys correspond one-to-one to upstream role labels, with punctuation and spaces represented as underscores. `judgment_and_prose` remains one shared role. `reflect_judgment_divergent_synthesizer` remains one shared role for those three agents; `reflect_tooling` is separate. Do not add a `comment_review` or `audit_reviewer` role. Comment Sicko inherits the parent configuration. `show-me-your-work` selects its reviewer without a dedicated role. The `arena_cross_judge_pool` array preserves upstream's `arena cross-judge pool`.

Shipped defaults use `gpt-6.1-sol` at `high` for `how_explorer` and `reflect_tooling`, and at `xhigh` for `judgment_and_prose`, `how_explainer`, and `why_investigators`. Other configured roles retain GPT-6 Astra at the efforts recorded in `config/models.defaults.json`. Candidate and interrogate lists retain the upstream two entries and their order. A personal list sets its own count. This configuration never changes the user's main chat model. Use **setup-pstack** to change the budget, a role, or a list.

For Arena and `show-me-your-work`, this port maps upstream's cross-model-family review to GPT-6 Astra at different reasoning efforts. This is the port's substitution axis, not a claim that effort differences provide the same diversity as model families. Arena requires a different final effort from the parent when that effort is known. Try eligible explicit entries in configured pool order, then eligible shipped-pool entries, and recheck eligibility after adjustments and fallbacks. Aliases never judge. If no eligible entry runs, skip the judge and report it. If the parent effort is unknown, try explicit entries in pool order and disclose that the difference check did not run. `show-me-your-work` requires a different effort from the work agent and does not use a dedicated reviewer role.

## Choose effort and speed for the job

Resolve the role before adjusting a launch. Its saved model and effort are starting settings. Do not rewrite the role or the user's personal configuration for one task.

Use that model's supported effort levels in ascending order. Raise effort one step, capped at `max`, for the hardest or subtlest work. Lower it one step for judgment and at least two steps for routine work. Clamp to the supported levels. Keep the role's model unchanged. Verification keeps the `swarm_workers` model and speed while choosing its effort for the job.

Use fast speed only when CI or trunk is red, or a person is blocked on the result now. Otherwise use standard speed. Pass a speed setting only when the native subagent API exposes a supported field. If the API has no such field, keep the host's speed and report that speed selection is unavailable. Do not encode speed into a GPT model name.

For `auto` and `inherit-parent`, omit both model and effort instead of adjusting them. Comment Sicko also inherits both fields. After any adjustment, preserve Arena's required cross-judge effort difference and `show-me-your-work`'s required reviewer effort difference. If the work agent's effort is unknown, report that the required difference cannot be verified.

If the native tool rejects an adjusted configuration, do not try another adjustment. Launch with the resolved role's original configuration or default unless it is already rejected, and disclose the fallback. If it is rejected too, follow the calling skill's fallback and the model-role rules above.

## GitHub pull requests

Use GitHub CLI (`gh`) for retained PR workflows and worktree PR audits. Origin CLI integration is outside this port's scope. The audit must not probe or invoke Origin, including when `gh` is unavailable. Missing GitHub PR evidence stays unknown and cannot establish that a worktree is safe to remove. Git remotes named `origin` remain supported.

## Launch and supervise local subagents

Use the host’s native subagent API, such as `collaboration.spawn_agent`, `send_message`, `followup_task`, `interrupt_agent`, and `wait_agent`. Inspect the available schema before calling it. A typical launch passes `task_name`, a self-contained `message`, `model`, `reasoning_effort`, and `fork_turns: "none"`. Full-history forks inherit the parent configuration on hosts that prohibit overrides; use an independent context when an explicit model or effort is required. Do not drop the requested parameters merely to use a full fork.

Pass the user’s objective, bounded scope, working directory, required skill/role paths, inputs, output path, and success criteria in the message. Explicit configurations pass both fields; `auto` and `inherit-parent` omit both fields to inherit the parent configuration. Role names are workflow settings, not native agent types. To use the poteto role, point the worker at `poteto-mode/references/poteto-agent.md`. To use Comment Sicko, point it at `no-comments/references/comment-sicko.md`. Require the worker to read the named file.

Review-only assignments keep the reviewed checkout and external records read-only and use independent contexts. When a workflow requires running repros, give each reviewer its own isolated worktree and allow repro scripts, tests, and their outputs only there. Copy the scoped staged and unstaged changes and any necessary untracked inputs into each worktree, preserving the code being reviewed. Reuse shared dependency caches. Do not apply fixes to the reviewed code. Use a read-only sandbox option for purely read-only assignments if the host supports it, but do not invent unsupported API fields. Repro execution stays within the user's authorized scope and does not authorize destructive actions or external writes.

Comment Sicko is an editing role. It may delete scoped comments, but must not edit application code. Give parallel writers separate worktrees or output paths. Native desktop worktree tools manage Codex-owned checkouts; inspect existing artifacts before creating a checkout and archive through the native tool. Ordinary Git worktrees use Git’s own lifecycle.

Run independent jobs concurrently within the available slots. If a workflow requires more scenarios than slots, keep all scenarios and run batches. Parallelism does not authorize unbounded nesting or the creation of separate user-visible chats. Wait for terminal reports, inspect their evidence, and own the final result. Give new work, including corrections, retries, and follow-up rounds, to a fresh agent with a consolidated brief. Reuse an agent only when the work needs state it holds that is costly to move, as defined in the parent skill's Subagents section. Stop and hold orders remain available. If an agent or native capability is unavailable, report the missing portion rather than claiming it ran.

## Conversation history

Resolve the intended thread ID from the current host context or a user-provided reference. Do not infer it by scanning unrelated conversations. Export the available persisted history to the task directory with:

```bash
node "$POTETO_SKILL_ROOT/scripts/read-thread.mjs" --thread-id <thread-id> > <task-dir>/transcript.json
```

The reader uses the local Codex App Server’s full paginated history API and only read operations. Preserve thread, turn, item, and tool-result associations in the exported data. An API error, unavailable full-history capability, missing items, or truncation is an explicit coverage gap. A summary is not a full transcript. Continue unaffected work, but do not claim an unperformed history audit passed.

## Goals, tools, and authorization

A skill describes how to perform the user’s task; it does not enlarge the authorized scope. Respect existing user approvals and the host’s execution boundaries. Tool discovery uses the current host inventory and its supported discovery interfaces. Missing optional connectors are evidence gaps, not a reason to install a personal plugin.

Continue ordinary multi-step work within the active turn. Map an explicit request for a persistent objective, such as `/goal <objective>` or Cursor's `/loop until <condition>`, to a Codex Goal. A routine task, a quoted example, or "keep going" alone does not authorize creating a Goal.

Read the available Goal tool schemas. Use `get_goal` first and reuse an existing Goal for the same objective. Do not overwrite an unfinished Goal for another objective. When creation is needed and authorized, call `create_goal` with the objective, checkable completion condition, and constraints in `objective`. Set `token_budget` only if the user specified one. Call the tools directly rather than typing a slash command into the UI. Codex owns continuation across turns while the Goal is active. Keep the playbook's work, verification, and checkpoint steps unchanged.

Use `update_goal` to mark completion only after the predicate passes. Pause only on the user's explicit request, and mark blocked only under the current tool's blocking criteria. Respect host budget and stop states. Resume and clear use the host's supported controls, such as `/goal resume` and `/goal clear`, rather than invented `update_goal` statuses. If Goal tools are unavailable, report the missing continuation capability and continue only within the active process or on explicit resume.

Map explicit timed or later checks, such as `/loop 1h`, to native automation. A Goal does not provide a polling interval. Preserve event watchers and requested heartbeat intervals; avoid duplicate Goals or schedules for the same work. If the host has no scheduler, report that gap and use the active process and explicit resume. Local Goals, subagents, and schedules do not imply off-machine execution.
