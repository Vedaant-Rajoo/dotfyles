# System snapshot

Snapshot date: **2026-07-28**

This file records the source Mac at the time the full manifest and bootstrap were created. It is an audit snapshot, not a promise that every cache, credential, GUI preference, or runtime database is portable. The evergreen recovery instructions live in [README.md](README.md).

## Platform

| Item | Snapshot |
|------|----------|
| Hardware architecture | Apple Silicon (`arm64`) |
| macOS | 26.5.2 (build 25F84) |
| Homebrew | `/opt/homebrew` |
| Login shell | `/usr/local/bin/fish` |
| Active project root | `~/.config` |
| Primary project directory | `~/Development` |

## Toolchain provenance

The Brewfile declares fresh-machine fallbacks while preserving the source machine's current resolution order.

| Tool | Active snapshot state | Reproduction policy |
|------|-----------------------|---------------------|
| Fish | 4.6.0, official signed macOS pkg at `/usr/local/bin/fish`; login shell | Fresh machines install Homebrew Fish; `bin/bootstrap` adds it to `/etc/shells` and runs `chsh` |
| Node | 24.14.1, fnm default under `~/.local/share/fnm` | Pinned in `bin/bootstrap` |
| Python | 3.14.4, pyenv global | Pinned in `bin/bootstrap` |
| Go | Official Go 1.26.2 at `/usr/local/go` wins over Homebrew Go 1.26.5 | Keep `fish/conf.d/00-paths.fish` preference; Brewfile Go is the fresh-machine fallback |
| Rust | Homebrew Rust 1.97.1 wins on PATH; rustup stable ARM64 1.96.0 also exists | Brewfile reproduces Homebrew Rust; rustup remains documented local state |
| Bun | 1.3.14, Homebrew | Declared in Brewfile; the former `~/.bun` native install is no longer present |
| pnpm | 11.17.0, Homebrew | Declared in Brewfile |
| Claude Code | 2.1.220 native install under `~/.local/share/claude`, launcher in `~/.local/bin` | `bin/bootstrap` uses the official native self-updating installer |
| Cursor Agent | CLI `2026.07.23-e383d2b` under `~/.local/share/cursor-agent`; Cursor.app is `2026.07.09-a3815c0` | Not declaratively installed; Cursor.app is declared, agent state remains manual |
| Proton Pass CLI | 2.2.3 under `~/.local/bin` | `proton-pass-cli` is now declared as a fresh-machine fallback |

The duplicated Go and Rust providers are intentional snapshot facts, not a desired cleanup performed by this change.

## Shared agent configuration

`agents/` is the canonical behavior layer for the installed AI harnesses. `bin/agents_link` projects it into native locations and `bin/agents_conform` verifies both deterministic wiring and optional behavioral canaries.

| Harness | Rules | Skills | Subagents | Portable hook coverage |
|---------|-------|--------|-----------|------------------------|
| Claude Code | `~/.claude` **is** `claude/`; `claude/CLAUDE.md` → `agents/AGENTS.md` | `claude/skills` → `agents/skills` | Generated into `claude/agents` | Native `Stop` command hook, from tracked settings |
| Codex | `~/.codex/AGENTS.md` → `agents/AGENTS.md` | Per-skill links in `~/.codex/skills` | N/A: no stable subagent file format | Unmanaged until the native TOML hook schema stabilizes |
| OpenCode | `~/.config/opencode/AGENTS.md` → `agents/AGENTS.md` | Per-skill links plus `~/.agents/skills` | Generated into `~/.config/opencode/agents` | Not portable: lifecycle extension surface is the plugin API |
| Cursor Agent | Generated `~/.cursor/rules/agents.mdc` (`alwaysApply`), found by ancestor walk | Per-skill links in `~/.cursor/skills` and `~/.agents/skills` | N/A: the CLI reads subagents only from a workspace `.cursor/agents` | Generated `~/.cursor/hooks.json` stop hook |
| Shared standard | `~/.agents/AGENTS.md` → `agents/AGENTS.md` | Per-skill links in `~/.agents/skills` | — | — |

