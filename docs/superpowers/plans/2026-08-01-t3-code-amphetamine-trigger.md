# T3 Code Activity Amphetamine Trigger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep this Mac awake while a T3 Code thread is actively working, replacing the existing Amphetamine trigger that fires merely because T3 Code is frontmost.

**Architecture:** A Bash LaunchAgent daemon polls T3 Code's own orchestration projections in `~/.t3/userdata/state.sqlite` read-only, and reflects "a turn is running" by opening or terminating a dockless stay-open AppleScript applet. A native Amphetamine trigger keyed to that applet supplies the wake session, so Amphetamine's session state is never scripted. The signal lives above T3 Code's provider drivers, so one integration covers every agent driver.

**Tech Stack:** Bash 3.2, `/usr/bin/sqlite3`, `/usr/bin/osacompile`, `/usr/libexec/PlistBuddy`, `codesign`, `launchd`, Fish 4.x for tests, Amphetamine 5.3.2.

Design spec: `docs/superpowers/specs/2026-08-01-t3-code-amphetamine-trigger-design.md`.

## Global Constraints

- Never write to `~/.t3/userdata/state.sqlite`. Every read uses `sqlite3 -readonly`.
- Never call Amphetamine's `start new session` or `end session`. AppleScript is used only for the read-only queries `session is active` and `session is Trigger`.
- Every failure path resolves toward not-busy, so a malfunction lets the Mac sleep rather than pinning it awake.
- `bin/t3_awake` is Bash, not Fish, because launchd's default `PATH` does not include `/opt/homebrew/bin`. Use only tools present on a stock macOS system; no Homebrew dependency, no `jq`.
- The busy predicate is exactly `projection_turns.state = 'running'` OR `projection_pending_approvals.resolved_at IS NULL`, gated on T3 Code's server PID being alive.
- `projection_threads.pending_user_input_count` and `has_actionable_proposed_plan` must never influence the decision; they are post-turn states.
- Re-sign the applet with `codesign --force --sign -` after every `Info.plist` edit. `osacompile` ad-hoc signs the bundle and editing the plist invalidates that signature.
- Default identifiers: bundle `dev.newedia.t3-busy`, LaunchAgent label `dev.newedia.t3-awake`, applet `~/Applications/T3 Busy.app`.
- Do not stage the unrelated working-tree changes in `fish/conf.d/00-paths.fish`, `nvim/lazy-lock.json`, or `.claude/`.

---

## File Structure

- **Create:** `bin/t3_awake` — the whole daemon: configuration, busy predicate, sentinel lifecycle, watch loop, status, install, uninstall.
- **Create:** `amphetamine/t3-busy.applescript` — sentinel applet source.
- **Create:** `amphetamine/dev.newedia.t3-awake.plist` — LaunchAgent template with substitution placeholders.
- **Create:** `amphetamine/README.md` — the one manual Amphetamine step and the disposition of the two existing triggers.
- **Create:** `tests/bin/t3_awake_test.fish` — dependency-free Fish test runner driving `bin/t3_awake` through its CLI against scratch fixtures.
- **Modify:** `bin/bootstrap` — install the LaunchAgent during setup.
- **Modify:** `SYSTEM.md` — correct the claim that all user LaunchAgents are app-generated.

## Defined Interfaces

`bin/t3_awake` exposes these subcommands. `probe` and `sentinel` exist so the Fish tests can drive the logic without launchd or a real thread.

```text
bin/t3_awake probe                 # prints "busy" or "idle"; always exits 0
bin/t3_awake sentinel build        # compile + patch + sign the applet
bin/t3_awake sentinel up           # launch the applet (idempotent)
bin/t3_awake sentinel down         # SIGTERM the applet, wait for exit (idempotent)
bin/t3_awake sentinel state        # prints "running" or "stopped"
bin/t3_awake watch                 # the daemon loop; what launchd runs
bin/t3_awake status                # human-readable diagnostic dump
bin/t3_awake install [--dry-run]   # build applet, write + bootstrap LaunchAgent
bin/t3_awake uninstall             # bootout, remove plist, stop + remove applet
```

Environment overrides, all read at startup:

| Variable | Default |
| --- | --- |
| `T3_AWAKE_DB` | `$HOME/.t3/userdata/state.sqlite` |
| `T3_AWAKE_RUNTIME_JSON` | `$HOME/.t3/userdata/server-runtime.json` |
| `T3_AWAKE_APP` | `$HOME/Applications/T3 Busy.app` |
| `T3_AWAKE_POLL` | `2` |
| `T3_AWAKE_IDLE_POLL` | `15` |
| `T3_AWAKE_LINGER` | `30` |
| `T3_AWAKE_LOG` | `$HOME/Library/Logs/t3-awake.log` |

`probe` always exiting 0 is load-bearing, not incidental: together with `status` and `uninstall` it is the recovery path a user reaches for when the machine is stuck awake. Nothing outside `watch` may reject its input and exit non-zero — in particular, the interval knobs are validated inside `cmd_watch` and nowhere else.

Internal return-code contract, relied on by the watch loop:

- `t3_server_alive` — 0 alive, 1 dead or unreadable.
- `db_busy` — 0 busy, 1 idle, 2 unreadable or query error.
- `sentinel_up` / `sentinel_down` — 0 reached the requested state, 1 did not.

---

### Task 1: The busy predicate and the Fish test harness

**Files:**
- Create: `bin/t3_awake`
- Test: `tests/bin/t3_awake_test.fish`

**Interfaces:**
- Consumes: nothing.
- Produces: `bin/t3_awake probe` printing `busy` or `idle`; the shell functions `t3_server_alive`, `db_busy`, `t3_probe`, `log`; the environment-variable contract above.

- [ ] **Step 1: Write the failing test**

Create `tests/bin/t3_awake_test.fish`:

