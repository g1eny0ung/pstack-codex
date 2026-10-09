---
name: poteto-help
description: Guides users through pstack setup, $poteto-mode, and picking the skill, playbook, or principle for a task. Type $poteto-help with a question.
---

# Poteto help

Answer the user's question about pstack, hand them a prompt they can send, and link the file the answer came from. For a help question, don't start the work. The user asked how, and a pstack run spends real tokens, so let them send the prompt.

A message that asks for work, such as "use pstack to fix this bug", is not a help question. Read [`poteto-mode`](../poteto-mode/SKILL.md), do the work under it, and mention once that it applies to the current task.

This file maps questions to the skills and guide pages that hold the answers. Those files own the details. Read the file you route to before you quote it, and trust it when it disagrees with this map. The local links here point into the installed plugin. Give the user the resolved file link for Codex instructions. Links to upstream guide pages are pinned source references; their Cursor-specific instructions do not override this port.

## Find out what they need

Infer the need from the message and the conversation. A named situation, such as "which skill reviews a PR?", goes straight to its section. If the need is still unclear, ask one multiple-choice question with these options, then answer only the section they pick:

- Get set up
- Start a task with `$poteto-mode`
- Pick a skill for a situation
- Fix a run that went wrong
- Make pstack my own

Check the state that changes the answer, and mention it only when it does:

- No `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` means `$setup-pstack` hasn't run for this user, so every role uses its default model.
- No `verify-*` skill or other app harness in the project means agents have no scripted way to drive the app. Mention the missing harness when the question is about proving a change works. The upstream `create-verification-skill` skill is outside this port.

When the model configuration is missing and it matters, ask whether the user wants to pick a model for each role and a reasoning budget now. It matters when the user is new, the question is about setup or cost, or the answer depends on which models run. Ask at most once per chat. If the need is also unclear, ask both questions together. Offer two choices:

- Now: give them `$setup-pstack` to type, and answer their question too.
- Later: answer their question, and add one line saying every role keeps its default model until they run `$setup-pstack`.

## Get set up

1. Install with `codex plugin marketplace add https://github.com/g1eny0ung/pstack-codex.git`, then `codex plugin add pstack-codex@pstack-codex`. Start a new chat after installation.
2. Run [`$setup-pstack`](../setup-pstack/SKILL.md). It asks for a reasoning budget, maps a model to each role, and writes personal JSON configuration. The configuration applies to subsequent subagent launches.
3. Start a real task with `$poteto-mode`, a goal, and a check that can pass or fail.

