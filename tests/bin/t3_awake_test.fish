#!/usr/bin/env fish
# Tests for bin/t3_awake. Run: fish tests/bin/t3_awake_test.fish

set -g repo (path resolve (status dirname)/../..)
set -g bin $repo/bin/t3_awake
set -g failures 0
set -g checks 0
set -g workdir (mktemp -d /tmp/t3-awake-test.XXXXXX)
set -g watch_pids
set -g state_files
set -g last_watch_pid

function teardown --on-event fish_exit
    for pid in $watch_pids
        kill -TERM $pid 2>/dev/null
    end
    for state in $state_files
        if test -r $state
            set -l child (awk 'NR == 1 { print $2 }' $state 2>/dev/null)
            string match -qr '^[1-9][0-9]*$' -- $child; and kill $child 2>/dev/null
        end
    end
    if string match -q '/tmp/t3-awake-test.*' -- $workdir
        rm -rf -- $workdir
    end
end

function check --argument-names label expected actual
    set -g checks (math $checks + 1)
    if test "$expected" = "$actual"
        printf 'ok   %s\n' $label
    else
        set -g failures (math $failures + 1)
        printf 'FAIL %s\n       expected: %s\n       actual:   %s\n' $label "$expected" "$actual"
    end
end

# Run a command until it succeeds, checking every delay seconds. Commands are
# passed as argv, so no eval or shell quoting is involved.
function wait_until --argument-names tries delay
    set -e argv[1..2]
    for ignored in (seq $tries)
        if $argv
            return 0
        end
        sleep $delay
    end
    return 1
end

function pid_alive
    kill -0 $argv[1] 2>/dev/null
end

function pid_gone
    not kill -0 $argv[1] 2>/dev/null
end

function file_absent
    not test -e $argv[1]
end

function wake_state_at
    env T3_AWAKE_STATE=$argv[1] bash -c 'source "$1"; wake_state' _ $bin
end

function state_is_active
    set -l actual (wake_state_at $argv[1])
    string match -q 'active*' -- $actual
end

function state_is_inactive
    test (wake_state_at $argv[1]) = inactive
end

function state_is_stale
    test (wake_state_at $argv[1]) = stale
end

function state_child
    awk 'NR == 1 { print $2 }' $argv[1]
end

function state_has_new_child
    set -l state $argv[1]
    set -l old $argv[2]
    state_is_active $state; or return 1
    set -l current (state_child $state)
    test -n "$current"; and test "$current" != "$old"
end

function child_has_idle_assertion
    /usr/bin/pmset -g assertions | awk -v pid=$argv[1] '
        index($0, "pid " pid "(caffeinate)") && index($0, "PreventUserIdleSystemSleep") { found = 1 }
        END { exit !found }
    '
end

function child_has_display_assertion
    /usr/bin/pmset -g assertions | awk -v pid=$argv[1] '
        index($0, "pid " pid "(caffeinate)") && index($0, "DisplaySleep") { found = 1 }
        END { exit !found }
    '
end

function direct_caffeinate_child_count
    /bin/ps -ww -axo ppid=,command= | awk -v parent=$argv[1] '
        $1 == parent {
            $1 = ""
            sub(/^[[:space:]]+/, "")
            if ($0 == "/usr/bin/caffeinate -i -w " parent) count++
        }
        END { print count + 0 }
    '
end

function make_fixture --argument-names dir
    mkdir -p $dir
    sqlite3 $dir/state.sqlite "CREATE TABLE projection_turns (thread_id TEXT NOT NULL, turn_id TEXT, state TEXT NOT NULL, requested_at TEXT NOT NULL, completed_at TEXT);
CREATE TABLE projection_pending_approvals (request_id TEXT PRIMARY KEY, thread_id TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL, resolved_at TEXT);"
    printf '{"version":1,"pid":%d,"host":"127.0.0.1","port":3773}\n' $fish_pid >$dir/server-runtime.json
end

function make_wal_fixture --argument-names dir
    make_fixture $dir
    sqlite3 $dir/state.sqlite 'PRAGMA journal_mode=WAL;' >/dev/null
end

function probe --argument-names dir
    env T3_AWAKE_DB=$dir/state.sqlite T3_AWAKE_RUNTIME_JSON=$dir/server-runtime.json $bin probe
end

