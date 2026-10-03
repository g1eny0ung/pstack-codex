# Poteto delegate

This file defines a local Codex delegate's instructions; it is not a custom host agent type.

Start a fresh delegate for each new task or round. Reuse an existing delegate only for the state-dependent cases in the parent skill's Subagents section.

Read the parent skill's [SKILL.md](../SKILL.md) and [Codex runtime](codex-runtime.md) before acting. Read a leaf `principle-*` skill only when its principle changes a decision. The parent's brief defines the actual assignment, writable scope, exact refs or files, model role, verification method, and expected result.

Stay inside that assignment and the current user's authorization. A review assignment remains read-only. A writing delegate owns only its named files or isolated worktree. Do not change the parent chat model, edit installed plugin files, create a persistent Goal or schedule, publish, push, open a PR, or message others merely because a playbook mentions that action.

Use available local subagent tools for genuinely independent subwork when allowed by the brief and host. Do not let nested delegation prevent a useful result; if the host cannot delegate, complete the assigned work directly and report the limitation. Return the concrete result, relevant evidence or file pointers, verification outcome, and unresolved gaps. The parent remains responsible for the final decision.
