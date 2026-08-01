# T3 Code Activity Amphetamine Trigger Design

## Summary

Replace the Amphetamine trigger that keeps this Mac awake while *T3 Code is frontmost* with one that keeps it awake only while a T3 Code thread is **actively working**. Application focus is a poor proxy for work: the app can sit frontmost and idle for hours, and conversely a thread driven remotely through the machine's `cloudflared` tunnel does real work while T3 Code is not frontmost at all.

A LaunchAgent daemon reads T3 Code's own orchestration state from `~/.t3/userdata/state.sqlite` and reflects "a turn is running" by opening or quitting a dockless sentinel application. A native Amphetamine trigger keyed to that application supplies the wake session.

The signal is read from T3 Code's provider-agnostic projection tables, above the agent drivers, so one integration covers `claudeAgent`, `codex`, `cursor`, `opencode`, and `grok` alike.

## Goals

- Hold a wake session while, and only while, at least one T3 Code turn is running or blocked on an unresolved approval.
- Cover every T3 Code agent driver through a single signal, with no per-driver hook integration.
- Keep wake sessions native to Amphetamine, so trigger precedence, menu-bar state, session statistics, and the global Enable Triggers switch continue to behave normally.
- Never write to T3 Code's database and never script Amphetamine's session state.
- Release the wake session on every failure path, including a T3 Code crash that leaves a stale `running` turn behind.
- Install, verify, and uninstall from this repository using only tools present on a stock macOS system.

## Non-goals

- Keeping the Mac awake for terminal or tmux `claude` sessions outside T3 Code.
- Keeping the Mac awake for post-turn states in which the thread waits on the user: `projection_threads.pending_user_input_count` and `has_actionable_proposed_plan`. A finished turn that asks a question is not work in progress. This is distinct from an approval request, which is a permission prompt raised *during* a turn and is in scope.
- Preventing display sleep. The existing triggers use `AllowDisplaySleep = 1`, and the new trigger inherits that.
- Writing Amphetamine's trigger list programmatically. Trigger creation is one documented manual step.
- Detecting T3 Code activity that is not a thread turn, such as editor or integrated-terminal use.
- Replacing Amphetamine with a `caffeinate` power assertion.

## Architecture

Data flows in one direction, and nothing outside this repository is mutated:

```
T3 Code server ──writes──▶ ~/.t3/userdata/state.sqlite
                                  │  read-only poll
                          bin/t3_awake watch          ← LaunchAgent, KeepAlive
                                  │  open / quit
                          ~/Applications/T3 Busy.app  ← dockless sentinel
                                  │  visible to NSWorkspace
                          Amphetamine trigger "t3-busy"
```

The daemon's only observable output is whether one sentinel application is running. Amphetamine's own trigger engine owns everything else.

### Signal source

T3 Code maintains an event-sourced projection of thread state in `~/.t3/userdata/state.sqlite`. Two tables matter:

- `projection_turns(thread_id, turn_id, state, requested_at, started_at, completed_at, …)` — one row per turn, with `state` observed as `running` while work is in flight and `completed` afterwards.
- `projection_pending_approvals(request_id, thread_id, turn_id, status, decision, created_at, resolved_at)` — one row per approval request.

These are populated by T3 Code's orchestration layer, which sits above the provider drivers. That is what makes the signal driver-agnostic.

Two adjacent tables are deliberately **not** used. `provider_session_runtime.status` and `projection_thread_sessions.status` also carry a `running` value, but they describe whether the agent process is alive, not whether it is working — at design time the machine showed two `running` `claudeAgent` provider sessions against exactly one `running` turn. Turn state is the finer and correct signal.

### `bin/t3_awake`

A single Bash executable with four subcommands:

- `install` — build the sentinel, write and load the LaunchAgent, then print the manual Amphetamine trigger steps.
- `uninstall` — unload the LaunchAgent, quit the sentinel, remove the built application.
- `watch` — the daemon loop; this is what launchd runs.
- `status` — a one-shot report of running turn count, unresolved approval count, T3 Code server liveness, sentinel state, and Amphetamine session state. Used for debugging and by the verification checklist.

