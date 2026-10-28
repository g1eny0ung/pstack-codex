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
3. Pick the runners. Use the `arena_runners` line in the Codex model configuration. If the rule or that line is missing, default to one each on `gpt-6-astra` with `reasoning_effort: xhigh` and `gpt-6-astra` with `reasoning_effort: high`. An `auto` or `inherit-parent` entry in this line means the parent configuration, so omit both `model` and `reasoning_effort` for it. If the native subagent tool rejects a configured entry, run that seat on its corresponding shipped role default and say so, unless that configuration is already rejected. If there is no corresponding default, or the native tool rejects it, use the closest supported configuration of the same GPT model from its error message, or drop the seat and say so when there is none. Never retry a rejected configuration or a model the error excludes. If dropped seats leave fewer than two runners, add runners until there are two, or one when the line has one entry. Run each added runner on a remaining runner's model and reasoning effort, or omit both fields so it runs on the parent configuration when none remain, and say so. Spawn more runners when the arena covers multiple design directions. Use the same model N times when the work is generation-bound rather than judgment-sensitive. Pick each subagent's reasoning level and fast or standard speed for the job, per the Subagents section of the **poteto-mode** skill.
4. Give each candidate its own output location (a git worktree where possible, otherwise `/tmp/arena-<slug>/candidate-<n>/`), per the **separate-before-serializing-shared-state** principle skill.

## Phase B: Fan out

Spawn all N local subagents concurrently, in batches when the host limits slots, each with the task, the path to the shared grounding, its own output path, and instructions to produce the artifact and a short rationale naming the alternatives it considered and what it rejected.

If a candidate produces no output, proceed with N-1 and note the dropout.

## Phase C: Cross-judge

After all Phase B candidates complete, choose one configuration from the `arena_cross_judge_pool` line in the Codex model configuration. If the rule or that line is missing, use the shipped pool, `gpt-6-astra` with `reasoning_effort: xhigh` followed by `gpt-6-astra` with `reasoning_effort: high`. Spawn one readonly judge subagent. The judge's final reasoning effort must differ from the parent's when the parent effort is known. Try only eligible explicit entries, in pool order. An `auto` or `inherit-parent` entry inherits the parent configuration, so it never judges. If the native tool rejects an entry, use a supported configuration of the same GPT model at the closest effort or speed from the error message that still satisfies the effort difference, or move to the next entry when there is none. Recheck eligibility after task adjustments and every fallback. Never retry a rejected configuration or excluded model. If no eligible configured entry runs, try eligible entries from the shipped pool the same way. If none runs, skip the judge, pick the base alone in Phase D, and say so. If you do not know the parent's effort, try the pool's explicit entries in pool order and say that the effort-difference check did not run. The judge sees the rubric and the candidates by path label, scores each criterion, and recommends a base with rationale. It runs in parallel with your reading in Phase D. Don't spawn it while candidates are still writing.

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
