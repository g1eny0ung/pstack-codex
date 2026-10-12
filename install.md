# Install pstack-codex for a user

Use this guide when a user asks you to install pstack-codex into Codex. Run the commands on the user's machine. Use the same account and Codex home as their Codex session. Complete the installation when authorized by the request.

Install through Codex's plugin marketplace commands. Do not copy individual skills into a personal skills directory or edit the installed plugin cache. Preserve the user's main chat model and personal model overrides.

## Check the environment

Run these commands before changing the installation:

```bash
codex --version
codex plugin --help
codex plugin marketplace --help
```

If `codex` is missing or lacks the plugin commands, report the blocker. Direct the user to the [Codex CLI installation instructions](https://developers.openai.com/codex/cli). Resume once a compatible CLI is available.

Use macOS, Linux, or Windows through WSL. Native Windows is outside this project's target. Confirm that the Codex host provides local subagents before promising delegated workflows.

Check the current registration and installation:

```bash
codex plugin marketplace list --json
codex plugin list --marketplace pstack-codex --json
```

Inspect the `pstack-codex` marketplace source and the `pstack-codex@pstack-codex` plugin entry. If the plugin is already installed and enabled from the requested source, report its version. Skip reinstallation unless the user requests an update or a different version.

If the marketplace is absent, register it in the next step. If the list command fails, resolve the reported error before treating the plugin as absent.

## Install from GitHub

Use GitHub unless the user requests a release ZIP, a specific release, or a local checkout. Ensure that Git and access to the repository are available.

If `pstack-codex` is not registered, run:

```bash
codex plugin marketplace add https://github.com/g1eny0ung/pstack-codex.git
```

If the same Git source is already registered, reuse it. To update that source when the user requests an update, run:

```bash
codex plugin marketplace upgrade pstack-codex
```

If the existing registration uses another source, preserve it unless switching sources is part of the request. To switch, remove that registration, then run the GitHub registration command above:

```bash
codex plugin marketplace remove pstack-codex
```

Install the plugin after the registration command succeeds:

```bash
codex plugin add pstack-codex@pstack-codex
```

## Install from a release ZIP or local checkout

For a ZIP installation, download the requested asset from [GitHub Releases](https://github.com/g1eny0ung/pstack-codex/releases). Extract the entire archive into a persistent directory. Preserve hidden directories, including `.agents` and `.codex-plugin`.

For either source, locate the root containing `.agents/plugins/marketplace.json` and `plugins/pstack-codex/.codex-plugin/plugin.json`. Register that root, not the nested plugin directory. Replace the example path with its absolute path on the user's machine:

```bash
codex plugin marketplace add "/path/to/pstack-codex"
codex plugin add pstack-codex@pstack-codex
```

If `pstack-codex` already uses another source, apply the source-switch procedure above before adding the local root. Reuse an existing registration for the same root.

A release ZIP includes the built runtime helpers. Do not install Bun or development dependencies for a release installation. For a source checkout, confirm that `plugins/pstack-codex/skills/poteto-mode/scripts/dist/watch-pr.mjs` exists. If it is missing, use a release ZIP or follow the repository's [build instructions](AGENTS.md#verify-the-affected-files).

## Verify the installation

Run both checks after installation:

```bash
codex plugin marketplace list --json
codex plugin list --marketplace pstack-codex --json
```

Confirm that the marketplace points to the selected source. In the plugin list, find `pstack-codex@pstack-codex` under `installed`. Confirm that `installed` and `enabled` are both `true`. Record the reported version. An entry under `available` alone does not prove installation.

Tell the user to start a new Codex chat. In that chat, check that `poteto-mode` and `poteto-help` are available. Use this read-only prompt to check skill invocation:

```text
$poteto-help Which skill should I use to explain code?
```

Report CLI installation and skill invocation separately. If you cannot check a new chat, state that skill loading still needs that check. Do not claim that all workflows are verified by installation alone.

## Report the result

Tell the user which source and version you installed. State which checks passed and any remaining blocker. Include the new-chat step and an example invocation:

```text
$poteto-mode Explain how this project works.
```

Keep model setup separate from installation. If the user wants to inspect or change subagent settings, use `$setup-pstack` in the new chat. Preserve overrides in `${CODEX_HOME:-$HOME/.codex}/pstack-codex/models.json`. See [README configuration and requirements](README.md#configure-models) for model settings and workflow dependencies.
