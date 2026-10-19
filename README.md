# pstack-codex

Bring [Cursor pstack](https://github.com/cursor/plugins/tree/8838150c6b4829ea3c01782631213776d86df14a/pstack)'s engineering workflows to Codex. Use `poteto-mode` to investigate, implement, and verify a task, or invoke individual skills for code explanations, design comparisons, reviews, and writing. Workflows run locally and can use Codex subagents.

## Install

For installation by an AI agent, give the agent [install.md](install.md) and ask it to follow the guide.

Use a Codex version with plugin and local subagent support. Install from GitHub:

```bash
codex plugin marketplace add https://github.com/g1eny0ung/pstack-codex.git
codex plugin add pstack-codex@pstack-codex
```

Start a new Codex chat after installation.

For a release ZIP, local checkout, or source switch, follow [install.md](install.md).

## Use

In a Codex chat, invoke a skill and describe the task:

```text
$poteto-mode Fix the failing feature and verify the user-visible behavior.
```

`poteto-mode` applies to the current task and selects related workflows as needed. It does not enable a persistent mode or change your main chat's model. Asking it to inspect or plan keeps the task within that scope.

To continue work across turns, explicitly request a Codex Goal on a host that supports Goals. See [Goals and timed automation](plugins/pstack-codex/skills/poteto-mode/references/codex-runtime.md#goals-tools-and-authorization) for examples and host requirements.

You can also invoke a focused skill directly:

| Goal | Example prompt |
|---|---|
| Find the right workflow | `$poteto-help Which skill should I use for this task?` |
| Understand code | `$how Explain how this request moves through the codebase.` |
| Compare designs | `$architect Compare plausible designs for this module.` |
| Review a change | `$interrogate Review this diff; report findings without changing code.` |
| Verify a code property | `$create-formal-verification-skill Check a key property and create a project skill to rerun it.` |
| Improve writing | `$unslop Rewrite this paragraph in plain language.` |
| Configure models | `$setup-pstack Show the current role defaults.` |

Skills activate only when explicitly invoked. An invoked workflow can read related skills and delegate work when its instructions call for it. See the [skill directory](plugins/pstack-codex/skills/) for all available skills.

## Differences from upstream

This port includes selected upstream skills and runs workflows locally. PR workflows and worktree PR audits use GitHub CLI (`gh`). Origin CLI integration and cloud orchestration are excluded. See [UPSTREAM.md](UPSTREAM.md#exclusions) for the port scope and exclusions.

## Configure models

Subagent roles start with GPT-6.1 Sol for exploration, explanations, and writing, and GPT-6 Astra for implementation and reviews. Workflows adjust reasoning effort for each task from those starting settings. Your account and Codex environment must support the configured models and reasoning effort levels. These settings apply only to subagents and do not change your main chat's model or reasoning effort settings.

Use `$setup-pstack` to inspect or change these settings. For example:

```text
$setup-pstack Set the reasoning budget to medium.
$setup-pstack Set judgment_and_prose to inherit-parent.
```

Personal overrides live in `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` and survive plugin updates. Changes apply to subsequent subagent launches. Use `$setup-pstack` to reset a role or review older overrides.

See [setup-pstack](plugins/pstack-codex/skills/setup-pstack/SKILL.md) for budget choices, [model role rules](plugins/pstack-codex/skills/poteto-mode/references/codex-runtime.md#resolve-model-roles) for configuration behavior, [task effort rules](plugins/pstack-codex/skills/poteto-mode/references/codex-runtime.md#choose-effort-and-speed-for-the-job) for launch adjustments, and [model defaults](plugins/pstack-codex/config/models.defaults.json) for every role's shipped settings.

## Requirements and compatibility

Additional tools depend on the workflow you use:

| Workflow | Requirements |
|---|---|
| Node helper scripts | Node.js 22+ |
| Git and worktree operations | Bash, Git, `jq` for the worktree audit, and standard system utilities |
| GitHub pull requests | GitHub CLI, `gh`, authenticated with your account |
| Browser or interactive CLI verification | Suitable tools provided by your Codex host or project |
| Spatial explanations in `teach` | A host image-generation tool; unavailable image generation is reported as blocked |
| Session-history workflows | A Codex CLI on `PATH` that supports the experimental App Server `thread/turns/list` API |

The release includes the built PR helper and its runtime dependency. You do not need Bun or an npm dependency installation to use it.

Target platforms are macOS, Linux, and Windows through WSL. Native Windows is outside the current target. Version 0.1.0 was checked for installation and basic skill invocation on macOS. Full workflows and Linux/WSL execution were not verified.

## Update

For a Git-installed marketplace, refresh it and reinstall the plugin:

```bash
codex plugin marketplace upgrade pstack-codex
codex plugin add pstack-codex@pstack-codex
```

Start a new Codex chat afterward. For a ZIP installation, download the desired release and follow [the ZIP installation guide](install.md#install-from-a-release-zip-or-local-checkout). Personal model overrides remain in place.

## Roll back

Download the desired version from [Releases](https://github.com/g1eny0ung/pstack-codex/releases), then follow [the ZIP installation guide](install.md#install-from-a-release-zip-or-local-checkout) to switch sources and reinstall. Start a new Codex chat afterward.

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
