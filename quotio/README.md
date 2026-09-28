# Quotio harness routing

Quotio owns CLIProxyAPI at `http://127.0.0.1:8317` and the connected accounts.
Codex and Claude Code obtain its client credential through
`../bin/quotio-client-key`. That helper only supplies authentication; it does not
inject prompts. OpenCode uses a private copy at `~/.local/state/quotio/client-key`;
refresh that file from the helper if Quotio's client key changes.
Provider tokens and client keys do not belong in this repository.

T3's default Codex and Claude providers load the native CLI settings for new
threads. Its CLIProxyAPI quota source is separate from inference routing.

## Manage router prompts in the UI

Open [CLIProxyAPI Management](http://127.0.0.1:8317/management.html) and select
**Prompt Rules** under **Plugins** in the sidebar. Sign in with Quotio's management
key if requested. Reconnect the YubiKey if Quotio needs it to retrieve that key.

- **Run this rule** switches an individual rule on or off. Toggle both matching
  Caveman rules to turn Caveman off, or both Ponytail rules to turn Ponytail off.
  The two features work independently.
- Edit **Content** to change a prompt; edit **Model scope** to limit its application.
- Click **Save changes** to apply edits. CLIProxyAPI reloads without restarting.

Leave **Plugin enabled** on inside this page. In the tested versions, disabling
the plugin unloads its own save-validation endpoint, so this page cannot turn it
back on (HTTP 404). If that happens, re-enable Prompt Rules from the main
**Plugins** management page, then reopen its rule editor.

The native `prompt-rules` plugin is v0.2.1, installed through CLIProxyAPI's Plugin
Store. Its library lives under `~/Library/Application Support/Quotio/plugins`,
outside Quotio's versioned proxy binary directory. Updates are managed in the
Plugin Store. The authoritative prompts live in Quotio's `config.yaml`, under
`plugins.configs.prompt-rules.rules`; there is no local prompt toggle script or
second active rule file to synchronize.

## The rules

| Rule | Input protocol | Injection |
| --- | --- | --- |
| Ponytail Full — Responses | OpenAI Responses, used by Codex and the tested OpenCode provider | Append a text block to the last user message |
| Ponytail Full — Other APIs | Claude, Chat Completions, Gemini, Interactions | Append system text |
| Caveman Full — Responses | OpenAI Responses | Append a text block to the last user message |
| Caveman Full — Other APIs | Claude, Chat Completions, Gemini, Interactions | Append system text |

The Ponytail pair contains the same coding preferences, enclosed in
`<router_coding_preferences>` with identifier `PONYTAIL_ROUTER_FULL_V1`.
When changing the shared wording, update both rules. The protocol filters are
mutually exclusive, so each supported request receives one copy.

Responses uses a user-message block because live Codex-backend checks did not
recognize the plugin's top-level `instructions` injection. Explicit block
boundaries were also needed for reliable recognition. Existing developer
instructions, project messages, and tool definitions remain intact. The scope
sentence makes these coding preferences subordinate to explicit user requests,
project instructions, and harness requirements.

Keep the opening tag at the start of Content, without leading blank lines.
Leading blank lines triggered a YAML serialization error when saving with
CLIProxyAPI 8.0.3. Lines beginning with Markdown `#` headings also trigger this
bug; use plain section labels. Normal line breaks inside the block work.

## Caveman Full

The Caveman pair contains the upstream response-style rules from commit
`2fd153c67988e980fb0b2455c90832159a6a5a25`, inside
`<router_response_preferences>` with marker `CAVEMAN_ROUTER_FULL_V1`.
Only YAML frontmatter was removed and Markdown headings changed to plain labels.
A scope wrapper preserves explicit user requests, project instructions, harness
requirements, accurate uncertainty, and structured/tool output.

Full is the default style. Code, commands, exact errors, and persisted artifacts
retain their normal form. Explicit requests for normal prose, detail, or another
language take precedence. Conversational overrides depend on visible history;
the router does not track durable per-session mode state. Use the UI checkboxes
for persistent changes, and edit both Caveman rules for shared wording changes.

This setup uses Caveman's prompt behavior through the existing native Prompt
Rules plugin. It does not install Caveman's separate compression proxy, CLI,
hooks, slash commands, status line, or tool-output recovery store. Harness URLs,
credentials, skills, and project instruction files were not changed for Caveman.
No token or cost savings are claimed; the prompt itself adds input tokens.

A separate compression-proxy feasibility check passed for both Responses and
Claude Messages through the connected CLIProxyAPI accounts, including byte-exact
MCP recovery. It is not installed or enabled for the harnesses. See
[the feasibility report](caveman-proxy-feasibility.md) for results and the remaining
deployment requirements.

Source: [Caveman skill at the pinned commit](https://github.com/JuliusBrussee/caveman/blob/2fd153c67988e980fb0b2455c90832159a6a5a25/skills/caveman/SKILL.md).
The upstream MIT notice is retained in `licenses/caveman-MIT.txt`.
See `caveman-verification.json` for checks and the private pre-Caveman backup.

This is prompt configuration. AGENTS.md/CLAUDE.md discovery, hooks, skills, and
slash commands still belong to the harness; a router prompt does not install or
execute them.

## Verification and recovery

`verification.json` records the native plugin migration: 21 isolated checks,
successful live Codex/Claude Code/OpenCode responses, single injection in the
outgoing requests, preservation of original instructions/messages/tools, and UI
saves. Chat Completions, Gemini, and Interactions are configured but were not
live-tested. No token or cost savings were benchmarked.

The user previously confirmed a fresh T3 thread with the old payload rules.
Native CLI checks passed after this migration; a fresh T3 thread has not been
separately checked again.

A private pre-migration backup is at
`~/.local/state/quotio-setup/20260929-002836-plugin-migration`.
The old payload rules, `bin/quotio-ponytail`, and `quotio/ponytail.json` were removed
from the active setup. The backup contains credentials; keep it private.

Prompt source: [9router's pinned Ponytail Full adaptation](https://github.com/decolua/9router/blob/f01fb909e37189008080632ddaf404f096345cde/open-sse/rtk/ponytailPrompt.js).
Original project: [Ponytail](https://github.com/DietrichGebert/ponytail).
Plugin: [Prompt Rules v0.2.1](https://github.com/markhuangai/cpa-plugin-prompt-rules/tree/v0.2.1).
