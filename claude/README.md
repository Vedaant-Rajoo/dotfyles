# Native Claude configuration

`~/.claude` remains a symlink to this directory, preserving existing runtime
state. `settings.json` keeps native model selection, permissions, and hook
behavior. Ponytail is enabled through Claude's native plugin manager; the other
listed plugins remain disabled. Theme and onboarding preferences are retained.

Inference uses Claude Code's native authentication through Caveman's local
compression proxy. Sign in with `claude auth login`; `claude auth status` reports
the active authentication method. No router API key is stored in settings.

Caveman owns its generated hooks and endpoint override; RTK owns its Bash hook
and `RTK.md` import. Run their native installers after bootstrap to regenerate
machine-specific paths; see [the setup commands](../docs/setup.md#ai-harness-routing).
The Rex session-start hook remains independent.

Shared skills are restored separately by `bin/agent-skills`; see
[agent skills](../docs/setup.md#agent-skills). Bootstrap does not install
shared harness rules, generated subagents, custom hooks, or a status line.

Runtime files, plugin installations, sessions, transcripts, and caches remain
ignored. `~/.claude.json` stays at the home root with OAuth and per-project state.
Do not remove account or conversation data to reset routing.

Repository Git hooks remain independent of AI harness hooks. See
[docs/setup.md](../docs/setup.md) and [README.md](../README.md).
