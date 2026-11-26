# Native Claude configuration

`~/.claude` remains a symlink to this directory, preserving existing runtime
state. `settings.json` keeps native model selection, permissions, and hook
behavior. Existing plugins are explicitly disabled; theme and onboarding
preferences are retained.

Inference uses Claude Code's native provider and authentication. Sign in with
`claude auth login`; `claude auth status` reports the active authentication method.

Shared skills are restored separately by `bin/agent-skills`; see
[agent skills](../docs/setup.md#agent-skills). Bootstrap does not install
shared harness rules, generated subagents, custom hooks, or a status line.

Runtime files, plugin installations, sessions, transcripts, and caches remain
ignored. `~/.claude.json` stays at the home root with OAuth and per-project state.
Do not remove account or conversation data to reset routing.

Repository Git hooks remain independent of AI harness hooks. See
[docs/setup.md](../docs/setup.md) and [README.md](../README.md).