function start_watch --argument-names dir state linger
    env T3_AWAKE_DB=$dir/state.sqlite \
        T3_AWAKE_RUNTIME_JSON=$dir/server-runtime.json \
        T3_AWAKE_STATE=$state \
        T3_AWAKE_POLL=0.1 \
        T3_AWAKE_IDLE_POLL=0.1 \
        T3_AWAKE_LINGER=$linger \
        T3_AWAKE_LOG=$dir/t3-awake.log \
        $bin watch >$dir/watch.stdout 2>$dir/watch.stderr &
    set -g last_watch_pid $last_pid
    set -ga watch_pids $last_pid
    set -ga state_files $state
end

function stop_watch --argument-names pid
    kill -TERM $pid 2>/dev/null
    wait $pid 2>/dev/null
end

# --- predicate ---------------------------------------------------------

set d $workdir/predicate
make_fixture $d

check 'empty database is idle' idle (probe $d)

sqlite3 $d/state.sqlite "INSERT INTO projection_turns VALUES ('t1','turn1','running','2026-08-01T00:00:00Z',NULL);"
check 'running turn is busy' busy (probe $d)

sqlite3 $d/state.sqlite "UPDATE projection_turns SET state='completed', completed_at='2026-08-01T00:01:00Z';"
check 'completed turn is idle' idle (probe $d)

sqlite3 $d/state.sqlite "INSERT INTO projection_pending_approvals VALUES ('r1','t1','pending','2026-08-01T00:02:00Z',NULL);"
check 'unresolved approval is busy' busy (probe $d)

sqlite3 $d/state.sqlite "UPDATE projection_pending_approvals SET resolved_at='2026-08-01T00:03:00Z';"
check 'resolved approval is idle' idle (probe $d)

set dead $workdir/dead
make_fixture $dead
sqlite3 $dead/state.sqlite "INSERT INTO projection_turns VALUES ('t1','turn1','running','2026-08-01T00:00:00Z',NULL);"
printf '{"version":1,"pid":999999}\n' >$dead/server-runtime.json
check 'running turn with dead server is idle' idle (probe $dead)

printf 'not json at all\n' >$dead/server-runtime.json
check 'unparseable runtime file is idle' idle (probe $dead)

printf '{ "port": 3773, "pid" : %d, "version": 1 }\n' $fish_pid >$dead/server-runtime.json
check 'bash regex accepts reordered runtime fields' busy (probe $dead)

set missing $workdir/missing
make_fixture $missing
rm $missing/state.sqlite
check 'missing database is idle' idle (probe $missing)

set empty $workdir/empty
make_fixture $empty
rm $empty/state.sqlite
sqlite3 $empty/state.sqlite 'CREATE TABLE unrelated (x INTEGER);'
check 'database without projection tables is idle' idle (probe $empty)

# --- assertion lifecycle ----------------------------------------------

set w $workdir/watch
set wstate $w/awake.state
make_fixture $w
start_watch $w $wstate 2
set watch_pid $last_watch_pid

check 'idle starts without an assertion' 0 (wait_until 20 0.05 state_is_inactive $wstate; echo $status)

sqlite3 $w/state.sqlite "INSERT INTO projection_turns VALUES ('t1','turn1','running','2026-08-01T00:00:00Z',NULL);"
check 'running turn acquires an assertion' 0 (wait_until 40 0.05 state_is_active $wstate; echo $status)

set child (state_child $wstate)
set child_command (ps -ww -p $child -o command= | string trim)
check 'child is parent-bound caffeinate' "/usr/bin/caffeinate -i -w $watch_pid" "$child_command"
check 'busy creates exactly one caffeinate child' 1 (direct_caffeinate_child_count $watch_pid)
check 'caffeinate owns an idle-system assertion' 0 (wait_until 20 0.05 child_has_idle_assertion $child; echo $status)
check 'caffeinate does not own a display assertion' 1 (child_has_display_assertion $child; echo $status)

kill $child
check 'externally killed child is replaced' 0 (wait_until 40 0.05 state_has_new_child $wstate $child; echo $status)
set replacement (state_child $wstate)
check 'replacement also owns the assertion' 0 (wait_until 20 0.05 child_has_idle_assertion $replacement; echo $status)

set st (env T3_AWAKE_DB=$w/state.sqlite T3_AWAKE_RUNTIME_JSON=$w/server-runtime.json T3_AWAKE_STATE=$wstate $bin status 2>/dev/null)
check 'status exits cleanly while active' 0 $status
check 'status reports a verified assertion' 1 (printf '%s\n' $st | grep -c '^wake assertion:  active (pid ')

