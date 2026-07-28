# dotfyles

Personal machine configuration for macOS, with Linux as a secondary target. The repository is the config directory itself: clone it directly to `~/.config`, then run one bootstrap command to install the declared software, configure Fish, restore pinned runtimes, and connect the tracked application settings.

The current machine inventory and intentional exceptions are recorded in [SYSTEM.md](SYSTEM.md).

## Quick start (macOS)

A new Mac does not have a GitHub SSH key yet, so the HTTPS clone is the easiest first step:

```bash
mv ~/.config ~/.config.bak  # optional: preserve an existing config directory
git clone https://github.com/Vedaant-Rajoo/dotfyles.git ~/.config
~/.config/bin/bootstrap
```

After GitHub authentication is configured, switch the clone to SSH:

```bash
gh auth login
git -C ~/.config remote set-url origin git@github.com:Vedaant-Rajoo/dotfyles.git
ssh -T git@github.com
```

If SSH is already configured, clone directly:

```bash
git clone git@github.com:Vedaant-Rajoo/dotfyles.git ~/.config
~/.config/bin/bootstrap
```

### Bootstrap options

```bash
bin/bootstrap --dry-run             # print mutations only
bin/bootstrap --with-defaults       # also apply bin/macdefaults
bin/bootstrap --with-herdr-service  # also start Herdr through brew services
```

The bootstrap is safe to re-run. It:

1. Checks Xcode Command Line Tools and Homebrew.
2. Installs the full [`Brewfile`](Brewfile), including graphical and App Store apps.
3. Installs Homebrew Fish, adds it to `/etc/shells`, and selects it as the login shell.
4. Installs and selects Node `24.14.1` through fnm and Python `3.14.4` through pyenv.
5. Installs the npm tools required by this configuration, including `postplan@0.0.4`.
6. Installs/links Claude Code configuration, enables the gitleaks hook, and installs Fisher plugins.
7. Optionally applies macOS defaults and starts the Herdr service.

The App Store must be signed in before `mas` can install its entries. A failed App Store install is reported and can be resumed by signing in and re-running the bootstrap.

> On this already-configured source machine, use `brew bundle check --file=Brewfile` to validate the manifest. Do not run `brew bundle install` merely as a check: casks such as DisplayLink invoke system package installers.

## What's included

| Path | Purpose |
|------|---------|
| `Brewfile` | Full Homebrew formula, cask, tap, and Mac App Store manifest |
| `bin/bootstrap` | Idempotent macOS bootstrap and runtime pinning |
| `SYSTEM.md` | Dated snapshot of installed toolchain provenance and deliberate exceptions |
| `nvim/` | Neovim Lua config with lazy.nvim and pinned plugins |
| `fish/` | Modular Fish config and Fisher plugin manifest — see [fish/README.md](fish/README.md) |
| `claude/` | Sanitized Claude Code settings and the tracked HTML-planning skill |
| `ghostty/` | Ghostty config and Rosé Pine theme |
| `herdr/` | Herdr workspace manager config; replaces tmux |
| `git/` | Global XDG Git identity, ignore rules, and opt-in repository hook |
| `gh/` | GitHub CLI configuration (credentials remain in the keychain) |
| `linearmouse/` | LinearMouse per-device settings |
| `zed/` | Zed settings; the app itself is not currently installed |
| `opencode/` | Sanitized OpenCode config; provider credentials remain local |
| `bat/` | Bat configuration |
| `Config.code-workspace` | Cursor / VS Code workspace for this repository |

## Manual setup after bootstrap

A complete clone deliberately does **not** copy credentials, account sessions, conversation history, caches, or application databases. Complete these steps on each machine.

### SSH and GitHub

Generate or restore an SSH key, register it with GitHub, authenticate `gh`, and test the connection:

```bash
ssh-keygen -t ed25519 -C "vedaant12345@gmail.com"
gh auth login
ssh -T git@github.com
```

Recreate any private host aliases from `~/.ssh/config` manually. Private keys and `known_hosts` never belong in this repository.

### Git identity migration

Git identity and `push.autoSetupRemote` now live in tracked `git/config`. On an existing machine, `~/.gitconfig` loads later and shadows this XDG file. Remove the old file only after proving it contains the same values:

```bash
git config --global --list --show-origin
rm ~/.gitconfig
git config --show-origin --get user.email
```

The final command should resolve from `~/.config/git/config`. After this migration, `git config --global ...` writes to the tracked file; review `git diff` before committing.

### Neovim and WakaTime

Open Neovim once so lazy.nvim installs the pinned plugins:

```bash
nvim
```

Use `:Lazy sync` to verify plugin state. The tracked WakaTime plugin also requires a machine-local `~/.wakatime.cfg`; create it through WakaTime's normal authentication flow and never commit its API key.

### Claude Code

The bootstrap installs Claude Code with Anthropic's native self-updating installer when `claude` is missing. It then runs `bin/claude_link`, which:

- symlinks `~/.claude/CLAUDE.md`, `skills/`, and `statusline-command.sh` to `claude/`;
- seeds `~/.claude/settings.local.json` from the tracked example;
- materializes live `~/.claude/settings.json` by merging the local `env` block into the sanitized tracked settings.

Replace the placeholder CLIProxyAPI values in `~/.claude/settings.local.json`, mirror the required shell exports in `fish/local/claude-code.fish`, and run:

```bash
bin/claude_link
bin/claude_link --check
```

Everything else under `~/.claude` — authentication, sessions, projects, transcripts, telemetry, and caches — remains local.

### HTML planning / Postplan

`bin/bootstrap` installs the pinned `postplan@0.0.4` required by the tracked `html-planning` skill. Authenticate it separately:

```bash
postplan login
postplan whoami
```

Postplan credentials and local draft mappings stay outside the repository.

### OpenCode

`opencode/opencode.jsonc` is the sanitized tracked base. Recreate machine-local provider/proxy configuration in `opencode/opencode.json`; it is ignored because it contains live credentials.

### Zed

Zed settings remain tracked even though Zed.app is not installed in this snapshot. If Zed is re-adopted, install it and then:

- set `context_servers.mcp-server-context7.settings.context7_api_key` in `zed/settings.json`;
- sign in to GitHub Copilot.

Add `cask "zed"` to the Brewfile when the app becomes part of the active machine again.

### Cursor, Codex, DockDoor, and Raycast

These applications are installed by the Brewfile, but their mutable settings are deliberately not tracked:

- Cursor editor/agent settings, MCP configuration, extension list, and sessions;
- Codex `~/.codex/config.toml`, authentication, memories, and session state;
- DockDoor plist preferences;
- Raycast Beta preferences, databases, and downloaded extensions.

Sign in and configure them manually. See [SYSTEM.md](SYSTEM.md) for the current extension/app snapshot.

### OrbStack and Docker

OrbStack is installed by the Brewfile and supplies `docker`, `kubectl`, `orbctl`, and the tracked Fish completion targets. Start OrbStack, select its Docker context, reauthenticate registries through the macOS keychain, and reapply local IPv6/Rosetta preferences if needed.

## Fish plugins

`fish/fish_plugins` is the manifest for Fisher, fzf.fish, autopair.fish, sponge, and Pure. Bootstrap installs Fisher and runs `fisher update`; after future plugin-manifest changes, run:

```fish
fisher update
```

## macOS defaults

`bin/macdefaults` covers selected keyboard, Dock, Finder, screenshot, and window-dragging preferences. It is intentionally opt-in because it requests administrator access and restarts user-interface services:

```bash
bin/bootstrap --with-defaults
# or directly:
fish bin/macdefaults
```

It does not attempt to clone every GUI preference. Trackpad, Mission Control, hot corners, menu bar, energy, default-app, and many third-party plist settings remain outside scope.

## Git hooks and secret scanning

Bootstrap enables the tracked hook for this clone:

```bash
git config core.hooksPath git/hooks
```

The hook runs `gitleaks protect --staged -v`. Before commits that affect credential-adjacent config, also run:

```bash
gitleaks detect --source . -v
```

## Machine-local and ignored files

| Path | Why it remains local |
|------|----------------------|
| `fish/local/` | Shell secrets and machine-specific exports |
| `fish/fish_variables` | Fish runtime/universal variables |
| `claude/settings.local.json` and broader `~/.claude/` state | Credentials, permissions, account and conversation state |
| `opencode/opencode.json` | Provider configuration and API credentials |
| `github-copilot/` | OAuth and Copilot state |
| `~/.wakatime.cfg` | WakaTime API key |
| `raycast-x/` | Downloaded extensions and app data |
| `herdr/*.sock`, logs, sessions, `.plugins.lock` | Runtime state |
| `nvim/tmp/`, `zed/prompts/`, caches and logs | Generated state |
| `~/.ssh/`, `~/.docker/`, `~/.orbstack/` | Keys, credential-store selection, and local runtime settings |

## Updating

```bash
cd ~/.config
git pull
brew bundle check --file=Brewfile
fisher update
```

For Neovim lockfile changes, open Neovim and run `:Lazy sync`. `bin/brew_update` and `bin/u` provide the existing interactive update flows.

## Linux

The repository remains useful on Linux, but `bin/bootstrap` intentionally exits rather than pretending macOS casks, `mas`, `chsh` paths, and `bin/macdefaults` are portable.

For Linux:

1. Clone the repository directly to `~/.config`.
2. Install Fish through the distribution package manager and make it the login shell.
3. Install compatible Brewfile formulae through Linuxbrew or native packages; skip all casks and `mas` entries.
4. Install Node `24.14.1` with fnm and Python `3.14.4` with pyenv.
5. Run `bin/claude_link` and `fish -c 'fisher update'`.
6. Replace macOS-only integrations (OrbStack, LinearMouse, DockDoor, DisplayLink, and `macos-*` Ghostty settings) with Linux equivalents.

The tracked Fish and Neovim configuration guard most optional commands, but the Brewfile itself is Mac-first by design.