Behavior is overridable through the environment so the logic can be exercised against a scratch database: `T3_AWAKE_DB`, `T3_AWAKE_RUNTIME_JSON`, `T3_AWAKE_APP`, `T3_AWAKE_POLL`, `T3_AWAKE_IDLE_POLL`, `T3_AWAKE_LINGER`.

### Sentinel application

`amphetamine/t3-busy.applescript` is compiled with `osacompile -s -o "T3 Busy.app"` into `~/Applications/T3 Busy.app` at install time. Its `Info.plist` is then patched with `LSUIElement = 1` and the bundle identifier `dev.newedia.t3-busy`, giving an application with no Dock icon, no menu bar, and no window.

A compiled stay-open AppleScript applet is required rather than a shell script in an application bundle: only a real Cocoa application registers as an `NSRunningApplication`, which is the list Amphetamine's app trigger consults. Amphetamine itself runs with `Hide Dock Icon = 1` and remains visible at that level, confirming that a dockless application is detectable.

Both `/usr/bin/osacompile` and `/usr/bin/sqlite3` ship with macOS, so the component has no Homebrew dependency.

### LaunchAgent

`amphetamine/dev.newedia.t3-awake.plist` is the tracked template, installed to `~/Library/LaunchAgents/dev.newedia.t3-awake.plist` with label `dev.newedia.t3-awake`, `RunAtLoad` and `KeepAlive` enabled, running `bin/t3_awake watch`.

This is the repository's first hand-authored LaunchAgent. `SYSTEM.md` currently records that all user LaunchAgents are app-generated rather than hand-authored automation; that line is updated as part of this work, and `bin/bootstrap` gains a step that installs the agent.

### Amphetamine trigger

Created once through Amphetamine's interface, matching the shape of the existing entries in `Trigger Data`:

| Field | Value |
| --- | --- |
| `Name` | `t3-busy` |
| `App` | `T3 Busy` |
| `RequireAppFrontmost` | unset |
| `AllowDisplaySleep` | enabled |
| `Enabled` | enabled |

The two existing triggers are removed:

- `t3` (`App = T3 Code (Nightly)`, `RequireAppFrontmost = 1`) is the false positive this work replaces.
- `claude` (`App = claude`) has never fired. The `claude` CLI is not an `NSWorkspace` application; System Events does not list a process by that name while sessions are running.

Amphetamine's AppleScript interface is used only for read-only queries in `status` and in verification (`session is active`, `session is Trigger`). It is never used to start or end sessions, because `start new session` is documented to end any existing session including Trigger-based ones, and Amphetamine exposes no session identity that would let the daemon tell its own session from a manually started one.

## Busy determination

A poll is busy when the T3 Code server is alive **and** the database reports work:

```sql
SELECT EXISTS(SELECT 1 FROM projection_turns WHERE state = 'running')
    OR EXISTS(SELECT 1 FROM projection_pending_approvals WHERE resolved_at IS NULL);
```

Server liveness is `kill -0` against the `pid` field of `~/.t3/userdata/server-runtime.json`.

The approvals clause is a safety net for the "in flight or blocked on you" boundary. A mid-turn approval should already hold its turn at `running`, but if any driver settles the turn while waiting for a decision, this clause still holds the session. It is expressed as `resolved_at IS NULL` rather than a `status` comparison because no approval was outstanding when the schema was surveyed, so the `status` vocabulary is unconfirmed; `resolved_at` is unambiguous from the schema. Confirming the `status` values, and confirming that `projection_turns.state` has no additional in-flight value such as a queued state, are explicit verification steps.

Loop behavior:

- Run the query unconditionally on every poll while the T3 Code server is alive. An earlier revision short-circuited on the modification time of `state.sqlite-wal` and ran the query only when it changed; that was removed because it could latch the busy state permanently. The change signal was consumed before the query result was known, so a transient read error stopped the retry from ever running again, and `stat` reports only whole seconds, so a turn completing in the same second as the last observed write could be missed entirely. Both paths end with the sentinel held up for the life of the server — the one failure direction this design forbids. Two `EXISTS` probes against small projections cost single-digit milliseconds, so the optimization bought nothing worth that risk: correctness over a negligible saving.
- Poll every 2 seconds while the T3 Code server is alive, every 15 seconds when it is not.
- After the last busy poll, linger 30 seconds before quitting the sentinel. This bridges back-to-back turns during conversational work and prevents the application from flapping open and closed.
- Open or quit the sentinel only on a state transition, never on every poll.

