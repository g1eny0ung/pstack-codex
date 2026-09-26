---
name: interrogate
description: "Use for \"interrogate\", \"adversarial review\", \"multi-model review\", \"challenge this\", \"stress test this code\", \"find blind spots\", or \"tear this apart\". Independent GPT reviewers challenge code changes."
---

# Interrogate

Read [Codex runtime](../poteto-mode/references/codex-runtime.md) before using subagents, model settings, or conversation history. Resolve sibling skills from this plugin’s `skills/` directory.

Spawn three independent GPT reviewers to adversarially review code changes. Each gets the same evidence, prompt, and rubric. They do not see each other’s findings before submitting their own. Different reasoning efforts do not guarantee different blind spots.

The deliverable is a synthesized verdict. Do NOT auto-apply changes.

## Step 1, Determine Scope

Identify what to review from context:

- If the user points at specific files or a diff, use that
- If on a feature branch, run `git diff <base>...HEAD` (resolve the project’s actual base branch first) for the full changeset
- If the user's message references recent work, gather the relevant files

Package the diff (or file contents) plus any surrounding context files the reviewers need to understand the code.

## Step 2, State the Intent

Before spawning reviewers, state the intent explicitly. Derive this from:

- The user's message
- Commit messages
- PR description if one exists
- The code itself

Write one clear paragraph. If you're unsure about the intent, ask the user before proceeding.

## Step 3, Spawn Reviewers

Read the ordered `interrogate_reviewers` role. Its three default seats are:

| Reviewer | Model | Reasoning effort |
|---|---|---|
| A | `gpt-6-astra` | `ultra` |
| B | `gpt-6-astra` | `xhigh` |
| C | `gpt-6-astra` | `high` |

Launch fresh local Codex subagents with explicit `model` and `reasoning_effort`, using the shared runtime. Launch concurrently when three slots are available; otherwise run all three seats in batches without exposing earlier findings. Each task is read-only. Do not modify the code under review. If a seat is unavailable, report the exact gap; do not silently lower its effort or claim a complete three-reviewer run.

Read `references/reviewer-prompt.md` and fill in the template with:
1. The stated intent
2. The diff or file contents
3. The review rubric from `references/rubric.md`
4. The code-quality lens from `references/code-quality-review.md`

The same filled template goes to all reviewers, so every reviewer applies the code-quality lens.

## Step 4, Synthesize

As results come back, build a unified picture:

1. **Parse all findings** from the reviewers
2. **Identify consensus**. Findings raised by 2+ reviewers independently are strong leads, not a vote.
3. **Identify individual findings**. Check their evidence, especially correctness and security findings, even when neither other reviewer mentioned them.
4. **Deduplicate**. Different reviewers may describe the same issue differently. Merge these and note which reviewers raised it.
5. **Note disagreements**. If one reviewer flags something and another explicitly says the opposite, that's useful context for the verdict.

## Step 5, Lead Judgment

You are the lead reviewer, a pragmatic senior engineer, not a neutral aggregator.

Read `references/lead-judgment.md` for the full framework. Decide from code evidence and actual behavior, never majority vote or reasoning rank. Agreement by two reviewers cannot dismiss a proven finding from another seat.

Categorize every finding using these buckets:

- **Act on**. Real issues affecting correctness, security, or maintainability given the actual goals. These would block a real PR.
- **Consider**. Legitimate points, but you're not sure they outweigh the cost of addressing them right now. Worth the user's attention.
- **Noted**. Technically valid but not actionable. Context-dependent, premature optimization, or low-impact given the current stage.
- **Dismissed**. Wrong, nitpicky, or missing context. Brief explanation why.

For each finding, include:
- Which reviewer(s) raised it
- The category (act on / consider / noted / dismissed)
- A one-line rationale for the categorization

## Output Format

Present the verdict in this structure:

### Intent
> [The stated intent paragraph from Step 2]

### Reviewers
- Reviewer [label]: [model name], [reasoning effort], [N findings] (one bullet per reviewer)

### Act On
[Findings that should be addressed. For each: description, which reviewers raised it, why it matters.]

### Consider
[Findings worth thinking about. For each: description, which reviewers raised it, tradeoff involved.]

### Noted
[Valid but low-priority. Brief list.]

### Dismissed
[Rejected findings with brief rationale.]

### Agreement Map
[Where did reviewers agree, where did they diverge, and what does the pattern of agreement/disagreement tell us?]
