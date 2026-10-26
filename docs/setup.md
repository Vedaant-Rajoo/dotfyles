# Manual setup after bootstrap

A complete clone deliberately does **not** copy credentials, account sessions,
conversation history, caches, or application databases. Complete these steps on
each machine.

Back to [the repository overview](../README.md). The [Brewfile](../Brewfile)
and [bootstrap script](../bin/bootstrap) declare the software restored on a new machine.

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

## Moving an existing machine to mise

On a machine bootstrapped before mise owned the language runtimes, run
`brew install mise` first: `bin/u` upgrades what Homebrew has but installs no
new Brewfile entries. The next `bin/u` then installs the mise defaults and runs
the migrations that uninstall fnm, pyenv, pyenv-virtualenv, and Homebrew's Bun,
pnpm, prettier, and prettierd; Homebrew removes its Node with them unless
another formula still needs it. A migration waits, and says so, until mise can
run every replacement. Open a new shell afterwards and check:

```bash
command -s node python3 bun go pnpm   # all in ~/.local/share/mise/shims
npm ls -g --depth=0                   # globals stay in ~/.node_modules
```

The migrations keep `~/.pyenv` and `~/.local/share/fnm`. mise's Python is a
prebuilt python-build-standalone interpreter rather than pyenv's local build,
so recreate any virtualenv that points into `~/.pyenv/versions`, then delete
both directories by hand. Global npm modules with compiled parts need
`npm rebuild -g` only when the default Node major version changes.

A project that pins a version mise has not installed fails with a message
naming `mise install`; run it in that project. JavaScript projects list
prettier as a dev dependency (`bun add -d prettier` or `npm i -D prettier`).
Neovim formats with that copy; outside a project, JavaScript and TypeScript
fall back to the language server, and JSON, HTML, and CSS stay as written.

## Postplan

`bin/bootstrap` installs the standalone `postplan@0.0.4` CLI. If needed,
authenticate it separately:

```bash
postplan login
postplan whoami
```

Postplan credentials and local draft mappings stay outside the repository.

## AI harness routing

