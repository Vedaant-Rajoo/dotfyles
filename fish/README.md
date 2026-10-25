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
every new hand-written `conf.d/` or `functions/` file must be added to
`.gitignore` on purpose or it stays untracked. `completions/` is ignored
entirely: Homebrew and OrbStack ship their own. Configure plugins from
a numbered `conf.d/` module instead (`30-fzf.fish`), which sorts after the
plugin's own `conf.d` file and survives updates.

The prompt is provided by [Hydro](https://github.com/jorgebucaran/hydro), installed
through Fisher with its default configuration. It shows the working directory,
asynchronous Git status, and command duration without a separate prompt binary.
Background Git fetching is disabled by default.

## Tooling

Command-line tools come from the [Brewfile](../Brewfile) and plugins from
`fish_plugins`. Each module is guarded so Fish still starts cleanly when an
optional tool is missing.

## Runtimes

`conf.d/50-mise.fish` puts mise's shims first on `PATH` in every shell,
interactive or not. Each shim picks the Node or Python version from the
working directory when it runs, so a `cd` takes effect at once, and starting a
shell runs no mise process. The defaults come from
[`mise/mise.toml`](../mise/mise.toml).

`mise activate` is deliberately unused. It takes the shims off `PATH`, so a
project pinning a version that is not installed would quietly run Homebrew's
dependency Node or Python instead of failing. The module also disables the
activation snippet that Homebrew's mise installs into Fish.

Consequences worth knowing:

- There is no per-prompt hook and no automatic virtualenv activation. Activate
  a project's environment with `source .venv/bin/activate.fish`.
- A command-line tool pip-installed into a mise Python appears on `PATH` only
  after `mise reshim`.
- A tool that mise installs for one project, with no default in
  `mise/mise.toml`, fails in every other directory instead of running the
  Homebrew copy. Give it a default with `mise use -g`, which makes mise its
  owner, and retire its Brewfile entry.

## Startup cache

`zoxide init` is the slowest startup call, so its output is cached in
`~/.cache/fish/zoxide-init.fish` and regenerated only when the zoxide binary is
newer than the cache. A failed regeneration keeps the last good cache. If the
cache ever goes stale (say a Homebrew bottle installs with an older mtime than
the cache), rebuild it with `rm ~/.cache/fish/zoxide-init.fish; reload`.