sqlite3 $w/state.sqlite "UPDATE projection_turns SET state='completed';"
sleep 0.15
check 'assertion is held during linger' 0 (state_is_active $wstate; echo $status)
check 'assertion releases after linger' 0 (wait_until 70 0.05 state_is_inactive $wstate; echo $status)

sqlite3 $w/state.sqlite "UPDATE projection_turns SET state='running';"
check 'assertion reacquires for dead-server case' 0 (wait_until 40 0.05 state_is_active $wstate; echo $status)
printf '{"version":1,"pid":999999}\n' >$w/server-runtime.json
check 'dead server releases despite running row' 0 (wait_until 70 0.05 state_is_inactive $wstate; echo $status)

printf '{"version":1,"pid":%d}\n' $fish_pid >$w/server-runtime.json
check 'assertion reacquires before SIGTERM' 0 (wait_until 40 0.05 state_is_active $wstate; echo $status)
set term_child (state_child $wstate)
stop_watch $watch_pid
check 'SIGTERM exits the watch' 0 (pid_gone $watch_pid; echo $status)
check 'SIGTERM exits caffeinate' 0 (wait_until 20 0.05 pid_gone $term_child; echo $status)
check 'SIGTERM removes runtime state' 0 (wait_until 20 0.05 file_absent $wstate; echo $status)

# --- WAL and query-failure fallback -----------------------------------

set wal $workdir/wal
set walstate $wal/awake.state
make_wal_fixture $wal
check 'wal fixture really uses WAL' wal (sqlite3 $wal/state.sqlite 'PRAGMA journal_mode;')
sqlite3 $wal/state.sqlite "INSERT INTO projection_turns VALUES ('t1','turn1','running','2026-08-01T00:00:00Z',NULL);"
start_watch $wal $walstate 1
set wal_pid $last_watch_pid
check 'WAL running turn acquires assertion' 0 (wait_until 40 0.05 state_is_active $walstate; echo $status)

sqlite3 $wal/state.sqlite "UPDATE projection_turns SET state='completed';"
check 'WAL completed turn releases assertion' 0 (wait_until 50 0.05 state_is_inactive $walstate; echo $status)

sqlite3 $wal/state.sqlite "UPDATE projection_turns SET state='running';"
check 'WAL assertion reacquires before query failures' 0 (wait_until 40 0.05 state_is_active $walstate; echo $status)
chmod 000 $wal/state.sqlite
check 'five query failures fall back to idle' 0 (wait_until 60 0.05 state_is_inactive $walstate; echo $status)
chmod 644 $wal/state.sqlite
check 'query failure episode logs once' 1 (grep -c '^.*busy query failed for 5 consecutive polls' $wal/t3-awake.log)
stop_watch $wal_pid

# --- parent SIGKILL and stale-state recovery --------------------------

set killed $workdir/killed
set killedstate $killed/awake.state
make_fixture $killed
sqlite3 $killed/state.sqlite "INSERT INTO projection_turns VALUES ('t1','turn1','running','2026-08-01T00:00:00Z',NULL);"
start_watch $killed $killedstate 1
set killed_pid $last_watch_pid
check 'SIGKILL fixture acquires assertion' 0 (wait_until 40 0.05 state_is_active $killedstate; echo $status)
set killed_child (state_child $killedstate)
kill -KILL $killed_pid
wait $killed_pid 2>/dev/null
check 'parent SIGKILL still exits caffeinate' 0 (wait_until 20 0.05 pid_gone $killed_child; echo $status)
check 'dead parent state is stale, not active' stale (wake_state_at $killedstate)

start_watch $killed $killedstate 1
set repaired_pid $last_watch_pid
check 'new watch repairs stale state' 0 (wait_until 40 0.05 state_is_active $killedstate; echo $status)
stop_watch $repaired_pid

printf '999999 999998\n' >$workdir/manual-stale.state
check 'arbitrary dead PID record is stale' stale (wake_state_at $workdir/manual-stale.state)

