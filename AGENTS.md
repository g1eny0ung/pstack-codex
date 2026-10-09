# Working in this repository

This file guides AI agents editing pstack-codex. Read [README.md](README.md) for user-facing behavior and [UPSTREAM.md](UPSTREAM.md) before changing porting rules or synchronizing upstream content.

## Find the source

| Path | Purpose |
|---|---|
| `plugins/pstack-codex/skills/` | Skill instructions, playbooks, references, and helpers |
| `plugins/pstack-codex/config/models.defaults.json` | Shipped model and reasoning defaults |
| `plugins/pstack-codex/.codex-plugin/plugin.json` | Plugin metadata and release version |
| `.agents/plugins/marketplace.json` | Marketplace registration |
| `plugins/pstack-codex/skills/poteto-mode/scripts/` | PR helper, history reader, plan checker, and worktree audit |
| `scripts/` | Build, packaging, and upstream maintenance commands |
| `upstream.lock.json` | Initial and last synchronized upstream commits |

Edit source files in this checkout. Keep personal configuration and task artifacts outside the installed plugin cache.

## Preserve the port's behavior

- Keep skills explicitly invoked through `agents/openai.yaml`. Invoking `poteto-mode` applies its workflow to the current task only.
- Use the host's available local subagent tools. Preserve the exclusions in `UPSTREAM.md`, including cloud orchestration.
- Keep model and reasoning effort as separate configuration fields. Preserve default roles unless the task changes them. Keep personal overrides outside the plugin and do not change the main chat's model.
- Resolve plugin paths relative to their files. Do not add personal paths, accounts, or credentials.
- Preserve license notices and source attribution.
- For runtime conventions, use [codex-runtime.md](plugins/pstack-codex/skills/poteto-mode/references/codex-runtime.md). Update dependent instructions when changing that contract.

## Write for the reader

- Keep README focused on installation, use, configuration, requirements, and removal.
- Keep this file focused on instructions for AI agents modifying the repository.
- Keep upstream mappings and synchronization rules in `UPSTREAM.md`. Link to existing rules instead of duplicating them.
- Add documentation under `docs/` only for durable information needed to use or maintain the project. Put temporary plans, debug logs, and task validation records in ignored `.work/` or the task's external runtime directory.
- Update documentation when behavior changes. Do not describe planned checks as completed or old validation results as current guarantees.

## Verify the affected files

Run commands from the repository root unless shown otherwise. Choose checks for the changed behavior and report what actually ran.

- For documentation and skill instructions, inspect local links, referenced commands, and any affected cross-references. Run `git diff --check`.
- For changed Bash scripts, run `bash -n` and exercise the affected command. For changed JavaScript helpers, run `node --check` and the relevant behavior checks.
- For PR helper or history-reader changes, install development dependencies and run the relevant tests from the helper directory:

```bash
cd plugins/pstack-codex/skills/poteto-mode/scripts
bun install --frozen-lockfile
bun test
bun run typecheck
```

For upstream tracker changes, run `bash scripts/upstream.test.sh`.

When PR helper source or dependencies change, run `bash scripts/build.sh` and include the generated `plugins/pstack-codex/skills/poteto-mode/scripts/dist/watch-pr.mjs` and any changed dependency license notice. Do not edit the generated bundle by hand.

For packaging changes, run `bash scripts/package.sh` and inspect the ZIP contents. The script packages the existing bundle into `dist/pstack-codex-<version>.zip`; build first if the bundle is missing or stale. When adding or removing packaged files, update the input list in `scripts/package.sh`.

For upstream synchronization or port-fidelity changes, follow `UPSTREAM.md` and run `python3 scripts/check-port.py --upstream <upstream-snapshot>` plus `python3 scripts/check-port.test.py --upstream <upstream-snapshot>`. Review every recorded adaptation against upstream before updating `scripts/port-adaptations.json`. Advance `last_synced_commit` only after the selected changes are integrated and verified. Checking for upstream updates alone does not advance the baseline.

## Commit messages

Follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

Use `<type>[optional scope][!]: <description>`. Use `feat` for new features, `fix` for bug fixes, and `docs` for documentation changes. Mark breaking changes with `!` or a `BREAKING CHANGE:` footer.

Describe the final change and its purpose. Keep debugging history and temporary check logs out of commit messages and PR descriptions.