Cursor is the awkward one, and the table above understates it. It has no global rules *file*: `LocalCursorRulesService` walks up from the workspace directory reading `<dir>/.cursor/rules/**/*.mdc` and `<dir>/AGENTS.md` at every ancestor until it hits `/`. `~/.cursor/rules` is therefore reached only because `$HOME` is an ancestor — the shared rule applies to every project under the home directory and to nothing outside it. There is no `~/.cursor/AGENTS.md` and no `CURSOR.md` anywhere in the shipped bundle. `CURSOR_CONFIG_DIR` exists but relocates only `cli-config.json` and `permissions.json`, so it cannot move rules, skills, agents, or hooks.

Three Cursor findings worth not rediscovering:

- **Subagents are workspace-only.** `computeAgentsDirs()` resolves from `workspacePath` alone; no `homedir()`-joined agents directory exists in the bundle. Projecting into `~/.cursor/agents` would fail silently, which is why this repo does not.
- **Cursor imports Claude's hooks.** It reads `~/.claude/settings.json` directly and maps `Stop`→`stop`, `PreToolUse`→`preToolUse`, and six more. With both that and `~/.cursor/hooks.json` configured, a portable hook can run twice under Cursor.
- **`XDG_CONFIG_HOME` is a latent trap for this machine.** It is unset today. Exporting it as `~/.config` — tempting, given this repo lives there — silently moves Cursor's config dir to `~/.config/cursor` and orphans `cli-config.json` and `permissions.json`.

Rules and skills are symlinks elsewhere, so all other harnesses read the same bytes. Subagent frontmatter is harness-specific, so `bin/agents_render` translates each `agents/subagents/<name>.md` and `agents_link` writes the result; those generated files are untracked and carry a generation header that marks them safe to rewrite or prune. The lossy edges — model tier dropped on OpenCode, permission tiers `safe`/`full` dropped on Claude — are recorded in `agents/subagents/README.md`.

Provider/auth/model settings remain native and untracked. Live conformance calls are opt-in because they consume tokens and model obedience is probabilistic.

Claude Code is the one harness whose config directory this repository owns outright: `~/.claude` is a symlink to `claude/`. Claude rewrites its own `settings.json`, so the only way to keep the tracked copy authoritative is to make it the live copy and read the drift out of `git diff`. Its credential lives behind `apiKeyHelper` in a gitignored `claude/auth-token`, which is why the tracked settings carry no secret and `agents_conform` now passes end to end, live tier included.

About 340 MB of Claude runtime state — `security/` alone is a 297 MB agent SDK venv — now sits inside the working tree and is gitignored wholesale. `~/.claude.json` is deliberately left at the home root: it is OAuth and per-project state, not configuration.

## npm global tools

The user-owned npm prefix is `~/.node_modules`. Bootstrap restores:

- `postplan@0.0.4` — required by `agents/skills/html-planning`;
- `@augmentcode/auggie`;
- `localtunnel`.

The snapshot also contained a separate npm installation and a broken `vaultwork` launcher. Those are not restored. Corepack ships with the fnm-managed Node runtime; the old Brewfile `npm "corepack"` directive was removed because Brew Bundle cannot pin npm versions and may install Homebrew Node before fnm is ready.

## Mac App Store inventory

| Application | App Store ID | Snapshot version |
|-------------|-------------:|-----------------:|
| Amphetamine | 937984704 | 5.3.2 |
| Hush | 1544743900 | 1.0.19 |
| NepTunes | 1006739057 | 3.2.8 |
| Proton Pass for Safari | 6502835663 | 1.38.0 |
| Tampermonkey | 6738342400 | 5.6.6240 |
| TrashMe 3 | 1490879410 | 3.7.5 |
| Wipr | 1662217862 | 2.34 |
| Xcode | 497799835 | 26.6 |

These IDs are captured directly in the Brewfile. Installation still requires an App Store sign-in.

## Application coverage

The Brewfile now covers the active package-manageable application set, including:

- development: Cursor, T3 Code Nightly, OrbStack, Codex, Ghostty, FluxMarkdown;
- productivity/UI: Raycast, Rectangle Pro, Hyperkey, Bartender 6, Shottr, Alcove, Wallspace, Wispr Flow, DockDoor, LinearMouse, Quotio;
- browsers/networking: Google Chrome, Zen, Legcord, Proton Pass, Tailscale;
- hardware/system: Logitech G Hub, Macs Fan Control, Music Presence, WakaTime;
- games: League of Legends and Riot Client;
- font: JetBrains Mono Nerd Font.

