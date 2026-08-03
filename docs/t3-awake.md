# T3 Awake

Keeps this Mac awake while a T3 Code thread is actively working, rather than
while the T3 Code window merely happens to be frontmost.

## How it works

`bin/t3_awake watch` runs as the LaunchAgent `dev.newedia.t3-awake`. It reads
T3 Code's orchestration projections in `~/.t3/userdata/state.sqlite` read-only
and treats the machine as busy when a turn is running or an approval is
unresolved, gated on T3 Code's server process being alive.

While busy, the daemon owns one direct child:

```text
/usr/bin/caffeinate -i -w <daemon-pid>
```

`-i` prevents idle system sleep but still allows display sleep. `-w` binds the
assertion to the daemon PID, so it is released even if the daemon is killed
without running its cleanup trap. Once T3 Code has been idle for 30 seconds,
the daemon terminates and reaps the child itself.

The signal comes from T3 Code's orchestration layer rather than an agent CLI,
so it covers every provider driver without per-driver hooks.

## Setup

```bash
bin/t3_awake install
```

The installer renders and validates the LaunchAgent before reconciling it. An
identical loaded installation is a no-op. A change only to `bin/t3_awake`
restarts the job with `launchctl kickstart -k`; a changed LaunchAgent definition
uses the slower bootout/wait/bootstrap path.

No Amphetamine trigger or other GUI setup is required.

## Checking it

```bash
bin/t3_awake status
bin/t3_awake probe
tail -f ~/Library/Logs/t3-awake.log
tail -f ~/Library/Logs/t3-awake.err
fish tests/bin/t3_awake_test.fish
```

`status` verifies the recorded daemon and child PIDs against the exact
parent-bound caffeinate command. A malformed or dead PID record is reported as
`stale`, never as an active assertion.

The daemon log and launchd stderr are separate because the daemon rotates its
own log. Sharing the file with launchd would let launchd write at its old file
offset after truncation and fill the gap with NUL bytes.

## Configuration

All overrides are read at process startup:

| Variable | Default |
| --- | --- |
| `T3_AWAKE_DB` | `~/.t3/userdata/state.sqlite` |
| `T3_AWAKE_RUNTIME_JSON` | `~/.t3/userdata/server-runtime.json` |
| `T3_AWAKE_POLL` | `2` seconds |
| `T3_AWAKE_IDLE_POLL` | `15` seconds |
| `T3_AWAKE_LINGER` | `30` whole seconds |
| `T3_AWAKE_LOG` | `~/Library/Logs/t3-awake.log` |
| `T3_AWAKE_STATE` | `~/Library/Caches/dev.newedia.t3-awake.state` |

Poll intervals may be fractional positive numbers. Linger must be a positive
whole number. Interval validation applies only to `watch`, so a bad exported
value cannot disable `probe`, `status`, or `uninstall`.

## Removing it

```bash
bin/t3_awake uninstall
```

Uninstall waits for launchd to confirm the job is gone before removing its
plist and runtime state. If the job cannot be unloaded, it leaves the plist in
place and reports failure instead of claiming that removal succeeded.

## Migrating from the former Amphetamine trigger

The previous design used `~/Applications/T3 Busy.app` as an Amphetamine app
trigger. After the new LaunchAgent has been installed and its assertion has
been verified:

1. Confirm no `T3 Busy.app` process remains.
2. Move the legacy app bundle to Trash.
3. Delete the inert `t3-busy` trigger from Amphetamine.

Amphetamine itself remains installed for manual or unrelated use.
