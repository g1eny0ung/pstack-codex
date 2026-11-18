### Opening a PR

Invoked at the end of every other playbook when PR delivery is authorized.

Reuse the current checkout or an attached worktree when it suits the PR. When isolation is needed, create a worktree off trunk, and keep unrelated work out of it. Rebase into small, landable commits. Run the bundled **deslop** skill over the diff before commit.

Title: `type(scope): subject`, naming a real symbol when one carries the change. Body: a one-minute briefing under 40 lines with these `##` headings in order, dropping empty ones: `## Why`, `## What changed`, `## Scope`, `## Tradeoffs` (only rejected alternatives a reviewer would otherwise ask about), `## Blast Radius`, `## Verification`.

Stack follow-ups by base branch. Open PRs ready using the [Codex PR creation workflow](../references/codex-runtime.md#github-pull-requests). Opening a PR does not start a babysit.
