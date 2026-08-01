#!/usr/bin/env fish
# Tests for bin/t3_awake. Run: fish tests/bin/t3_awake_test.fish

set -g repo (path resolve (status dirname)/../..)
set -g bin $repo/bin/t3_awake
set -g failures 0
set -g checks 0
set -g workdir (mktemp -d /tmp/t3-awake-test.XXXXXX)

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
        env T3_AWAKE_APP=$stray $bin sentinel down >/dev/null 2>&1
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

# --- sentinel ----------------------------------------------------------

set app $workdir/T3\ Busy\ Test.app
set -g sentinel_env T3_AWAKE_APP=$app

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
check "up on a missing bundle fails" 1 (env T3_AWAKE_APP=$absent $bin sentinel up >/dev/null 2>&1; echo $status)

# --- watch loop --------------------------------------------------------

set wapp $workdir/T3\ Busy\ Watch.app
set w $workdir/watch
make_fixture $w
env T3_AWAKE_APP=$wapp $bin sentinel build
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
env T3_AWAKE_APP=$walapp $bin sentinel build
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

# --- plist template and install planning -------------------------------

check "template is valid plist" 0 (plutil -lint $repo/amphetamine/dev.newedia.t3-awake.plist >/dev/null 2>&1; echo $status)

set dry (env T3_AWAKE_APP=$workdir/Dry.app $bin install --dry-run)
check "dry run plans the applet build" 1 (printf '%s\n' $dry | grep -c '^would build applet')
check "dry run plans the plist write" 1 (printf '%s\n' $dry | grep -c '^would write .*dev\.newedia\.t3-awake\.plist')
check "dry run plans the bootstrap" 1 (printf '%s\n' $dry | grep -c '^would bootstrap gui/')
check "dry run creates nothing" 1 (test -d $workdir/Dry.app; echo $status)

check "status runs cleanly" 0 (env T3_AWAKE_APP=$workdir/None.app $bin status >/dev/null 2>&1; echo $status)

# --- summary -----------------------------------------------------------

printf '\n%d checks, %d failures\n' $checks $failures
test $failures -eq 0
