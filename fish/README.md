# Fish Config

This directory is organized around a thin `config.fish` plus focused `conf.d`
startup modules. For the repository as a whole, see [../README.md](../README.md).

## Layout

- `config.fish`: minimal entrypoint
- `conf.d/`: startup behavior split by concern
- `functions/`: custom autoloaded functions
- `fish_plugins`: curated Fisher plugin manifest — the only tracked record of
  which plugins this config uses

Fisher installs into this directory (`$fisher_path` defaults to
`$__fish_config_dir`), so plugin files sit alongside the hand-written ones and
are gitignored; only `fish_plugins` and the files whitelisted in `.gitignore`
are tracked. `bin/bootstrap` installs Fisher itself when it is missing and then
runs `fisher update`, which reinstalls everything `fish_plugins` lists; run
`fisher update` by hand to do the same later. The whitelist is by filename, so
every new hand-written `conf.d/`, `functions/`, or `completions/` file must be
added to `.gitignore` on purpose or it stays untracked. Beware that Pure owns
`functions/fish_prompt.fish`, `fish_mode_prompt.fish`, and `fish_title.fish` —
they look hand-written but are plugin output. Configure plugins from a
numbered `conf.d/` module instead (`30-fzf.fish`, `60-pure.fish`), which sorts
after the plugin's own `conf.d` file and survives updates.

## Tooling

This setup assumes Homebrew-managed tools when available:

- `fzf`
- `fzf.fish` via Fisher (`conf.d/30-fzf.fish` configures it)
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

## Startup caches

`pyenv init` and `zoxide init` are the two slowest startup calls, so their
output is cached in `~/.cache/fish` (`pyenv-init-<escaped PYENV_ROOT>.fish`,
`zoxide-init.fish`) and regenerated only when the tool's binary is newer than
the cache. A failed regeneration keeps the last good cache. The pyenv cache is
keyed by `PYENV_ROOT` because the generated init hard-codes that root's shim
path, so a shell with a custom root gets its own cache instead of the default
root's Python.

Consequences worth knowing:

- There is no automatic pyenv virtualenv activation and no per-prompt hook.
  Activate manually with `pyenv activate <name>`.
- Shims are not rehashed on startup. Run `pyenv rehash` after pip-installing a
  command-line tool.
- If a cache ever goes stale — say a Homebrew bottle installs with an older
  mtime than the cache — rebuild it with
  `rm ~/.cache/fish/pyenv-init-*.fish ~/.cache/fish/zoxide-init.fish; reload`.
