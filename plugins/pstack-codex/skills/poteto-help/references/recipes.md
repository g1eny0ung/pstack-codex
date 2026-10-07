# Prompts worth copying

Replace the placeholders with real paths and done checks. Informal wording works.

## Understand

- `$poteto-mode Read <specific chat reference>. Restate the underlying issue in plain words.`
- `$poteto-mode Investigate why <symptom>. Give me what we know, the evidence, and your hypotheses. Don't change code yet.`
- `Use $how to understand <subsystem>, then $why to find out why it broke recently.`
- `Explain why you implemented this change this way and what you traded off.`
- `$poteto-mode Take over this branch. Read the decision log, find what is done, and continue. Don't redo finished work.`

## Build

- `$poteto-mode <Symptom>. Reproduce it first, then fix and verify.`
- `$poteto-mode Reproduce <bug> using the project's verification tools. If it occurs on main, fix it and show the actual flow as proof.`
- `$poteto-mode Reproduce <bug> first. If there is a cheap test path, use $tdd. Then fix and rerun.`
- `$poteto-mode Add <behavior>. <Current output> stays byte-identical. Verify both.`
- `$poteto-mode Move <code> into one module with zero behavior change. Record the current output first and prove it stays unchanged.`
- `$poteto-mode <Operation> takes <time> on <fixture>. Trace it, fix the measured cause, and show before and after.`

## Design and plan

- `$poteto-mode Prototype a few options for <feature>. Capture screenshots or recordings for comparison.`
- `$poteto-mode We need <feature>. Use $architect with checkpoint. Answer open questions with prototypes and let me review before implementation.`
- `$poteto-mode Write a tutorial for <new package> first. Explain why the proposed interface is better for its callers.`
- `Use $arena to compare alternatives for this approach.`
- `$poteto-mode Turn this design into a plan of small verifiable PRs, each with its own checks. Don't implement yet.`
- `$poteto-mode Plan the migration of <library> to <target>. Use small verifiable steps. Preserve existing behavior exactly, including known bugs.`

## Review and ship

- `$interrogate Review the whole branch skeptically. Don't change anything. Report real bugs or regressions, not style preferences.` Read the dismissals too.
- `$swarm Check every package under <dir> with its check script. One worker per package within available slots. Return one report.`
- `$correct Find repeated agent mistakes in this repo. Prevent the supported classes and prove each check catches a past mistake.`
- `$poteto-mode Open the PR. Use small ordered commits and put verification evidence in the description.`
- `$poteto-mode Babysit this PR. Get it green.` For status only, use `$poteto-mode Check on PR <number>. Anything outstanding?`
- `$poteto-mode Land the stack.`

## Away and back

- `$poteto-mode I'm stepping away. Complete <goal> in a fresh worktree off <base>. Done means <checks>. Keep a decision log. You may commit locally. If blocked, stop and report the evidence and what is needed.`
- `$show-me-your-work Catch me up on the decision log from the last run.` Read its attention notes first.
- `$poteto-mode Plan these changes as a stack of PRs. Don't implement or merge yet.`
- `$reflect Capture what we learned so the next run avoids the same mistakes.` Approve edits that change a future decision.
- `Restate the last reply in plain words.`
