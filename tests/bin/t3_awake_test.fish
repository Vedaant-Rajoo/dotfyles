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

# --- summary -----------------------------------------------------------

printf '\n%d checks, %d failures\n' $checks $failures
test $failures -eq 0
