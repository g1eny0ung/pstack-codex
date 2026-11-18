---
name: arena
description: "Spawn N parallel candidates at the same task, pick a base, graft the strongest parts of the losers into it. Use for $arena, 'arena this', 'throw it in the arena', or when one attempt at a non-trivial artifact would lock in the wrong shape."
---

# Arena

Read [Codex runtime](../poteto-mode/references/codex-runtime.md) for model roles, native subagents, paths, and history.

Open a todolist with one entry per phase (Frame, Fan out, Cross-judge, Pick, Graft, Verify) before launching anything.

## Phase A: Frame

Every candidate gets the same prompt, so the prompt is the contract.

1. State the artifact each candidate is producing.
2. Derive the rubric, 3-6 concrete gradeable criteria for what success looks like on *this* task. It is the picker's tool in Phase D. Candidates only see the task.
3. Pick the runners from `arena_runners` in the Codex model configuration, by default two on `gpt-6.2-astra`, one with `reasoning_effort: xhigh` and one with `reasoning_effort: high`. For `auto` or `inherit-parent`, omit both `model` and `reasoning_effort`. If the native subagent tool rejects a configuration, use the nearest supported effort at or below `xhigh` for the same GPT model or drop the seat and say so. If dropping seats leaves fewer than two runners, add runners until there are two. Use a remaining runner's configuration, or omit both fields when none remains, and say so. Never retry a rejected configuration or a model the tool excludes. Spawn more for multiple design directions, and repeat one model when the work is generation-bound, not judgment-sensitive. Pick each subagent's reasoning level per the Subagents section of the **poteto-mode** skill.
4. Give each candidate its own output location (a git worktree where possible, otherwise `/tmp/arena-<slug>/candidate-<n>/`), per the **separate-before-serializing-shared-state** principle skill.

## Phase B: Fan out

Spawn all N local subagents concurrently, in batches when the host limits slots, each with the task, the path to the shared grounding, its own output path, and instructions to produce the artifact and a short rationale naming the alternatives it considered and what it rejected.

If a candidate produces no output, proceed with N-1 and note the dropout.

## Phase C: Cross-judge

After all Phase B candidates complete, spawn one readonly judge from `arena_cross_judge_pool` in the Codex model configuration, by default `gpt-6.2-astra` with `reasoning_effort: xhigh` followed by `gpt-6.2-astra` with `reasoning_effort: high`. Use the first explicit entry whose final reasoning effort differs from the parent's. Skip `auto` and `inherit-parent` because neither establishes an effort difference. If you do not know the parent's effort, use the first explicit entry and say that the effort-difference check did not run. If the native subagent tool rejects an entry, try the nearest supported effort at or below `xhigh` for the same GPT model that still qualifies, then the next eligible entry. If no eligible entry runs, skip the judge and say so. Never retry a rejected configuration or a model the tool excludes. While you read in Phase D, the judge scores each candidate, by path label, on each rubric criterion and recommends a base.

## Phase D: Pick a base

Read every candidate end to end before picking. Score each against the rubric criterion by criterion, not on holistic feel, and compare with the cross-judge when Phase C ran one. Agreement on the base confirms the pick. Disagreement means one of you is biased or the rubric was ambiguous. Read both rationales before deciding.

Pick the base a future maintainer can extend most easily without breaking invariants. When two feel tied, prefer the cleaner boundary or smaller API, per the Laziness Protocol.

## Phase E: Graft

Walk each losing candidate once more for what is worth porting into the base, usually one or two things per candidate, not most of it. Fold each graft in by hand, per the **redesign-from-first-principles** principle skill, so the result stays coherent under one mental model. Don't paste mechanically.

If the candidates converge on one shape, that is strong agreement. Note it and ship the consensus shape. No graft is needed. If they wildly diverge, Phase A was under-specified. Reframe and re-run rather than averaging the divergence.

## Phase F: Verify

Verify the synthesized artifact like any other output, per the **prove-it-works** principle skill. If verification finds a problem the arena missed, either Phase A was wrong (re-frame and re-run) or a candidate caught it and you missed the graft (go back to Phase E). Don't paper over it.

## Outputs

One synthesized artifact, with a short synthesis note alongside naming the base and why, the cross-judge's verdict or that Phase C skipped the judge, each graft with its source candidate, what was rejected and why, any convergence or dropouts, and the verification result.