check 'state repair failure terminates an existing assertion' 0 (env T3_AWAKE_LOG=$workdir/state-failure.log bash -c '
source "$1"
STATE_FILE="$2/initial.state"
wake_up
child="$WAKE_PID"
STATE_FILE=/dev/null/t3-awake.state
set +e
wake_up 2>/dev/null
rc=$?
set -e
[ "$rc" -eq 1 ]
[ -z "$WAKE_PID" ]
! kill -0 "$child" 2>/dev/null
' _ $bin $workdir; echo $status)

# --- interval validation and recovery commands ------------------------

set vdir $workdir/validate
set vstate $vdir/awake.state
make_fixture $vdir
set venv T3_AWAKE_DB=$vdir/state.sqlite T3_AWAKE_RUNTIME_JSON=$vdir/server-runtime.json T3_AWAKE_STATE=$vstate T3_AWAKE_LOG=$vdir/t3-awake.log

check 'watch rejects non-numeric poll' 78 (env $venv T3_AWAKE_POLL=abc $bin watch >/dev/null 2>&1; echo $status)
check 'watch rejects zero linger' 78 (env $venv T3_AWAKE_LINGER=0 $bin watch >/dev/null 2>&1; echo $status)
check 'watch rejects fractional linger' 78 (env $venv T3_AWAKE_LINGER=1.5 $bin watch >/dev/null 2>&1; echo $status)

env $venv T3_AWAKE_POLL=0.1 T3_AWAKE_IDLE_POLL=0.1 T3_AWAKE_LINGER=1 $bin watch >/dev/null 2>&1 &
set decimal_pid $last_pid
set -ga watch_pids $decimal_pid
sleep 0.2
check 'watch accepts fractional poll intervals' 0 (pid_alive $decimal_pid; echo $status)
stop_watch $decimal_pid

check 'bad poll does not break probe' idle (env T3_AWAKE_POLL=abc T3_AWAKE_DB=$missing/state.sqlite T3_AWAKE_RUNTIME_JSON=$missing/server-runtime.json $bin probe)
check 'bad linger does not break status' 0 (env $venv T3_AWAKE_LINGER=bad $bin status >/dev/null 2>&1; echo $status)

set uhome $workdir/uninstall-home
mkdir -p $uhome/Library/LaunchAgents
check 'bad interval does not break mocked uninstall' 0 (env HOME=$uhome T3_AWAKE_POLL=bad bash -c '
source "$1"
launchctl() { return 1; }
cmd_uninstall >/dev/null
' _ $bin; echo $status)

# --- LaunchAgent rendering and reconciliation -------------------------

check 'template is valid plist' 0 (plutil -lint $repo/launchd/dev.newedia.t3-awake.plist >/dev/null 2>&1; echo $status)
check 'install rejects unknown argument' 64 ($bin install --dryrun >/dev/null 2>&1; echo $status)

set install_output (env HOME=$workdir/install-base bash -c '
set -euo pipefail
source "$1"
root="$2"
new=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
old=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

run_case() (
    name="$1"
    mock_loaded="$2"
    initial="$3"
    mode="${4:-normal}"
    HOME="$root/$name"
    export HOME
    LOG="$HOME/t3-awake.log"
    ERRLOG="$HOME/t3-awake.err"
    target="$(plist_target)"
    calls="$HOME/calls"
    expected="$HOME/expected.plist"
    mkdir -p "${target%/*}"
    : >"$calls"

    case "$initial" in
        exact) render_plist "$new" "$target" ;;
        script) render_plist "$old" "$target" ;;
        structural) printf "legacy plist\n" >"$target" ;;
        missing) ;;
    esac

    script_sha() { printf "%s\n" "$new"; }
    launchctl() {
        case "$1" in
            print) [ "$mock_loaded" -eq 1 ] ;;
            kickstart)
                printf "kickstart:%s\n" "$(installed_script_sha "$target")" >>"$calls"
                ;;
            bootout)
                printf "bootout\n" >>"$calls"
                if [ "$mode" != timeout ]; then mock_loaded=0; fi
                ;;
            bootstrap)
                printf "bootstrap:%s\n" "$(installed_script_sha "$target")" >>"$calls"
                if [ "$mode" = bootstrap-fail ]; then return 42; fi
                ;;
        esac
    }
    if [ "$mode" = timeout ]; then
        wait_for_bootout() { return 1; }
    fi

    set +e
    cmd_install >/dev/null 2>&1
    rc=$?
    set -e

    render_plist "$new" "$expected"
    same=no
    [ -f "$target" ] && cmp -s "$target" "$expected" && same=yes
    unchanged=no
    [ "$initial" = structural ] && [ "$(cat "$target" 2>/dev/null)" = "legacy plist" ] && unchanged=yes
    call_list="$(paste -sd, "$calls")"
    [ -n "$call_list" ] || call_list=none
    printf "%s|%s|%s|%s|%s\n" "$name" "$rc" "$call_list" "$same" "$unchanged"
)

