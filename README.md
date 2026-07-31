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
6. Installs Claude Code, projects shared agent rules/skills/subagents/hooks into every installed harness, enables the gitleaks hook, and installs Fisher plugins.
7. Optionally applies macOS defaults and starts the Herdr service.

The App Store must be signed in before `mas` can install its entries. A failed App Store install is reported and can be resumed by signing in and re-running the bootstrap.

> On this already-configured source machine, use `brew bundle check --file=Brewfile` to validate the manifest. Do not run `brew bundle install` merely as a check: it may adopt externally installed applications into Homebrew ownership.

## What's included

| Path | Purpose |
|------|---------|
| `Brewfile` | Full Homebrew formula, cask, tap, and Mac App Store manifest |
| `bin/bootstrap` | Idempotent macOS bootstrap and runtime pinning |
| `SYSTEM.md` | Dated snapshot of installed toolchain provenance and deliberate exceptions |
| `nvim/` | Neovim Lua config with lazy.nvim and pinned plugins |
| `fish/` | Modular Fish config and Fisher plugin manifest — see [fish/README.md](fish/README.md) |
| `agents/` | Canonical cross-harness rules, skills, subagents, and portable hook definitions |
| `claude/` | Claude-native settings, hooks, statusline, and adapters into `agents/` |
| `ghostty/` | Ghostty config and Rosé Pine theme |
| `herdr/` | Herdr workspace manager config; replaces tmux |
| `git/` | Global XDG Git identity, ignore rules, and opt-in repository hook |
| `gh/` | GitHub CLI configuration (credentials remain in the keychain) |
| `linearmouse/` | LinearMouse per-device settings |
| `legcord/` | Legcord (alternate Discord client) settings, connected by `bin/legcord_link` |
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

### Shared AI harness configuration

`agents/` is the source of truth for behavior shared by Claude Code, Codex, OpenCode, and Cursor Agent:

- `agents/AGENTS.md` contains platform-neutral standing rules;
- `agents/skills/` uses the common `SKILL.md` directory format;
- `agents/subagents/` holds one canonical file per subagent — see [agents/subagents/README.md](agents/subagents/README.md);
- `agents/hooks/manifest.json` records the portable hook intersection, with commands under `agents/hooks/scripts/`.

`bin/agents_link all` projects that core into each installed harness. It uses native global rule files for Claude, Codex, and OpenCode; installs each shared skill additively without replacing harness-native skills; and generates Cursor's native hook file. Cursor Agent has no verified filesystem-backed global rule path in the installed build, so its shared rules are project-scoped through a repository `AGENTS.md`; the conformance report labels that limitation instead of claiming global coverage.

Rules and skills are the same bytes everywhere, so they are symlinked — a skill written into `~/.claude/skills/` physically lands in `agents/skills/` through the link chain and is instantly shared with every other harness as a reviewable diff. `~/.agents/` is the cross-tool convention: Codex and OpenCode scan `~/.agents/skills` natively, `~/.agents/AGENTS.md` links to the same shared rules, and `npx skills --global` installs there.

Subagents cannot be symlinked, because Claude and OpenCode disagree about the frontmatter. `bin/agents_render` translates each canonical file instead, and `agents_link` writes the result to `~/.claude/agents/` and `~/.config/opencode/agents/`. Those generated files are untracked and carry a `generated by bin/agents_link` header; edit `agents/subagents/<name>.md` and re-run `bin/agents_link all`. Codex has no stable subagent format and Cursor's is unverified, so both are reported as not applicable rather than guessed at. Model tiers are dropped on OpenCode (its model ids are machine-local) — the full translation contract and its lossy cases are documented alongside the sources.

### Adopting a skill installed from outside

`npx skills add --global` writes a real directory into `~/.agents/skills/<name>`. It works immediately but only on this machine, so `bin/agents_link --check` reports it as unmanaged. Promote it:

```bash
bin/agents_adopt --dry-run <name>   # show what would move
bin/agents_adopt <name>             # move into agents/skills, relink, reproject
```

The directory is moved into `agents/skills/<name>` and linked back where it was. Nothing is committed: adopted files come from outside this repository, so read them before `git add`, and never let credentials land under `agents/`.

Run the deterministic wiring checks at any time:

```bash
bin/agents_link all
bin/agents_conform
```

Behavioral checks use real model calls and are deliberately opt-in:

```bash
bin/agents_conform --live           # rules + supported hooks
bin/agents_conform --live --skills  # also test skill discovery/invocation
```

The static tier exits non-zero on drift. It also validates `agents/hooks/manifest.json` against its own schema, checks that Claude's tracked settings really run every hook the manifest calls portable, and requires each `agents/skills/*/SKILL.md` to declare a `name:` matching its directory. The live tier prints a scorecard and is informational by default because model obedience is probabilistic; set `AGENTS_LIVE_GATE=1` only when a failing canary should fail automation. A skill joins the live tier by publishing a `SKILL-CHECK <name>` contract line in its own `SKILL.md`.

