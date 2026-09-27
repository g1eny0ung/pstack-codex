# pstack-codex

Bring [Cursor pstack](https://github.com/cursor/plugins/tree/ecc249f1e306fc64ddf83c7bed16cacf7c2239db/pstack)'s engineering workflows to Codex. Use `poteto-mode` to investigate, implement, and verify a task, or invoke individual skills for code explanations, design comparisons, reviews, and writing. Workflows run locally and can use Codex subagents.

## Install

Use a Codex version with plugin and local subagent support. Install from GitHub:

```bash
codex plugin marketplace add https://github.com/g1eny0ung/pstack-codex.git
codex plugin add pstack-codex@pstack-codex
```

Start a new Codex chat after installation.

To install from a [release ZIP](https://github.com/g1eny0ung/pstack-codex/releases), extract the entire archive and register the extracted repository directory:

```bash
codex plugin marketplace add /path/to/extracted/pstack-codex
codex plugin add pstack-codex@pstack-codex
```

Keep the hidden `.agents` and `.codex-plugin` directories when extracting or copying files. If `pstack-codex` is already registered from another source, remove that registration before switching:

```bash
codex plugin marketplace remove pstack-codex
```

## Use

In a Codex chat, invoke a skill and describe the task:

```text
$poteto-mode Fix the failing feature and verify the user-visible behavior.
```

`poteto-mode` applies to the current task and selects related workflows as needed. It does not enable a persistent mode or change your main chat's model. Asking it to inspect or plan keeps the task within that scope.

You can also invoke a focused skill directly:

| Goal | Example prompt |
|---|---|
| Understand code | `$how Explain how this request moves through the codebase.` |
| Understand a design decision | `$why Explain why this module uses a queue.` |
| Compare designs | `$architect Compare plausible designs for this module.` |
| Review a change | `$interrogate Review this diff; report findings without changing code.` |
| Improve writing | `$unslop Rewrite this paragraph in plain language.` |
| Configure models | `$setup-pstack Show the current role defaults.` |

Skills activate only when explicitly invoked. An invoked workflow can read related skills and delegate work when its instructions call for it. See the [skill directory](plugins/pstack-codex/skills/) for all available skills.

## Configure models

Subagents default to GPT-6 Astra, `gpt-6-astra`. The main chat keeps its own model settings.

| Task | Default reasoning effort |
|---|---|
| Delegated writing | `medium` |
| Ordinary implementation, exploration, and judgment | `high` |
| Complex synthesis and judging | `xhigh` |
| Three independent `interrogate` reviewers | `ultra`, `xhigh`, `high` |

Use `$setup-pstack` to inspect or change these settings. For example:

```text
$setup-pstack Set the writing role's reasoning effort to high.
```

Personal overrides live in `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` and survive plugin updates. To restore a role's default, ask `$setup-pstack` to reset that role. Changes apply to subsequent subagent launches.

You need access to the configured GPT models and reasoning levels. The plugin reports unavailable settings and asks you to choose a replacement. See the [default role configuration](plugins/pstack-codex/config/models.defaults.json) for every role.

## Requirements and compatibility

Additional tools depend on the workflow you use:

| Workflow | Requirements |
|---|---|
| Node helper scripts | Node.js 22+ |
| Git and worktree operations | Bash, Git, and standard system utilities |
| GitHub pull requests | GitHub CLI, `gh`, authenticated with your account |
| Browser or interactive CLI verification | Suitable tools provided by your Codex host or project |
| Session-history workflows | A Codex CLI on `PATH` that supports the experimental App Server `thread/turns/list` API |

The release includes the built PR helper and its runtime dependency. You do not need Bun or an npm dependency installation to use it.

Target platforms are macOS, Linux, and Windows through WSL. Native Windows is outside the current target. Version 0.1.0 was checked for installation and basic skill invocation on macOS. Full workflows and Linux/WSL execution were not verified.

## Update

For a Git-installed marketplace, refresh it and reinstall the plugin:

```bash
codex plugin marketplace upgrade pstack-codex
codex plugin add pstack-codex@pstack-codex
```

Start a new Codex chat afterward. For a ZIP installation, download the desired release and follow the ZIP installation steps above. Personal model overrides remain in place.

## Roll back

Download the desired version from [Releases](https://github.com/g1eny0ung/pstack-codex/releases). Remove the current marketplace registration, then follow the ZIP installation steps with that version. Start a new Codex chat after reinstalling.

## Uninstall

```bash
codex plugin remove pstack-codex@pstack-codex
codex plugin marketplace remove pstack-codex
```

Your personal model overrides remain in `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json`. Delete that file separately if you no longer need it.

## Repository maintenance

See [AGENTS.md](AGENTS.md) for repository editing rules and development checks. [UPSTREAM.md](UPSTREAM.md) records source mappings, porting constraints, and the upstream synchronization process.

## License

MIT. Original pstack is copyright Lauren Tan. The three reused cursor-team-kit skills are copyright Cursor. Their notices and the bundled commander's MIT license are preserved in [plugin licenses](plugins/pstack-codex/licenses/). This is an independent Codex port.
