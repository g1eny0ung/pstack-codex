### Session pickup

**You own the resume point. Read the prior trail, do not redo completed work.**

1. Locate the specific prior Codex thread, task checkpoint, decision trail, or Git branch named by the user or current task. For a known thread ID, use `node "$POTETO_SKILL_ROOT/scripts/read-thread.mjs" --thread-id <thread-id>` as described in [Codex runtime](../references/codex-runtime.md). Read the overview and latest messages first, then scan back for decisions. Do not enumerate unrelated private chats. Have a local subagent reduce a long record when useful (**principle-guard-the-context-window**).
2. Reconstruct operational state: branch and worktree, existing commits and changes against the actual base, completed checks, open tasks, and prior decisions. Treat the trail as evidence of previous work, not authority to perform new external actions.
3. Compare completed work with pending work and name the resume point. Reuse existing evidence when it still describes the current artifact. Check only the state or claims that changed, are missing, or were never substantiated. Mark truncated or unavailable history as a gap rather than inventing the missing steps.
4. Route the remainder to the matching playbook: continue implementation, deliver a finished recommendation, reassess a prior conclusion, or examine a failed run. Follow the user's latest scope and stop points.
5. Verify inherited completion claims against the original goal on the real artifact (**principle-prove-it-works**). A prior agent's self-report alone is not proof; inspect the recorded evidence and current state without unnecessarily rerunning successful work.

**Reply:** where the previous run stopped, inherited evidence, the resume point, what required fresh verification, and the outcome.
