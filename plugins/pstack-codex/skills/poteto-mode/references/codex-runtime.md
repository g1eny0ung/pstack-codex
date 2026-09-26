# Codex runtime

Read this reference when a pstack-codex skill uses subagents, model roles, session history, or local worktrees. It applies whether the caller invoked poteto-mode or a sibling skill directly.

## Paths and skill lookup

Resolve paths from the loaded skill file, never a hard-coded checkout or user name. `PSTACK_PLUGIN_ROOT` is the plugin directory containing `config/` and `skills/`. `POTETO_SKILL_ROOT` is its `skills/poteto-mode` directory. These are task-local shell variables to set to the resolved absolute paths before executing examples, not installation requirements. Quote paths in shell commands. Keep task artifacts outside the installed plugin, which may be read-only.

A sibling skill named `how` means `skills/how/SKILL.md` in this plugin. Resolve every relative file reference from the document containing it, and every sibling-skill directory from this plugin’s `skills/` directory. Read a referenced skill when its workflow is needed; invoking one skill does not globally enable poteto-mode. All shipped skills have explicit invocation policy, and an invoked workflow can deliberately read its declared dependencies. If the user only activates `$poteto-mode` without a task, confirm the current-task scope and wait for a concrete request; activation alone does not start a playbook, launch agents, or open a PR.

## Resolve model roles

1. Read `config/models.defaults.json` from the plugin root.
2. Read `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` when present. Do not change `CODEX_HOME` or `HOME` to resolve it.
3. Both files use `{ "version": 1, "roles": { ... } }`. Unknown versions or role names, malformed JSON, and invalid values are errors to report before launching affected roles. Missing override files mean use defaults.
4. For a scalar role, merge its optional `model` and `reasoning_effort` fields over the default. For an array role, the override replaces the entire array; every seat contains both fields. Candidate arrays must be nonempty, and `interrogate_reviewers` has exactly three ordered seats. Reject other seat fields.
5. Validate the effective model/effort pair against the current native subagent tool. All configured models must be GPT models. Use explicit `model` and `reasoning_effort` fields, never a suffix that combines them. Report unavailable values; do not substitute or lower effort automatically.

Roles are the keys in the defaults file. `feature_refactoring`, `bug_fix`, `perf_issue`, `hillclimb`, `how_explorer`, `how_explainer`, `why_investigators`, `swarm_workers`, `comment_review`, and `reflect_tooling` cover ordinary work. `judgment` covers ordinary decisions. `writing` is for delegated prose work, not a mandatory extra pass for each reply. `hardest_tasks`, `why_synthesizer`, `reflect_judgment`, `reflect_divergent`, `reflect_synthesizer`, `arena_judge`, and `audit_reviewer` cover deeper implementation, evidence synthesis, or judging. `arena_runners` and `architect_runners` are candidate lists. `interrogate_reviewers` is the A/B/C review list.

The default model is `gpt-6-astra` throughout. The defaults file is authoritative for effort. This configuration never changes the user’s main chat model. The user can change role settings with `$setup-pstack`.

## Launch and supervise local subagents

Use the host’s native subagent API, such as `collaboration.spawn_agent`, `send_message`, `followup_task`, `interrupt_agent`, and `wait_agent`. Inspect the available schema before calling it. A typical launch passes `task_name`, a self-contained `message`, `model`, `reasoning_effort`, and `fork_turns: "none"`. Full-history forks inherit the parent configuration on hosts that prohibit overrides; use an independent context when an explicit model or effort is required. Do not drop the requested parameters merely to use a full fork.

Pass the user’s objective, bounded scope, working directory, required skill/role paths, inputs, output path, and success criteria in the message. Model overrides remain explicit. Role names are workflow settings, not native agent types. To use the poteto role, point the worker at `poteto-mode/references/poteto-agent.md`. To use Comment Sicko, point it at `no-comments/references/comment-sicko.md`. Require the worker to read the named file.

Reviewers receive read-only tasks and independent contexts. Use a read-only sandbox option if the host supports it, but do not invent unsupported API fields. They may inspect evidence and run permitted non-mutating checks; they must not edit the reviewed artifact or external records. Give parallel writers separate worktrees or output paths. Native desktop worktree tools manage Codex-owned checkouts; inspect existing artifacts before creating a checkout and archive through the native tool. Ordinary Git worktrees use Git’s own lifecycle.

Run independent jobs concurrently within the available slots. If a workflow requires more scenarios than slots, keep all scenarios and run batches. Parallelism does not authorize unbounded nesting or the creation of separate user-visible chats. Wait for terminal reports, inspect their evidence, and own the final result. Send a correction to a running worker; use follow-up only when new work is intended. If an agent or native capability is unavailable, report the missing portion rather than claiming it ran.

## Conversation history

Resolve the intended thread ID from the current host context or a user-provided reference. Do not infer it by scanning unrelated conversations. Export the available persisted history to the task directory with:

```bash
node "$POTETO_SKILL_ROOT/scripts/read-thread.mjs" --thread-id <thread-id> > <task-dir>/transcript.json
```

The reader uses the local Codex App Server’s full paginated history API and only read operations. Preserve thread, turn, item, and tool-result associations in the exported data. An API error, unavailable full-history capability, missing items, or truncation is an explicit coverage gap. A summary is not a full transcript. Continue unaffected work, but do not claim an unperformed history audit passed.

## Goals, tools, and authorization

A skill describes how to perform the user’s task; it does not enlarge the authorized scope. Respect existing user approvals and the host’s execution boundaries. Tool discovery uses the current host inventory and its supported discovery interfaces. Missing optional connectors are evidence gaps, not a reason to install a personal plugin.

Continue ordinary multi-step work within the active turn. Create a persistent Goal only when the user explicitly requests a continuing goal. For an explicit request to check later or on a schedule, use the host’s native automation capability. If the CLI has no scheduler, support the active process and explicit resume; do not build a background service. Local subagents and local schedules do not imply off-machine execution.
