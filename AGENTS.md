# Agent rules

## About the repo

This checkout is the user's system control plane, cloned directly to `~/.config`.
`bin/bootstrap` installs the declared software and connects settings on macOS;
Linux setup is manual. Edits here can change the live system.
Apps and installers also write here; review their diffs for secrets and runtime
state before staging.

## Commit style

Subjects use `<scope>: <description>`: a lowercase path-based scope, an
imperative description starting lowercase, no type prefix or final period,
and at most 72 characters. T3's commit button needs this summary because it
does not expand links. Before writing a commit message, read and follow the
full [commit standard](git/commit-style.md).

## Ownership

Read the [ownership table](README.md#ownership) before changing how anything is
installed, selected, updated, or restored. Give each tool, runtime, and kind of
state one owner. Use that owner's manifest and update path; update the table
when ownership moves.

While this setup runs on one machine, snapshot and clean up retired managed
state directly, preserving user data. Keep the [migration runner](migrations/README.md),
but add migrations only after the user reports a second machine.

mise owns its declared runtimes; rustup owns Rust. Preserve Homebrew's dependency
runtimes. Inventory global npm CLIs before changing ownership; bootstrap's
`NPM_GLOBALS` list is not exhaustive.

## Safety

- Worktrees are drafts. Run machine-changing helpers there only in verified
  dry-run modes or isolated tests. Apply live changes from the main checkout.
- Other sessions share this checkout, index, and branch. Preserve their staged
  and unstaged work. Path-specific commits include every edit in the named files;
  coordinate overlapping changes and branch switches.
- Use a coordinated branch in the main checkout for live trials. Snapshot state
  under `.local/snapshots/` before irreversible changes. Switching branches does
  not restore packages, services, or app data.
- Keep credentials, sessions, history, and caches machine-local. Redact secrets
  from output and reports.
- Whitelist new handwritten files in `claude/`, `fish/conf.d/`, `fish/functions/`,
  `herdr/`, `karabiner/`, and `legcord/` in `.gitignore`. Keep runtime state ignored;
  `tests/gitignore_test.fish` checks this boundary.

## Documentation

Tracked docs explain configuration, package inventory, maintenance, and machine
setup. Keep research, comparisons, plans, machine snapshots, and validation
reports in this repo's ignored `.local/`. A clone does not restore those notes.
Update the relevant existing doc when behavior changes.

## Tests

Test current requirements and observable outcomes, including failures and cleanup.
Use focused checks for nontrivial logic and meaningful bug fixes; trivial edits
need none. Extend existing suites and `tests/lib/harness.fish`. Avoid assertions
that merely mirror implementation or preserve accidental quirks. Verify that a
regression test fails when the behavior is broken.

Use a temporary `HOME`, copied config, and isolated state paths (including `XDG_*`).
Stub commands that affect live packages, apps, or services, and close stdin.
Start Fish mocks with
`--no-config`; load configuration deliberately when testing startup behavior.

Run relevant suites with `tests/run tests/<path>_test.fish ...`. Report what
passed, what only mocks covered, and what ran live.

## Agent universe

Shared skills live in `~/.agents/skills`. The skills CLI owns the upstream
inventory in `agents/skill-lock.json`; Ardia owns `ardia` and `cua-driver`.
Use `bin/agent-skills` and the [skill setup instructions](docs/setup.md#agent-skills)
for installs, links, and updates. Updates can replace installed skill files;
keep durable customizations in an owned source with a supported update path.
Built-in and plugin skills retain their native owners.

Harnesses use their native providers and authentication. Harnesses own
instruction loading, permissions, and hooks. T3 coordinates sessions and delegates.
Give delegated work a narrow scope and checkable result; isolate independent
writers in worktrees or assign one writer per file.

## Bin helpers

Reuse `bin/` helpers: `bootstrap` installs the declared setup, `u [section ...]`
updates selected parts, `migrate` applies pending migrations, and `agent-skills`
maintains shared skills. Read a script's usage before running it; dry-run support
varies. Check packages with `brew bundle check --file=Brewfile`; never use
`brew bundle install` as a check, because it can adopt apps into Homebrew ownership.
Unreferenced helpers may still be used manually; verify usage before proposing
deletion.

## Fish, Ghostty, and Herdr

Read [fish/README.md](fish/README.md) before changing shell startup, plugins, or
runtime selection. Keep startup modules in `fish/conf.d/`, helpers in
`fish/functions/`, and mise shims available in every shell. Configure Fisher
plugins through handwritten modules; leave installed plugin files to Fisher.

Ghostty is the terminal; Herdr manages workspaces. Keep `bin/herdr-sessionizer`
and its bindings in Fish, `ghostty/config`, and `herdr/config.toml` consistent.
Herdr pane commands inherit a minimal service environment; use login Fish when
they need its environment. Restarting Herdr can terminate active pane work.
