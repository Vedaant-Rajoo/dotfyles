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

Codex, Claude Code, OpenCode, and Antigravity keep their native authentication.
Bootstrap installs Claude Code and Caveman's npm CLI; the Brewfile installs
Codex, OpenCode, and RTK. 9router and its T3 quota feed are retired.

Sign in with `codex login`, `claude auth login`, and `opencode auth login`.
Antigravity uses its own Google sign-in flow, including when launched through
T3. T3's Codex and Claude providers load their native harness settings.
Restart existing harness sessions after changing provider settings or hooks.

### Caveman

The independently installed Caveman proxy compresses eligible context locally
while the harness keeps its own provider login. Configure the native integrations
from Bash or Zsh after bootstrap:

```bash
caveman setup --yes --only input,output --agents claude,codex
caveman tools config set think.shrink false
```

The second command leaves command rewriting to RTK; Caveman's proxy remains in
compression mode. Automatic model routing, cache warming, scripts, and browser
modules stay off. Caveman owns the generated hooks, MCP recovery tools, and
machine-specific paths. Its binaries, config, journals, request history, and
recovery data stay under `~/.caveman/`, outside Git.

Codex and Claude use the proxy at `127.0.0.1:8787` with their native subscription
credentials. OpenCode's OpenAI, Anthropic, and OpenCode Go provider entries point
there too; its default free provider goes directly to OpenCode. Provider and
model choice remain with each harness. Antigravity stays on Google's native
endpoint and uses Caveman through local MCP tools, as described below.

Caveman CLI 4.2.0 writes OpenCode 1 config keys, and its OpenCode native plugin
rewrites shell commands even with `think.shrink` disabled. Leave that plugin
uninstalled so RTK owns shell rewriting. If already installed, snapshot the
configuration and run `caveman disable opencode`. This checkout owns the OpenCode
V2 proxy routes and recovery MCP in `opencode/opencode.jsonc`; verify they survive
disable with `opencode debug config`. Caveman's status intentionally reports
OpenCode as not wired. Do not run `caveman enable opencode` or its doctor repair
until upstream fixes these conflicts.

OpenCode can use the same running proxy as Codex and Claude. If launching it on
its own with a proxied provider, first run `caveman start` in another terminal.
Its free default provider needs no proxy. OpenCode gets Ponytail instructions;
Caveman's native lifecycle instructions are limited to Codex and Claude.

Check `caveman status`, `caveman doctor codex`, and `caveman doctor claude`.
In Codex, open `/hooks` and review/trust the installed hooks, then start a new
session. The native hooks start the local proxy when needed. A configured proxy
must be running for inference; it does not silently fall back to a direct route.
`caveman tools stats --plain` reports measurements; successful requests alone do
not establish token savings.

Use `bin/u npm` to update the CLI and `caveman setup --install` to refresh its
companion binaries. Recheck native integration compatibility after updates.
To return to direct providers, run `caveman disable claude` and
`caveman disable codex`, then check the native configs and restart sessions.
For OpenCode V2, remove the Caveman `baseURL` overrides and
`mcp.servers.caveman` from its config.
Keep login and conversation data. Switching Git branches alone cannot undo
package, service, or machine-local configuration changes.

### Ponytail

Install Ponytail through each harness's own plugin manager:

```bash
claude plugin marketplace add DietrichGebert/ponytail
claude plugin install ponytail@ponytail
codex plugin marketplace add DietrichGebert/ponytail
codex plugin add ponytail@ponytail
opencode plugin add @dietrichgebert/ponytail
```

Restart sessions and review/trust Ponytail's Codex hooks through `/hooks`.
Plugin caches and `~/.config/ponytail/` state stay machine-local. Update through
native plugin managers; these plugins are separate from `agents/skill-lock.json`.

### RTK

Homebrew owns the RTK binary. RTK installs its native command hooks and instruction
imports, preserving unrelated hooks:

```bash
rtk init -g --opencode --auto-patch --no-trust-filters
rtk init -g --codex --no-trust-filters
```

The first command covers Claude and OpenCode. Restart all three harnesses and
review/trust the Codex hook. Run `git status` in a session to check rewriting.
Re-run these commands after RTK updates to refresh its generated integrations.
No shared instruction generator or additional router is needed.

### Antigravity

Antigravity supports Ponytail's skills, RTK's native command hook, and Caveman's
local compression/recovery MCP. Caveman CLI 4.2.0 has no Antigravity proxy adapter;
leave Google's native authentication and endpoint in place.

```bash
agy plugin install https://github.com/DietrichGebert/ponytail
rtk init -g --agent antigravity --no-trust-filters
agy mcp add caveman "$HOME/.caveman/bin/caveman-mcp"
agy plugin list
agy mcp list
```

Restart Antigravity after installation. Invoke `/ponytail` for its coding rules;
its Antigravity package supplies skills rather than the persistent lifecycle
mode used by Codex and Claude. RTK rewrites supported commands automatically.
Caveman compression here is an explicit MCP tool call, not an inference proxy.
The harness still applies its normal tool permissions.

T3 gives each Antigravity provider instance a private Gemini home under
`~/.t3/userdata/providers/antigravity/`. It shares global skills and rules but
isolates plugins, hooks, and MCP. In the chosen profile's `config/plugins.json`,
use the native customization manifest to select the two global plugin installs:

```json
{
  "entries": [
    {
      "path": "~/.gemini/config/plugins",
      "include_only": ["ponytail", "rtk"]
    }
  ]
}
```

Merge the Caveman server entry generated by `agy mcp add` into that profile's
`config/mcp_config.json`, preserving other servers. Snapshot existing config
first. These files remain machine-local; keep T3's profile authentication and
runtime permissions under T3's ownership. Start a new T3 Antigravity session
after changing them. Plugin updates use `agy`; regenerate RTK's plugin with its
init command after updating the Homebrew binary.

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
`opencode/opencode.jsonc` keeps the default model, adds Ponytail, and configures
the Caveman routes and recovery MCP described above.
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
| `opencode/plugins/`, `ponytail/` | Native installers own the generated plugins and plugin runtime state |
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
