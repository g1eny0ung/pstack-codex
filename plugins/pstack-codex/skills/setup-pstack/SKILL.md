---
name: setup-pstack
description: Configure which models pstack uses per role and at what reasoning budget. Detects your available models and writes personal JSON configuration that overrides the skill defaults. Use for $setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

Write `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json`, personal JSON configuration that sets pstack's model and reasoning effort per role. Read [Codex runtime](../poteto-mode/references/codex-runtime.md) for configuration resolution and local launch rules. Do not change the main chat's model or write inside the installed plugin cache.

## Steps

### 1. Detect available models

Enumerate the GPT models and reasoning efforts you can pass to a native local subagent in this session. That is the dependable source. If the host also exposes a models API or CLI that lists the user's entitled models, prefer it for completeness. If you cannot detect any, ask the user to paste the GPT model and reasoning-effort pairs they have access to. Never write a model and reasoning-effort pair you have not confirmed is available. The aliases `inherit-parent` and `auto` are always valid even though they are not detected configurations.

### 2. Load current state

Read the role keys and defaults from [models.defaults.json](../../config/models.defaults.json). If `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` exists, read it and use its budget and role overrides as the starting choices. Otherwise start from the shipped defaults.

When this skill is invoked, prepare the following changes in memory before resolving the current roles. Drop the retired `hardest_tasks`, `architect_runners`, `reflect_tooling`, and `reflect_judgment_divergent_synthesizer` keys. Treat a saved `unlimited` budget as `large`. Bring any effort above `xhigh` down to the highest supported effort at or below `xhigh` for the same GPT model, including panel entries. If none is available, mark the entry as needing a choice. Preserve all other valid overrides, panel order, and aliases. Tell the user which keys or values you propose to change. Write only after the user confirms in step 3.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Prefer the host's question tool over free text when available. Offer these three options, and name the current budget when the configuration records one. With no configuration, say that `large` matches the shipped defaults.

- `large`, default effort
- `medium`, one step below default
- `small`, two steps below default

**(b) Apply it.** With a new configuration or a change of budget, start each target from its shipped default effort. Keep any model, ordered list, or alias the user chose. For a panel, use the default effort at the same position, and use the last shipped effort for positions beyond the default list. `large` keeps the starting effort, `medium` lowers it one step, and `small` lowers it two steps, on the ladder `xhigh` > `high` > `medium` > `low`. Stop at `low`. Write the target to the separate `reasoning_effort` field for each explicit configuration. If the model does not support the target, choose that model's highest supported effort at or below the target, or mark the role as needing a choice if it has none. For example, a panel with shipped efforts `xhigh` and `high` targets `high` and `medium` on `medium`. On a re-run with the same budget, keep the current role settings from step 2. Leave `inherit-parent` and `auto` unchanged.

**(c) Show the roles and confirm.** Show every role with its model and reasoning effort, marking any explicit pair not in the detected set as needing a choice. List the keys dropped and values replaced in step 2. Ask whether to accept as-is or change specific roles, offering the detected GPT model/effort pairs at `xhigh` or below plus `inherit-parent` and `auto` (both omit model and effort at launch and use the host's resolution rules in Codex runtime) as the options. Prefer the host's question tool over free text when available. For panel roles (arena runners, interrogate reviewers) the value is a list, and one subagent runs per entry, alias entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena runs one judge. It tries only explicit values whose final reasoning effort differs from the parent's when that effort is known, in list order, so order it by preference. An `inherit-parent` or `auto` value never judges. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

Every explicit model/effort pair written must be in the detected set and at `xhigh` or below. `inherit-parent` and `auto` always pass. If a chosen pair is unavailable or above the cap, stop and ask again.

### 5. Write the configuration

Write `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` with `"version": 1`, a `budget` field with the chosen label, and a `roles` object, using the role keys poteto-mode uses. Create the personal configuration directory if needed. The saved role values are launch starting settings; workflows adjust effort for the job per Codex runtime. The budget records the chosen label and does not overwrite later per-role edits. Overwrite the whole file so re-runs stay idempotent. Shape:

Use the role keys and shipped defaults loaded in step 2. After a budget is chosen, record its label in `budget` and write the mapped role values. Remove a role override to fall back to its shipped default. Scalar objects may override either or both fields. Lists replace the whole ordered list and must be nonempty; each entry is a complete model/effort object or `"inherit-parent"` or `"auto"`. Alias entries still count toward panel fan-out.

A partial override can look like this after confirming the effort is supported:

```json
{
  "version": 1,
  "budget": "medium",
  "roles": {
    "feature_refactoring": "inherit-parent",
    "judgment_and_prose": {
      "reasoning_effort": "high"
    }
  }
}
```

### 6. Confirm

Tell the user the configuration was written and that it applies to subsequent subagent launches; running agents keep their settings. Re-running this skill updates it.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can help author one with the poteto-mode authoring playbook." On yes, use the [Authoring a skill playbook](../poteto-mode/playbooks/authoring-a-skill.md). The upstream `create-verification-skill` skill is outside this port. On no, move on without pushing.

### 8. Offer a formal verification skill (optional)

Check whether the project already has a formal verification skill (a project skill that runs a model checker, a proof, or another verifier against the code). If not, offer once: "want a formal verification skill, so agents can prove a key property of your code holds in every case in scope, not only the cases tests reach? I can generate one with $create-formal-verification-skill." On yes, invoke [`$create-formal-verification-skill`](../create-formal-verification-skill/SKILL.md). On no, move on without pushing.
