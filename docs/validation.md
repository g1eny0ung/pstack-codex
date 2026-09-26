# Validation

Acceptance scope requested for this release: install the plugin and confirm skill invocation. No full workflow or multi-agent test campaign.

Environment: macOS arm64; Codex CLI `0.158.0-alpha.2.1`; Bun `1.4.2`; Node.js `26.10.0`.

## Completed before upload

- All 42 skills passed Codex's existing frontmatter validator.
- Plugin and marketplace identifiers/structure passed existing validators; all 42 skill metadata files use `allow_implicit_invocation: false`.
- Confirmed 42 skills, 20 playbooks, valid local references, pinned upstream baseline, and removal of Cursor runtime and cloud orchestration paths.
- Bash syntax checks passed for the new maintenance scripts and worktree audit. Node syntax checks passed for changed `.mjs` helpers.
- Bundled the existing PR helper and commander dependency for Node. The generated entry's `--help` completed successfully.
- `worktree-audit.sh` completed one ordinary run in the newly initialized project. With no remote, commits, or linked worktrees yet, it reported unavailable merge/PR metadata. No temporary Git worktree scenarios were created.
- The retained multi-phase plan template passed its structural checker.

## Installation and invocation

Passed on 2026-09-26, after publishing the source to `https://github.com/g1eny0ung/pstack-codex`.

1. `codex plugin marketplace add https://github.com/g1eny0ung/pstack-codex.git` registered the Git marketplace.
2. `codex plugin add pstack-codex@pstack-codex` installed version `0.1.0`.
3. `codex plugin list --marketplace pstack-codex --json` reported `installed: true` and `enabled: true`.
4. A fresh ephemeral `codex exec` call, with an empty working directory and read-only sandbox, invoked `$poteto-mode`. The test agent actually read the installed cache's `skills/poteto-mode/SKILL.md` and `config/models.defaults.json`; both reads exited 0.
5. The agent returned `SKILL_OK`, confirmed current-task scope, all three `gpt-6-astra` reviewer defaults (`ultra`, `xhigh`, `high`), and `writing: medium`. The Codex process exited 0.

The smoke-call model was GPT-6 Astra with ultra reasoning. It did not launch review workers or execute engineering workflows. Thus the test confirms installation, loading, and readable role defaults; it does not claim that each configured role was run. Raw local invocation logs are not included in the public repository.

## Not run

- Existing PR helper test suite and TypeScript checks.
- New history-reader fixture tests and Bash upstream-sync tests.
- Full history-reader integration, PR mutation/merge, multi-agent model launch, candidate comparison, pause/resume, and UI workflows.
- Linux/WSL or native Windows execution; read-only cache and config persistence scenarios.

Test sources remain available for maintainers. These limited checks do not establish full workflow correctness or cross-platform verification.
