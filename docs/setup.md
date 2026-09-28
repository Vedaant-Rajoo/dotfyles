# Manual setup after bootstrap

A complete clone deliberately does **not** copy credentials, account sessions,
conversation history, caches, or application databases. Complete these steps on
each machine.

Back to [the repository overview](../README.md); the current machine inventory
and intentional exceptions are recorded in [SYSTEM.md](../SYSTEM.md).

## SSH and GitHub

Generate or restore an SSH key, register it with GitHub, authenticate `gh`, and
test the connection:

```bash
ssh-keygen -t ed25519 -C "vedaant12345@gmail.com"
gh auth login
ssh -T git@github.com
```

Recreate any private host aliases from `~/.ssh/config` manually. Private keys
and `known_hosts` never belong in this repository.

## Git identity migration

Git identity and `push.autoSetupRemote` now live in tracked `git/config`. On an
existing machine, `~/.gitconfig` loads later and shadows this XDG file. Remove
the old file only after proving it contains the same values:

```bash
git config --global --list --show-origin
rm ~/.gitconfig
git config --show-origin --get user.email
```

The final command should resolve from `~/.config/git/config`. After this
migration, `git config --global ...` writes to the tracked file; review
`git diff` before committing.

## Neovim and WakaTime

Open Neovim once so lazy.nvim installs the pinned plugins:

```bash
nvim
```

Use `:Lazy sync` to verify plugin state. The tracked WakaTime plugin also
requires a machine-local `~/.wakatime.cfg`; create it through WakaTime's normal
authentication flow and never commit its API key.

## Postplan

`bin/bootstrap` installs the standalone `postplan@0.0.4` CLI. If needed,
authenticate it separately:

```bash
postplan login
postplan whoami
```

Postplan credentials and local draft mappings stay outside the repository.

## AI harness defaults

Harnesses use native provider selection and authentication. Bootstrap installs
Claude Code when missing, but does not install or start a router, load proxy
credentials, or project shared rules, skills, subagents, or hooks.

The previous 9router configuration and shared behavior layer were retired on
2026-09-28. Future middleware configuration is an explicit, separate setup step.
Do not restore old harness settings or shell exports without reviewing them.

## OpenCode

`opencode/opencode.jsonc` contains only the schema declaration. Authenticate and
select providers through OpenCode's native configuration. Machine-local
`opencode/opencode.json` remains ignored for credential-bearing settings.

## Zed

Zed settings remain tracked even though Zed.app is not installed in this
snapshot. The tracked
`context_servers.mcp-server-context7.settings.context7_api_key` value in
`zed/settings.json` must remain blank so credentials never enter the repository.
Until a verified machine-local credential mechanism is documented, leave
Context7 disabled or uncredentialed there. If Zed is re-adopted, install it and
sign in to GitHub Copilot through Zed's normal account flow.

Add `cask "zed"` to the Brewfile when the app becomes part of the active machine
again.

## Legcord

Legcord keeps its configuration at
`~/Library/Application Support/legcord/storage/settings.json` and rewrites it in
place, so bootstrap runs `bin/legcord_link` to symlink that file to the tracked
`legcord/storage/settings.json`. In-app settings changes land directly in this
repository's working tree; review `git diff legcord/` before committing, because
Legcord also bumps internal fields such as `modCache` hashes on its own. Discord
account login, session cookies, caches, window geometry, and the locale cache
stay machine-local. On Linux no link is needed — Electron's config directory for
Legcord is `~/.config/legcord` itself — and the tracked `.gitignore` rules keep
everything except `storage/settings.json` out of version control there.

## Cursor, Codex, DockDoor, and Raycast

Authenticate Cursor Agent with `cursor-agent login` and sign in to other
harnesses using their native flows. These applications are installed by the
Brewfile; mutable native settings remain deliberately untracked:

- Cursor editor/agent settings, MCP configuration, extension list, sessions, and
  account-backed user rules;
- Codex `~/.codex/config.toml`, authentication, memories, plugins, and session
  state;
- DockDoor plist preferences;
- Raycast Beta preferences, databases, and downloaded extensions.

Sign in and configure the native state manually. See [SYSTEM.md](../SYSTEM.md)
for the current extension/app snapshot.

## OrbStack and Docker

OrbStack is installed by the Brewfile and supplies `docker`, `kubectl`,
`orbctl`, and the tracked Fish completion targets. Start OrbStack, select its
Docker context, reauthenticate registries through the macOS keychain, and
reapply local IPv6/Rosetta preferences if needed.

## macOS defaults

`bin/macdefaults` covers selected keyboard, Dock, Finder, screenshot, and
window-dragging preferences. It is intentionally opt-in because it restarts
Dock, Finder, and related UI services:

```bash
bin/bootstrap --with-defaults
# or directly:
fish bin/macdefaults
```

It does not attempt to clone every GUI preference. Trackpad, Mission Control,
hot corners, menu bar, energy, default-app, and many third-party plist settings
remain outside scope.

## Git hooks and secret scanning

Bootstrap enables the tracked hooks for this clone:

```bash
git config core.hooksPath git/hooks
```

Two hooks run from there: `pre-commit` scans staged changes with
`gitleaks protect --staged -v`, and `commit-msg` enforces the commit style —
a single lowercase conventional-commit subject of at most 100 characters, no
prose body, trailers only — for every author, human or agent. Before commits
that affect credential-adjacent config, also run:

```bash
gitleaks detect --source . -v
```

## Machine-local and ignored files

| Path | Why it remains local |
|------|----------------------|
| `fish/local/` | Shell secrets and machine-specific exports |
| `fish/fish_variables` | Fish runtime/universal variables |
| Fisher-installed plugin files under `fish/{functions,conf.d,completions,themes}/` | Fisher installs into this repo; `fish/fish_plugins` is the tracked source, and `fisher update` reinstalls them |
| `opencode/agents/`, `claude/agents/` | Optional machine-local agent definitions; none are installed by bootstrap |
| `claude/auth-token` | Legacy proxy credential path remains ignored; native Claude settings do not use it |
| `claude/` runtime state (`sessions/`, `projects/`, `plugins/`, `security/`, `history.jsonl`, caches) | Claude Code writes it into the working tree because `~/.claude` links here; only config is tracked — see [claude/README.md](../claude/README.md) |
| `~/.claude.json` | Stays at the home root: OAuth, per-project state, and user MCP configuration — see [claude/README.md](../claude/README.md) |
| Harness-native auth/config (`~/.codex`, `~/.cursor`, OpenCode local override) | Credentials, provider settings, permissions, account and conversation state |
| `opencode/opencode.json` | Provider configuration and API credentials |
| `github-copilot/` | OAuth and Copilot state |
| `~/.wakatime.cfg` | WakaTime API key |
| `raycast/`, `raycast-x/` | Downloaded extensions and app data |
| `legcord/` except `storage/settings.json` | Discord session, caches, and window state (Linux Legcord writes them into this directory) |
| `herdr/*.sock`, logs, sessions, `.plugins.lock` | Runtime state |
| `nvim/tmp/`, `zed/prompts/`, caches and logs | Generated state |
| `~/.rustup/`, `~/.cargo/` | Rust toolchains, downloaded crates, and build caches; `bin/bootstrap` installs them with the official rustup installer rather than copying them from a clone |
| `~/.ssh/`, `~/.docker/`, `~/.orbstack/` | Keys, credential-store selection, and local runtime settings |
