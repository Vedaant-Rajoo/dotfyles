# Caveman deployment

Deployed on 2026-09-29 after checkpoint commit `a543f2d`.
Codex, Claude Code and OpenCode now send inference through Caveman on
`127.0.0.1:8787`, which forwards to Quotio's CLIProxyAPI on `127.0.0.1:8317`.
Quotio still manages provider accounts and the native Ponytail/Caveman prompt
rules. Provider model IDs and client-key helpers are unchanged.

## Runtime and configuration

- Runtime: official Caveman `bin-v1.1.7` macOS ARM64 proxy and MCP binaries,
  installed in `~/.local/share/caveman/bin-v1.1.7`. SHA-256 verification matches
  the [feasibility report](../quotio/caveman-proxy-feasibility.md). Since
  2026-09-29 the service runs a locally patched proxy from
  `~/.local/share/caveman/bin-v1.1.7-models.1`; see [Local patch](#local-patch).
  All harnesses still use the official `caveman-mcp`.
- Configuration: [caveman.yaml](caveman.yaml).
- Service: `local.caveman.proxy`, loaded from the launch-agent symlink
  `~/Library/LaunchAgents/local.caveman.proxy.plist`. It starts at login and
  restarts after an unexpected exit.
- State: `~/.local/state/caveman`. `ccr.db` holds original compressed content;
  `caveman.db` holds measurements and stable replacements. Keep recovery state
  while conversations refer to it. Do not move live SQLite databases.
- Readiness: `http://127.0.0.1:8787/health/ready`.
- Quotas and management UI remain at CLIProxyAPI, port 8317.

The service uses `CAVEMAN_RECOVERY=mcp`. Codex 0.158.0 uses Responses Lite and
places tools in `input[].additional_tools`; this Caveman release only detects
recovery tools in top-level `tools`. Explicit recovery mode is therefore needed
for native Codex compression. All three configured harnesses share the same MCP
recovery database. Clients without Caveman MCP must use CLIProxyAPI directly.

Codex requires the MCP server to initialize. Only `caveman_retrieve` is configured
for automatic approval, as explicitly approved by the user. Other tool policies
are unchanged. Claude and OpenCode retain their normal tool permission behavior;
the headless Claude validation explicitly allowed Read and Caveman recovery.

No hooks or project instruction files were installed. AGENTS.md/CLAUDE.md,
skills, hooks, and tool execution continue to belong to the harness. The native
project checks used disposable instruction files outside real projects.

## Verification

[verify.py](verify.py) first checks that model discovery through Caveman
returns the same OpenAI, Codex and Anthropic catalogs as CLIProxyAPI. It then
checks live streaming, compression and exact original recovery for Responses
and Claude Messages. It makes two small inference calls:

```sh
python3 ~/.config/caveman/verify.py
```

Additional native Codex, Claude Code and OpenCode checks read a synthetic build
log, recovered compressed content and followed the disposable project rule.
Separate native probes reported both active router preference markers.
See [verification.json](verification.json) for outcomes and the T3 check status.

One upstream limitation remains: Caveman records Codex's stream close as
`cave_client_canceled` even when Codex successfully finishes; compression is
visible in forwarded request hashes and recovery records, but its displayed
savings can be zero. No billing or representative savings claim is made.

## Local patch

Official Caveman only proxies inference (POST), so `GET
/compat/quotio/v1/models` returned 404 and Codex, including T3's Codex
threads, fell back to its bundled catalog. The patch
[`patches/0001-…`](patches/0001-feat-gateway-forward-model-discovery-on-named-compat.patch)
adds one GET route for named compat mounts. It authenticates, forwards the
query and caller's User-Agent, and relays CLIProxyAPI's status, headers and
body unchanged, with a 30-second timeout. Discovery reads no body and is never
compressed or recorded. Every other route and method behaves as before.

Who uses discovery: Codex refreshes at app-server start and every 4.5 minutes.
Claude Code only does so with `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`
(not set). OpenCode and T3's Claude and OpenCode pickers never call it.

Source and build details are in `SOURCE` and `SHA256SUMS` next to the binary.
The branch `quotio/compat-models-discovery` in `~/.local/src/caveman` holds the
commit. Nothing updates Caveman automatically. For a new `bin-v*` release:

1. Check whether upstream serves GET `/compat/<name>/v1/models`. If so, drop
   the patch and install the official binaries only.
2. Otherwise cherry-pick the patch onto the new tag, run
   `go test ./proxy/internal/gateway/`, and build as described in `SOURCE`
   into a new versioned directory. Never overwrite an existing one.
3. Upgrade `caveman-mcp` together with the proxy, because both open `ccr.db`.
4. Smoke-test on a spare port, switch the plist path, restart the service,
   then run `verify.py`.

To return to the official proxy, set the plist's `ProgramArguments` path back to
`bin-v1.1.7/caveman-proxy` and unload and bootstrap the service as described
below. Model discovery then returns 404 again; nothing else changes.

## Operations and rollback

To check the service or restart the current configuration:

```sh
launchctl print gui/$(id -u)/local.caveman.proxy
launchctl kickstart -k gui/$(id -u)/local.caveman.proxy
```

After editing launch-agent environment variables, unload and bootstrap the
plist; allow launchd to finish unloading before bootstrapping again. Changes to
harness settings and MCP tools require new sessions; restart T3 if it retains
an old provider process.

To bypass compression, set Codex and OpenCode base URLs back to
`http://127.0.0.1:8317/v1`, and Claude's base URL to `http://127.0.0.1:8317`.
Then stop Caveman with `launchctl bootout gui/$(id -u)/local.caveman.proxy`.
Recovery can remain registered for existing conversations. Preserve its state.
To disable login startup, remove only the launch-agent symlink after stopping it.

Private pre-deployment settings are in
`~/.local/state/quotio-setup/20260929-011633-caveman-deploy`.
Prefer reverting individual routing/MCP fields over replacing whole settings
files after later configuration changes.

References: [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli),
[OpenCode MCP configuration](https://opencode.ai/docs/mcp-servers/).