```fish
#!/usr/bin/env fish
# Tests for bin/t3_awake. Run: fish tests/bin/t3_awake_test.fish

set -g repo (path resolve (status dirname)/../..)
set -g bin $repo/bin/t3_awake
set -g failures 0
set -g checks 0
set -g workdir (mktemp -d /tmp/t3-awake-test.XXXXXX)

# Every invocation that can write a log line must be given this. Overriding only
# T3_AWAKE_APP still leaves T3_AWAKE_LOG at its default, and ~/Library/Logs/
# t3-awake.log is the first file you read when the machine is stuck awake — the
# suite must not fill it with lines about deleted temp paths.
set -g log_env T3_AWAKE_LOG=$workdir/sentinel.log

# Daemons and applets started by the suite. Removing $workdir is not enough: if
# the run aborts between starting a watch daemon and stopping it, the orphan and
# its applet survive — leaking exactly the process that pins the machine awake.
set -g watch_pids
set -g sentinel_apps

function teardown --on-event fish_exit
    for pid in $watch_pids
        kill -TERM $pid 2>/dev/null
    end
    for stray in $sentinel_apps
        env $log_env T3_AWAKE_APP=$stray $bin sentinel down >/dev/null 2>&1
    end
    test -n "$workdir"; and rm -rf $workdir
end

function check --argument-names label expected actual
    set -g checks (math $checks + 1)
    if test "$expected" = "$actual"
        printf 'ok   %s\n' $label
    else
        set -g failures (math $failures + 1)
        printf 'FAIL %s\n       expected: %s\n       actual:   %s\n' $label $expected $actual
    end
end

# Build a scratch database with only the two tables the predicate reads,
# plus a runtime file naming a PID that is guaranteed to be alive.
function make_fixture --argument-names dir
    mkdir -p $dir
    sqlite3 $dir/state.sqlite "CREATE TABLE projection_turns (thread_id TEXT NOT NULL, turn_id TEXT, state TEXT NOT NULL, requested_at TEXT NOT NULL, completed_at TEXT);
CREATE TABLE projection_pending_approvals (request_id TEXT PRIMARY KEY, thread_id TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, resolved_at TEXT);"
    printf '{"version":1,"pid":%d,"host":"127.0.0.1","port":3773}\n' $fish_pid >$dir/server-runtime.json
end

# Production runs journal_mode=WAL, while a plain sqlite3 database is
# journal_mode=delete. This variant exercises the mode the daemon really meets.
function make_wal_fixture --argument-names dir
    make_fixture $dir
    sqlite3 $dir/state.sqlite "PRAGMA journal_mode=WAL;" >/dev/null
end

function probe --argument-names dir
    env T3_AWAKE_DB=$dir/state.sqlite T3_AWAKE_RUNTIME_JSON=$dir/server-runtime.json $bin probe
end

# --- predicate ---------------------------------------------------------

set d $workdir/predicate
make_fixture $d

check "empty database is idle" idle (probe $d)

sqlite3 $d/state.sqlite "INSERT INTO projection_turns VALUES ('t1','turn1','running','2026-08-01T00:00:00Z',NULL);"
check "running turn is busy" busy (probe $d)

sqlite3 $d/state.sqlite "UPDATE projection_turns SET state='completed', completed_at='2026-08-01T00:01:00Z';"
check "completed turn is idle" idle (probe $d)

sqlite3 $d/state.sqlite "INSERT INTO projection_pending_approvals VALUES ('r1','t1','pending','2026-08-01T00:02:00Z',NULL);"
check "unresolved approval is busy" busy (probe $d)

sqlite3 $d/state.sqlite "UPDATE projection_pending_approvals SET resolved_at='2026-08-01T00:03:00Z';"
check "resolved approval is idle" idle (probe $d)

# --- liveness gate -----------------------------------------------------

set dead $workdir/dead
make_fixture $dead
sqlite3 $dead/state.sqlite "INSERT INTO projection_turns VALUES ('t1','turn1','running','2026-08-01T00:00:00Z',NULL);"
printf '{"version":1,"pid":999999,"host":"127.0.0.1","port":3773}\n' >$dead/server-runtime.json
check "running turn with dead server is idle" idle (probe $dead)

printf 'not json at all\n' >$dead/server-runtime.json
check "unparseable runtime file is idle" idle (probe $dead)

# --- degraded inputs ---------------------------------------------------

set missing $workdir/missing
make_fixture $missing
rm $missing/state.sqlite
check "missing database is idle" idle (probe $missing)

set empty $workdir/empty
make_fixture $empty
rm $empty/state.sqlite
sqlite3 $empty/state.sqlite "CREATE TABLE unrelated (x INTEGER);"
check "database without the projection tables is idle" idle (probe $empty)
# --- summary -----------------------------------------------------------

printf '\n%d checks, %d failures\n' $checks $failures
test $failures -eq 0
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: FAIL — every check errors because `bin/t3_awake` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

Create `bin/t3_awake`:

```bash
#!/usr/bin/env bash
# Hold an Amphetamine trigger session while a T3 Code thread is actively working.
#
# The daemon reads T3 Code's own orchestration projections read-only and
# reflects "a turn is running" by opening or terminating a dockless sentinel
# application. A native Amphetamine trigger keyed to that application supplies
# the wake session; Amphetamine's own session state is never scripted.

set -euo pipefail

DB="${T3_AWAKE_DB:-$HOME/.t3/userdata/state.sqlite}"
RUNTIME_JSON="${T3_AWAKE_RUNTIME_JSON:-$HOME/.t3/userdata/server-runtime.json}"
APP="${T3_AWAKE_APP:-$HOME/Applications/T3 Busy.app}"
POLL="${T3_AWAKE_POLL:-2}"
IDLE_POLL="${T3_AWAKE_IDLE_POLL:-15}"
LINGER="${T3_AWAKE_LINGER:-30}"
LOG="${T3_AWAKE_LOG:-$HOME/Library/Logs/t3-awake.log}"

# launchd holds its own descriptor on StandardErrorPath at its own offset. If it
# pointed at LOG, every truncation in log() would leave launchd writing past the
# new end of file and re-inflating it with NUL padding, so stderr gets its own
# file. It follows LOG so an override still keeps the pair together.
ERRLOG="${LOG%.log}.err"

BUNDLE_ID="dev.newedia.t3-busy"
LABEL="dev.newedia.t3-awake"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Tracks the backgrounded poll sleep so a signal handler can interrupt it.
SLEEP_PID=""

# Set while sentinel_up is failing, so a persistent failure logs once per
# episode rather than once per poll.
SENTINEL_FAIL_LOGGED=0

log() {
	local ts
	ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
	mkdir -p "$(dirname "$LOG")"
	if [ -f "$LOG" ] && [ "$(stat -f %z "$LOG")" -gt 1048576 ]; then
		: >"$LOG"
	fi
	printf '%s %s\n' "$ts" "$*" >>"$LOG"
}

# 0 alive, 1 dead or unreadable.
t3_server_alive() {
	local pid
	if [ ! -r "$RUNTIME_JSON" ]; then
		return 1
	fi
	pid="$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$RUNTIME_JSON" | head -1)"
	if [ -z "$pid" ]; then
		return 1
	fi
	kill -0 "$pid" 2>/dev/null
}

# 0 busy, 1 idle, 2 unreadable or query error.
db_busy() {
	local out
	if [ ! -r "$DB" ]; then
		return 2
	fi
	if ! out="$(sqlite3 -readonly -cmd '.timeout 1000' "$DB" \
		"SELECT EXISTS(SELECT 1 FROM projection_turns WHERE state = 'running')
		     OR EXISTS(SELECT 1 FROM projection_pending_approvals WHERE resolved_at IS NULL);" 2>/dev/null)"; then
		return 2
	fi
	if [ "$out" = "1" ]; then
		return 0
	fi
	return 1
}

t3_probe() {
	if ! t3_server_alive; then
		printf 'idle\n'
		return 0
	fi
	if db_busy; then
		printf 'busy\n'
	else
		printf 'idle\n'
	fi
	return 0
}

