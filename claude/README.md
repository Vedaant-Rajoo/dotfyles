# Native Claude configuration

`~/.claude` remains a symlink to this directory, preserving existing runtime
state. `settings.json` keeps native model selection, permissions, and hook
behavior. Existing plugins are explicitly disabled; theme and onboarding
preferences are retained.

Inference goes through the local Caveman proxy: `ANTHROPIC_BASE_URL` is
`http://127.0.0.1:8787/compat/quotio`, and `apiKeyHelper` reads Quotio's client
key through `bin/quotio-client-key`. See [caveman/README.md](../caveman/README.md).

Shared skills are restored separately by `bin/agent-skills`; see
[agent skills](../docs/setup.md#agent-skills). Bootstrap does not install
shared harness rules, generated subagents, custom hooks, or a status line.

Runtime files, plugin installations, sessions, transcripts, and caches remain
ignored. `~/.claude.json` stays at the home root with OAuth and per-project state.
Do not remove account or conversation data to reset routing.

Repository Git hooks remain independent of AI harness hooks. See
[docs/setup.md](../docs/setup.md) and [README.md](../README.md).
