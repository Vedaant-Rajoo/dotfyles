# Caveman compression in front of Quotio

Tested on 2026-09-29. Feasible with the existing Quotio/CLIProxyAPI setup.
This is a feasibility result, not a deployment: all production settings are
unchanged and all temporary Caveman processes have stopped.

## Proposed route

```text
T3 / native CLI agent
  → Caveman local compression proxy
  → Quotio's CLIProxyAPI at 127.0.0.1:8317
  → connected provider account

Agent's Caveman MCP tool → same local CCR recovery database as the proxy
```

Quotio continues to own provider accounts and CLIProxyAPI. Caveman forwards the
existing proxy client credential; it does not need separate provider sign-ins.
Model IDs remain `gpt-6-luna`, `claude-haiku-4-5-20251001`, etc.
The existing Ponytail and Caveman response rules run downstream in CLIProxyAPI.

## Results

The official `bin-v1.1.7` macOS ARM64 proxy and MCP binaries were downloaded to a
temporary directory and checked against the GitHub release asset SHA-256 digests.
Their signatures were not verified. The proxy's version command reports `dev`,
so release identity here is established by the asset hashes, not its version string.

| Check | Responses API | Claude Messages API |
| --- | --- | --- |
| Record mode preserves fixture request | Passed | Passed |
| Streaming without MCP recovery leaves fixture uncompressed | Passed | Passed |
| Compression preserves model ID, instructions, tools and tool-call IDs | Passed | Passed |
| MCP retrieves byte-exact original tool output | Passed | Passed |
| Namespaced MCP tool enables compression without global recovery override | Passed | Passed |
| Previous compressed output stays byte-identical on the next turn | Passed | Passed |
| Live compressed request through existing CLIProxyAPI completes its stream | Passed | Passed |
| Live response reports error canary and exit code | Passed | Passed |
| Live response reports both active router preference identifiers | Passed | Passed |

The live models were `gpt-6-luna` and `claude-haiku-4-5-20251001`. Exactly two live
requests were sent, after explicit approval. Responses were inspected in memory;
the report contains only test outcomes. Existing CLIProxyAPI logging was unchanged.

The synthetic repeated build-log fixture shrank from 93,030 to 3,867 request bytes
for Responses, and from 93,084 to 3,921 for Messages, including its recovery marker.
These are synthetic byte measurements, not representative token or billing savings.
Authentication checks covered Bearer credentials on both protocols and `x-api-key`
on Messages.

SHA-256 comparisons confirmed no changes to Quotio's config, native Codex config,
Claude settings or OpenCode config. No service, login item, hook, skill or MCP
registration was installed. New T3/native CLI sessions were not exercised in this
probe; the live tests directly used the two underlying HTTP protocols.

## What installation would require

1. One additional local Caveman service, bound to loopback, with a named
   `compat.quotio` upstream pointing at `http://127.0.0.1:8317` and
   `wire_dialect: anthropic`. Allow only the required loopback upstream through
   `CAVE_SSRF_ALLOWLIST`. The same mount serves both API formats.
2. Point the native Codex Responses base URL at
   `http://127.0.0.1:<caveman-port>/compat/quotio/v1`; point Claude's base URL at
   `http://127.0.0.1:<caveman-port>/compat/quotio`. Keep existing client-key helpers.
   Configure other harnesses according to their actual protocol.
3. Register Caveman MCP in each participating harness, sharing the proxy's
   `CAVEMAN_CCR_DB`. Preserve that database while conversations contain recovery
   handles. Prefer request-level recognition of the namespaced recovery tool
   over globally asserting that every client has recovery installed.
4. Verify a fresh T3 thread and native CLI tool/recovery turn before enabling
   compression for normal work. T3's quota source can keep pointing directly
   at CLIProxyAPI.

The test explicitly disabled tool-schema stripping, automatic cache-breakpoint
planning and provider cache optimizers to isolate compression and preserve the
existing request structure. Those extra optimizations have not been evaluated.

AGENTS.md/CLAUDE.md loading, local hooks, skills and permissions remain harness
responsibilities. The fixtures proved preservation of system/instructions fields
and tool definitions. They do not prove that every long instruction embedded in
a user-message block is exempt from compression; a real project pilot should
check those placements and recovery behavior.

This runtime is separate from the current Prompt Rules plugin. That plugin edits
response instructions; its UI does not start or configure Caveman's proxy or MCP
recovery server. Consolidating those controls into CLIProxyAPI's UI would be a
separate integration project.

## Sources and reproducibility

- [Runtime release](https://github.com/JuliusBrussee/caveman/releases/tag/bin-v1.1.7)
- [Custom upstreams and protocol routing](https://github.com/JuliusBrussee/caveman/blob/2fd153c67988e980fb0b2455c90832159a6a5a25/docs/technical/proxy-and-providers.md)
- [Configuration](https://github.com/JuliusBrussee/caveman/blob/2fd153c67988e980fb0b2455c90832159a6a5a25/docs/technical/configuration.md)
- [Recovery architecture](https://github.com/JuliusBrussee/caveman/blob/2fd153c67988e980fb0b2455c90832159a6a5a25/docs/technical/context-recovery.md)
- [Runtime MCP recovery gates](https://github.com/JuliusBrussee/caveman/blob/bin-v1.1.7/proxy/internal/gateway/server.go)

Sanitized results: `caveman-proxy-feasibility.json`.
Temporary probes: `/private/tmp/caveman-feasibility/{check,replay,live}.py`.

Release asset SHA-256 digests:

```text
caveman-proxy_darwin_arm64  2ad5195b357121b4c2fbd4154d6df971affc2cf898f313efb40fb1e9fce50dc2
caveman-mcp_darwin_arm64    44664fe2cd72d52998ba4ebb0adc675cc825c56abbc0a839a40ac21f35794c41
```
