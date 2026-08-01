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

function teardown --on-event fish_exit
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

BUNDLE_ID="dev.newedia.t3-busy"
LABEL="dev.newedia.t3-awake"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
- Modify: `bin/t3_awake` — add `sentinel_exec`, `sentinel_running`, `sentinel_up`, `sentinel_down`, `sentinel_build`, and the `sentinel` subcommand
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
set -g sentinel_env T3_AWAKE_APP=$app

env $sentinel_env $bin sentinel build
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
check "up on a missing bundle fails" 1 (env T3_AWAKE_APP=$absent $bin sentinel up >/dev/null 2>&1; echo $status)
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

sentinel_running() {
	pgrep -f "$(sentinel_exec)" >/dev/null 2>&1
}

sentinel_up() {
	if sentinel_running; then
		return 0
	fi
	if [ ! -d "$APP" ]; then
		log "sentinel missing at $APP"
		return 1
	fi
	if ! open "$APP" >/dev/null 2>&1; then
		log "failed to open sentinel at $APP"
		return 1
	fi
	local i
	for i in 1 2 3 4 5 6 7 8 9 10; do
		if sentinel_running; then
			return 0
		fi
		sleep 0.5
	done
	log "sentinel did not appear after open"
	return 1
}

sentinel_down() {
	if ! sentinel_running; then
		return 0
	fi
	pkill -f "$(sentinel_exec)" >/dev/null 2>&1 || true
	local i
	for i in 1 2 3 4 5 6 7 8 9 10; do
		if ! sentinel_running; then
			return 0
		fi
		sleep 0.5
	done
	log "sentinel did not exit after SIGTERM"
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
	osacompile -s -o "$APP" "$src"
	/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$APP/Contents/Info.plist" >/dev/null
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist" >/dev/null 2>&1 ||
		/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$APP/Contents/Info.plist" >/dev/null
	codesign --force --sign - "$APP" >/dev/null 2>&1
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
- Modify: `bin/t3_awake` — add `cmd_watch` and its dispatch arm
- Test: `tests/bin/t3_awake_test.fish` — append the watch section

**Interfaces:**
- Consumes: `t3_server_alive`, `db_busy`, `sentinel_up`, `sentinel_down`, `log` from Tasks 1 and 2.
- Produces: `bin/t3_awake watch`, the long-running process launchd supervises.

The loop reconciles on startup rather than assuming a clean slate: the initial state is `unknown`, so the first iteration always drives the sentinel to match the computed desired state. That is what makes a launchd restart mid-turn converge back to busy.

- [ ] **Step 1: Write the failing test**

Append to `tests/bin/t3_awake_test.fish`, immediately before the `# --- summary ---` block:

```fish
# --- watch loop --------------------------------------------------------

set wapp $workdir/T3\ Busy\ Watch.app
set w $workdir/watch
make_fixture $w
env T3_AWAKE_APP=$wapp $bin sentinel build

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
set -l watch_pid $last_pid
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: the watch checks fail; `watch` is not yet a known command.

- [ ] **Step 3: Write the implementation**

Add to `bin/t3_awake`, after `cmd_sentinel`:

```bash
cmd_watch() {
	local state want interval now last_busy fails rc wal_mtime prev_wal cached

	trap 'sentinel_down || true; exit 0' TERM INT

	state="unknown"
	cached="idle"
	prev_wal=""
	last_busy=0
	fails=0

	log "watch started (poll=${POLL}s idle=${IDLE_POLL}s linger=${LINGER}s)"

	while :; do
		if t3_server_alive; then
			interval="$POLL"
			wal_mtime="$(stat -f %m "$DB-wal" 2>/dev/null || echo 0)"
			if [ "$wal_mtime" != "$prev_wal" ] || [ "$state" = "unknown" ]; then
				prev_wal="$wal_mtime"
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
					if [ "$fails" -ge 5 ]; then
						if [ "$cached" != "idle" ]; then
							log "database unreadable for $fails polls; falling back to idle"
						fi
						cached="idle"
					fi
					;;
				esac
			fi
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

		if [ "$want" = "busy" ] && [ "$state" != "busy" ]; then
			if sentinel_up; then
				state="busy"
				log "busy: sentinel up"
			fi
		elif [ "$want" = "idle" ] && [ "$state" != "idle" ]; then
			if [ $((now - last_busy)) -ge "$LINGER" ]; then
				if sentinel_down; then
					state="idle"
					log "idle: sentinel down after ${LINGER}s linger"
				fi
			fi
		fi

		sleep "$interval"
	done
}
```

Add the dispatch arm to `main`, before the `*)` case:

```bash
	watch) cmd_watch ;;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: `28 checks, 0 failures`, exit 0. The watch section takes roughly 30 seconds.

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

check "status runs cleanly" 0 (env T3_AWAKE_APP=$workdir/None.app $bin status >/dev/null 2>&1; echo $status)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `fish tests/bin/t3_awake_test.fish`
Expected: the six new checks fail; the template does not exist and `install` is unknown.

- [ ] **Step 3: Write the LaunchAgent template**

Create `amphetamine/dev.newedia.t3-awake.plist`. `__T3_AWAKE_BIN__` and `__T3_AWAKE_LOG__` are substituted at install time:

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
	<key>StandardErrorPath</key>
	<string>__T3_AWAKE_LOG__</string>
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
	if [ "${1:-}" = "--dry-run" ]; then
		dry=1
	fi
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
		-e "s|__T3_AWAKE_LOG__|$LOG|g" \
		"$template" >"$target"

	launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
	launchctl bootstrap "gui/$(id -u)" "$target"

	cat <<EOF

Installed. One manual step remains, because Amphetamine's trigger list cannot
be written safely from outside the app:

  1. Open Amphetamine -> Preferences -> Triggers.
  2. Add a trigger for a running application and select:
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
Expected: `34 checks, 0 failures`, exit 0.

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
  - Add the "T3 Busy" trigger in Amphetamine -> Preferences -> Triggers (see amphetamine/README.md).
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
