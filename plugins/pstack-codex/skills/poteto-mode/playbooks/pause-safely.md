### Pause safely

**You own a clean stop. Leave a checkpoint another run can resume.** Pause only on an explicit request or when the host requires the run to end. Context compaction calls for a checkpoint, not an invented user request to pause. On "keep going", continue within the requested scope.

1. Stop at a safe boundary. Finish the current atomic operation or preserve its partial state. Start nothing new. Interrupt the active local delegates and record any that could not be stopped.
2. Take no new external action merely to pause. Do not create a PR, push, publish, or expand permissions for the checkpoint.
3. Preserve the work on disk. If committing is already authorized, make a clear checkpoint commit containing only the task's edits and state whether it passes checks. Otherwise leave the changes intact and record dirty state; do not discard, stash, reset, or commit unrelated user work.
4. Write a durable resume note in the task runtime directory defined by [Codex runtime](../references/codex-runtime.md), outside the installed plugin. Capture the intent, requested boundaries, progress and evidence, branch/worktree and current state, next steps, relevant files, and active process or delegate IDs. Link an existing **show-me-your-work** trail instead of copying it. Record any explicitly requested Goal or automation and whether it remains active; do not silently leave a requested pause scheduled to restart work.

**Reply:** the resume-note path, current step, preserved changes and commits, stopped or still-active work, and the first action on resume.
