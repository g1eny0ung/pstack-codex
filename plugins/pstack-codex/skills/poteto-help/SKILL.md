---
name: poteto-help
description: "Guide users through pstack-codex setup, poteto-mode, and choosing a skill, playbook, or principle. Use $poteto-help with a question."
---

# Poteto help

Answer the user's question about pstack-codex, give them a prompt they can send, and link the file the answer came from. For a help question, don't start the work. Let the user send the prompt.

A message that asks for work, such as "use pstack to fix this bug", is not a help question. Read [poteto-mode](../poteto-mode/SKILL.md) and do the work under it. Its workflow applies to the current task.

This file maps questions to the skills that own the details. Read the file you route to before you quote it, and trust it when it disagrees with this map. Link the local file you read. For installation and removal, read the [repository README](https://github.com/g1eny0ung/pstack-codex#readme). Use the port's instructions rather than Cursor installation or Custom Mode instructions.

## Find out what they need

Infer the need from the message and conversation. A named situation, such as "which skill reviews a PR?", goes straight to its section. If the need is unclear, ask one multiple-choice question with these options, then answer the section they pick:

- Get set up.
- Start a task with `$poteto-mode`.
- Pick a skill for a situation.
- Fix a run that went wrong.
- Make pstack my own.

Check the state that changes the answer, and mention it only when it does:

- Read [Codex runtime](../poteto-mode/references/codex-runtime.md) before checking model settings. If the personal override file is absent, every role uses its shipped default. Absence does not prove setup has never run.
- Check the project's verification tools when the question is about proving a change works. Use available tests and host control tools. Don't recommend an unshipped verification skill.

When personal overrides are absent and it matters, ask whether the user wants to choose role models and reasoning effort now. It matters when the user is new, asks about setup or cost, or needs to know which models run. Ask at most once per chat. If the need is also unclear, combine the questions. Offer two choices:

- Now. Give them `$setup-pstack` to type, and answer their question too.
- Later. Answer their question and say roles keep their shipped defaults until configured.

## Get set up

1. Follow the [README installation instructions](https://github.com/g1eny0ung/pstack-codex#install) and start a new Codex chat.
2. Invoke [setup-pstack](../setup-pstack/SKILL.md) to inspect or change role models and reasoning effort. Personal overrides stay outside the installed plugin.
3. Start a real task with `$poteto-mode`, a goal, and a check that can pass or fail.

All skills require explicit invocation. An invoked workflow can read related skills when needed. Offer to word the first prompt using [the prompting reference](references/prompting.md).

If cost is the concern, explain that subagents and review panels consume additional tokens. Use `$setup-pstack` to choose supported models or lower reasoning effort. The runtime owns the allowed settings and panel sizes. Do not suggest `auto`, `inherit-parent`, or fewer interrogate seats. Those are not supported configuration values in this port.

## Start a task with `$poteto-mode`

`$poteto-mode` matches the task to a playbook, tracks its applicable steps, and reads other skills as needed. A skipped material step keeps its reason. A good prompt states the goal and how to tell it is done. Read [the prompting reference](references/prompting.md) before helping write one.

Invoke `$poteto-mode` for each new task that needs it. It does not install a persistent chat mode or change the main chat's model. Mid-chat, "new task" tells the agent to match a fresh playbook. Playbook delegates use the local [poteto-agent reference](../poteto-mode/references/poteto-agent.md) through the host's native subagent tools.

## Pick a skill

The default answer for a nontrivial engineering task is `$poteto-mode`. Name a focused skill when the user wants a specific workflow. Read that skill before recommending it and give one example prompt.

| The user wants to | Skill |
|---|---|
| Complete an engineering task with verification | [poteto-mode](../poteto-mode/SKILL.md) |
| Understand current code or where a change belongs | [how](../how/SKILL.md) |
| Understand why code has its current shape | [why](../why/SKILL.md) |
| Compare types and module structure before implementation | [architect](../architect/SKILL.md) |
| Compare attempts at one brief and combine the best parts | [arena](../arena/SKILL.md) |
| Split checks or exploration across local agents | [swarm](../swarm/SKILL.md) |
| Get independent reviews of a diff | [interrogate](../interrogate/SKILL.md) |
| Fix a bug with a cheap local test first | [tdd](../tdd/SKILL.md) |
| Apply TypeScript conventions | [typescript-best-practices](../typescript-best-practices/SKILL.md) |
| Review comments and their underlying constraints | [no-comments](../no-comments/SKILL.md) |
| Remove unnecessary generated code | [deslop](../deslop/SKILL.md) |
| Drive a CLI or browser for verification | [control-cli](../control-cli/SKILL.md), [control-ui](../control-ui/SKILL.md) |
| Remove AI writing patterns | [unslop](../unslop/SKILL.md) |
| Write technical documentation | [technical-writing](../technical-writing/SKILL.md) |
| Check a performance measurement | [benchmark-checklist](../benchmark-checklist/SKILL.md) |
| Plan a large or cross-cutting engineering run | [figure-it-out](../figure-it-out/SKILL.md) |
| Keep or review a decision log | [show-me-your-work](../show-me-your-work/SKILL.md) |
| Configure role models and reasoning effort | [setup-pstack](../setup-pstack/SKILL.md) |
| Turn a completed task's lessons into proposed skill changes | [reflect](../reflect/SKILL.md) |
| Prevent repeated agent mistakes in a repository | [correct](../correct/SKILL.md) |
| Find their way around the plugin | `$poteto-help` |

If a sibling skill is missing from the table, read its frontmatter and route by its description. The `principle-*` directories are covered below.

Close calls:

- `$how` explains mechanics. `$why` explains reasons.
- `$arena` gives every worker the same brief. `$swarm` splits the work into slices or a race.
- `$architect` implements after settling the design. Add "with checkpoint" to review the design before implementation.
- `$interrogate` reviews a diff. `$correct` identifies repeated mistakes and changes the repository to prevent them.
- Resuming a specific chat or branch uses Session pickup. This port does not ship a cross-chat recall skill.
- `$figure-it-out` designs a rigorous run. The Autonomous run playbook drives one task to a finish condition.

## Playbooks and principles

Playbooks are step lists inside `$poteto-mode`, not separate skills. These phrases select one:

- "Check on PR 123. Anything outstanding?" runs Babysit in its status mode. "Babysit this PR. Get it green." requests active work. Neither request authorizes a merge.
- "Land the stack" runs Shipping.
- "Take over this branch" runs Session pickup.
- "Pause safely" runs Pause safely.
- "Run the eval playbook" runs Eval.

The [poteto-mode playbook list](../poteto-mode/SKILL.md#playbooks) owns the complete routing. Cloud orchestration and the two Autopilot playbooks are excluded from this port.

For work spanning phases or stacked PRs, asking `$poteto-mode` for a plan runs the [Multi-phase plan playbook](../poteto-mode/playbooks/multi-phase-plan.md). A plan request does not authorize implementation. For a design question, the Prototype playbook or `$architect` can test alternatives first.

Principles are focused skills that `$poteto-mode` reads and cites when they change a decision. A user can steer with a name, such as "Apply Prove It Works. Show me the actual output." Read the relevant `principle-*/SKILL.md` before explaining it.

## Fix a run that went wrong

| Symptom | Fix |
|---|---|
| An unrelated task inherited the previous workflow | State "new task" and invoke the desired skill for that task. |
| A new model setting had no effect | Read the effective configuration. New settings apply to subsequent subagent launches, not running agents or the main chat. |
| Runs cost more than expected | Inspect role settings and the subagents the selected workflow requires. |
| A skill did not load on its own | Invoke it explicitly. All shipped skills are explicit-only. |
| Parallel agents overwrote each other | Give writers separate worktrees or disjoint file ownership. |
| An unattended run made changes but finished nothing | Set a checkable finish condition. Request scheduling explicitly only when later wakeups are needed and the host supports them. |
| The reply claims success from a green build | Ask for the actual command output, user flow, stored value, or profile. |

[The prompting reference](references/prompting.md) has short ways to redirect a run. [The recipes](references/recipes.md) provide example prompts.

## Make pstack my own

- Use `$setup-pstack` for personal role configuration.
- Use [reflect](../reflect/SKILL.md) after a session to propose skill edits.
- Ask `$poteto-mode` to write a skill for a workflow. It uses the host's skill authoring tools when available. The Eval playbook can test a change independently.
- Edit skills in their source checkout. Keep personal configuration and task artifacts outside the installed cache.

## Reply

Lead with the answer. Give at most one example prompt in a code block, adapted from [the recipes](references/recipes.md), then a link to the source you read. Keep it short unless the user asks for the whole map.
