---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
---

# Reflect

Read [Codex runtime](../poteto-mode/references/codex-runtime.md) for model roles, native subagents, paths, and history.

Mine the current conversation for durable learnings, then route them into skill edits.

## When to invoke

Invoke when the user says "reflect" or "$reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## Process

### 1. Locate the active transcript

The parent finds its own transcript file before fanning out. Resolve the current thread ID from the host context and export it with `read-thread.mjs` as described in Codex runtime. Do not scan unrelated Codex conversations. That crosses workspace boundaries and reads private chats from unrelated projects.

```bash
node "$POTETO_SKILL_ROOT/scripts/read-thread.mjs" --thread-id <thread-id> > <task-dir>/transcript.json
```

The export preserves thread, turn, item, and tool-result associations.

Check the exported thread ID and opening user prompt against the current conversation. Take the matching path. If no path resolves, write a tight digest of the session and pass that instead, marking the missing transcript as a coverage gap.

### 2. Spawn three reviewers in parallel

Three concurrent native local subagent launches, with `model` and `reasoning_effort` set as below. Reviewers need MCP access for context lookups (tickets, chat threads, observability traces referenced in the transcript). Preserve MCP access while prohibiting writes.

Each reviewer and the synthesizer name a role in the Codex model configuration and a default. Set `model` and `reasoning_effort` to that role's values, or to the default if the rule or the line is missing. Leave `model` and `reasoning_effort` unset when the value is `auto` or `inherit-parent`. If the native subagent tool rejects a configuration, use the default and say so. If it rejects the default, use the closest supported configuration of the same GPT model from its error message.

| Lens | Role line | Default `model` | Prompt template |
|---|---|---|---|
| Judgment | `reflect_judgment_divergent_synthesizer` | `gpt-6-astra` with `reasoning_effort: xhigh` | `references/judgment-reviewer.md` |
| Tooling | `reflect_tooling` | `gpt-6.1-sol` with `reasoning_effort: high` | `references/tooling-reviewer.md` |
| Divergent | `reflect_judgment_divergent_synthesizer` | `gpt-6-astra` with `reasoning_effort: xhigh` | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in their native subagent reports.

### 3. Synthesize

One native local subagent launch, with `model` and `reasoning_effort` from the `reflect_judgment_divergent_synthesizer` line (default `gpt-6-astra` with `reasoning_effort: xhigh`). The synthesizer's quality check includes spot-verifying citations, which can require MCP access. Preserve MCP access while prohibiting writes. Use `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. The synthesizer returns a structured Accepted / Rejected / Backlog list.

### 4. Structural enforcement check

Sanity-check the synthesizer's Accepted list. For any item that would be enforced more reliably by a lint rule, script, metadata flag, or runtime check, move it from Accepted to Backlog. See the **encode-lessons-in-structure** principle skill.

### 5. Apply

Before applying any Accepted edit, present the synthesizer's full Accepted/Rejected/Backlog output to the user and wait for explicit approval. The user picks which subset to apply and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

Backlog items file to whatever devex / backlog tracker your team uses automatically when the user has authorized filing them. Only the Accepted list waits for approval.

For each approved Accepted item, follow the Routing field exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): parent does directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to Codex's built-in `skill-creator` skill and run its draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to `skill-creator` and run its description-optimization loop if available; otherwise report that missing capability.
- `new skill via skill-creator: <kebab-name>`: hand creation to `skill-creator`. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done. Skip this step if it doesn't.

### 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