usage() {
	cat <<'EOF'
usage: bin/t3_awake <command>

  probe                 Print "busy" or "idle" for the current state.
  sentinel <build|up|down|state>
                        Manage the marker application directly.
  watch                 Run the daemon loop (what launchd runs).
  status                Print a diagnostic summary.
  install [--dry-run]   Build the applet and load the LaunchAgent.
  uninstall             Remove the LaunchAgent and the applet.
EOF
}

main() {
	case "${1:-}" in
	probe) t3_probe ;;
	-h | --help | help | '') usage ;;
	*)
		printf 'unknown command: %s\n' "$1" >&2
		usage >&2
		return 64
		;;
	esac
}

main "$@"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x bin/t3_awake && fish tests/bin/t3_awake_test.fish`
Expected: `9 checks, 0 failures`, exit 0.

- [ ] **Step 5: Sanity-check against the real database**

Run: `bin/t3_awake probe`
Expected: `busy` while a T3 Code turn is running, `idle` when none is. Compare against the raw count:

```bash
sqlite3 -readonly ~/.t3/userdata/state.sqlite \
  "SELECT COUNT(*) FROM projection_turns WHERE state='running';"
```

- [ ] **Step 6: Commit**

```bash
git add bin/t3_awake tests/bin/t3_awake_test.fish
git commit -m 'feat(t3-awake): add T3 Code turn-activity predicate'
```

---

### Task 2: The sentinel application

**Files:**
- Create: `amphetamine/t3-busy.applescript`
- Modify: `bin/t3_awake` — add `sentinel_exec`, `sentinel_pattern`, `sentinel_running`, `sentinel_fail`, `sentinel_up`, `sentinel_down`, `sentinel_build`, and the `sentinel` subcommand (`SENTINEL_FAIL_LOGGED` is declared with the other globals in Task 1)
- Test: `tests/bin/t3_awake_test.fish` — append the sentinel section

**Interfaces:**
- Consumes: `log` and the `APP` / `BUNDLE_ID` configuration from Task 1.
- Produces: `bin/t3_awake sentinel build|up|down|state`; the shell functions `sentinel_running`, `sentinel_up`, `sentinel_down` with the return-code contract above.

A stay-open AppleScript applet is required rather than a shell script in an `.app` bundle: only a real Cocoa application registers as an `NSRunningApplication`, which is the list Amphetamine's app trigger consults. This was verified on this machine — the compiled applet appears in System Events with `background only = true` once `LSUIElement` is set.

- [ ] **Step 1: Write the failing test**

Append to `tests/bin/t3_awake_test.fish`, immediately before the `# --- summary ---` block:

```fish
# --- sentinel ----------------------------------------------------------

set app $workdir/T3\ Busy\ Test.app
set -g sentinel_env $log_env T3_AWAKE_APP=$app

env $sentinel_env $bin sentinel build
set -a sentinel_apps $app
check "build produces a bundle" 0 (test -d $app; echo $status)
check "build hides the dock icon" true (/usr/libexec/PlistBuddy -c 'Print :LSUIElement' $app/Contents/Info.plist)
check "build sets the bundle identifier" dev.newedia.t3-busy (/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' $app/Contents/Info.plist)
check "build leaves a valid signature" 0 (codesign --verify $app 2>/dev/null; echo $status)

check "starts stopped" stopped (env $sentinel_env $bin sentinel state)

env $sentinel_env $bin sentinel up
check "up starts it" running (env $sentinel_env $bin sentinel state)

env $sentinel_env $bin sentinel up
check "up is idempotent" running (env $sentinel_env $bin sentinel state)

env $sentinel_env $bin sentinel down
check "down stops it" stopped (env $sentinel_env $bin sentinel state)

env $sentinel_env $bin sentinel down
check "down is idempotent" stopped (env $sentinel_env $bin sentinel state)

set absent $workdir/Nothing.app
check "up on a missing bundle fails" 1 (env $log_env T3_AWAKE_APP=$absent $bin sentinel up >/dev/null 2>&1; echo $status)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: the ten sentinel checks fail; `bin/t3_awake` exits 64 on the unknown `sentinel` command.

- [ ] **Step 3: Write the applet source**

Create `amphetamine/t3-busy.applescript`:

```applescript
-- T3 Busy: a marker application that does nothing but exist.
--
-- Amphetamine's app trigger watches for this bundle; bin/t3_awake launches and
-- terminates it as T3 Code turn activity starts and stops. The long idle return
-- keeps wakeups negligible.

on run
end run

on idle
	return 3600
end idle
```

- [ ] **Step 4: Write the sentinel implementation**

Add to `bin/t3_awake`, after `t3_probe`:

```bash
sentinel_exec() {
	printf '%s/Contents/MacOS/applet' "$APP"
}

# pgrep and pkill match their operand as an extended regular expression. An APP
# path holding regex metacharacters would match nothing, or be rejected outright
# as an invalid pattern; either way sentinel_running reports "stopped" for an
# applet that is genuinely running, and sentinel_down then returns success
# without having killed anything — leaving the machine pinned awake. Quote the
# path so it is matched literally.
sentinel_pattern() {
	sentinel_exec | sed 's/[][^$.*+?(){}|\]/\\&/g'
}

sentinel_running() {
	pgrep -f "$(sentinel_pattern)" >/dev/null 2>&1
}

# The watch loop reconciles on every poll, so a sentinel that cannot be started
# would otherwise write a log line every POLL seconds — turning a missing bundle
# into a log flood in the one file you read when the machine is stuck awake. Log
# the first failure of an episode and stay quiet until the sentinel comes up.
sentinel_fail() {
	if [ "$SENTINEL_FAIL_LOGGED" -eq 0 ]; then
		log "$1"
		SENTINEL_FAIL_LOGGED=1
	fi
	return 1
}

sentinel_up() {
	if sentinel_running; then
		SENTINEL_FAIL_LOGGED=0
		return 0
	fi
	if [ ! -d "$APP" ]; then
		sentinel_fail "sentinel missing at $APP"
		return 1
	fi
	if ! open "$APP" >/dev/null 2>&1; then
		sentinel_fail "failed to open sentinel at $APP"
		return 1
	fi
	local i
	for i in 1 2 3 4 5 6 7 8 9 10; do
		if sentinel_running; then
			SENTINEL_FAIL_LOGGED=0
			return 0
		fi
		sleep 0.5
	done
	sentinel_fail "sentinel did not appear after open"
	return 1
}