Until `~/.claude/settings.local.json` holds a real CLIProxyAPI token, `agents_conform` reports two expected `BROKEN` rows for `settings.local.json` and `settings.json`. That file is machine-local by design and cannot be fixed from the repository — see the note below. Three consequences follow from that one placeholder, and all three clear together once the token is real:

- `claude_link` refuses to materialize `~/.claude/settings.json`, so the live settings file keeps whatever Claude Code last wrote and carries none of the tracked hooks;
- Claude's `Stop` hook therefore never fires, and the live scorecard shows `HOOK N/A`;
- the live tier never runs at all, because `--live` is gated behind a passing static tier.

The bootstrap still installs Claude Code with Anthropic's native self-updating installer when `claude` is missing. The Claude adapter delegates to `bin/claude_link`, which preserves Claude-native settings: it seeds `~/.claude/settings.local.json`, materializes `~/.claude/settings.json` with the local CLIProxyAPI environment, and links Claude-only hooks/statusline files. Replace the placeholder values in `~/.claude/settings.local.json`, mirror the required exports in `fish/local/claude-code.fish`, then re-run `bin/agents_link all`.

Authentication, provider settings, sessions, transcripts, caches, and model selection remain native and machine-local for every harness.

### HTML planning / Postplan

`bin/bootstrap` installs the pinned `postplan@0.0.4` required by the tracked `html-planning` skill. Authenticate it separately:

```bash
postplan login
postplan whoami
```

Postplan credentials and local draft mappings stay outside the repository.

### OpenCode

`opencode/opencode.jsonc` is the sanitized tracked base and points at the shared global rules/skill roots. Recreate machine-local provider/proxy configuration in `opencode/opencode.json`; it is ignored because it contains live credentials. OpenCode lifecycle customization uses plugins rather than portable command hooks, so `agents_conform` reports hook coverage as not applicable.

### Zed

Zed settings remain tracked even though Zed.app is not installed in this snapshot. If Zed is re-adopted, install it and then:

- set `context_servers.mcp-server-context7.settings.context7_api_key` in `zed/settings.json`;
- sign in to GitHub Copilot.

Add `cask "zed"` to the Brewfile when the app becomes part of the active machine again.

### Legcord

Legcord keeps its configuration at `~/Library/Application Support/legcord/storage/settings.json` and rewrites it in place, so bootstrap runs `bin/legcord_link` to symlink that file to the tracked `legcord/storage/settings.json`. In-app settings changes land directly in this repository's working tree; review `git diff legcord/` before committing, because Legcord also bumps internal fields such as `modCache` hashes on its own. Discord account login, session cookies, caches, window geometry, and the locale cache stay machine-local. On Linux no link is needed — Electron's config directory for Legcord is `~/.config/legcord` itself — and the tracked `.gitignore` rules keep everything except `storage/settings.json` out of version control there.

### Cursor, Codex, DockDoor, and Raycast

These applications are installed by the Brewfile. Shared agent behavior is projected by `bin/agents_link`, but mutable native settings remain deliberately untracked:

- Cursor editor/agent settings, MCP configuration, extension list, sessions, and account-backed user rules;
- Codex `~/.codex/config.toml`, authentication, memories, plugins, and session state;
- DockDoor plist preferences;
- Raycast Beta preferences, databases, and downloaded extensions.

Sign in and configure the native state manually. See [SYSTEM.md](SYSTEM.md) for the current extension/app snapshot.

### OrbStack and Docker

OrbStack is installed by the Brewfile and supplies `docker`, `kubectl`, `orbctl`, and the tracked Fish completion targets. Start OrbStack, select its Docker context, reauthenticate registries through the macOS keychain, and reapply local IPv6/Rosetta preferences if needed.

## Fish plugins

`fish/fish_plugins` is the manifest for Fisher, fzf.fish, autopair.fish, sponge, and Pure. Bootstrap installs Fisher and runs `fisher update`; after future plugin-manifest changes, run:

```fish
fisher update
```

## macOS defaults

`bin/macdefaults` covers selected keyboard, Dock, Finder, screenshot, and window-dragging preferences. It is intentionally opt-in because it restarts Dock, Finder, and related UI services:

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
| `opencode/agents/`, `~/.claude/agents/` | Generated from `agents/subagents/`; regenerate with `bin/agents_link all` |
| Harness-native auth/config (`~/.claude`, `~/.codex`, `~/.cursor`, OpenCode local override) | Credentials, provider settings, permissions, account and conversation state |
| `opencode/opencode.json` | Provider configuration and API credentials |
| `github-copilot/` | OAuth and Copilot state |
| `~/.wakatime.cfg` | WakaTime API key |
| `raycast/`, `raycast-x/` | Downloaded extensions and app data |
| `legcord/` except `storage/settings.json` | Discord session, caches, and window state (Linux Legcord writes them into this directory) |
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
5. Run `bin/agents_link all` and `fish -c 'fisher update'`.
6. Replace macOS-only integrations (OrbStack, LinearMouse, DockDoor, and `macos-*` Ghostty settings) with Linux equivalents.

The tracked Fish and Neovim configuration guard most optional commands, but the Brewfile itself is Mac-first by design.
