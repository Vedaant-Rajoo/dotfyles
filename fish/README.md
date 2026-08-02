# Fish Config

This directory is organized around a thin `config.fish` plus focused `conf.d`
startup modules.

## Layout

- `config.fish`: minimal entrypoint
- `conf.d/`: startup behavior split by concern
- `functions/`: custom autoloaded functions
- `fish_plugins`: curated Fisher plugin manifest — the only tracked record of
  which plugins this config uses

Fisher installs into this directory (`$fisher_path` defaults to
`$__fish_config_dir`), so plugin files sit alongside the hand-written ones and
are gitignored; only `fish_plugins` and the files whitelisted in `.gitignore`
are tracked. Run `fisher update` to reinstall them. Beware that Pure owns
`functions/fish_prompt.fish`, `fish_mode_prompt.fish`, and `fish_title.fish` —
they look hand-written but are plugin output. Configure plugins from a
numbered `conf.d/` module instead (`30-fzf.fish`, `60-pure.fish`), which sorts
after the plugin's own `conf.d` file and survives updates.

## Tooling

This setup assumes Homebrew-managed tools when available:

- `fzf`
- `pure` via Fisher
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