run_case exact-loaded 1 exact
run_case script-loaded 1 script
run_case structural-loaded 1 structural
run_case exact-unloaded 0 exact
run_case structural-unloaded 0 structural
run_case bootstrap-failure 0 structural bootstrap-fail
run_case bootout-timeout 1 structural timeout

HOME="$root/dry-run"
export HOME
LOG="$HOME/t3-awake.log"
ERRLOG="$HOME/t3-awake.err"
mkdir -p "$HOME"
script_sha() { printf "%s\n" "$new"; }
launchctl() { [ "$1" = print ] && return 1; printf "unexpected mutation: %s\n" "$*" >&2; return 1; }
dry="$(cmd_install --dry-run)"
target="$(plist_target)"
[ ! -e "$target" ]
grep -q "^would write " <<<"$dry"
grep -q "^would bootstrap " <<<"$dry"
printf "dry-run|0|none|absent|yes\n"
' _ $bin $workdir/install-cases)
set install_rc $status
check 'install reconciliation harness exits cleanly' 0 $install_rc
check 'identical loaded install is a no-op' 1 (count (string match -r '^exact-loaded\|0\|none\|yes\|' $install_output))
check 'script-only change kickstarts before marker update' 1 (count (string match -r '^script-loaded\|0\|kickstart:a{64}\|yes\|' $install_output))
check 'structural loaded change bootouts, writes, then bootstraps' 1 (count (string match -r '^structural-loaded\|0\|bootout,bootstrap:b{64}\|yes\|' $install_output))
check 'identical unloaded install only bootstraps' 1 (count (string match -r '^exact-unloaded\|0\|bootstrap:b{64}\|yes\|' $install_output))
check 'changed unloaded install writes before bootstrap' 1 (count (string match -r '^structural-unloaded\|0\|bootstrap:b{64}\|yes\|' $install_output))
check 'failed bootstrap leaves desired plist for retry' 1 (count (string match -r '^bootstrap-failure\|1\|bootstrap:b{64}\|yes\|' $install_output))
check 'failed bootout leaves old plist untouched' 1 (count (string match -r '^bootout-timeout\|1\|bootout\|no\|yes$' $install_output))
check 'dry run creates no target and makes no calls' 1 (count (string match -r '^dry-run\|0\|none\|absent\|yes$' $install_output))

check 'failed uninstall keeps plist and state' 0 (env HOME=$workdir/uninstall-fail T3_AWAKE_STATE=$workdir/uninstall-fail/awake.state bash -c '
source "$1"
target="$(plist_target)"
mkdir -p "${target%/*}"
printf "installed\n" >"$target"
printf "999999 999998\n" >"$STATE_FILE"
service_loaded() { return 0; }
launchctl() { return 1; }
wait_for_bootout() { return 1; }
set +e
cmd_uninstall >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 1 ] && [ -f "$target" ] && [ -f "$STATE_FILE" ]
' _ $bin; echo $status)

check 'successful uninstall removes files after stop confirmation' 0 (env HOME=$workdir/uninstall-ok T3_AWAKE_STATE=$workdir/uninstall-ok/awake.state bash -c '
source "$1"
target="$(plist_target)"
mkdir -p "${target%/*}"
printf "installed\n" >"$target"
printf "999999 999998\n" >"$STATE_FILE"
service_loaded() { return 0; }
launchctl() { [ "$1" = bootout ]; }
wait_for_bootout() { [ -f "$target" ] && [ -f "$STATE_FILE" ]; }
cmd_uninstall >/dev/null
[ ! -e "$target" ] && [ ! -e "$STATE_FILE" ]
' _ $bin; echo $status)

check 'wait_for_bootout polls until first miss' 0 (bash -c '
source "$1"
calls=0
launchctl() { calls=$((calls + 1)); [ "$calls" -lt 3 ]; }
sleep() { :; }
wait_for_bootout fake.label 20
[ "$calls" -eq 3 ]
' _ $bin; echo $status)

check 'wait_for_bootout gives up on wedged label' 1 (bash -c '
source "$1"
launchctl() { return 0; }
sleep() { :; }
wait_for_bootout fake.label 3
' _ $bin; echo $status)

# --- summary -----------------------------------------------------------

printf '\n%d checks, %d failures\n' $checks $failures
test $failures -eq 0
