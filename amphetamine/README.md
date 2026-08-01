# Amphetamine

Keeps this Mac awake while a T3 Code thread is actively working, rather than
while the T3 Code window merely happens to be frontmost.

## How it works

`bin/t3_awake watch` runs as the LaunchAgent `dev.newedia.t3-awake`. It reads
T3 Code's orchestration projections in `~/.t3/userdata/state.sqlite` read-only
and treats the machine as busy when a turn is running or an approval is
unresolved, gated on T3 Code's server process being alive.

When busy it launches `~/Applications/T3 Busy.app`, a dockless do-nothing
applet compiled from `t3-busy.applescript`. An Amphetamine trigger keyed to
that application supplies the wake session. Amphetamine's own session state is
never scripted, so manual sessions and other triggers are unaffected.

Because the signal comes from T3 Code's orchestration layer rather than from an
agent CLI, it covers every provider driver — `claudeAgent`, `codex`, `cursor`,
`opencode`, `grok` — without per-driver integration.

## Setup

```bash
bin/t3_awake install
```

Then, in Amphetamine -> Preferences -> Triggers:

1. Add a trigger for a running application and select `~/Applications/T3 Busy.app`.
2. Leave the frontmost requirement off; allow display sleep on.
3. Delete the `t3` trigger. It fires whenever T3 Code is frontmost, which is the
   false positive this replaces.
4. Delete the `claude` trigger. The `claude` CLI is not an `NSWorkspace`
   application, so that trigger has never fired.

## Checking it

```bash
bin/t3_awake status     # turns, approvals, sentinel, Amphetamine session
bin/t3_awake probe      # just "busy" or "idle"
tail -f ~/Library/Logs/t3-awake.log
fish tests/bin/t3_awake_test.fish
```

## Removing it

```bash
bin/t3_awake uninstall
```

Then delete the `t3-busy` trigger in Amphetamine.
