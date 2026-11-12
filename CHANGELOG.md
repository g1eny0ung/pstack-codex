# Changelog

Notable changes to pstack-codex are recorded here. The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.6.1] - 2026-11-12

### Changed

- Consolidated runtime and model setup instructions.

### Fixed

- Let Codex resolve subagent model and reasoning settings when the workflow omits them.
- Keep monitoring of a specific run in the active task and accept the updated multi-phase plan template.
- Reuse suitable worktrees, preserve local changes, and archive Codex-managed worktrees from the owning chat.
- Check the merged PR head before recommending worktree cleanup.
- Detect truncated Codex history exports and explain SQLite state access errors.

## [0.6.0] - 2026-10-28

### Changed

- Synced selected workflows through Cursor pstack 0.15.36.
- **Breaking:** `interrogate` reports only findings demonstrated by a run and confirmed by a coordinator rerun. Reviewers reproduce findings in isolated worktrees with the changes under review.
- **Breaking:** When the parent chat's reasoning effort is known, `arena` requires a different effort for its final judge. It skips judging if no eligible configuration can run.
- Track rejected subagent model configurations across fallbacks so they are tried only once.

## [0.5.3] - 2026-10-26

### Added

- `maintain-formal-verification-skill` keeps project verification instructions aligned with code changes.

### Changed

- Synced selected workflows through Cursor pstack 0.15.32. `sharpen` now analyzes and rewrites prompts without executing the underlying task.

### Fixed

- Distinguish fork heads when discovering connected PR stacks and cap polling and retry sleeps at the configured deadline.
- Recognize multi-backtick inline code spans in plan checks.
- Keep `reflect` edits outside the installed plugin cache and correct `swarm` phase references.

## [0.5.2] - 2026-10-19

### Added

- `create-formal-verification-skill` helps set up project verification and is discoverable through `poteto-help`.

### Changed

- Synced selected workflows through Cursor pstack 0.15.27, including updates to `sharpen` and TypeScript type guard examples.
- `ketchup` lists every pending decision with the context needed to act.

## [0.5.1] - 2026-10-14

### Removed

- Origin CLI integration. PR workflows and worktree PR audits use GitHub CLI (`gh`). If GitHub PR status is unavailable, the audit reports it as unknown. Git remotes named `origin` remain supported.

## [0.5.0] - 2026-10-14

### Added

- `in-your-own-words` restates the user's goal and problem before work starts.
- `sharpen` applies expert methods to a task and calls for an independent check of the outcome.

### Changed

- Synced selected workflows through Cursor pstack 0.15.24.
- Adjust subagent reasoning effort per task within the configured role model.
- Shortened `ketchup` summaries and added visuals for progress and pending decisions.
- Shipping confirms each merge. Multi-phase verification retains independent PR verdicts and uses one verifier for minor follow-up changes.
- Worktree audits prefer the Origin CLI for PR status and fall back to GitHub CLI.

### Fixed

- Recognize a Code Review Gate waiting for owner approval as pending.
- Resolve delegate skills and playbook references relative to the loaded Codex plugin.

## [0.4.0] - 2026-10-12

### Added

- `ketchup` summarizes progress, work status, and pending decisions using the current chat's history.
- Worktree audits accept `-b` or `--base` to select an existing local ref.

### Changed

- Synced selected workflows through Cursor pstack 0.15.19.

### Fixed

- Read every GitHub review-thread page when checking PR readiness and counting Bugbot passes.
- Recognize tilde fences, nested backticks, indentation, and longer closing fences in plan checks.

## [0.3.0] - 2026-10-09

### Added

- `blast-radius` checks effects beyond the diff, `bro` simplifies the last answer, and `teach` explains code behavior and design.

### Changed

- Restored upstream workflow steps, reviewer responsibilities, and verification gates with Codex-specific adaptations.
- **Breaking:** Aligned personal model overrides with the 17 upstream roles. Merge `judgment` and `writing` into `judgment_and_prose` and the three Reflect judgment roles into `reflect_judgment_divergent_synthesizer`. Replace `arena_judge` with the `arena_cross_judge_pool` array and remove `comment_review` and `audit_reviewer`. Run `setup-pstack` to review your overrides.
- Use GPT-6.1 Sol for exploration, explanations, investigation, judgment, prose, and tooling reflection. Use GPT-6 Astra for implementation, complex synthesis, and review.
- Use Codex Goals for explicitly requested persistent objectives.
- Limited release ZIPs to installation and runtime files, including the built helpers and licenses.

### Fixed

- Use the remote default branch to check whether worktree changes have merged and handle paths containing tabs or newlines.

## [0.2.0] - 2026-10-07

### Added

- `poteto-help` explains setup and helps choose a workflow.
- `correct` identifies repeated agent mistakes and suggests ways to prevent them through architecture, types, checks, or tests.
- `benchmark-checklist` and `principle-explain-the-number` guide performance measurement and interpretation.

### Changed

- Synced selected workflows through Cursor pstack 0.15.15, including fresh-subagent guidance and updates to performance, PR, and writing workflows.

## [0.1.0] - 2026-09-26

### Added

- Initial Codex port with 42 explicitly invoked skills, 20 local playbooks, and GPT-6 Astra model defaults.
- GitHub marketplace and local ZIP installation, with a bundled PR helper and a read-only worktree audit.

[Unreleased]: https://github.com/g1eny0ung/pstack-codex/compare/v0.6.1...HEAD
[0.6.1]: https://github.com/g1eny0ung/pstack-codex/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/g1eny0ung/pstack-codex/compare/v0.5.3...v0.6.0
[0.5.3]: https://github.com/g1eny0ung/pstack-codex/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/g1eny0ung/pstack-codex/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/g1eny0ung/pstack-codex/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/g1eny0ung/pstack-codex/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/g1eny0ung/pstack-codex/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/g1eny0ung/pstack-codex/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/g1eny0ung/pstack-codex/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/g1eny0ung/pstack-codex/releases/tag/v0.1.0
