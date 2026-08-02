# Claude Code owns ~/.claude, so this repo *is* ~/.claude

`~/.claude` is a symlink to this directory. That inversion is deliberate. Claude
Code rewrites its own `settings.json` — it once dropped every hook, permission,
and statusline entry this repo had configured while adding six plugins of its
own — so a tracked file that is merely *copied outward* rots silently and the
live file always wins. Pointing Claude at the working tree makes the live file
the tracked file: anything it rewrites shows up in `git diff`, which is the only
thing that keeps it honest.

## Credentials

Credentials still never enter the repository. `claude/settings.json` carries an
`apiKeyHelper` command rather than a token; `claude/api-key-helper.sh` is
tracked and reads `claude/auth-token`, which is gitignored and mode `600`. The
base URL is a localhost proxy and the model ids are not secrets, so those stay
tracked in `env`. `claude_link --check` fails hard if a literal
`ANTHROPIC_AUTH_TOKEN` ever appears in the tracked settings.

## Runtime state

Everything Claude writes at runtime — `sessions/`, `projects/`,
`history.jsonl`, `shell-snapshots/`, `plugins/`, `security/`, caches — lands in
the working tree and is gitignored, so `git status` stays clean while ~340 MB of
state sits beside the few tracked files. `~/.claude.json` is **not** part of
this: it stays at the home root, holding OAuth and per-project state.

## Linking

```bash
bin/claude_link            # ensure the symlink and seed claude/auth-token
bin/claude_link --check    # symlink, settings, helper, and token status
bin/claude_link --migrate  # fold a pre-existing real ~/.claude in, backup first
```

`--migrate` clones `~/.claude` to `~/.claude.pre-migrate-backup` (an APFS clone,
so it is near-instant and nearly free), moves everything the repo does not
already track into `claude/`, drops its own stale per-file links, and lets the
repo copy win every collision. Remove the backup once you are satisfied.

`CLAUDE_CONFIG_DIR` would also relocate the directory and is the officially
documented mechanism, but it depends on the environment being set — any launch
that does not inherit it silently falls back to a fresh `~/.claude`. The symlink
has no such failure mode. (Note that on this build `CLAUDE_CONFIG_DIR` also
relocates `~/.claude.json`, which the published docs say it does not.)

Authentication, provider settings, sessions, transcripts, caches, and model
selection remain native and machine-local for every harness. The bootstrap still
installs Claude Code with Anthropic's native self-updating installer when
`claude` is missing.

## Generated and tested parts

`claude/agents/` is **generated** from the canonical sources in
[`agents/subagents/`](../agents/subagents/README.md) by `bin/agents_link all`;
it is untracked, and edits belong in the source files. `CLAUDE.md` and `skills/`
are symlinks into `agents/`, so shared rules and skills are the same bytes here
as in every other harness.

Tests for the tracked hooks live under `tests/claude/hooks/` and run as Fish
test files, for example:

```bash
fish tests/claude/hooks/commit-msg-guard_test.fish
```

---

Back to [the repository overview](../README.md); the shared harness architecture
is in [agents/README.md](../agents/README.md), and the machine inventory in
[SYSTEM.md](../SYSTEM.md).