sentinel_down() {
	if ! sentinel_running; then
		return 0
	fi
	pkill -f "$(sentinel_pattern)" >/dev/null 2>&1 || true
	local i
	for i in 1 2 3 4 5 6 7 8 9 10; do
		if ! sentinel_running; then
			return 0
		fi
		sleep 0.5
	done
	# Repeating SIGTERM cannot win against an applet that ignores it, and the
	# loop would re-send it on every poll while Amphetamine holds the machine
	# awake. Escalate instead: an unkillable sentinel is a worse outcome than
	# an ungraceful one.
	log "sentinel ignored SIGTERM; escalating to SIGKILL"
	pkill -9 -f "$(sentinel_pattern)" >/dev/null 2>&1 || true
	for i in 1 2 3 4; do
		if ! sentinel_running; then
			return 0
		fi
		sleep 0.5
	done
	log "sentinel survived SIGKILL at $APP"
	return 1
}

# osacompile ad-hoc signs the bundle, and editing Info.plist invalidates that
# signature, so the bundle must be re-signed after patching.
sentinel_build() {
	local src="$REPO_DIR/amphetamine/t3-busy.applescript"
	if [ ! -r "$src" ]; then
		printf 'missing applet source: %s\n' "$src" >&2
		return 1
	fi
	sentinel_down || true
	mkdir -p "$(dirname "$APP")"
	rm -rf "$APP"
	# Both tools ad-hoc sign and announce "replacing existing signature" on
	# success, which is pure noise; but a codesign failure is what aborts an
	# install, so it must not be swallowed. Capture each and report only on
	# failure: quiet when it works, diagnosable when it does not.
	local out
	if ! out="$(osacompile -s -o "$APP" "$src" 2>&1)"; then
		printf 'failed to compile applet: %s\n%s\n' "$src" "$out" >&2
		return 1
	fi
	/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$APP/Contents/Info.plist" >/dev/null
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist" >/dev/null 2>&1 ||
		/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$APP/Contents/Info.plist" >/dev/null
	if ! out="$(codesign --force --sign - "$APP" 2>&1)"; then
		printf 'failed to sign applet: %s\n%s\n' "$APP" "$out" >&2
		return 1
	fi
}

cmd_sentinel() {
	case "${1:-}" in
	build) sentinel_build ;;
	up) sentinel_up ;;
	down) sentinel_down ;;
	state)
		if sentinel_running; then
			printf 'running\n'
		else
			printf 'stopped\n'
		fi
		;;
	*)
		printf 'usage: bin/t3_awake sentinel <build|up|down|state>\n' >&2
		return 64
		;;
	esac
}
```

Add the dispatch arm to `main`, before the `*)` case:

```bash
	sentinel)
		shift
		cmd_sentinel "$@"
		;;
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: `19 checks, 0 failures`, exit 0.

- [ ] **Step 6: Confirm no test applet leaked**

Run: `pgrep -fl 'T3 Busy' || echo 'none running'`
Expected: `none running`.

- [ ] **Step 7: Commit**

```bash
git add amphetamine/t3-busy.applescript bin/t3_awake tests/bin/t3_awake_test.fish
git commit -m 'feat(t3-awake): add dockless sentinel application'
```

---

### Task 3: The watch loop

**Files:**
- Modify: `bin/t3_awake` — add `watch_cleanup`, `validate_intervals`, `cmd_watch` and the dispatch arm
- Test: `tests/bin/t3_awake_test.fish` — append the watch, WAL, lockout, and interval-validation sections

**Interfaces:**
- Consumes: `t3_server_alive`, `db_busy`, `sentinel_up`, `sentinel_down`, `log` from Tasks 1 and 2.
- Produces: `bin/t3_awake watch`, the long-running process launchd supervises.

The loop reconciles the sentinel to the desired state on *every* poll, not only on a transition. The initial state is `unknown`, so a launchd restart mid-turn converges back to busy on the first iteration; and because the check repeats, an applet that dies on its own is noticed, and an applet started by anything else is quit rather than held for the life of the daemon. Only the log lines are gated on the transition, so the log records changes rather than every poll.

`validate_intervals` runs inside `cmd_watch`, not at top level. The knobs are the daemon's, and validating them for every subcommand made an exported bad value break `probe`, `status` and `uninstall` — turning the guard against a stranded applet into the reason a user could not clear one.

- [ ] **Step 1: Write the failing test**

Append to `tests/bin/t3_awake_test.fish`, immediately before the `# --- summary ---` block:

```fish
# --- watch loop --------------------------------------------------------

set wapp $workdir/T3\ Busy\ Watch.app
set w $workdir/watch
make_fixture $w
env $log_env T3_AWAKE_APP=$wapp $bin sentinel build
set -a sentinel_apps $wapp

function watch_env
    echo T3_AWAKE_DB=$w/state.sqlite
    echo T3_AWAKE_RUNTIME_JSON=$w/server-runtime.json
    echo T3_AWAKE_APP=$wapp
    echo T3_AWAKE_POLL=1
    echo T3_AWAKE_IDLE_POLL=1
    echo T3_AWAKE_LINGER=3
    echo T3_AWAKE_LOG=$w/t3-awake.log
end

env (watch_env) $bin watch &
set -g watch_pid $last_pid
set -a watch_pids $watch_pid
sleep 2
check "idle at rest" stopped (env T3_AWAKE_APP=$wapp $bin sentinel state)

sqlite3 $w/state.sqlite "INSERT INTO projection_turns VALUES ('t1','turn1','running','2026-08-01T00:00:00Z',NULL);"
sleep 3
check "running turn raises the sentinel" running (env T3_AWAKE_APP=$wapp $bin sentinel state)

sqlite3 $w/state.sqlite "UPDATE projection_turns SET state='completed';"
sleep 2
check "sentinel held during linger" running (env T3_AWAKE_APP=$wapp $bin sentinel state)

sleep 4
check "sentinel released after linger" stopped (env T3_AWAKE_APP=$wapp $bin sentinel state)

# A dead server must release even while the database still says running.
sqlite3 $w/state.sqlite "UPDATE projection_turns SET state='running';"
sleep 3
check "reacquired for the stale-guard case" running (env T3_AWAKE_APP=$wapp $bin sentinel state)
printf '{"version":1,"pid":999999}\n' >$w/server-runtime.json
sleep 6
check "dead server releases despite running row" stopped (env T3_AWAKE_APP=$wapp $bin sentinel state)

# SIGTERM must not strand a running sentinel.
printf '{"version":1,"pid":%d}\n' $fish_pid >$w/server-runtime.json
sleep 3
check "reacquired before shutdown test" running (env T3_AWAKE_APP=$wapp $bin sentinel state)
kill -TERM $watch_pid
sleep 3
check "SIGTERM lowers the sentinel" stopped (env T3_AWAKE_APP=$wapp $bin sentinel state)
check "watch exited" 1 (kill -0 $watch_pid 2>/dev/null; echo $status)

# --- watch loop against a WAL database ----------------------------------
#
# Every other fixture is journal_mode=delete, which is not what the daemon meets
# in production. Drive the same raise/release transitions through a real WAL
# database so the loop is proven against the mode it will actually run on.

set walapp $workdir/T3\ Busy\ Wal.app
set wal $workdir/wal
make_wal_fixture $wal
env $log_env T3_AWAKE_APP=$walapp $bin sentinel build
set -a sentinel_apps $walapp

# Read-write connection on purpose: a read-only one cannot open a WAL database
# that has no -shm yet, and this assertion is about the fixture, not the daemon.
check "wal fixture really is wal mode" wal (sqlite3 $wal/state.sqlite "PRAGMA journal_mode;")

function wal_env
    echo T3_AWAKE_DB=$wal/state.sqlite
    echo T3_AWAKE_RUNTIME_JSON=$wal/server-runtime.json
    echo T3_AWAKE_APP=$walapp
    echo T3_AWAKE_POLL=1
    echo T3_AWAKE_IDLE_POLL=1
    echo T3_AWAKE_LINGER=3
    echo T3_AWAKE_LOG=$wal/t3-awake.log
end

env (wal_env) $bin watch &
set -g wal_pid $last_pid
set -a watch_pids $wal_pid

sqlite3 $wal/state.sqlite "INSERT INTO projection_turns VALUES ('t1','turn1','running','2026-08-01T00:00:00Z',NULL);"
sleep 3
check "wal: running turn raises the sentinel" running (env T3_AWAKE_APP=$walapp $bin sentinel state)

sqlite3 $wal/state.sqlite "UPDATE projection_turns SET state='completed';"
sleep 6
check "wal: completed turn releases the sentinel" stopped (env T3_AWAKE_APP=$walapp $bin sentinel state)

# --- unreadable database mid-turn ---------------------------------------
#
# db_busy returns 2 when the database cannot be read. The loop must keep
# retrying, count five consecutive failures and fall back to idle. If anything
# ever stops that retry from running again, the sentinel stays up for the life
# of the server — the one failure direction the design forbids.

sqlite3 $wal/state.sqlite "UPDATE projection_turns SET state='running';"
sleep 3
check "raised before the database is locked out" running (env T3_AWAKE_APP=$walapp $bin sentinel state)

chmod 000 $wal/state.sqlite
sleep 12
check "unreadable database releases the sentinel" stopped (env T3_AWAKE_APP=$walapp $bin sentinel state)
chmod 644 $wal/state.sqlite

kill -TERM $wal_pid
sleep 2

# --- interval validation ------------------------------------------------
#
# A non-numeric interval wedges the linger comparison open, so the watch loop
# refuses to start on one. The validation belongs to the daemon alone: gating
# every subcommand on it meant an exported bad value broke `uninstall`, which is
# the one command that clears a stranded applet.

set vdir $workdir/validate
make_fixture $vdir

function validate_env
    echo $log_env
    echo T3_AWAKE_DB=$vdir/state.sqlite
    echo T3_AWAKE_RUNTIME_JSON=$vdir/server-runtime.json
    echo T3_AWAKE_APP=$workdir/Unbuilt.app
end

check "watch rejects a non-numeric interval" 78 (env (validate_env) T3_AWAKE_POLL=abc $bin watch >/dev/null 2>&1; echo $status)
check "watch rejects a zero interval" 78 (env (validate_env) T3_AWAKE_LINGER=0 $bin watch >/dev/null 2>&1; echo $status)

# Decimals are legal: these knobs feed `sleep`, which takes fractions. The
# fixture has no running turn, so the loop stays idle and never touches the
# unbuilt bundle; surviving two seconds is the assertion.
env (validate_env) T3_AWAKE_POLL=0.5 T3_AWAKE_IDLE_POLL=0.5 T3_AWAKE_LINGER=1 $bin watch &
set -g validate_pid $last_pid
set -a watch_pids $validate_pid
sleep 2
check "watch accepts a decimal interval" 0 (kill -0 $validate_pid 2>/dev/null; echo $status)
kill -TERM $validate_pid 2>/dev/null
sleep 1

# The recovery path must survive a bad value that is merely exported.
check "a bad interval does not break probe" idle (env T3_AWAKE_POLL=abc T3_AWAKE_DB=$missing/state.sqlite T3_AWAKE_RUNTIME_JSON=$missing/server-runtime.json $bin probe)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: the watch checks fail; `watch` is not yet a known command.

- [ ] **Step 3: Write the implementation**

Add to `bin/t3_awake`, after `cmd_sentinel`:

```bash
# Runs on every exit path, and takes down any applet that is registered by the
# time it runs. It cannot promise more than that: a signal arriving while
# sentinel_up is still waiting on LaunchServices lands before the applet has
# registered, so the first sentinel_down finds nothing to kill and returns
# success. The second pass, after a short pause, catches an applet that
# registers in that window. An applet that takes longer than the pause to appear
# can still outlive the daemon; `bin/t3_awake sentinel down` clears it.
watch_cleanup() {
	local rc=$?
	if [ -n "$SLEEP_PID" ]; then
		kill "$SLEEP_PID" 2>/dev/null || true
		SLEEP_PID=""
	fi
	sentinel_down || true
	sleep 1
	sentinel_down || true
	return "$rc"
}

# Only the watch loop consumes these, so only the watch loop is gated on them.
# Validating at top level instead made an exported bad value break `probe`,
# `status` and — the part that matters — `uninstall`, so the guard meant to stop
# a stranded applet became the reason the user could not clear one.
#
# Decimals are legal because POLL and IDLE_POLL feed `sleep`, which accepts
# fractions. Zero is not: it would spin the poll loop with no delay. A
# non-numeric value is the real hazard, because LINGER's arithmetic comparison
# would then error rather than evaluate false, and the guarding `if` swallows
# that — skipping the linger branch on every iteration so the sentinel never
# comes down.
validate_intervals() {
	local knob
	for knob in POLL IDLE_POLL LINGER; do
		case "${!knob}" in
		*[!0-9.]* | *.*.*) ;; # not a plain decimal number
		*[1-9]*) continue ;;  # a number, and not zero
		esac
		printf 'T3_AWAKE_%s must be a positive number, got: %s\n' "$knob" "${!knob}" >&2
		return 78
	done
}

