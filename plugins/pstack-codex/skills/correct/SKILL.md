---
name: correct
description: "Find repeated agent mistakes in this repo and prevent them through architecture, types, checks, or tests. Prove each new check catches a real past mistake. Use for $correct."
---

# Correct

The user keeps correcting agents in this repo for the same mistakes. Change the repo so the next agent can't make them.

Apply this workflow to the requested task only. Preserve the user's scope and authorization boundaries in [Codex runtime](../poteto-mode/references/codex-runtime.md). If the user asks only for an audit, report the classes and proposed checks without editing.

Assume every contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that compiles. Design the repo so a change that looks right from one file is right for the whole repo.

## Find the mistake classes

Read recent commits, reverts, available review comments, agent instruction files, and comments that explain workarounds. Group the mistakes into classes. A class counts once it has happened twice. Cite both occurrences. Missing review access is an evidence gap, not permission to invent a repeat or scan unrelated chats.

## Fix each class at the highest level that works

1. **Eliminate it with architecture.** Give each piece of state one owner and each task one supported way. Hide internals so the wrong import fails. Replace hand-synced lists with one source of truth. Delete old ways and dead code an agent would copy.
2. **Enforce it with types so the bad state can't be written.** If bad code still compiles, add a lint or CI check whose error names the file, type, or function to use instead. If the pattern is already common, fail only when a change adds more.
3. **Test the behavior.** Fix or delete any test that would still pass if every function it calls returned nothing.
4. **Write docs or agent rules last, only for judgment calls.** Nothing fails when an agent skips them.

## Fix and prove

Fix the most frequent classes within the requested scope. Keep each class as a separate verified change, and use one commit per class when commits are part of the requested delivery. Prove each new check fails on a real past mistake and passes on the corrected case. Run the same command locally and in CI when CI execution is available and authorized. Otherwise report that CI execution remains unverified. Exceptions go on the offending line with a reason, an expiry date, and the user's approval.

## Keep the rule table

Keep a table in the repository's agent instruction file that pairs each remaining rule with what enforces it. During this task, when the user corrects you, fix the mistake and add the rule. If the rule was already there and nothing enforces it, that's a repeat. Fix it at the highest level within scope. Drop a rule once its mistake can't happen.

**Reply:** each class with its evidence, the level you picked, why a higher level didn't work, and the verification result. If no class has two supported occurrences, say so instead of changing the repo.
