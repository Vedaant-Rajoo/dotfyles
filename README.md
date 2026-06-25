# dotfyles

Personal `~/.config` for macOS and Unix setups. This repo is the config directory itself — clone it directly to `~/.config` to bootstrap Neovim, Fish, Ghostty, Zed, and LinearMouse on a new machine.

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
| `ghostty/` | [Ghostty](https://ghostty.org/) | Terminal theme, fonts, window settings |
| `zed/` | [Zed](https://zed.dev/) | Editor settings (secrets redacted) |
| `linearmouse/` | [LinearMouse](https://linearmouse.app/) | Per-device pointer and scroll settings |
| `Config.code-workspace` | VS Code / Cursor | Opens this repo as a workspace |

## Prerequisites

**Apps** (install via Homebrew or each project's installer):

- Neovim, Fish, Ghostty, Zed, LinearMouse
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

### Ghostty & LinearMouse

No extra steps. Config is picked up automatically on launch.

## Machine-local & ignored files

These are **not** tracked (see `.gitignore`). Configure or regenerate on each machine:

| Path | Why |
|------|-----|
| `github-copilot/` | OAuth tokens and Copilot app state |
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