## Failure and cleanup behavior

Every failure path resolves toward not-busy, so a malfunction lets the Mac sleep rather than pinning it awake.

### Stale running turn

If the T3 Code server process is gone, the daemon reports not-busy regardless of database contents. Without this guard, a crash during a turn leaves a `running` row that no process will ever complete, holding the Mac awake indefinitely.

### Database unavailable

A missing or unreadable database yields not-busy.

### Query failure

A transient `sqlite3` error, such as a locked database, retains the previous state. After five consecutive failures the daemon falls back to not-busy and logs the transition. The counter resets on the next successful query.

### Sentinel unavailable

If the sentinel application is missing, the daemon logs once and continues polling rather than exiting, so it cannot crash-loop under launchd's `KeepAlive`.

### Daemon restart

On start the daemon recomputes desired state and opens or quits the sentinel to match, rather than assuming it inherited a clean slate. A restart during a running turn therefore converges back to busy within one poll.

### Daemon shutdown

`SIGTERM` and `SIGINT` handlers quit the sentinel before exiting, so logout or an explicit unload does not strand a running sentinel and, with it, a permanent wake session.

## Logging

The daemon writes to `~/Library/Logs/t3-awake.log`, one timestamped line per state transition and per error condition — never per poll. The file is truncated when it exceeds 1 MB. Thread identifiers, titles, and message content are never logged; only counts and states.

## Verification strategy

There is no test framework in this repository, so verification is a scratch-database harness plus a documented acceptance checklist.

The harness creates a temporary SQLite database containing only `projection_turns` and `projection_pending_approvals`, and a matching `server-runtime.json` naming a live PID. Pointing `T3_AWAKE_DB` and `T3_AWAKE_RUNTIME_JSON` at these drives the daemon's logic in seconds, without waiting on real threads:

1. No rows → not busy; sentinel stays down.
2. Insert a `running` turn → busy within one poll; sentinel comes up.
3. Set the turn to `completed` → sentinel goes down after the linger.
4. Insert an unresolved approval with no running turn → busy. This exercises the safety net for a driver that settles its turn while waiting on a permission decision; it is not the expected steady state.
5. Point `T3_AWAKE_RUNTIME_JSON` at a dead PID while a `running` turn exists → not busy.
6. Make the database unreadable mid-run → not busy after the retry budget, with a logged transition.

Against the real system, with the trigger installed:

1. Idle T3 Code → `t3_awake status` reports zero running turns, sentinel down, and no active trigger session.
2. Start a long turn → within roughly 2 seconds the sentinel is running and `session is Trigger` returns true.
3. Let the turn finish → after the linger the sentinel is gone and the trigger session has ended.
4. Run a turn on a non-Claude driver → identical behavior, confirming the driver-agnostic claim.
5. `kill -9` the T3 Code server mid-turn → the daemon releases within one poll.
6. `launchctl kickstart -k dev.newedia.t3-awake` mid-turn → the daemon reconciles back to busy.
7. Confirm the observed `projection_pending_approvals.status` value for an outstanding approval, and confirm no additional in-flight `projection_turns.state` value appears in normal use.

## Success criteria

- A running turn on any driver holds an Amphetamine trigger session; an idle T3 Code window, frontmost or not, does not.
- A thread driven remotely over the tunnel holds the session while T3 Code is not frontmost.
- Manual Amphetamine sessions and other triggers are never ended or altered by this system.
- Killing T3 Code at any point, including mid-turn, releases the session within one poll.
- `bin/t3_awake install` on a clean machine produces a working setup after the one documented Amphetamine step, and `bin/t3_awake uninstall` removes every artifact it created.
