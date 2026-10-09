# pstack-codex

Bring [Cursor pstack](https://github.com/cursor/plugins/tree/d0ef80d86795816da932a153458c5dbe192d294e/pstack)'s engineering workflows to Codex. Use `poteto-mode` to investigate, implement, and verify a task, or invoke individual skills for code explanations, design comparisons, reviews, and writing. Workflows run locally and can use Codex subagents.

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
| Find the right workflow | `$poteto-help Which skill should I use for this task?` |
| Understand code | `$how Explain how this request moves through the codebase.` |
| Understand a design decision | `$why Explain why this module uses a queue.` |
| Check impact beyond a diff | `$blast-radius What could this change break elsewhere?` |
| Simplify the last answer | `$bro` |
| Understand how and why together | `$teach Explain this subsystem plainly.` |
| Compare designs | `$architect Compare plausible designs for this module.` |
| Review a change | `$interrogate Review this diff; report findings without changing code.` |
| Check a performance result | `$benchmark-checklist Check whether this benchmark supports the claimed speedup.` |
| Improve writing | `$unslop Rewrite this paragraph in plain language.` |
| Configure models | `$setup-pstack Show the current role defaults.` |
| Prevent repeated mistakes | `$correct Find repeated agent mistakes in this repo and prevent them with verified changes.` |

Skills activate only when explicitly invoked. An invoked workflow can read related skills and delegate work when its instructions call for it. See the [skill directory](plugins/pstack-codex/skills/) for all available skills.

## Configure models

Subagents use GPT-6.1 Sol or GPT-6 Astra according to their role. The main chat keeps its own model settings.

| Task | Default model | Reasoning effort |
|---|---|---|
| Source exploration and tooling reflection | `gpt-6.1-sol` | `high` |
| Judgment, prose, code explanations, and cause investigation | `gpt-6.1-sol` | `xhigh` |
| Implementation, refactoring, bug fixes, performance work, and swarm workers | `gpt-6-astra` | `high` |
| Hardest tasks and complex synthesis | `gpt-6-astra` | `xhigh` |
| Arena cross-judge pool, select one | `gpt-6-astra` | `xhigh`, `high` |
| Two default `arena` or `architect` candidates | `gpt-6-astra` | `xhigh`, `high` |
| Two default `interrogate` reviewers | `gpt-6-astra` | `xhigh`, `high` |

Use `$setup-pstack` to inspect or change these settings. For example:

```text
$setup-pstack Set the reasoning budget to medium.
$setup-pstack Set judgment_and_prose to inherit-parent.
```

Budget choices are `unlimited` (`max`), `large` (`xhigh`), `medium` (`high`), and `small` (`medium`). A budget updates explicit configurations across roles and lists, using the highest supported effort at or below the target. Both `auto` and `inherit-parent` preserve the parent model and effort. They work as scalar role values and list entries.

Personal overrides live in `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json` and survive plugin updates. To restore a role's default, ask `$setup-pstack` to reset that role. Changes apply to subsequent subagent launches. The main chat's configuration remains unchanged.

Each entry in `arena_runners`, `architect_runners`, or `interrogate_reviewers` launches one agent. Change a list to change its count. Arena selects one judge from `arena_cross_judge_pool`, preferring an effort different from the main chat's. Pool size does not change the number of judges.

Role boundaries match upstream. Judgment and prose share `judgment_and_prose`. Reflect's judgment, divergent, and synthesis agents share `reflect_judgment_divergent_synthesizer`. See the [default role configuration](plugins/pstack-codex/config/models.defaults.json) for all 17 roles.

For older personal overrides, run `$setup-pstack` to review the migration. Replace separate `judgment` and `writing` entries with `judgment_and_prose`, and the three separate Reflect entries with their shared role. Conflicting values need one chosen shared setting. Move the former `arena_judge` object into a one-entry `arena_cross_judge_pool` array. Remove `comment_review` and `audit_reviewer`; those roles do not exist upstream. Comment Sicko inherits its parent's configuration. Upstream's `show-me-your-work` review step has no dedicated role or fixed effort.

You need access to the configured GPT models and reasoning levels. Setup validates settings before saving. A workflow that specifies a launch fallback reports the configuration it actually used.

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

This port maps the cross-model reviews in Arena and `show-me-your-work` to GPT-6 Astra at different reasoning efforts. Arena prefers a different effort for its judge. `show-me-your-work` selects a different supported effort from the agent that did the work, without a dedicated reviewer role or fixed effort.

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
