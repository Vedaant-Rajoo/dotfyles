# dotfyles

Personal `~/.config` for macOS and Unix setups. This repo is the config directory itself — clone it directly to `~/.config` to bootstrap Neovim, Fish, Ghostty, Herdr, Zed, and LinearMouse on a new machine.

## Quick start

Back up any existing config, then clone:

```bash
mv ~/.config ~/.config.bak   # optional
git clone <repo-url> ~/.config
```

Install the apps below, then finish per-app setup in [Post-install](#post-install).

## What's included

| Path | App | Notes |
|------|-----|-------|
| `nvim/` | [Neovim](https://neovim.io/) | Lua config with [lazy.nvim](https://github.com/folke/lazy.nvim); plugins pinned in `lazy-lock.json` |
| `fish/` | [Fish](https://fishshell.com/) | Modular `conf.d/` layout, Fisher plugins — see [fish/README.md](fish/README.md) |
| `claude/` | [Claude Code](https://claude.com/claude-code) | Sanitized copy of `~/.claude` config, symlinked back in — see [Post-install](#claude-code) |
| `ghostty/` | [Ghostty](https://ghostty.org/) | Terminal theme, fonts, window settings |
| `herdr/` | [Herdr](https://herdr.dev) | Terminal workspace manager (replaces tmux); sessionizer bound to Ctrl-o in Fish and cmd+s in Ghostty via `bin/herdr-sessionizer` |
| `zed/` | [Zed](https://zed.dev/) | Editor settings (secrets redacted) |
| `linearmouse/` | [LinearMouse](https://linearmouse.app/) | Per-device pointer and scroll settings |
| `Config.code-workspace` | VS Code / Cursor | Opens this repo as a workspace |

## Prerequisites

**Apps** (install via Homebrew or each project's installer):

- Neovim, Fish, Ghostty, Herdr, Zed, LinearMouse
- `git` (required for lazy.nvim bootstrap and Fisher)

**CLI tools** (used by Fish; optional modules skip cleanly if missing):

- `fzf`, `zoxide`, `fnm`, `pyenv`, `pyenv-virtualenv`, `eza`, `bat`

**Fonts** (Ghostty): JetBrainsMono Nerd Font

## Post-install

### Neovim

Open Neovim once. lazy.nvim clones itself on first launch, then installs plugins from `lazy-lock.json`:

```bash
nvim
```

Inside Neovim: `:Lazy sync` to verify or update plugins.

### Fish

Install [Fisher](https://github.com/jorgebucaran/fisher), then install plugins from the manifest:

```bash
fisher update
```

See [fish/README.md](fish/README.md) for layout, tooling, and module details.

### Zed

Set machine-local values in `zed/settings.json` after clone — at minimum:

- `context_servers.mcp-server-context7.settings.context7_api_key` — Context7 API key (committed as `""`)

Sign in to GitHub Copilot inside Zed for edit predictions (`edit_predictions.provider` is `copilot`).

### Claude Code

Run `bin/claude_link` once after cloning. It symlinks `~/.claude/CLAUDE.md`, `~/.claude/skills`, and `~/.claude/statusline-command.sh` to their counterparts under `claude/`, seeds `~/.claude/settings.local.json` from `claude/settings.local.json.example` if needed, and materializes `~/.claude/settings.json` as a regular file.

`claude/settings.json` intentionally omits the top-level `env` block. Put the CLIProxyAPI auth token, base URL, and default-model vars in machine-local `~/.claude/settings.local.json` (see the example). `claude_link` merges that `env` into live `~/.claude/settings.json`, which is what Claude Code actually injects on every launch — including SDK/IDE and background agents. Mirror the same exports in [`fish/local/claude-code.fish`](#machine-local--ignored-files) for shell tools and scripts; Fish loads that file for interactive and non-interactive sessions.

For the symlinked files, editing either `~/.claude/...` or `claude/...` edits the same file — run `git diff` from the repo root to see what changed before committing. After editing `settings.local.json` or if Claude Code rewrites `settings.json`, re-run `bin/claude_link` (and use `bin/claude_link --check` to verify).

`~/.claude` holds substantially more private state than what's mirrored here — conversation transcripts, telemetry, OAuth/account data, session history — and none of that broader state is meant to ever enter this repo (see the ignore rules in `.gitignore` and `git/ignore`).

### Git hooks (secret scanning)

This repo ships a `gitleaks`-based pre-commit hook in `git/hooks/pre-commit`, but hooks are opt-in — nothing here applies itself automatically. Enable it once per clone:

```bash
git config core.hooksPath git/hooks
```

Before the first commit that touches `claude/`, it's also worth running an independent one-off check:

```bash
gitleaks detect --source . -v
```

### Ghostty & LinearMouse

No extra steps. Config is picked up automatically on launch.

## Machine-local & ignored files

These are **not** tracked (see `.gitignore`). Configure or regenerate on each machine:

| Path | Why |
|------|-----|
| `github-copilot/` | OAuth tokens and Copilot app state |
| `fish/local/` | Machine-local Fish secrets (e.g. Claude Code / CLIProxyAPI auth) |
| `claude/settings.local.json` | Local Claude Code `env` (CLIProxyAPI) + permission allow-list, generated from `claude/settings.local.json.example` |
| `fish/fish_variables` | Universal variables (Fish writes this at runtime) |
| `nvim/tmp/` | Neovim session / plugin temp state |
| `zed/prompts/` | Zed prompt library database (regenerated at runtime) |
| `raycast-x/extensions/` | Downloaded Raycast extension bundles |
| `*-backup*/`, `.codex-backup*/` | Local backup dirs |
| `node_modules/`, `*.log`, `.cache/` | Build artifacts and caches |

`github-copilot/` and Raycast data live under `~/.config` but stay local — do not commit them.

## Updating

```bash
cd ~/.config
git pull
```

After pulling Fish plugin changes: `fisher update`

After pulling Neovim lockfile changes: open Neovim and run `:Lazy sync`
