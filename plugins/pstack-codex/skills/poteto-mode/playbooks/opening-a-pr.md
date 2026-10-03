### Opening a PR

Use after implementation to prepare the requested delivery. Create or update a PR, push a branch, or post a comment only when the current user request authorizes it. Otherwise return the verified local diff and any proposed PR text. This playbook never grants merge authority.

**Worktree.** Inspect the current checkout, changes, and requested base before choosing a worktree. Discover the repository's default branch rather than assuming `main`. Reuse a suitable free worktree; when isolation is necessary, use the host's managed-worktree tool if available, otherwise ordinary Git worktrees. Give concurrent writers disjoint files or separate checkouts and explicit paths. Preserve unrelated user changes; do not reset or clean a checkout to simplify this workflow.

**Commits.** When commits are part of the authorized delivery, make small verified units. Reorder or amend only task-owned history where rewriting is authorized; preserve shared history. Each commit is a future PR: landable, ordered to tell the story. Amend when the fix belongs in a just-made commit. New commit when separable.

**PRs.** Run `$deslop` over the diff before commit. Run `$no-comments` before review. Write every PR title, PR description, and commit body with `$technical-writing`, then apply `$unslop`. Apply every technical-writing layer except Diátaxis. Use one word for each action, keep articles, and avoid `-ing` when a plain verb works.

**Titles.** Use Conventional Commits in the form `type(scope): subject`. Use `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, or `perf` as the type. Use the changed area, such as `pstack` or `poteto-mode`, as the scope. Keep the subject short and imperative. Name a real symbol when one carries the change. For example, `fix(pstack): retarget opening-a-pr babysit trigger`. Do not add a trailing period.

**Descriptions.** The PR body is a briefing, not the lab notebook. A reviewer who has the diff should learn why the change exists, what it leaves out, what it could break, and how you proved it works, in under a minute. Write short, simple sentences with few identifiers. Do not write walls of text. The squash commit body is the PR body. If the body would make the squash commit longer than about 40 lines, cut the body.

Put each section under a `##` heading, not a bold lead-in, so the sections stand apart. Use these sections in order. Drop a section when it has nothing to say.

- `## Why` gives the problem and the approach in one to three short sentences. Do not list SHAs or rebase genealogy. Do not add a "based on main" preamble.
- `## What changed` has one to three short bullets. Name a real symbol or path only when it carries the change. Name both sides of a rename or retarget.
- `## Scope` names what the PR covers and leaves out when that boundary matters, for example a related follow-up or a known gap. Use one to three short items. Do not list symbols or paths, and do not write a file-by-file essay.
- `## Tradeoffs` names only rejected alternatives that a reviewer would otherwise ask about. Skip this section when there was no real choice.
- `## Blast Radius` gives one or two sentences on who or what the change touches and why that is safe or risky. If main is red, state the cost of leaving it red.
- `## Verification` has one to three bullets. Each bullet names a real run path and its outcome. For a performance change, report one primary number with its unit in `before → after` form. Link the arena or swarm directory for the remaining evidence. Do not include sample-size methodology, swarm recitals, or metric tables.

After these sections, attach videos or screenshots when they prove a claim. Do not paste full SHAs, swarm or arena lane recitals, lever-correction essays, file-by-file checklists, or "CLEAN" verdicts. Put these details in a linked artifact. A commit body does not restate its subject.

**Forge.** Resolve the forge before the first PR operation and keep that choice for create, edit, view, watch, and merge. GitHub CLI (`gh`) is the default. If `command -v origin` succeeds and Origin can resolve the repository, prefer `origin pr ...`. If Origin is absent or cannot resolve the repository, stay on `gh` and record the fallback. Do not require Graphite (`gt`).

**Built-in PR tool.** When the host provides a tool for creating or editing PRs, use it for the operations it supports and follow its instructions. An attachment-only tool does not create or edit a PR. Use the resolved forge for unsupported operations or when no PR tool is available.

**Size and stacks.** Choose independently reviewable units within the requested scope; do not multiply PRs for a fixed count. A stack is a base-branch chain. The root PR targets trunk. Each child branch rebases onto its parent's exact tip and its PR targets the parent branch. When no built-in PR tool supports creation, create a child with `origin pr create --status open --base <parent-branch>` or `gh pr create --base <parent-branch>` according to the resolved forge. When no built-in PR tool supports retargeting, retarget an existing child with `origin pr edit <pr> --base <parent-branch>` or `gh pr edit <pr> --base <parent-branch>`. Branch from trunk only for independent work. Rebase on trunk before substantial stack work.

**Readiness.** Follow the user's requested draft or ready state. Set the requested state explicitly through the built-in PR tool when it supports that operation. Otherwise, for a ready PR, use `origin pr create --status open` or omit `--draft` with `gh`; use the forge's draft option when requested or when checks remain incomplete. Verify the actual PR state before reporting it. After creating a PR, attach its URL through the host's artifact tool when that tool is available.

**Babysit.** Opening a PR does not start a babysit. Post the URL and keep building. Finish the phase or stack first. Run a separate babysit pass only when the user asks for one after the whole stack exists. A babysit for each new PR stalls the build and spends checks on commits that later waves restart. Push back when feedback drifts from intent.

A delegate returns its verified changes, evidence, and proposed delivery to the parent. If its brief explicitly authorizes opening a PR, it applies **deslop** and **no-comments**, runs **interrogate** only when the design is contested or review was requested, and returns the URL. It does not start a babysit or merge unless that work was separately authorized.
