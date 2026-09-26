---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
---

# Reflect

Read [Codex runtime](../poteto-mode/references/codex-runtime.md) before using subagents, model settings, or conversation history. Resolve sibling skills from this plugin’s `skills/` directory.

Mine the current conversation for durable learnings, then route them into skill edits.

## When to invoke

Invoke when the user says "reflect" or "$reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## Process

### 1. Locate the active transcript

Export only the target conversation with the shared runtime’s session reader before fanning out. Resolve the thread ID from the current host or an explicit user reference.

```bash
node "$POTETO_SKILL_ROOT/scripts/read-thread.mjs" --thread-id <thread-id> > <task-dir>/transcript.json
```

Give reviewers the exported path and any missing/truncated-history markers. If full persisted history is unavailable, report that limitation; do not substitute a digest and call it a transcript audit. Do not search unrelated conversations.

### 2. Spawn three reviewers in parallel

Launch three independent local review subagents within the available slots. Their task is read-only, including connector lookups.

Resolve each role through the shared model configuration.

| Lens | Role | Default effort | Prompt template |
|---|---|---|---|
| Judgment | `reflect_judgment` | `xhigh` | `references/judgment-reviewer.md` |
| Tooling | `reflect_tooling` | `high` | `references/tooling-reviewer.md` |
| Divergent | `reflect_divergent` | `xhigh` | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the exported transcript path where marked. Reviewers return findings in their final report.

### 3. Synthesize

Launch one read-only synthesis subagent using `reflect_synthesizer`. Spot-verify citations using available tools. Use `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. The synthesizer returns a structured Accepted / Rejected / Backlog list.

### 4. Structural enforcement check

Sanity-check the synthesizer's Accepted list. For any item that would be enforced more reliably by a lint rule, script, metadata flag, or runtime check, move it from Accepted to Backlog. See the **encode-lessons-in-structure** principle skill.

### 5. Apply

Before applying any Accepted edit, present the synthesizer's full Accepted/Rejected/Backlog output to the user and wait for explicit approval. The user picks which subset to apply and may redirect routings. Skill changes affect future uses of the edited skill. Do not auto-apply.

Keep backlog items in the report. File them to an external tracker only when the user authorized that action. Apply approved edits to the skill’s maintained source, not a read-only plugin cache.

For each approved Accepted item, follow the Routing field exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): parent does directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to the host’s `skill-creator` skill and run its draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to `skill-creator` and run its description-optimization loop.
- `new skill via skill-creator: <kebab-name>`: hand creation to `skill-creator`. Do not invent the shape ad hoc.

If `skill-creator` is unavailable, use the Codex format: a directory with `SKILL.md`, `name` and `description` frontmatter, plus only the supporting resources the workflow needs.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done. Skip this step if it doesn't.

### 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog: one line per item. Include a tracker link only when an authorized write actually occurred.
- Dropped: one line per rejected finding + reason from the synthesizer.