Raycast runs its Beta channel selected inside the application; Homebrew exposes the `raycast` cask rather than a beta-specific token.

Zed settings remain tracked, but **Zed.app was not installed at snapshot time**, so `cask "zed"` is intentionally absent. Add it if Zed becomes active again.

## Cursor extension snapshot

Cursor had 14 extensions installed, but the user chose not to track or bootstrap editor state:

- `anysphere.remote-containers`
- `anysphere.remote-ssh`
- `astro-build.astro-vscode`
- `enkia.tokyo-night`
- `expo.vscode-expo-tools`
- `flvffy.poimandres`
- `johnnymorganz.stylua`
- `llvm-vs-code-extensions.lldb-dap`
- `mikestead.dotenv`
- `mvllow.rose-pine`
- `pkief.material-icon-theme`
- `redhat.vscode-yaml`
- `swiftlang.swift-vscode`
- `yoavbls.pretty-ts-errors`

Cursor's editor settings, keybindings, MCP configuration, CLI configuration, sessions, and extension state remain machine-local by explicit decision.

## Deliberately unmanaged configuration

These items influence the daily machine but are intentionally excluded from version control:

| State | Reason / recovery path |
|-------|------------------------|
| Cursor settings, keybindings, extensions, MCP, account-backed user rules and agent state | Native/account state remains local; shared skills and portable hooks are projected from `agents/` |
| Codex `~/.codex/config.toml`, auth, memories, plugins and sessions | Native/provider state remains local; shared rules and skills are projected from `agents/` |
| DockDoor plist preferences | User explicitly chose not to export GUI defaults |
| Raycast Beta preferences, databases, HyperKey state and downloaded extensions | Mutable application database and account state |
| Claude Code account, conversations, projects, sessions and telemetry | Private runtime state; it now lives under `claude/` because `~/.claude` links there, and is gitignored wholesale |
| `claude/auth-token` and `~/.claude.json` | The CLIProxyAPI credential and Claude's OAuth/project state; neither is ever tracked |
| GitHub Copilot OAuth state | Credential-bearing runtime data |
| SSH private keys, known hosts, and the `trixie` host alias | Security boundary; recreate manually |
| WakaTime API configuration | Credential-bearing `~/.wakatime.cfg` |
| OpenCode live provider configuration | `opencode/opencode.json` contains credentials |
| OrbStack/Docker contexts, registry auth, IPv6/Rosetta preferences | Keychain and machine/runtime state |
| Legcord Discord session, caches, window geometry, and locale cache | Only `storage/settings.json` is tracked; `bin/legcord_link` connects it |
| GUI preference plists for third-party apps | Full GUI cloning is outside the repository boundary |

## Runtime and service state

- Herdr is installed and was running through `homebrew.mxcl.herdr`; bootstrap starts it only with `--with-herdr-service`.
- `tmux` 3.7b remains installed locally as legacy state but is deliberately absent from the Brewfile. `bin/tmux-sessionizer` forwards to Herdr.
- `/etc/shells` contains `/usr/local/bin/fish` twice. This is harmless snapshot drift; bootstrap's exact-match guard does not add another duplicate.
- No user crontab existed.
- User LaunchAgents were app-generated (Google updater, Riot client, Herdr), not hand-authored automation to preserve.
- `~/Development` existed; `~/dev` and `~/projects` did not. `bin/herdr-sessionizer` safely searches all three plus `~/.config`.

## Security boundary

The repository intentionally omits tokens, API keys, browser/account sessions, private keys, Docker registry credentials, Claude transcripts, Postplan credentials, WakaTime credentials, and generated databases. A machine clone therefore means **software + configuration + a documented authentication checklist**, not credential replication.

At snapshot time:

- the working tree was clean before implementation;
- `bin/claude_link --check` passed;
- there were no ordinary untracked files under `~/.config`;
- ignored files matched the documented secret/runtime policy.
