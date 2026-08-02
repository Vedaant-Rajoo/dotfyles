# T3 Code Activity Caffeinate Design

## Summary

A user LaunchAgent keeps the Mac awake while T3 Code is actively running a
thread turn or waiting on an unresolved approval. The daemon reads T3 Code's
own projections read-only and owns a parent-bound `caffeinate` child while the
predicate is busy.

This replaces the former dockless AppleScript sentinel and Amphetamine app
trigger. The replacement removes applet compilation, signing, process-pattern
matching, force-kill escalation, recursive bundle deletion, and the failure
class in which a stranded sentinel leaves the Mac awake indefinitely.

## Goals

- Hold an idle-system-sleep assertion while at least one T3 Code turn is
  running or an approval remains unresolved.
- Cover all provider drivers through one orchestration-layer signal.
- Allow display sleep.
- Release the assertion if the daemon exits for any reason, including SIGKILL.
- Resolve all database and state failures toward allowing sleep.
- Make repeated bootstrap runs reconcile rather than always reload launchd.
- Use only tools shipped with macOS.

## Non-goals

- Keeping the display awake.
- Covering terminal sessions outside T3 Code.
- Treating completed turns waiting on normal user input as active work.
- Writing to T3 Code's database.
- Replacing or uninstalling Amphetamine for unrelated use.
- Maintaining a persistent SQLite worker; stock Bash 3.2 has no `coproc`, and a
  custom FIFO worker would add reconnection and replaced-database hazards.

## Architecture

```text
T3 Code server ──writes──▶ ~/.t3/userdata/state.sqlite
                                  │ read-only poll
                          bin/t3_awake watch
                                  │ direct child while busy
                          caffeinate -i -w <watch-pid>
                                  │
                          IOPM idle-sleep assertion
```

The LaunchAgent remains `dev.newedia.t3-awake`, installed at
`~/Library/LaunchAgents/dev.newedia.t3-awake.plist` with `RunAtLoad` and
`KeepAlive` enabled.

## Busy determination

A poll is busy only when the PID in `server-runtime.json` is alive and this
read-only query succeeds with value 1:

```sql
SELECT EXISTS(SELECT 1 FROM projection_turns WHERE state = 'running')
    OR EXISTS(SELECT 1 FROM projection_pending_approvals WHERE resolved_at IS NULL);
```

The runtime PID is parsed in Bash with a regular expression. A dead, missing,
or malformed PID makes the poll idle even if the database contains a stale
running row.

While the server is alive, the query runs afresh every two seconds. A query
error retains the prior state for four polls. The fifth consecutive failure
falls back to idle and logs once; a successful query resets the episode.
When the server is down, the loop polls every 15 seconds.

`projection_threads.pending_user_input_count` and
`has_actionable_proposed_plan` remain excluded because they represent
post-turn user work, not an in-flight agent turn.

## Assertion lifecycle

On a busy poll the daemon starts:

```text
/usr/bin/caffeinate -i -w <daemon-pid>
```

The child PID is held in memory and written with the daemon PID to
`~/Library/Caches/dev.newedia.t3-awake.state`. Every busy poll confirms the
tracked child still exists and repairs the state record; an externally killed
child is reaped and replaced.

`-i` creates `PreventUserIdleSystemSleep` and does not prevent display sleep.
`-w` makes caffeinate release its assertion when the daemon PID exits. Normal
idle and signal paths still terminate and `wait` for the child explicitly, but
correctness does not depend on a trap executing.

After the last busy poll, the daemon uses Bash's monotonic `$SECONDS` counter
to linger for 30 whole seconds. Poll intervals accept fractions; linger is
intentionally integer-only because stock Bash has no higher-resolution
monotonic clock that avoids another process on every tick.

## Runtime state and status

The state file contains two decimal PIDs:

```text
<daemon-pid> <caffeinate-pid>
```

`status` reports it active only if both PIDs exist and one `/bin/ps -ww` query
proves the second process is a direct child with the exact command
`/usr/bin/caffeinate -i -w <daemon-pid>`. Missing state is inactive; malformed,
dead, or mismatched state is stale. A new daemon removes stale state at startup
but refuses to start over a verified live owner.

If the daemon cannot write state after spawning caffeinate, it immediately
terminates the child and logs the acquire failure. The system therefore never
keeps an assertion that its diagnostics cannot account for.

## LaunchAgent reconciliation

The tracked plist template contains a comment with the SHA-256 of
`bin/t3_awake`. Installation renders and lints the desired plist before
touching launchd.

- Identical target and loaded service: no-op.
- Only the embedded script SHA differs: `kickstart -k`, then update the marker.
- Structural difference while loaded: bootout, wait, atomically replace, and
  bootstrap.
- Identical target while unloaded: bootstrap directly.
- Missing or changed target while unloaded: atomically write and bootstrap.

The bootout poll is bounded at ten seconds and is only used for structural
reloads or uninstall. A failed structural bootout leaves the old plist
untouched. A failed bootstrap leaves the desired plist on disk so retrying can
bootstrap it directly.

## Failure behavior

- Missing database or dead server: idle.
- Query failure: retain the last state for four polls, then idle.
- Missing caffeinate binary or state-write failure: no assertion, throttled log.
- Caffeinate killed externally: replace it on the next busy poll.
- Graceful daemon exit: kill and reap caffeinate.
- SIGKILL of daemon: caffeinate observes the `-w` PID exit and releases itself.
- Stale state file: never reported as active; repaired on daemon startup.
- Failed launchd unload: do not remove the installed plist or report success.

## Verification strategy

The Fish harness uses scratch SQLite databases and the real stock caffeinate
binary. Polls are 0.1 seconds and waits are bounded by condition rather than
long fixed sleeps. It covers the predicate, WAL mode, retry fallback, linger,
child replacement, graceful shutdown, parent SIGKILL, state verification, and
every install reconciliation branch with a mocked launchctl.

Live verification is a separate approval gate because it changes the loaded
LaunchAgent and retires the legacy app bundle and GUI trigger.

## Recorded platform evidence

On this Mac, `/usr/bin/caffeinate -i -w <test-parent>` created one
`PreventUserIdleSystemSleep` assertion named `caffeinate command-line tool`.
No display assertion was associated with the process. After the parent was
killed with untrapped SIGKILL, the caffeinate process exited immediately.

That test establishes the property the architecture relies on: an assertion
cannot outlive the daemon whose PID it watches.
