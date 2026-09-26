# Validation

Acceptance scope requested for this release: install the plugin and confirm skill invocation. No full workflow or multi-agent test campaign.

Environment: macOS arm64; Codex CLI `0.158.0-alpha.2.1`; Bun `1.4.2`.

## Completed before upload

- All 42 skills passed Codex's existing frontmatter validator.
- Plugin and marketplace identifiers/structure passed existing validators; all 42 skill metadata files use `allow_implicit_invocation: false`.
- Confirmed 42 skills, 20 playbooks, valid local references, pinned upstream baseline, and removal of Cursor runtime and cloud orchestration paths.
- Bash syntax checks passed for the new maintenance scripts and worktree audit. Node syntax checks passed for changed `.mjs` helpers.
- Bundled the existing PR helper and commander dependency for Node. The generated entry's `--help` completed successfully.
- `worktree-audit.sh` completed one ordinary run in the newly initialized project. With no remote, commits, or linked worktrees yet, it reported unavailable merge/PR metadata. No temporary Git worktree scenarios were created.
- The retained multi-phase plan template passed its structural checker.

## Installation and invocation

Pending the post-upload Codex installation check.

## Not run

- Existing PR helper test suite and TypeScript checks.
- New history-reader fixture tests and Bash upstream-sync tests.
- Full history-reader integration, PR mutation/merge, multi-agent model launch, candidate comparison, pause/resume, and UI workflows.
- Linux/WSL or native Windows execution; read-only cache and config persistence scenarios.

Test sources remain available for maintainers. These limited checks do not establish full workflow correctness or cross-platform verification.
