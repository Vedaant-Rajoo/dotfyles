# Native Claude configuration

`~/.claude` remains a symlink to this directory, preserving existing runtime
state. `settings.json` uses native authentication, model selection, permissions,
and hook behavior. Existing plugins are explicitly disabled; theme and onboarding
preferences are retained. No proxy endpoint or API-key helper is configured.

The previous shared rules, skill links, generated subagents, custom hooks,
status line, and proxy integration were archived on 2026-09-28. Bootstrap no
longer recreates them. New integrations must be configured explicitly.

Runtime files, plugin installations, sessions, transcripts, and caches remain
ignored. `~/.claude.json` stays at the home root with OAuth and per-project state.
Do not remove account or conversation data to reset routing.

Repository Git hooks remain independent of AI harness hooks. See
[docs/setup.md](../docs/setup.md) and [README.md](../README.md).