Installing changes nothing until the user invokes a skill. All skills require explicit invocation or deliberate routing from an invoked workflow. The [README](../../../../README.md) and [guide page 1](https://github.com/cursor/plugins/blob/ccb5507cec1546dc88135c1139c811e6c59115ba/pstack/docs/guide/01-setup.md) have the details. Offer to word their first prompt with them, per [`references/prompting.md`](references/prompting.md).

If cost is the worry, say where the tokens go and how to spend fewer. pstack spends extra tokens on subagents and review panels. Rerun `$setup-pstack` and pick a smaller budget or cheaper models. A role set to `auto` or `inherit-parent` runs on the chat's model, which saves tokens when the chat runs on a cheaper model. A shorter panel list runs fewer subagents, one for each entry. Save `$poteto-mode` for work that needs rigor.

pstack is built for Cursor. This port uses the Agent Skills format and Codex local subagents with per-role GPT models. Custom Modes and `/loop` are Cursor features; this port uses current-task invocation and the host's native continuation and automation capabilities. Read [Codex runtime](../poteto-mode/references/codex-runtime.md) for those interfaces.

## Start a task with `$poteto-mode`

`$poteto-mode` matches the task to a playbook, copies the playbook's steps into the todo list, and runs the other skills as the steps need them. A step it skips stays in the list as `skip: <reason>`. A good prompt states the goal and how to tell it's done. It doesn't list skills, because a hand-written sequence tends to drop or reorder steps the playbook would keep. Read [`references/prompting.md`](references/prompting.md) before you help word one. [Guide page 2](https://github.com/cursor/plugins/blob/ccb5507cec1546dc88135c1139c811e6c59115ba/pstack/docs/guide/02-poteto-mode.md) has examples.

`$poteto-mode` applies to the current task. Start each new task with `$poteto-mode`; this port does not install a persistent Custom Mode.

Link [Codex runtime](../poteto-mode/references/codex-runtime.md) when this comes up. Mid-chat, "new task" makes the mode match a fresh playbook. `$poteto-mode` already uses `poteto-agent` for the subagents its playbook steps spawn. To get the same style from a subagent of your own, spawn it with the native local subagent tool and require it to read [poteto-agent](../poteto-mode/references/poteto-agent.md).

## Pick a skill

The default answer is `$poteto-mode`, which runs most of the others when its steps need them. Name a skill directly when the user wants more or less of something than the playbook gives. Read the skill before you recommend it, and give one example prompt.

| The user wants to | Skill |
|---|---|
| Do any non-trivial task with rigor | [`$poteto-mode`](../poteto-mode/SKILL.md) |
| Know how code works now, or where new code should live | [`$how`](../how/SKILL.md) |
| Know why code is shaped this way, or where a number came from | [`$why`](../why/SKILL.md) |
| Understand a change or subsystem, explained plainly | [`$teach`](../teach/SKILL.md) |
| Know what a small diff could break outside itself | [`$blast-radius`](../blast-radius/SKILL.md) |
| Settle types and module shape before code that crosses a function boundary | [`$architect`](../architect/SKILL.md) |
| Get several attempts at one brief, merged into the best one | [`$arena`](../arena/SKILL.md) |
| Run parallel checks over slices, or race workers, as local agents | [`$swarm`](../swarm/SKILL.md) |
| Have different GPT configurations review a diff and try to break it | [`$interrogate`](../interrogate/SKILL.md) |
| Fix a bug test-first when a cheap local test exists | [`$tdd`](../tdd/SKILL.md) |
| Apply TypeScript rules to `.ts` or `.tsx` work | [`$typescript-best-practices`](../typescript-best-practices/SKILL.md) |
| Strip comments before review, using a reviewer that didn't write them | [`$no-comments`](../no-comments/SKILL.md) |
| Clean AI tells out of prose | [`$unslop`](../unslop/SKILL.md) |
| Write docs, an RFC, a README, a PR description, or a commit message to a standard | [`$technical-writing`](../technical-writing/SKILL.md) |
| Hear the last reply again in plain words | [`$bro`](../bro/SKILL.md) |
| Vet a performance number before reporting or acting on it | [`$benchmark-checklist`](../benchmark-checklist/SKILL.md) |
| Run a large or cross-cutting change, or one to review after stepping away | [`$figure-it-out`](../figure-it-out/SKILL.md) |
| Keep a decision log during a run, and review it afterward | [`$show-me-your-work`](../show-me-your-work/SKILL.md) |
| Pick a model for each role and a reasoning budget | [`$setup-pstack`](../setup-pstack/SKILL.md) |
| Turn what a finished task taught into skill edits | [`$reflect`](../reflect/SKILL.md) |
| Stop agents from repeating the same mistakes in this repo | [`$correct`](../correct/SKILL.md) |
| Find their way around pstack | `$poteto-help` |

If a skill directory next to this one is missing from the table, read its frontmatter and route by its description. The `principle-*` directories are covered under principles below.

Close calls:

- `$how` explains what the code does. `$why` explains the reasons. `$teach` runs one or both and explains the result plainly.
- `$arena` gives every worker the same brief and merges the best parts. `$swarm` splits work into slices or a race and returns one report.
- `$architect` implements right after it settles the design. Add "with checkpoint" to review the design before it writes code.
- `$interrogate` reviews the diff. `$blast-radius` looks for breakage outside the diff and proves the one fact that makes the change safe.
- Resuming one specific chat or branch is the Session pickup playbook.
- `$figure-it-out` designs one rigorous run. The Autonomous run playbook drives one task to a finish condition.

Availability in this port:

- `$deslop`, `control-cli`, and `control-ui` come from `cursor-team-kit` and are bundled in this port.
- `/loop` and `/create-skill` are Cursor built-ins. Use the Codex runtime continuation interfaces and the host's skill-creator skill instead.
- pstack has no `/orchestrate` skill. Its Orchestrate playbook is excluded from this port, as are Autopilot-full and Autopilot-stack. If a skill menu shows `/orchestrate`, another plugin provides it.

## Playbooks and principles

Playbooks are step lists inside `$poteto-mode`, not skills, so they have no standalone skill command. Inside `$poteto-mode`, describing the task picks one, and these phrases name one directly:

- "babysit this pr" or "check on pr 123" runs Babysit. It drives the PR to merge-ready and stops there. It doesn't merge unless the user asks to merge, land, or ship.
- "land the stack" runs Shipping.
- "take over this branch" runs Session pickup.
- "pause safely" runs Pause safely.
- "run the eval playbook" runs Eval.

Without `$poteto-mode`, a phrase such as "babysit this pr" can start another installed skill for the same job instead. The Playbooks section of [`poteto-mode`](../poteto-mode/SKILL.md) lists every playbook and when it applies. [Guide page 6](https://github.com/cursor/plugins/blob/ccb5507cec1546dc88135c1139c811e6c59115ba/pstack/docs/guide/06-verify-and-ship.md) covers opening, babysitting, and landing a PR.

pstack has no planning skill. Codex's Plan Mode works alongside it. For work that spans phases or stacked PRs, asking `$poteto-mode` for a plan runs the [Multi-phase plan playbook](../poteto-mode/playbooks/multi-phase-plan.md), which writes the plan and doesn't implement it. For a design question, the Prototype playbook or `$architect` settles it in code first.

Principles are one-rule skills that `$poteto-mode` reads and cites in its replies. The user rarely invokes one. They steer with the names instead, as in "apply prove it works. show me the real output." Typing `$principle-<name>` still loads one on demand. [Guide page 8](https://github.com/cursor/plugins/blob/ccb5507cec1546dc88135c1139c811e6c59115ba/pstack/docs/guide/08-principles.md) lists them.

## Fix a run that went wrong

| Symptom | Fix |
|---|---|
| The mode stopped applying after a few turns | The invocation applies to one task. Start each task with `$poteto-mode`. |
| A question got treated as the next step of the last task | Say "new task", or say the turn doesn't need the mode. |
| A new model choice had no effect | The configuration from `$setup-pstack` applies to subsequent subagent launches. Running agents keep their settings. |
| Runs cost more than expected | See the cost paragraph under Get set up. |
| A skill didn't load on its own | All skills require explicit invocation or deliberate routing from an invoked workflow. They load when the user types them or when `$poteto-mode` runs them, and it doesn't run every skill. |
| Parallel agents overwrote each other | Give each agent its own worktree. |
| An overnight run moved but finished nothing | The autonomous run needs a check that can pass or fail, not a duration. See [guide page 7](https://github.com/cursor/plugins/blob/ccb5507cec1546dc88135c1139c811e6c59115ba/pstack/docs/guide/07-overnight.md). |
| The reply claims success from a green build | Ask for the real command, flow, stored value, or profile. That's the prove-it-works principle. |

For a run that drifts, [`references/prompting.md`](references/prompting.md) has one-line steers. [Guide page 10](https://github.com/cursor/plugins/blob/ccb5507cec1546dc88135c1139c811e6c59115ba/pstack/docs/guide/10-recipes-and-pitfalls.md) has more pitfalls and the recipes worth copying.

## Make pstack my own

- [`$reflect`](../reflect/SKILL.md) after a session turns its lessons into skill edits the user approves.
- `$poteto-mode write a skill for <workflow>` runs the authoring playbook. The eval playbook tests a skill change blind.
- Fix a misbehaving skill in its own PR, not inside the feature work where it went wrong.

[Guide page 9](https://github.com/cursor/plugins/blob/ccb5507cec1546dc88135c1139c811e6c59115ba/pstack/docs/guide/09-make-it-yours.md) covers each of these.

## Reply

Lead with the answer. Give at most one example prompt in a code block, adapted from [`references/recipes.md`](references/recipes.md) when one fits, then the link to that file. Keep it short unless the user asked for the whole map.
