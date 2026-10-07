# Word the prompt

A prompt states the intent and the check for done. The playbook supplies the steps, so a few plain sentences are enough.

## Put in

- The goal. Say what is wrong or what you want.
- The done check. It can pass or fail. "Make it better" and a duration are not checks.
- The proof to show. Ask for the actual command output, a recording of the flow, the stored value, or a before and after measurement.
- What you already know. A symptom, a reproduction step, a log, or a link saves the agent a search.
- The real constraints. "Reproduce first", "don't change any code yet", "zero behavior change", and "let me review before proceeding" each change what the agent does.

## Leave out

- A prescribed implementation when you want the agent to explore alternatives.
- A list of skills or steps that duplicates the playbook. Name a skill when you want to override a workflow choice.
- An unlabelled theory of the cause. Mark a guess as a guess so it does not replace the observed symptom.

## Load the context first

- For a noisy report, ask the agent to restate the issue in plain words before it starts. This exposes a misunderstanding before code exists.
- In a fresh chat, provide the relevant branch, decision log, or specific chat reference. Use Session pickup to continue that work. Do not scan unrelated conversations.
- Before a change to unfamiliar code, ask `$how` for the mechanics and `$why` for the reasons.
- Ask the agent to explain why its proposed change fixes the cause and what evidence supports that claim.

## Design before the plan

- For an unsettled design, ask for prototypes of a few options. Use screenshots or recordings for UI when the host can capture them.
- Let prototypes answer observable questions before reviewing an abstract plan.
- For a shared package or API, ask for usage documentation first, then work back to the code. The documentation becomes a target to verify.
- Ask for the implementation plan after the design is settled. Each step ends in a check.

## Follow up short

- "Do it", "continue", and "keep going until done" are complete prompts once the chat holds the task and its scope.
- Start with "new task" when the subject changes. Otherwise the agent treats the message as the next step.

## Before stepping away

- Say that you are stepping away and name the decisions the agent may make.
- Define done with checks the agent can run. A request to continue in the current turn does not create a schedule. Ask for monitoring or later wakeups explicitly when needed.
- Ask for a fresh worktree off a named base when isolation matters.
- State delivery permissions, such as whether to commit, push, or open a PR.
- Ask for a decision log to review later.
- Give a stop condition for an unresolved blocker and ask for the evidence gathered so far.

## Steer in one line

- Restate the goal. "I asked you to reproduce it, not to fix it yet."
- Name the principle. "Apply Prove It Works. Show me the actual output."
- A cited principle must be one the agent read. Its reply names the decision that the principle changed.
