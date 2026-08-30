# dotfyles

Personal machine configuration for macOS, with Linux as a secondary target. Clone the repository
itself directly to `~/.config`, then run one bootstrap command to install the declared software,
configure Fish, restore pinned runtimes, and connect tracked application settings. [SYSTEM.md](SYSTEM.md)
is a dated audit snapshot (2026-07-28), not a promise that every source-machine detail is portable.

## Quick start (macOS)

A new Mac has no GitHub SSH key yet, so HTTPS is the easiest first step:

```bash
mv ~/.config ~/.config.bak  # optional: preserve an existing config directory
git clone https://github.com/Vedaant-Rajoo/dotfyles.git ~/.config
~/.config/bin/bootstrap

# then, once GitHub authentication is configured, switch the clone to SSH
gh auth login
git -C ~/.config remote set-url origin git@github.com:Vedaant-Rajoo/dotfyles.git
ssh -T git@github.com
```

If SSH already works, clone `git@github.com:Vedaant-Rajoo/dotfyles.git` directly to `~/.config`, then run `~/.config/bin/bootstrap`.

## Bootstrap

```bash
bin/bootstrap --dry-run             # print mutations only
bin/bootstrap --with-defaults       # also apply bin/macdefaults
bin/bootstrap --with-herdr-service  # also start Herdr through brew services
```

`bin/bootstrap` is safe to re-run and moves through five phases:

1. **Prerequisites** — Xcode Command Line Tools and Homebrew.
2. **Packages** — the full [`Brewfile`](Brewfile): formulae, casks, and `mas` App Store entries.
3. **Shell** — Homebrew Fish into `/etc/shells` and as the login shell, then Fisher and the
   [`fish/fish_plugins`](fish/fish_plugins) manifest.
4. **Runtimes** — Node via fnm and Python via pyenv at the pinned [`.node-version`](.node-version) /
   [`.python-version`](.python-version), Rust via the official rustup installer, plus the npm tools
   this config needs, incl. `postplan`.
5. **Wiring** — AI harness config, Legcord settings, the [`dev.newedia.t3-awake`](docs/t3-awake.md)
   LaunchAgent, repo hooks, and the optional `--with-defaults` / `--with-herdr-service` steps.

The App Store must be signed in before `mas` installs entries; after a reported failure, sign in and re-run bootstrap.

## What's included

| Path | Purpose |
|------|---------|
| `Brewfile` | Full Homebrew formula, cask, tap, and Mac App Store manifest |
| `bin/` | 14 executables: bootstrap, linkers, conformance checks, maintenance |
| [`SYSTEM.md`](SYSTEM.md) | Dated snapshot of toolchain provenance and deliberate exceptions |
| [`docs/`](docs/setup.md) | Per-machine setup checklist and the t3-awake design note |
| `launchd/` | LaunchAgent plists installed by `bin/t3_awake` |
| `tests/` | Fish test suites and the shared harness |
| `nvim/` | Neovim Lua config with lazy.nvim and pinned plugins |
| [`fish/`](fish/README.md) | Modular Fish config and the Fisher plugin manifest |
| [`starship.toml`](starship.toml) | Rosé Pine adaptation of Starship's Jetpack preset |
| [`agents/`](agents/README.md) | Canonical cross-harness rules, skills, subagents, hooks |
| [`claude/`](claude/README.md) | Claude-native settings, hooks, statusline, adapters into `agents/` |
| `herdr/` | Herdr workspace manager config; replaces tmux |
| `git/` | Global XDG Git identity, ignore rules, and opt-in repository hooks (secrets, commit style) |
| `opencode/` | Sanitized OpenCode config; provider credentials remain local |
| `legcord/` | Legcord settings, connected by `bin/legcord_link` |
| leaf configs | `bat/`, `gh/`, `ghostty/`, `linearmouse/`, `monid/`, `rectangle-pro/`, `zed/`, `.vscode/` |

## After bootstrap

A clone deliberately carries **no** credentials, account sessions, conversation history, caches,
or application databases. Each step below is written out in [docs/setup.md](docs/setup.md):

- [SSH and GitHub](docs/setup.md#ssh-and-github) — key, `gh auth login`, remote.
- [Git identity](docs/setup.md#git-identity-migration) — retire a shadowing `~/.gitconfig`.
- [Neovim and WakaTime](docs/setup.md#neovim-and-wakatime) — first `nvim` run, `~/.wakatime.cfg`.
- [Postplan](docs/setup.md#html-planning--postplan) — `postplan login`.
- Native app auth — [OpenCode](docs/setup.md#opencode), [Zed](docs/setup.md#zed),
  [Legcord](docs/setup.md#legcord), [OrbStack and Docker](docs/setup.md#orbstack-and-docker),
  [Cursor, Codex, DockDoor, Raycast](docs/setup.md#cursor-codex-dockdoor-and-raycast).

Then verify the wiring: [agents/README.md](agents/README.md) covers `bin/agents_link --check all`
and `bin/agents_conform`, [claude/README.md](claude/README.md) covers `bin/agents_link --check claude`.

## Updating

```bash
cd ~/.config
git pull
bin/u                              # the interactive machine update: nvim, brew, casks
rustup update                      # Rust toolchains; no Brewfile entry owns them
fisher update                      # after fish_plugins changes
brew bundle check --file=Brewfile  # validate the manifest
```

Open Neovim and run `:Lazy sync` after `nvim/lazy-lock.json` changes. Never run `brew bundle install`
merely as a check — it may adopt externally installed applications into Homebrew ownership.

## Tests

Six Fish suites share [`tests/lib/harness.fish`](tests/lib/harness.fish), emit TAP-style lines, and have no aggregate runner; run one with `fish tests/<path>_test.fish`:

```
tests/bin/agents_link_test.fish          tests/bin/u_test.fish
tests/bin/t3_awake_test.fish             tests/git/hooks/commit-msg_test.fish
tests/bin/u-cask-lifecycle_test.fish     tests/fish/conf.d/init-cache_test.fish
```

## Linux

The repository remains useful on Linux, but `bin/bootstrap` intentionally exits rather than pretending
macOS casks, `mas`, `chsh` paths, and `bin/macdefaults` are portable. Tracked Fish and Neovim config
guards most optional commands; the Brewfile itself is Mac-first by design. For Linux:

1. Clone the repository directly to `~/.config`.
2. Install Fish from the distro package manager; make it the login shell.
3. Install compatible Brewfile formulae via Linuxbrew or native packages, skipping casks and `mas`.
4. Install Node with fnm and Python with pyenv at the pinned versions.
5. Run `bin/agents_link all` and `fish -c 'fisher update'`.
6. Replace macOS-only integrations (OrbStack, LinearMouse, DockDoor, `macos-*` Ghostty) with
   Linux equivalents.

## Documentation map

- [docs/setup.md](docs/setup.md) — per-machine manual setup after bootstrap.
- [agents/README.md](agents/README.md) — shared harness rules, skills, and conformance.
- [agents/subagents/README.md](agents/subagents/README.md) — subagent format, translation contract.
- [claude/README.md](claude/README.md) — why this repo *is* `~/.claude`.
- [fish/README.md](fish/README.md) — Fish layout, plugins, and init cache.
- [docs/t3-awake.md](docs/t3-awake.md) — the T3 Code activity wake hold.
- [SYSTEM.md](SYSTEM.md) — dated machine snapshot and deliberate exceptions.
