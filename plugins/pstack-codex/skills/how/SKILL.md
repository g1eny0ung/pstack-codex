---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Use why for motivation."
---

# How

Read [Codex runtime](../poteto-mode/references/codex-runtime.md) for model roles, native subagents, paths, and history.

Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

Every spawn uses the native asynchronous local subagent API with a read-only assignment. Do not edit files or external records. Explorers use the `how_explorer` line in the Codex model configuration (default `gpt-6.1-sol` with `reasoning_effort: high`), and every explainer uses the `how_explainer` line (default `gpt-6.1-sol` with `reasoning_effort: xhigh`). Set `model` and `reasoning_effort` to that role's values, or to the default if the rule or the line is missing. Leave `model` and `reasoning_effort` unset when the value is `auto` or `inherit-parent`. If the native subagent tool rejects a configuration, use the default and say so. If it rejects the default, use the closest supported configuration of the same GPT model from its error message.

## 1. Assess complexity

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

- **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. Spawn one explainer that explores and explains in one pass, built from `references/explainer-prompt.md` without the explorer-findings section. Go to step 4.
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): go to step 2.

When in doubt, take the simple path.

## 2. Explore (complex only)

Decompose the question into 2 to 4 angles, each a distinct slice of the subsystem. Spawn all explorers concurrently, in batches when the host limits slots, each with `references/explorer-prompt.md` and its angle filled in.

## 3. Synthesize (complex only)

Once all explorers have returned, spawn one explainer with `references/explainer-prompt.md` and every explorer's findings filled in.

## 4. Present

Present the explainer's output. Light edits for clarity or context from the conversation are fine. Do not substantially rewrite it.

## Output format

The explanation uses the sections defined in `references/explainer-prompt.md`, dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.