cmd_watch() {
	local state want interval now last_busy fails rc cached linger_secs

	validate_intervals || return $?

	# LINGER is the one knob compared arithmetically, and `[ x -ge 2.5 ]` is an
	# error rather than a comparison. Floor it once to whole seconds — the same
	# granularity `date +%s` reports — so a fractional value cannot wedge the
	# release branch shut.
	linger_secs="${LINGER%%.*}"
	[ -n "$linger_secs" ] || linger_secs=0

	# EXIT covers every way out, not just the signals: a `set -e` abort inside
	# the loop would otherwise leave the applet running with Amphetamine holding
	# the machine awake, and launchd's KeepAlive would not rescue it because the
	# respawned process dies before it can reconcile. The signal handlers only
	# exit; EXIT performs the single cleanup, so nothing runs twice and the
	# status is preserved.
	trap 'watch_cleanup' EXIT
	trap 'exit 0' TERM INT HUP

	state="unknown"
	cached="idle"
	last_busy=0
	fails=0

	log "watch started (poll=${POLL}s idle=${IDLE_POLL}s linger=${LINGER}s)"

	while :; do
		if t3_server_alive; then
			interval="$POLL"
			# Queried unconditionally on every poll. An earlier revision
			# short-circuited on the mtime of state.sqlite-wal, which could
			# latch the busy state permanently: the change signal was consumed
			# before the query result was known, so a transient error stopped
			# the retry from ever running again, and the second-granular mtime
			# could miss a commit landing in the same second. Two EXISTS
			# probes against small projections cost single-digit milliseconds,
			# which buys nothing worth that risk.
			rc=0
			db_busy || rc=$?
			case "$rc" in
			0)
				cached="busy"
				fails=0
				;;
			1)
				cached="idle"
				fails=0
				;;
			*)
				fails=$((fails + 1))
				# Logged the first time the threshold is crossed, whatever
				# the cached state was. Gating this on `cached != idle`
				# hid the case that matters most: a T3 Code upgrade that
				# renames a table or column breaks the query permanently,
				# and a daemon restarting after that upgrade is already
				# idle — so the feature would be dead forever with an
				# empty log to diagnose it from. "Failed" rather than
				# "unreadable", because a schema break is not an
				# unreadable file and the wrong word sends the reader
				# after the wrong cause. `-eq` keeps it to one line per
				# failure episode; `fails` resets on the next success.
				if [ "$fails" -eq 5 ]; then
					log "busy query failed for $fails consecutive polls; falling back to idle"
				fi
				if [ "$fails" -ge 5 ]; then
					cached="idle"
				fi
				;;
			esac
			want="$cached"
		else
			interval="$IDLE_POLL"
			want="idle"
			cached="idle"
			fails=0
		fi

		now="$(date +%s)"
		if [ "$want" = "busy" ]; then
			last_busy="$now"
		fi

		# Reconciled on every poll rather than only on a transition. Both
		# helpers are idempotent and cost one pgrep, and a cached state that
		# is never re-checked drifts from reality in both directions: an
		# applet that dies on its own leaves the daemon believing the machine
		# is still held awake, and an applet started by anything else — a
		# stranded instance, or macOS reopening it at login — is held up for
		# as long as the daemon runs. That second direction is the one the
		# design forbids. Only the log lines stay gated on the transition, so
		# the log still records changes and not every poll.
		if [ "$want" = "busy" ]; then
			if sentinel_up; then
				if [ "$state" != "busy" ]; then
					log "busy: sentinel up"
				fi
				state="busy"
			fi
		elif [ $((now - last_busy)) -ge "$linger_secs" ]; then
			if sentinel_down; then
				if [ "$state" != "idle" ]; then
					log "idle: sentinel down after ${LINGER}s linger"
				fi
				state="idle"
			fi
		fi

		# Bash defers a caught signal until the running foreground child exits,
		# and the sleep process does not receive the signal itself. A plain
		# sleep would therefore delay shutdown by up to IDLE_POLL seconds —
		# past launchd's SIGTERM-to-SIGKILL grace window, where a SIGKILL
		# would leave the applet running with nothing left to clean it up.
		# Backgrounding the sleep and waiting on it makes the trap fire at
		# once; watch_cleanup kills the child so no orphan is left behind.
		sleep "$interval" &
		SLEEP_PID=$!
		wait "$SLEEP_PID" || true
		SLEEP_PID=""
	done
}
```

Add the dispatch arm to `main`, before the `*)` case:

```bash
	watch) cmd_watch ;;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: `37 checks, 0 failures`, exit 0. The watch, WAL, and lockout sections together take roughly 70 seconds.

- [ ] **Step 5: Confirm no watch process or applet leaked**

Run: `pgrep -fl 't3_awake watch' || echo 'no watchers'; pgrep -fl 'T3 Busy' || echo 'no sentinels'`
Expected: `no watchers` and `no sentinels`.

- [ ] **Step 6: Commit**

```bash
git add bin/t3_awake tests/bin/t3_awake_test.fish
git commit -m 'feat(t3-awake): add the activity watch loop'
```

---

### Task 4: Status, install, uninstall, and the LaunchAgent

**Files:**
- Create: `amphetamine/dev.newedia.t3-awake.plist`
- Modify: `bin/t3_awake` — add `cmd_status`, `cmd_install`, `cmd_uninstall` and their dispatch arms
- Test: `tests/bin/t3_awake_test.fish` — append the install section

**Interfaces:**
- Consumes: everything from Tasks 1 to 3.
- Produces: `bin/t3_awake status`, `install [--dry-run]`, `uninstall`; the installed LaunchAgent `dev.newedia.t3-awake`.

`install --dry-run` prints each mutation it would perform, one per line, so the test can assert the plan without touching `~/Library/LaunchAgents` or the live launchd domain.

- [ ] **Step 1: Write the failing test**

Append to `tests/bin/t3_awake_test.fish`, immediately before the `# --- summary ---` block:

```fish
# --- plist template and install planning -------------------------------

check "template is valid plist" 0 (plutil -lint $repo/amphetamine/dev.newedia.t3-awake.plist >/dev/null 2>&1; echo $status)

set dry (env T3_AWAKE_APP=$workdir/Dry.app $bin install --dry-run)
check "dry run plans the applet build" 1 (printf '%s\n' $dry | grep -c '^would build applet')
check "dry run plans the plist write" 1 (printf '%s\n' $dry | grep -c '^would write .*dev\.newedia\.t3-awake\.plist')
check "dry run plans the bootstrap" 1 (printf '%s\n' $dry | grep -c '^would bootstrap gui/')
check "dry run creates nothing" 1 (test -d $workdir/Dry.app; echo $status)

# A mistyped flag used to fall through to a real install, which builds the
# applet, writes ~/Library/LaunchAgents and boots it.
check "install rejects an unknown argument" 64 (env $log_env T3_AWAKE_APP=$workdir/Typo.app $bin install --dryrun >/dev/null 2>&1; echo $status)
check "a rejected install builds nothing" 1 (test -d $workdir/Typo.app; echo $status)

# Asserting a field rather than the exit status: a `status` that printed nothing
# at all would still exit 0.
set st (env $log_env T3_AWAKE_APP=$workdir/None.app $bin status 2>/dev/null)
set st_rc $status
check "status exits cleanly" 0 $st_rc
check "status reports the sentinel state" stopped (printf '%s\n' $st | sed -n 's/^sentinel: *//p')
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: the nine new checks fail; the template does not exist and `install` is unknown.

- [ ] **Step 3: Write the LaunchAgent template**

Create `amphetamine/dev.newedia.t3-awake.plist`. `__T3_AWAKE_BIN__` and `__T3_AWAKE_ERR__` are substituted at install time:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>dev.newedia.t3-awake</string>
	<key>ProgramArguments</key>
	<array>
		<string>__T3_AWAKE_BIN__</string>
		<string>watch</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<!-- Deliberately not the daemon's own log. log() truncates that file past
	     1 MB, and launchd keeps its own descriptor at its own offset, so its
	     next write after a truncation would re-inflate the file with NUL
	     padding. -->
	<key>StandardErrorPath</key>
	<string>__T3_AWAKE_ERR__</string>
</dict>
</plist>
```

