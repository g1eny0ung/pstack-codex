### Autonomous run

**You own the exit condition. Define done, then drive to it within the user's scope.**

1. State the exit condition as a checkable predicate before the first iteration, such as tests green, the repro fixed, or the requested PRs ready. Use the user's condition and authority; a skill cannot authorize merging or unrelated work.
2. Pick the execution mechanism from [Codex runtime](../references/codex-runtime.md). Continue ordinary work in the current task. An event to watch can use a local watcher process or subagent and the host's waits. Create a Goal only for an explicit persistent-goal request, and a heartbeat or schedule only for an explicit request to monitor or continue later. If the host lacks that capability, state the limit and preserve a resume checkpoint; do not build a background scheduler.
3. Each iteration makes the smallest change the evidence justifies and verifies it against the predicate. Commit a verified unit when commits are in scope. Revert only the task's unsuccessful changes, preserving unrelated work. Sequence work via **principle-sequence-verifiable-units**, verifying each unit before the next.
4. Address blockers and related defects only within the authorized task. Report unrelated discoveries for a separate decision. Repair a broken skill only when its source edit is requested; keep the installed plugin read-only. Surface a product decision reserved for the user, missing external-action authorization, or a genuine dead end while continuing independent useful work.
5. Checkpoint each meaningful iteration via **show-me-your-work**, recording what changed, its evidence, and whether the predicate moved. Keep logs in the task runtime directory.
6. Stop when the predicate is met, the user stops the run, or a host limit or concrete blocker prevents progress. A plateau calls for a revised hypothesis, not a fabricated success. Never relax the predicate to declare victory. Report an unfinished state and the next actionable step.

**Reply:** the exit condition, iterations run, what changed, what was discarded, final predicate state, and any remaining blocker.
