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

`nvim/` holds the Neovim config. WakaTime requires a machine-local
`~/.wakatime.cfg`; create it through WakaTime's normal authentication flow and
never commit its API key.

In normal mode, press `-` to browse the current file’s directory in Oil.
Press `-` again to go up, `Enter` to open an entry, `_` to open Neovim’s
working directory, or `g?` to see Oil’s keymaps. `Space` then `-` toggles
a floating Oil window. Use `Ctrl-x` to decrement a number.

## Moving an existing machine to mise

The current machine already uses mise. On an older setup, run `brew install mise` first:
`bin/u` upgrades existing Homebrew packages but installs no new Brewfile entries.
It installs mise's declared defaults, but the old retirement migrations no longer
ship. Before removing an old runtime manager, snapshot its state and verify every
replacement. Remove only retired packages this repository managed, preserving
Homebrew's dependency runtimes. Open a new Fish shell and check:

```bash
command -s node python3 bun go pnpm   # all in ~/.local/share/mise/shims
npm ls -g --depth=0                   # globals stay in ~/.node_modules
```

Keep `~/.pyenv` and `~/.local/share/fnm` while projects still depend on them.
mise's Python uses python-build-standalone; recreate virtualenvs that point into
`~/.pyenv/versions` before removing their old interpreter. Remove old runtime
directories only after verifying they are unused. Global npm modules with
compiled parts need `npm rebuild -g` when the default Node major version changes.

No migrations ship while this configuration runs on one machine. See the
[migration policy](../migrations/README.md) before adding any.

A project that pins a version mise has not installed fails with a message
naming `mise install`; run it in that project. JavaScript projects list
prettier as a dev dependency (`bun add -d prettier` or `npm i -D prettier`).

## Postplan

`bin/bootstrap` installs the standalone `postplan@0.0.4` CLI. If needed,
authenticate it separately:

```bash
postplan login
postplan whoami
```

Postplan credentials and local draft mappings stay outside the repository.

## AI harness routing

Codex, Claude Code, OpenCode, and Antigravity use their native providers and
authentication. Bootstrap installs Claude Code; the Brewfile installs Codex
and OpenCode. No local inference router or proxy credential is required.

Sign in with `codex login`, `claude auth login`, and `opencode auth login`.
Antigravity uses its own Google sign-in flow, including when launched through
T3. T3's Codex and Claude providers load their native harness settings.
Restart existing harness sessions after changing provider settings.

## 9router

Bootstrap installs the upstream `9router` npm CLI in `~/.node_modules`, using
mise's default Node. `bin/u npm` updates it with the other npm globals. 9router
maintains its own runtime dependencies, database, provider credentials, and logs
under `~/.9router/`; keep that directory machine-local.

Start the vanilla router on this machine's loopback interface:

```bash
9router --host 127.0.0.1 --skip-update
```

The dashboard is at <http://127.0.0.1:20128/dashboard>, and the API base URL is
`http://127.0.0.1:20128/v1`. Add `--tray` to run with the menu-bar controls and
`--no-browser` to suppress opening a browser. Quit through the tray menu. Starting
it this way does not install a login service; bootstrap only installs the CLI.
`--skip-update` leaves package updates to `bin/u npm`.

Connect accounts in the dashboard's Providers page before selecting 9router in
a harness. Installation leaves the harnesses on native providers; routing changes
are a separate setup step. Upstream installation instructions:
<https://github.com/decolua/9router/blob/master/gitbook/content/en/getting-started/installation.md>.

Headroom runs as an optional local compression service on port 8787. On this
machine its CLI and compression extras are installed in mise's Python 3.14.
9router looks for a Python interpreter beside the Headroom executable when it
checks or installs extras. To restore the dashboard's links after installing
Headroom in mise Python, run:

```bash
ln -s "$HOME/.local/share/mise/installs/python/3.14/bin/headroom" "$HOME/.local/bin/headroom"
ln -s "$HOME/.local/share/mise/shims/python" "$HOME/.local/bin/python"
```

Use **Start** in **Setup Headroom** and check `http://localhost:8787/health`.
**Compression extras** shows the detected `code` and `ml` packages.

### 9router quotas in T3 Code

Open **Usage → Limits** to see native pooled bars for Codex and Claude. T3 reads
these through its built-in quota hub protocol. The local adapter translates
9router's primary and secondary Codex windows and Claude's five-hour, weekly,
and model-specific weekly windows. 9router 0.5.123 omits the Codex window duration,
so T3 supplies its usual period label. The percentage and reset time come from
9router. Account email and Codex workspace ID, when available, let T3 count the
same account once across environments.

The **9router** HTTP source also lists per-account readings, including Antigravity
model quotas. T3 displays these as text in **Usage → Limits**. Its hub reader
recognizes only Codex, Claude and Grok. For Codex and Claude thread bars, enable
**Settings → Appearance → Thread details → Usage limits**.

