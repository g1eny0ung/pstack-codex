---
name: setup-pstack
description: Configure pstack-codex models and reasoning effort per role without changing the main chat model. Use for $setup-pstack or requests to change pstack model settings.
---

# Setup pstack

Read [Codex runtime](../poteto-mode/references/codex-runtime.md) for the role schema, defaults, personal override path, and validation rules.

## 1. Inspect available configurations

Read the native subagent tool’s supported models and reasoning efforts. A host model-list interface may supplement it, but never assume a configured model is available to the current subagent tool. Only GPT configurations are supported by this plugin. Model and effort are separate fields.

## 2. Load current settings

Read the plugin’s `config/models.defaults.json`, then the personal override at `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` if it exists. Apply the merge rules in the runtime. Report invalid roles or unsupported values without silently deleting them.

## 3. Apply the requested change

When the user named roles or effort values, update those directly. If the request is only “configure pstack,” show the current role table and ask which settings to change. Do not require a second confirmation for a choice the user already made.

Keep the defaults unless changed explicitly: all agents use `gpt-6-astra`; writing uses `medium`, ordinary work uses `high`, complex synthesis and judging use `xhigh`, and the three ordered interrogate seats use `ultra`, `xhigh`, and `high`. A role is an object with `model` and `reasoning_effort`. Candidate and reviewer roles are ordered arrays of these objects.

The `writing` role applies when a writing task is delegated. It does not spawn an extra writing agent for each reply or change the main conversation’s model.

## 4. Validate and save

Validate every changed model and effort against the current native tool. An unavailable value is a concrete missing capability: report it and wait for the user to choose an available replacement. Do not silently substitute, lower effort, or encode effort inside a model name.

Create the personal configuration directory if needed. Write valid version-1 JSON containing only personal overrides. Preserve unrelated valid overrides. Scalar role overrides may name one or both fields. An array override replaces that role’s entire ordered array, with both fields in each seat. `interrogate_reviewers` always has three seats. Resetting a role removes its override and reveals the shipped default.

Never modify global Codex model settings or files in the installed plugin cache. Do not write an always-applied rule.

## 5. Report

Show the saved path and the changed effective role values. They apply to subsequent subagent launches after configuration is read again; running agents keep their original settings.