- [ ] **Step 4: Write the implementation**

Add to `bin/t3_awake`, after `cmd_watch`:

```bash
plist_target() {
	printf '%s/Library/LaunchAgents/%s.plist' "$HOME" "$LABEL"
}

cmd_status() {
	local running approvals
	running='?'
	approvals='?'
	if [ -r "$DB" ]; then
		running="$(sqlite3 -readonly -cmd '.timeout 1000' "$DB" \
			"SELECT COUNT(*) FROM projection_turns WHERE state='running';" 2>/dev/null || echo '?')"
		approvals="$(sqlite3 -readonly -cmd '.timeout 1000' "$DB" \
			"SELECT COUNT(*) FROM projection_pending_approvals WHERE resolved_at IS NULL;" 2>/dev/null || echo '?')"
	fi

	printf 'database:        %s\n' "$DB"
	printf 'running turns:   %s\n' "$running"
	printf 'open approvals:  %s\n' "$approvals"
	if t3_server_alive; then
		printf 'T3 Code server:  alive\n'
	else
		printf 'T3 Code server:  down\n'
	fi
	printf 'sentinel:        %s\n' "$(cmd_sentinel state)"
	printf 'desired state:   %s\n' "$(t3_probe)"
	printf 'launch agent:    %s\n' \
		"$(launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1 && echo loaded || echo 'not loaded')"
	printf 'amphetamine:     session=%s trigger=%s\n' \
		"$(osascript -e 'tell application "Amphetamine" to session is active' 2>/dev/null || echo '?')" \
		"$(osascript -e 'tell application "Amphetamine" to session is Trigger' 2>/dev/null || echo '?')"
}

cmd_install() {
	local dry=0 template target
	# Anything that was not exactly --dry-run used to fall through to a real
	# install, so `install --dryrun` built the applet, wrote the LaunchAgent
	# and booted it — the opposite of what the typo asked for.
	case "$#:${1:-}" in
	0:) ;;
	1:--dry-run) dry=1 ;;
	*)
		printf 'usage: bin/t3_awake install [--dry-run]\n' >&2
		return 64
		;;
	esac
	template="$REPO_DIR/amphetamine/$LABEL.plist"
	target="$(plist_target)"

	if [ ! -r "$template" ]; then
		printf 'missing LaunchAgent template: %s\n' "$template" >&2
		return 1
	fi

	if [ "$dry" -eq 1 ]; then
		printf 'would build applet at %s\n' "$APP"
		printf 'would write %s\n' "$target"
		printf 'would bootstrap gui/%s from %s\n' "$(id -u)" "$target"
		return 0
	fi

	sentinel_build
	mkdir -p "$(dirname "$target")"
	sed -e "s|__T3_AWAKE_BIN__|$REPO_DIR/bin/t3_awake|g" \
		-e "s|__T3_AWAKE_ERR__|$ERRLOG|g" \
		"$template" >"$target"

	launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
	launchctl bootstrap "gui/$(id -u)" "$target"

	cat <<EOF

Installed. One manual step remains, because Amphetamine's trigger list cannot
be written safely from outside the app:

  1. Open Amphetamine -> Preferences -> Triggers.
  2. Add a trigger for a running application, name it "t3-busy", and select:
       $APP
  3. Leave the frontmost requirement OFF, and allow display sleep ON.
  4. Delete the existing "t3" and "claude" triggers.

Verify with:  bin/t3_awake status
EOF
}

cmd_uninstall() {
	local target
	target="$(plist_target)"
	launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
	rm -f "$target"
	sentinel_down || true
	rm -rf "$APP"
	printf 'Removed the LaunchAgent and the applet.\n'
	printf 'Delete the "t3-busy" trigger in Amphetamine -> Preferences -> Triggers.\n'
}
```

Add the dispatch arms to `main`, before the `*)` case:

```bash
	status) cmd_status ;;
	install)
		shift
		cmd_install "$@"
		;;
	uninstall) cmd_uninstall ;;
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: `46 checks, 0 failures`, exit 0. That is the whole suite; no later task adds checks.

- [ ] **Step 6: Commit**

```bash
git add amphetamine/dev.newedia.t3-awake.plist bin/t3_awake tests/bin/t3_awake_test.fish
git commit -m 'feat(t3-awake): add status, install, and uninstall'
```

---

### Task 5: Documentation and bootstrap integration

**Files:**
- Create: `amphetamine/README.md`
- Modify: `bin/bootstrap`
- Modify: `SYSTEM.md:153`

**Interfaces:**
- Consumes: `bin/t3_awake install` from Task 4.
- Produces: no new code interfaces.

- [ ] **Step 1: Write the component README**

Create `amphetamine/README.md`:

```markdown
# Amphetamine

Keeps this Mac awake while a T3 Code thread is actively working, rather than
while the T3 Code window merely happens to be frontmost.

## How it works

`bin/t3_awake watch` runs as the LaunchAgent `dev.newedia.t3-awake`. It reads
T3 Code's orchestration projections in `~/.t3/userdata/state.sqlite` read-only
and treats the machine as busy when a turn is running or an approval is
unresolved, gated on T3 Code's server process being alive.

When busy it launches `~/Applications/T3 Busy.app`, a dockless do-nothing
applet compiled from `t3-busy.applescript`, and it terminates that applet once
the work has been done for 30 seconds — which is what ends the wake session. An
Amphetamine trigger keyed to that application supplies the session. Amphetamine's
own session state is never scripted, so manual sessions and other triggers are
unaffected.

Because the signal comes from T3 Code's orchestration layer rather than from an
agent CLI, it covers every provider driver — `claudeAgent`, `codex`, `cursor`,
`opencode`, `grok` — without per-driver integration.

## Setup

```bash
bin/t3_awake install
```

Then, in Amphetamine -> Preferences -> Triggers:

1. Add a trigger for a running application, name it `t3-busy`, and select
   `~/Applications/T3 Busy.app`. The name is what the uninstall step and
   `bin/bootstrap` refer to.
2. Leave the frontmost requirement off; allow display sleep on.
3. Delete the `t3` trigger. It fires whenever T3 Code is frontmost, which is the
   false positive this replaces.
4. Delete the `claude` trigger. The `claude` CLI is not an `NSWorkspace`
   application, so that trigger has never fired.

## Checking it

```bash
bin/t3_awake status     # turns, approvals, sentinel, Amphetamine session
bin/t3_awake probe      # just "busy" or "idle"
tail -f ~/Library/Logs/t3-awake.log   # transitions and error conditions
tail -f ~/Library/Logs/t3-awake.err   # launchd's stderr for the agent
fish tests/bin/t3_awake_test.fish
```

