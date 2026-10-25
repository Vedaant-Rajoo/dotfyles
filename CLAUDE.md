# Working in this repository

This checkout becomes `~/.config` on every machine, so it is the system's control
plane. [README.md#purpose](README.md#purpose) says what the repository is for, and
[README.md#ownership](README.md#ownership) names the single owner of each kind of
state. Read both before changing how anything is installed, selected, updated, or
restored.

Claude Code loads this file instead of `AGENTS.md`, so the commit standard is
imported below; `AGENTS.md` stays a link to the same file for other harnesses and
T3's commit button, and the commit-msg hook enforces it.

@git/commit-style.md

## Ownership

- Give every tool, runtime, and piece of state exactly one owner, and update the
  ownership table in the same change that moves one.
- mise owns the language runtimes that `mise/mise.toml` declares. Rust stays
  with rustup, which already reads each project's `rust-toolchain.toml`. To give
  mise a tool, find its registry shorthand with `mise registry <name>`, declare
  a release line in `mise/mise.toml`, and retire its Brewfile entry; the
  runtime-selection test covers every declared tool.
- Homebrew's own Go, Python, and Ruby serve its formulae (gofumpt and goimports,
  black and ykman, CocoaPods); leave them installed.
- A machine's global npm CLIs can outnumber `NPM_GLOBALS` in `bin/bootstrap`.
  Account for every installed one before changing how they are installed.

## Safety

- A worktree is a draft, not the live configuration. From a worktree, run
  `bin/bootstrap --dry-run` at most, and test against a sandboxed `HOME`, leaving
  the machine's packages, runtimes, and applications as they are.
- When a change leaves state on existing machines that the new configuration no
  longer owns, such as a retired formula, add a migration; read
  [migrations/README.md](migrations/README.md) first.
- Credentials, sessions, conversation history, and caches stay machine-local.
  A new hand-written file under `claude/` or `fish/` needs its own `.gitignore`
  whitelist entry; `tests/gitignore_test.fish` holds that boundary.

## Documentation

Tracked docs cover configuration, package inventory, maintenance, and new-machine
setup. Research, comparisons, design drafts, machine snapshots, and validation
reports go in the ignored `.local/`.

## Tests

A test guards a contract: an outcome a person relies on, observed from outside
the script. A good check goes red when that behavior drifts.

- Assert what a user would notice: the version a shell selects, the files a run
  leaves behind, the exit status after a failure or an interrupt, the commands a
  stub records, the state restored afterwards.
- Run real scripts against a sandbox: a temporary `HOME`, copies of the config,
  stub commands first on `PATH`, stdin closed. The machine stays untouched.
- Before keeping a new check, break the behavior once and watch the check go red.
- Decide whether existing behavior is intended before pinning it. Fix a quirk or
  leave it unasserted; a test makes whatever it asserts permanent.
- Leave construction unasserted: function names, source text, and call counts or
  exit codes that only mirror how the code happens to be written.
- Extend the existing suites and `tests/lib/harness.fish`; small fixtures beat a
  framework.
- Run the suites covering the change, and report which ran on which platform.