Codex, Claude Code and OpenCode send inference through the local Caveman proxy
(`127.0.0.1:8787`), which forwards to Quotio's CLIProxyAPI (`127.0.0.1:8317`).
Bootstrap installs Claude Code and the Quotio app, but not the Caveman binaries
or their launch agent, so the harnesses cannot reach a model until you follow
[Fresh machine](../caveman/README.md#fresh-machine).

## Agent skills

The [skills lock](../agents/skill-lock.json) records the shared skills restored
by bootstrap. Skill files remain machine-local in `~/.agents/skills`.
`bin/agent-skills` connects the CLI's lock paths to the tracked lock, installs
missing skills, and links them for the configured agents.

To restore skills or add one:

```bash
bin/agent-skills restore
npx skills@1.7.4 add <source> -g -a claude-code codex -s <name> -y
bin/agent-skills link
```

Commit the resulting lock change. Use `bin/agent-skills update` or `bin/u` for
updates; `npx skills update -g` links skills into every agent it detects instead
of preserving this setup's selected agents.

## OpenCode

OpenCode V2 (`anomalyco/tap/opencode-v2`) uses native V2 config.
`opencode/opencode.jsonc` routes the `openai` and `anthropic` providers through
Caveman and registers the `caveman-mcp` recovery server. It reads the client key
from `~/.local/state/quotio/client-key`, which stays outside the repository; see
[quotio/README.md](../quotio/README.md). Machine-local `opencode/opencode.json`
remains ignored for credential-bearing settings.

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

## Cursor, Codex, and Raycast

The Brewfile installs Cursor, Codex, and Raycast. Install Cursor Agent
separately if needed, then authenticate it with `cursor-agent login`. Sign in
to other harnesses using their native flows. Mutable native settings remain
deliberately untracked:

- Cursor editor/agent settings, MCP configuration, extension list, sessions, and
  account-backed user rules;
- Codex `~/.codex/config.toml`, authentication, memories, plugins, and session
  state;
- Raycast Beta preferences, databases, and downloaded extensions.

Sign in and configure the native state manually. Select Raycast's Beta channel
inside the application if desired; the Brewfile installs the `raycast` cask.

## Karabiner-Elements

The Brewfile installs Karabiner-Elements, and its rules live in the tracked
`karabiner/karabiner.json`. On first launch, allow its driver extension in
System Settings > General > Login Items & Extensions, then grant Input Monitoring
to each Karabiner process that macOS asks about. Held Caps Lock is hyper
(⌃⌥⇧⌘) and tapped Caps Lock toggles Caps Lock; hyper with h, j, k, or l sends
the arrow keys.

## Vorssaint

The Brewfile installs Vorssaint, which replaces DockDoor, Hyperkey, and Macs Fan
Control. Its features install one by one from Settings > Features:
add Dock Preview, App switcher, and Fan Control, then grant the permissions
that setup asks for. Leave its Super key off: Karabiner owns Caps Lock, and
Vorssaint would add its modifiers to Karabiner's arrow keys. Its settings stay machine-local; move them to
another Mac with Vorssaint's own export.

## OrbStack and Docker

OrbStack is installed by the Brewfile and supplies `docker`, `kubectl`,
`orbctl`, and their Fish completions through its shell integration. Start OrbStack, select its
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

Bootstrap enables the tracked hooks for this clone. The path is absolute, so
every worktree, including T3's, runs the main checkout's hooks:

```bash
git config core.hooksPath ~/.config/git/hooks
```

Two hooks run from there: `pre-commit` scans staged changes with
`gitleaks protect --staged -v`, and `commit-msg` enforces the scoped commit
standard in [`git/commit-style.md`](../git/commit-style.md) —
`<scope>: <description>`, where the scope names a path in the repository — for
every author, human or agent. That file is the only copy of the rule: the
repo-root `AGENTS.md` links to it, and the hook prints it with every rejection.
T3's commit button reads `AGENTS.md` because its writing style stays on
`repo_conventions`. Before commits that affect credential-adjacent config, also
run:

```bash
gitleaks detect --source . -v
```

### Opting another repository in

Inside the other repository, add the hook through Git's config-based hooks
(Git 2.54+). They run alongside the repository's own hooks, so husky, lefthook,
or pre-commit keep working. Never add this entry to `~/.config` itself, where
`core.hooksPath` already runs the hook, nor to the global `git/config`:

```bash
git config set hook.scoped-commits.command "$HOME/.config/git/hooks/commit-msg"
git config set hook.scoped-commits.event commit-msg
git hook list --show-scope commit-msg   # should list scoped-commits
```

Then paste [`git/commit-style.md`](../git/commit-style.md) into that
repository's `AGENTS.md` so agents and T3's commit button see the rule before the
hook rejects anything. A symlink does not work there: T3 ignores an `AGENTS.md`
that resolves outside the repository. The pasted copy is a hand copy; refresh it
when the standard changes.

## Machine-local and ignored files

| Path | Why it remains local |
|------|----------------------|
| `.local/` | Personal research, comparisons, design drafts, machine snapshots, and one-off verification reports; not restored by a clone |
| `fish/local/` | Shell secrets and machine-specific exports |
| `fish/fish_variables` | Fish runtime/universal variables |
| Fisher-installed plugin files under `fish/{functions,conf.d,completions,themes}/` | Fisher installs into this repo; `fish/fish_plugins` is the tracked source, and `fisher update` reinstalls them |
| `opencode/agents/` | Optional machine-local agent definitions; none are installed by bootstrap |
| `claude/` runtime state (`sessions/`, `projects/`, `plugins/`, `security/`, `history.jsonl`, caches) | Claude Code writes it into the working tree because `~/.claude` links here; only config is tracked — see [claude/README.md](../claude/README.md) |
| `~/.claude.json` | Stays at the home root: OAuth, per-project state, and user MCP configuration — see [claude/README.md](../claude/README.md) |
| Harness-native auth/config (`~/.codex`, `~/.cursor`, OpenCode local override) | Credentials, provider settings, permissions, account and conversation state |
| `opencode/opencode.json` | Provider configuration and API credentials |
| `github-copilot/` | OAuth and Copilot state |
| `~/.wakatime.cfg` | WakaTime API key |
| `raycast/` | Downloaded extensions and app data |
| `legcord/` except `storage/settings.json` | Discord session, caches, and window state (Linux Legcord writes them into this directory) |
| `herdr/*.sock`, logs, sessions, `.plugins.lock` | Runtime state |
| `nvim/tmp/`, caches and logs | Generated state |
| `~/.local/share/mise/`, `~/.local/state/mise/`, mise's cache | Installed runtimes, shims, trust records, and downloads; `mise install` recreates them from `mise/mise.toml` |
| `~/.rustup/`, `~/.cargo/` | Rust toolchains, downloaded crates, and build caches; `bin/bootstrap` installs them with the official rustup installer rather than copying them from a clone |
| `~/.ssh/`, `~/.docker/`, `~/.orbstack/` | Keys, credential-store selection, and local runtime settings |
