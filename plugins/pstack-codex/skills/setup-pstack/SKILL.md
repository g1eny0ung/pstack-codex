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

Read `config/models.defaults.json` from the plugin root. The default role-to-model mapping is the JSON shape shown in step 5 below. If `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` already exists, read it and treat its `budget` field and its role values as the current choices, resolving overrides per the Codex runtime. Otherwise start from those defaults. A key whose role is not in step 5, such as `how_critics`, is from a retired role. Drop it. If older split roles contain conflicting values for one shared role, show the conflict when choosing that shared setting.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Prefer the host's question tool over free text when available. Offer these four options with these exact labels, and name the current budget when the configuration records one. With no configuration, show the shipped defaults, whose reasoning efforts vary by role.

- `unlimited — max reasoning`
- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** Build the working table from the skill defaults, and on a re-run keep any role you changed by model, list, or alias (`inherit-parent`, `auto`). `unlimited`, `large`, `medium`, and `small` set the `reasoning_effort` field of every explicit configuration, panel entries included, to `max`, `xhigh`, `high`, or `medium`. Keep model and effort in separate fields. The effort ladder is `max` > `xhigh` > `high` > `medium` > `low`. If the result is not a detected model/effort pair, use the same model with its highest supported effort at or below the target, else mark the role as needing a choice. `inherit-parent` and `auto` do not change. So `unlimited` turns `{ "model": "gpt-6-astra", "reasoning_effort": "xhigh" }` into `{ "model": "gpt-6-astra", "reasoning_effort": "max" }` when supported. If a GPT model tops out at `xhigh`, under `unlimited` the fallback puts it at `xhigh` and keeps an existing `xhigh` configuration as it is. `large` sets explicit configurations to `xhigh` when supported. `small` sets them to `medium` when supported.

**(c) Show the roles and confirm.** Show every role with its model and reasoning effort, marking any explicit pair not in the detected set as needing a choice. Also list each key step 2 dropped. Ask whether to accept as-is or change specific roles, offering the detected GPT model/effort pairs plus `inherit-parent` and `auto` (both mean: this role inherits the parent model and reasoning effort by omitting both launch fields) as the options. Prefer the host's question tool over free text when available. For panel roles (arena runners, architect runners, interrogate reviewers) the value is a list, and one subagent runs per entry, alias entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena selects one value from it whose reasoning effort differs from the parent's when possible. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

Every explicit model/effort pair written must be in the detected set. `inherit-parent` and `auto` always pass. If a chosen model/effort pair is not available, stop and ask again.

### 5. Write the configuration

Write `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` with `"version": 1`, a `budget` field with the chosen label, and a `roles` object, using the role keys poteto-mode uses. Create the personal configuration directory if needed. The saved role values determine launches; the budget records the chosen label and does not overwrite later per-role edits. Overwrite the whole file so re-runs stay idempotent. Shape:

The following shape shows all 17 shipped defaults. After a budget is chosen, record its label in `budget` and write the mapped role values. Remove a role override to fall back to its shipped default. Scalar objects may override either or both fields. Lists replace the whole ordered list and must be nonempty; each entry is a complete model/effort object or `"inherit-parent"` or `"auto"`. Aliases inherit both parent fields and still count toward panel fan-out.

```json
{
  "version": 1,
  "roles": {
    "feature_refactoring": {
      "model": "gpt-6-astra",
      "reasoning_effort": "high"
    },
    "bug_fix": {
      "model": "gpt-6-astra",
      "reasoning_effort": "high"
    },
    "perf_issue": {
      "model": "gpt-6-astra",
      "reasoning_effort": "high"
    },
    "hillclimb": {
      "model": "gpt-6-astra",
      "reasoning_effort": "high"
    },
    "judgment_and_prose": {
      "model": "gpt-6.1-sol",
      "reasoning_effort": "xhigh"
    },
    "hardest_tasks": {
      "model": "gpt-6-astra",
      "reasoning_effort": "xhigh"
    },
    "how_explorer": {
      "model": "gpt-6.1-sol",
      "reasoning_effort": "high"
    },
    "how_explainer": {
      "model": "gpt-6.1-sol",
      "reasoning_effort": "xhigh"
    },
    "why_investigators": {
      "model": "gpt-6.1-sol",
      "reasoning_effort": "xhigh"
    },
    "why_synthesizer": {
      "model": "gpt-6-astra",
      "reasoning_effort": "xhigh"
    },
    "reflect_tooling": {
      "model": "gpt-6.1-sol",
      "reasoning_effort": "high"
    },
    "reflect_judgment_divergent_synthesizer": {
      "model": "gpt-6-astra",
      "reasoning_effort": "xhigh"
    },
    "arena_runners": [
      {
        "model": "gpt-6-astra",
        "reasoning_effort": "xhigh"
      },
      {
        "model": "gpt-6-astra",
        "reasoning_effort": "high"
      }
    ],
    "arena_cross_judge_pool": [
      {
        "model": "gpt-6-astra",
        "reasoning_effort": "xhigh"
      },
      {
        "model": "gpt-6-astra",
        "reasoning_effort": "high"
      }
    ],
    "swarm_workers": {
      "model": "gpt-6-astra",
      "reasoning_effort": "high"
    },
    "architect_runners": [
      {
        "model": "gpt-6-astra",
        "reasoning_effort": "xhigh"
      },
      {
        "model": "gpt-6-astra",
        "reasoning_effort": "high"
      }
    ],
    "interrogate_reviewers": [
      {
        "model": "gpt-6-astra",
        "reasoning_effort": "xhigh"
      },
      {
        "model": "gpt-6-astra",
        "reasoning_effort": "high"
      }
    ]
  }
}
```

### 6. Confirm

Tell the user the configuration was written and that it applies to subsequent subagent launches; running agents keep their settings. Re-running this skill updates it.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can help author one with the poteto-mode authoring playbook." On yes, use the [Authoring a skill playbook](../poteto-mode/playbooks/authoring-a-skill.md). The upstream `create-verification-skill` skill is outside this port. On no, move on without pushing.
