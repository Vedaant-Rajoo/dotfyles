# dotfyles

Personal machine configuration for macOS, with Linux as a secondary target. Clone the repository
itself directly to `~/.config`, then run one bootstrap command to install the declared software,
configure Fish, restore pinned runtimes, and connect tracked application settings.

## Purpose

1. **Control plane.** The checkout at `~/.config` is the one place where this system's
   configuration is declared and changed.
2. **Reproduction.** A new Mac reaches the same state with `bin/bootstrap`. Linux uses the same
   configuration files through the [manual steps](#linux).
3. **Ownership.** Packages, applications, runtime versions, project environments, and plugins
   each have one declared owner, listed under [Ownership](#ownership).
4. **Small scripts.** `bin/` holds short scripts that automate repeated work and run directly
   from the checkout.
5. **Agent universe.** The configured AI harnesses, their shared skills, and their routing are
   restored from here. Credentials, sessions, and conversation history stay on each machine.

Tracked documentation explains configuration, maintenance, and setup on a new machine.
Keep personal research, comparisons, design drafts, machine snapshots, and one-off
verification reports in the gitignored `.local/` directory.

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
4. **Runtimes** — the language runtimes in [`mise/mise.toml`](mise/mise.toml) via mise, Rust via
   the official rustup installer, plus the npm tools this config needs, including pinned `postplan`.
5. **Wiring** — native Claude installation, the shared agent skills listed in
   [`agents/skill-lock.json`](agents/skill-lock.json), Legcord settings, the [`dev.newedia.t3-awake`](docs/t3-awake.md)
   LaunchAgent, repo hooks, pending [migrations](migrations/README.md), and the optional
   `--with-defaults` / `--with-herdr-service` steps.

The App Store must be signed in before `mas` installs entries; after a reported failure, sign in and re-run bootstrap.

## What's included

| Path | Purpose |
|------|---------|
| `Brewfile` | Full Homebrew formula, cask, tap, and Mac App Store manifest |
| `agents/` | Install list of the shared agent skills, restored and updated by `bin/agent-skills` |
| `bin/` | Bootstrap, application linkers, and maintenance tools |
| [`docs/`](docs/setup.md) | Per-machine setup checklist and the t3-awake operating guide |
| `launchd/` | LaunchAgent plists installed by `bin/t3_awake` |
| `migrations/` | One-time scripts that bring an existing machine in line, run by `bin/migrate` |
| `mise/` | Global mise config: the default language runtimes, and how projects override them |
| `tests/` | Fish test suites and the shared harness |
| `nvim/` | Neovim Lua config with lazy.nvim and pinned plugins |
| [`fish/`](fish/README.md) | Modular Fish config and the Fisher plugin manifest |
| [`claude/`](claude/README.md) | Claude settings routed through Caveman; private runtime state is ignored |
| [`caveman/`](caveman/README.md) | Caveman compression proxy: config, launch agent, local patch, verification |
| [`quotio/`](quotio/README.md) | Quotio routing and prompt-rule notes |
| `herdr/` | Herdr workspace manager config; replaces tmux |
| `git/` | Global XDG Git identity, ignore rules, repository hooks (secrets, commit style), and the [commit standard](git/commit-style.md) |
| `opencode/` | Sanitized OpenCode config; provider credentials remain local |
| `legcord/` | Legcord settings, connected by `bin/legcord_link` |
| leaf configs | `bat/`, `gh/`, `ghostty/`, `linearmouse/`, `rectangle-pro/` |

## Ownership

| State | Owner | Declared in | Updated by |
|-------|-------|-------------|------------|
| CLI tools, libraries, apps, fonts | Homebrew | `Brewfile` | `bin/u` |
| Mac App Store apps | mas | `Brewfile` | `bin/u` |
| Default Node, Python, Bun, Go, pnpm | mise | `mise/mise.toml`, as release lines | `bin/u` (`mise install`, `mise upgrade`) |
| A project's runtime versions | the project | its `mise.toml`, `.nvmrc`, `.node-version`, or `.python-version` | the project |
| Rust toolchains | rustup | `bin/bootstrap` installs the stable toolchain | `bin/u` |
| Global npm CLIs | npm, prefix `~/.node_modules` | `NPM_GLOBALS` in `bin/bootstrap` | `bin/u` |
| Project dependencies, including prettier | npm, pnpm, Bun, pip, Cargo, CocoaPods, LuaRocks | each project's manifest and lockfile | the project |
| Fish plugins | Fisher | `fish/fish_plugins` | `bin/u` |
| Neovim plugins | lazy.nvim | `nvim/lazy-lock.json` | `bin/u` |
| Neovim language servers | Mason | `nvim/lua/newedia/lazy/lsp.lua` | `bin/u` refreshes the registry; `:Mason` updates packages |
| Shared agent skills | skills CLI, through `bin/agent-skills` | `agents/skill-lock.json` | `bin/u` |
| Running apps during cask upgrades | `bin/u` | | quits them with consent, upgrades, reopens them |
| Leftovers of retired setups on existing machines | `bin/migrate` | `migrations/` | `bin/bootstrap`, `bin/u` |
| Credentials, sessions, caches | each machine | not tracked | |

Homebrew also installs its own Go, Python, and Ruby as dependencies of gofumpt and goimports,
black and ykman, and CocoaPods. They belong to those formulae; mise's shims come first on `PATH`,
so `go` and `python3` still resolve to mise. A machine can carry more global npm CLIs
than `NPM_GLOBALS` restores; add one there before relying on it on a new machine.

## After bootstrap

A clone deliberately carries **no** credentials, account sessions, conversation history, caches,
or application databases. Each step below is written out in [docs/setup.md](docs/setup.md):

- [SSH and GitHub](docs/setup.md#ssh-and-github) — key, `gh auth login`, remote.
- [Git identity](docs/setup.md#git-identity-migration) — retire a shadowing `~/.gitconfig`.
- [Neovim and WakaTime](docs/setup.md#neovim-and-wakatime) — first `nvim` run, `~/.wakatime.cfg`.
- [Postplan](docs/setup.md#postplan) — optional `postplan login`.
- [AI harness routing](docs/setup.md#ai-harness-routing) — Quotio accounts and the Caveman proxy.
- Native app auth — [OpenCode](docs/setup.md#opencode),
  [Legcord](docs/setup.md#legcord), [OrbStack and Docker](docs/setup.md#orbstack-and-docker),
  [Cursor, Codex, DockDoor, Raycast](docs/setup.md#cursor-codex-dockdoor-and-raycast).

Codex, Claude Code and OpenCode route inference through the local Caveman proxy to Quotio.
Bootstrap installs Quotio but not Caveman; see [caveman/README.md](caveman/README.md#fresh-machine).
Shared skills are restored through `bin/agent-skills`; see [agent skills](docs/setup.md#agent-skills).
Bootstrap does not project shared rules, subagents, or harness hooks. Two agent instruction files apply
to work in this repository: the repo-root `AGENTS.md`, a link to the [commit standard](git/commit-style.md)
that T3's commit button reads, and [`CLAUDE.md`](CLAUDE.md), the working rules for this repository.
Claude Code reads only `CLAUDE.md`, which imports the commit standard; Codex and OpenCode read
only `AGENTS.md`.

## Updating

```bash
cd ~/.config
git pull
bin/u                              # the interactive machine update: nvim, brew, casks, mas, mise, migrations, rustup, npm, agent skills, fisher
rustup update                      # Rust toolchains; no Brewfile entry owns them
fisher update                      # after fish_plugins changes
brew bundle check --file=Brewfile  # validate the manifest
```

Open Neovim and run `:Lazy sync` after `nvim/lazy-lock.json` changes. Never run `brew bundle install`
merely as a check — it may adopt externally installed applications into Homebrew ownership.

## Tests

The tests guard behavior that a person relies on: which runtime answers in which shell and
directory, what a bootstrap dry run may touch, that an interrupted update still reopens the
applications it closed, which harnesses receive skills, and what stays out of commits. Each suite
runs the real scripts against a sandboxed home and stub commands, so it leaves the machine as it
was. [`CLAUDE.md`](CLAUDE.md#tests) holds the rules for adding checks.

The suites print one TAP-style line per check and have no aggregate runner. Run one with
`fish tests/<path>_test.fish`:

```
tests/bin/bootstrap_test.fish            tests/fish/conf.d/runtime-selection_test.fish
tests/bin/u_test.fish                    tests/fish/conf.d/init-cache_test.fish
tests/bin/u-cask-lifecycle_test.fish     tests/git/hooks/commit-msg_test.fish
tests/bin/agent-skills_test.fish         tests/gitignore_test.fish
tests/bin/t3_awake_test.fish             tests/bin/migrate_test.fish
```

`runtime-selection` needs mise on `PATH`, or `MISE_TEST_BIN` set to a mise binary.
`u-cask-lifecycle` and `t3_awake` exercise macOS services. So far every suite has run on macOS
only.

## Linux

The repository remains useful on Linux, but `bin/bootstrap` intentionally exits rather than pretending
macOS casks, `mas`, `chsh` paths, and `bin/macdefaults` are portable. Tracked Fish and Neovim config
guards most optional commands; the Brewfile itself is Mac-first by design. For Linux:

1. Clone the repository directly to `~/.config`.
2. Install Fish from the distro package manager; make it the login shell.
3. Install compatible Brewfile formulae via Linuxbrew or native packages, skipping casks and `mas`.
4. Install mise from the distro or [mise.jdx.dev](https://mise.jdx.dev), then run `mise install`
   from `~` to install the default runtimes from `mise/mise.toml`. Fish puts mise's shims on `PATH`
   the same way on Linux.
5. Run `fish -c 'fisher update'` and authenticate each AI harness natively.
6. Replace macOS-only integrations (OrbStack, LinearMouse, DockDoor, `macos-*` Ghostty) with
   Linux equivalents.
7. `bin/u` is macOS-only. After `git pull`, run `mise install && mise upgrade` from `~`, then
   `bin/migrate`.

## Documentation map

- [docs/setup.md](docs/setup.md) — per-machine manual setup after bootstrap.
- [CLAUDE.md](CLAUDE.md) — working rules for agents changing this repository.
- [claude/README.md](claude/README.md) — why this repo *is* `~/.claude`.
- [fish/README.md](fish/README.md) — Fish layout, plugins, and init cache.
- [docs/t3-awake.md](docs/t3-awake.md) — the T3 Code activity wake hold.