The two files are separate on purpose: the daemon truncates its own log past
1 MB, and launchd writing into that same file at its own offset would re-inflate
it with NUL padding.

## Removing it

```bash
bin/t3_awake uninstall
```

Then delete the `t3-busy` trigger in Amphetamine.
```

- [ ] **Step 2: Add the bootstrap step**

In `bin/bootstrap`, insert this block immediately after the Legcord settings block and immediately before `printf '\n==> Repository hooks\n'`. It follows the file's existing section idiom, so `--dry-run` keeps working and a failure warns instead of aborting:

```bash
printf '\n==> T3 Code activity trigger\n'
if [[ "$DRY_RUN" -eq 1 ]]; then
	quote_command "$REPO_ROOT/bin/t3_awake" install
elif ! "$REPO_ROOT/bin/t3_awake" install; then
	warn "t3_awake install failed; run bin/t3_awake install again after launching T3 Code once"
fi
```

In the same file's closing `cat <<'EOF'` block, add this line to the remaining-steps list, after the `bin/agents_link all` line:

```text
  - Add the "t3-busy" trigger in Amphetamine -> Preferences -> Triggers (see amphetamine/README.md).
```

In `README.md`, the bootstrap list currently ends:

```markdown
6. Installs Claude Code, projects shared agent rules/skills/subagents/hooks into every installed harness, enables the gitleaks hook, and installs Fisher plugins.
7. Optionally applies macOS defaults and starts the Herdr service.
```

Replace those two lines with:

```markdown
6. Installs Claude Code, projects shared agent rules/skills/subagents/hooks into every installed harness, enables the gitleaks hook, and installs Fisher plugins.
7. Installs the `dev.newedia.t3-awake` LaunchAgent, which keeps the Mac awake while a T3 Code thread is working.
8. Optionally applies macOS defaults and starts the Herdr service.
```

- [ ] **Step 3: Correct SYSTEM.md**

`SYSTEM.md:153` currently reads:

```markdown
- User LaunchAgents were app-generated (Google updater, Riot client, Herdr), not hand-authored automation to preserve.
```

Replace it with:

```markdown
- User LaunchAgents were app-generated at snapshot time (Google updater, Riot client, Herdr). `dev.newedia.t3-awake` is this repository's own hand-authored agent, installed by `bin/t3_awake install`; see `amphetamine/README.md`.
```

- [ ] **Step 4: Verify bootstrap still parses and dry-runs**

Run: `bash -n bin/bootstrap && bin/bootstrap --dry-run 2>&1 | grep t3_awake`
Expected: no syntax errors, and one `would run: .../bin/t3_awake install` line.

- [ ] **Step 5: Commit**

```bash
git add amphetamine/README.md bin/bootstrap README.md SYSTEM.md
git commit -m 'docs(t3-awake): document setup and wire into bootstrap'
```

---

### Task 6: Live verification and schema confirmation

**Files:**
- Modify: `bin/t3_awake` or `docs/superpowers/specs/2026-08-01-t3-code-amphetamine-trigger-design.md` only if verification finds a discrepancy

**Interfaces:**
- Consumes: everything above.
- Produces: a verified installation, and confirmation of the two schema assumptions the spec flagged as unverified.

This task runs against the live machine and requires the Amphetamine UI step. Do not mark it complete on the strength of the unit tests — they use fixtures, not the real database or Amphetamine.

- [ ] **Step 1: Install and add the trigger**

Run `bin/t3_awake install`, then perform the Amphetamine steps it prints. Confirm the resulting trigger configuration:

```bash
defaults read com.if.Amphetamine "Trigger Data"
```

Expected: one entry with `App = "T3 Busy"`, `Enabled = 1`, `AllowDisplaySleep = 1`, and **no** `RequireAppFrontmost` key; and no remaining `t3` or `claude` entries. Amphetamine may buffer preference writes, so quit and reopen it before re-reading if the output looks stale.

- [ ] **Step 2: Verify the idle baseline**

With T3 Code open but no turn running:

```bash
bin/t3_awake status
```

Expected: `running turns: 0`, `sentinel: stopped`, `desired state: idle`, `launch agent: loaded`. Leave T3 Code frontmost and confirm the Mac is *not* held awake — this is the behavior change the whole plan exists for.

- [ ] **Step 3: Verify a running turn acquires the session**

Start a long-running turn in a T3 Code thread, then within a few seconds:

```bash
bin/t3_awake status
```

Expected: `running turns: 1`, `sentinel: running`, and `amphetamine: session=true trigger=true`.

- [ ] **Step 4: Verify release**

Let the turn finish, wait past the 30-second linger, then re-run `bin/t3_awake status`.
Expected: `sentinel: stopped`. If no other trigger is active, `session=false`.

- [ ] **Step 5: Verify a non-Claude driver**

Enable a second provider in T3 Code's settings, run a turn on it, and repeat Step 3. Expected: identical behavior, confirming the driver-agnostic claim. If no second driver can be enabled, record that in the commit message rather than silently skipping it.

- [ ] **Step 6: Verify the stale-turn guard**

Start a turn, then kill T3 Code's server process:

```bash
kill -9 "$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' ~/.t3/userdata/server-runtime.json | head -1)"
```

Expected: `bin/t3_awake status` shows `T3 Code server: down` and the sentinel stops within one poll, even though a `running` row remains. Restart T3 Code afterwards.

- [ ] **Step 7: Verify restart reconciliation**

Start a turn, then:

```bash
launchctl kickstart -k "gui/$(id -u)/dev.newedia.t3-awake"
```

Expected: the sentinel is running again within a few seconds, and `~/Library/Logs/t3-awake.log` shows a fresh `watch started` line followed by `busy: sentinel up`.

- [ ] **Step 8: Confirm the two unverified schema assumptions**

While an approval prompt is outstanding in a thread:

```bash
sqlite3 -readonly ~/.t3/userdata/state.sqlite \
  "SELECT status, resolved_at IS NULL FROM projection_pending_approvals ORDER BY created_at DESC LIMIT 3;"
sqlite3 -readonly ~/.t3/userdata/state.sqlite \
  "SELECT DISTINCT state FROM projection_turns;"
```

Expected: outstanding approvals have `resolved_at IS NULL` (value 1), confirming the predicate. If `projection_turns` shows any in-flight state beyond `running` — a queued or starting state — add it to the predicate in `db_busy`, extend the Task 1 tests to cover it, and update the spec's busy-determination section.

- [ ] **Step 9: Commit any corrections**

```bash
git add -A bin/t3_awake tests/bin/t3_awake_test.fish docs/superpowers/specs/2026-08-01-t3-code-amphetamine-trigger-design.md
git commit -m 'fix(t3-awake): reconcile predicate with observed T3 Code schema'
```

If verification found no discrepancies, skip the commit and note the clean result when reporting the task complete.
