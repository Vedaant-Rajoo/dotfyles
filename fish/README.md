# Fish Config

This directory is organized around a thin `config.fish` plus focused `conf.d`
startup modules.

## Layout

- `config.fish`: minimal entrypoint
- `conf.d/`: startup behavior split by concern
- `functions/`: custom autoloaded functions
- `fish_plugins`: curated Fisher plugin manifest

## Tooling

This setup assumes Homebrew-managed tools when available:

- `fzf`
- `tide` via Fisher
- `autopair.fish` via Fisher
- `sponge` via Fisher
- `zoxide`
- `fnm`
- `pyenv`
- `pyenv-virtualenv`
- `eza`
- `bat`

Each module is guarded so Fish still starts cleanly when an optional tool is
missing.
