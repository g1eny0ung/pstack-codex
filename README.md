# pstack-codex

Codex port of [Cursor pstack](https://github.com/cursor/plugins/tree/ecc249f1e306fc64ddf83c7bed16cacf7c2239db/pstack), focused on poteto-mode and its local workflows. Includes 42 explicitly invoked skills, 20 playbooks, local subagent collaboration, evidence-based review, and upstream tracking. Cloud agent orchestration is excluded.

## Install

Use a Codex version with plugin and local subagent support:

```bash
codex plugin marketplace add https://github.com/g1eny0ung/pstack-codex.git
codex plugin add pstack-codex@pstack-codex
```

Start a new Codex chat after installation. To install a [release ZIP](https://github.com/g1eny0ung/pstack-codex/releases), extract the entire archive first, then register its root directory:

```bash
codex plugin marketplace add /path/to/extracted/pstack-codex
codex plugin add pstack-codex@pstack-codex
```

The ZIP contains hidden `.agents` and `.codex-plugin` directories. Keep them when copying the plugin. If the same marketplace name is already registered from another source, remove that registration with `codex plugin marketplace remove pstack-codex` before switching sources.

## Use

```text
$poteto-mode Fix the failing feature and verify the user-visible behavior.
$how Explain how this request moves through the codebase.
$interrogate Review this diff; report findings without changing code.
$architect Compare plausible designs for this module.
$unslop Rewrite this paragraph in plain language.
$setup-pstack Show the current role defaults and help customize them.
```

All skills are explicit-only. Invoking poteto-mode activates its workflow for the current task; it can then read related skills as needed. It does not change the main conversation's model or automatically launch every workflow. A request to inspect or plan remains an inspection or planning task.

| Group | Skills |
|---|---|
| Entry and configuration | `poteto-mode`, `setup-pstack` |
| Analysis and collaboration | `how`, `why`, `architect`, `arena`, `swarm`, `interrogate`, `figure-it-out` |
| Records and reflection | `show-me-your-work`, `reflect` |
| Code and verification | `tdd`, `no-comments`, `deslop`, `typescript-best-practices` |
| Writing and interaction | `technical-writing`, `unslop`, `control-cli`, `control-ui` |
| Engineering principles | All 23 pinned upstream `principle-*` skills; see [source mapping](UPSTREAM.md) |

## Models

Spawned roles default to **GPT-6 Astra** (`gpt-6-astra`):

| Role | Reasoning effort |
|---|---|
| Three independent interrogate reviewers | `ultra`, `xhigh`, `high` |
| Writing, rewriting, documentation, PR and commit text | `medium` |
| General judgment, exploration, implementation, verification | `high` |
| Complex synthesis, hardest implementation, independent judges | `xhigh` |
| Arena / architect candidates | Three independent `high` candidates; `xhigh` judge |

Reviewers receive the same evidence and criteria and do not read each other's findings before responding. The lead judges findings using code evidence, not votes or reasoning tiers. Candidate counts and task counts do not override the host's concurrency limit; run work in batches when needed.

Defaults live in `plugins/pstack-codex/config/models.defaults.json`. `$setup-pstack` manages personal overrides in `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json`. Overrides survive plugin updates. Model and reasoning effort are separate fields. Missing models or effort levels are reported; no silent downgrade. These settings do not switch the main chat's model.

## Requirements

| Capability | Requirements |
|---|---|
| Skill loading and local agents | Codex plugin and subagent support; access to configured models |
| Helper scripts | Node.js 22+ |
| Git / worktree / upstream scripts | Bash, Git, standard system utilities |
| GitHub PR operations | Authenticated GitHub CLI (`gh`) |
| UI or interactive CLI checks | Suitable host tools or the project's existing verification tools |
| Optional external research | Relevant connectors, only when the task needs them |

Bun is needed only to maintain, build, or run development tests. The release bundles the PR helper and its runtime dependency; installation does not run `bun install`. Python is used only by Codex's development validators, not by the plugin or upstream tracker.

Target platforms: macOS, Linux, Windows through WSL. Native Windows is not a claimed target. See [validation](docs/validation.md) for what was actually checked; targeting a platform does not mean it has been tested there.

Session history uses the experimental local App Server `thread/turns/list` API with full items. A compatible Codex CLI must be on PATH. Missing history or API support is reported explicitly and affects history-dependent workflows only. Reading a thread never starts or resumes it. Managed Codex worktrees use host tools when available; the Bash audit helper is read-only.

## Update, rollback, uninstall

For a Git-installed marketplace:

```bash
codex plugin marketplace upgrade pstack-codex
codex plugin add pstack-codex@pstack-codex
```

Start a new chat afterward. To roll back, download the desired release ZIP, remove the existing marketplace registration, register the extracted historical release, and reinstall. Personal model overrides stay outside the plugin cache.

```bash
codex plugin remove pstack-codex@pstack-codex
codex plugin marketplace remove pstack-codex
```

These commands do not intentionally remove the separate personal model configuration.

## Maintain

```bash
bash scripts/build.sh
bash scripts/package.sh
bash scripts/upstream.sh check
bash scripts/upstream.sh prepare --commit <full-upstream-SHA>
```

The build creates the committed Node runtime bundle. Packaging produces `dist/pstack-codex-0.1.0.zip`. The upstream tracker is Bash, uses Git and standard text tools, and never applies changes or advances the recorded baseline automatically. See [UPSTREAM.md](UPSTREAM.md) for the pinned commit, mappings, and synchronization process.

Development tests are retained for maintainers. They are not an installation step:

```bash
(
  cd plugins/pstack-codex/skills/poteto-mode/scripts
  bun test
  bun run typecheck
)
bash scripts/upstream.test.sh
```

The current release's requested acceptance scope is installation and basic invocation, not a full workflow test campaign.

## License

MIT. Original pstack is copyright Lauren Tan; the three reused cursor-team-kit skills are copyright Cursor. Their notices are preserved in [plugin licenses](plugins/pstack-codex/licenses/), together with the bundled commander's MIT license. This is an independent Codex port.