`bin/t3-9router-quota` reads 9router's local quota API on port 20128 using its
machine-local CLI authentication and caches polls for two minutes. Both T3 sources
share this cache and the same local feed token. The adapter serves quota reads
only. Check the upstream formats when upgrading 9router or T3.

To restore the optional feed after installing and configuring 9router, run
these commands in Bash or Zsh:

```bash
mkdir -p -m 700 ~/.local/state/t3-9router-quota
(umask 077; set -C; openssl rand -hex 32 > ~/.local/state/t3-9router-quota/token) # first setup only
ln -s ~/.config/launchd/dev.newedia.t3-9router-quota.plist ~/Library/LaunchAgents/
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/dev.newedia.t3-9router-quota.plist
pbcopy < ~/.local/state/t3-9router-quota/token
```

Under **Settings → Providers → Usage providers**, add these sources to the local
environment. Paste the feed token copied above into each source's key field.

| Action | Name | URL |
| --- | --- | --- |
| Add hub | 9router quota hub | `http://127.0.0.1:20129` |
| Add HTTP source | 9router | `http://127.0.0.1:20129/quotas` |

## Agent skills

The [skills lock](../agents/skill-lock.json) records upstream skills restored
by bootstrap. Skill files remain machine-local in `~/.agents/skills`.
`bin/agent-skills` connects the CLI's lock paths to the tracked lock, installs
missing skills, and links them for the configured agents.

Ardia owns the `ardia` and `cua-driver` skills because their instructions match
its installed browser and computer-use tools. When the Ardia CLI is available,
`bin/agent-skills restore` and `update` install that bundle only in
`~/.agents/skills`, then link Claude Code and OpenCode to those copies.
Antigravity uses the same shared files. Identical Ardia-managed copies become
links; modified or unmanaged copies stop the operation for manual reconciliation.
Ardia's installer preserves these links during app updates. Keep this bundle
out of the skills CLI lock and install it through `bin/agent-skills`.
After Ardia first installs its CLI, run `bin/agent-skills restore` to apply this wiring.

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
`opencode/opencode.jsonc` leaves provider and model selection at their defaults.
Use `opencode auth login` to connect a provider and `opencode auth list` to
check connected accounts. Machine-local `opencode/opencode.json` remains
ignored for credential-bearing settings.

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

## Codex and Raycast

The Brewfile installs Codex and Raycast. Sign in using their native flows.
Mutable native settings remain deliberately untracked:

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
window-dragging preferences. It also makes Strata the file manager for
"Reveal in Finder" and for opening folders; the folder handler applies at the
next login. It is intentionally opt-in because it restarts
Dock, Finder, and related UI services:

```bash
bin/bootstrap --with-defaults
# or directly:
fish bin/macdefaults
```

It does not attempt to clone every GUI preference. Trackpad, Mission Control,
hot corners, menu bar, energy, other default-app, and many third-party plist settings
remain outside scope.

## Git hooks and secret scanning

Bootstrap enables the tracked hooks for this clone. The path is absolute, so
every worktree, including T3's, runs the main checkout's hooks:

```bash
git config core.hooksPath ~/.config/git/hooks
```

Two hooks run from there: `pre-commit` scans staged changes with
`gitleaks protect --staged -v`, and `commit-msg` enforces the scoped commit
standard in [`git/commit-style.md`](../git/commit-style.md):
`<scope>: <description>`, where the scope names a path in the repository, for
every author, human or agent. The standard lives in that file; the hook prints
it with every rejection. [`AGENTS.md`](../AGENTS.md) directs agents to read it
and includes a short subject-format summary for T3's commit button, which does
not expand links. [`CLAUDE.md`](../CLAUDE.md) imports `AGENTS.md`. Before commits
that affect credential-adjacent config, also run:

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
| Harness-native auth/config (`~/.codex`, OpenCode local override) | Credentials, provider settings, permissions, account and conversation state |
| `opencode/opencode.json` | Provider configuration and API credentials |
| `github-copilot/` | OAuth and Copilot state |
| `~/.wakatime.cfg` | WakaTime API key |
| `raycast/` | Downloaded extensions and app data |
| `legcord/` except `storage/settings.json` | Discord session, caches, and window state (Linux Legcord writes them into this directory) |
| `herdr/*.sock`, logs, sessions, `.plugins.lock` | Runtime state |
| `~/.local/share/mise/`, `~/.local/state/mise/`, mise's cache | Installed runtimes, shims, trust records, and downloads; `mise install` recreates them from `mise/mise.toml` |
| `~/.rustup/`, `~/.cargo/` | Rust toolchains, downloaded crates, and build caches; `bin/bootstrap` installs them with the official rustup installer rather than copying them from a clone |
| `~/.ssh/`, `~/.docker/`, `~/.orbstack/` | Keys, credential-store selection, and local runtime settings |
