#!/usr/bin/env fish

set -g repo_root (path resolve (dirname (status filename))/../..)
set -g u_test_mock_calls

function assert_function
    set -l function_name $argv[1]
    set -l description $argv[2]

    if functions -q $function_name
        printf 'ok - %s\n' $description
        return 0
    end

    printf 'not ok - %s\n' $description
    return 1
end

function assert_equal
    set -l expected $argv[1]
    set -l actual $argv[2]
    set -l description $argv[3]

    if test "$expected" = "$actual"
        printf 'ok - %s\n' $description
        return 0
    end

    printf 'not ok - %s\n' $description
    printf '  expected: %s\n' (string escape -- "$expected")
    printf '  actual:   %s\n' (string escape -- "$actual")
    return 1
end

function assert_no_mock_calls
    if test (count $u_test_mock_calls) -eq 0
        printf 'ok - source runs no top-level commands in test mode\n'
        return 0
    end

    printf 'not ok - source runs top-level commands in test mode: %s\n' (string join ', ' $u_test_mock_calls)
    return 1
end

function gum
    set -ga u_test_mock_calls gum
    return 0
end

function nvim
    set -ga u_test_mock_calls nvim
    return 0
end

function brew
    set -ga u_test_mock_calls brew
    return 0
end

function bat
    set -ga u_test_mock_calls bat
    return 0
end

set -lx U_TEST_MODE 1
source "$repo_root/bin/u"

set -l test_status 0
assert_function u_main 'source exposes u_main'; or set test_status 1
assert_function u_outdated_names 'source exposes u_outdated_names'; or set test_status 1
assert_function u_cask_app_paths 'source exposes u_cask_app_paths'; or set test_status 1
assert_function u_inspect_app 'source exposes u_inspect_app'; or set test_status 1
assert_function u_prepare_cask 'source exposes u_prepare_cask'; or set test_status 1
assert_function u_confirm_running_apps 'source exposes u_confirm_running_apps'; or set test_status 1
assert_function u_stop_app 'source exposes u_stop_app'; or set test_status 1
assert_function u_stop_cask_apps 'source exposes u_stop_cask_apps'; or set test_status 1
assert_function u_recheck_cask_apps 'source exposes u_recheck_cask_apps'; or set test_status 1
assert_function u_upgrade_cask 'source exposes u_upgrade_cask'; or set test_status 1
assert_function u_reopen_closed 'source exposes u_reopen_closed'; or set test_status 1
assert_no_mock_calls; or set test_status 1

set -l literal_log (mktemp)
u_log "$literal_log" 'literal\ntext'
assert_equal 'literal\ntext' "$(string collect <"$literal_log")" \
    'log messages preserve literal backslash escapes'; or set test_status 1
rm -f "$literal_log"

# u_outdated_names

assert_equal '' "$(u_outdated_names formulae '{"formulae":[],"casks":[]}')" \
    'outdated names emits nothing for an empty section'; or set test_status 1

assert_equal jq "$(u_outdated_names formulae '{"formulae":[{"name":"jq"}],"casks":[{"name":"cursor"}]}')" \
    'outdated names emits the outdated formula name'; or set test_status 1

assert_equal cursor "$(u_outdated_names casks '{"formulae":[{"name":"jq"}],"casks":[{"name":"cursor"}]}')" \
    'outdated names emits the outdated cask name'; or set test_status 1

assert_equal 'jq
fish' "$(u_outdated_names formulae '{"formulae":[{"name":"jq"},{"name":"fish"}],"casks":[]}')" \
    'outdated names emits one name per line'; or set test_status 1

u_outdated_names formulae 'not json' >/dev/null 2>&1
assert_equal 5 $status 'outdated names rejects invalid JSON'; or set test_status 1

u_outdated_names formulae '{"formulae":[{"installed_versions":["1.0"]}],"casks":[]}' >/dev/null 2>&1
assert_equal 1 $status 'outdated names rejects a record without a name'; or set test_status 1

u_outdated_names formulae '{"formulae":{},"casks":[]}' >/dev/null 2>&1
assert_equal 1 $status 'outdated names rejects a non-array section'; or set test_status 1

# A missing section is tolerated as empty; brew always emits both keys, and an
# absent key carries no records to lose.
assert_equal '' "$(u_outdated_names casks '{"formulae":[]}')" \
    'outdated names treats a missing section as empty'; or set test_status 1

# Real callers pass unquoted command substitutions, which fish splits into one
# argument per line. The functions must consume every line, not just the first.
set -l pretty_outdated (printf '%s\n' '{"formulae":[{"name":"jq"}],"casks":[{"name":"cursor"}]}' | jq .)
assert_equal 12 (count $pretty_outdated) 'pretty outdated fixture splits into several arguments'; or set test_status 1
assert_equal jq "$(u_outdated_names formulae $pretty_outdated)" \
    'outdated names accepts multiline pretty-printed JSON'; or set test_status 1

# u_cask_app_paths — token-scoped slices of one batched brew info document

set -l batched_json '{"casks":[{"token":"cursor","artifacts":[{"app":["Cursor.app"],"target":"/Applications/Cursor.app"},{"binary":["cursor"],"target":"/opt/homebrew/bin/cursor"}]},{"token":"font-hack","artifacts":[{"font":["Hack-Regular.ttf"]}]}]}'
assert_equal /Applications/Cursor.app "$(u_cask_app_paths cursor $batched_json)" \
    'cask app paths emits only the app artifact target'; or set test_status 1

u_cask_app_paths font-hack $batched_json >/dev/null
assert_equal 0 $status 'cask app paths accepts a cask without app artifacts'; or set test_status 1
assert_equal '' "$(u_cask_app_paths font-hack $batched_json)" \
    'cask app paths emits nothing for a cask without app artifacts'; or set test_status 1

assert_equal '' "$(u_cask_app_paths ghost $batched_json)" \
    'cask app paths emits nothing for a token the document does not describe'; or set test_status 1

set -l cask_two_apps_json '{"casks":[{"token":"multi","artifacts":[{"app":["One.app"],"target":"/Applications/One.app"},{"app":["Two.app"],"target":"/Applications/Two.app"}]}]}'
assert_equal '/Applications/One.app
/Applications/Two.app' "$(u_cask_app_paths multi $cask_two_apps_json)" \
    'cask app paths emits every app artifact target'; or set test_status 1

set -l cask_missing_target_json '{"casks":[{"token":"bad","artifacts":[{"app":["Bad.app"]}]}]}'
u_cask_app_paths bad $cask_missing_target_json >/dev/null 2>&1
assert_equal 1 $status 'cask app paths rejects a missing app target'; or set test_status 1

set -l cask_relative_target_json '{"casks":[{"token":"bad","artifacts":[{"app":["Bad.app"],"target":"Bad.app"}]}]}'
u_cask_app_paths bad $cask_relative_target_json >/dev/null 2>&1
assert_equal 1 $status 'cask app paths rejects a non-absolute app target'; or set test_status 1

u_cask_app_paths bad 'not json' >/dev/null 2>&1
assert_equal 5 $status 'cask app paths rejects invalid JSON'; or set test_status 1

set -l cask_spaced_json '{"casks":[{"token":"google-chrome","artifacts":[{"app":["Google Chrome.app"],"target":"/Applications/Google Chrome.app"}]}]}'
assert_equal '/Applications/Google Chrome.app' "$(u_cask_app_paths google-chrome $cask_spaced_json)" \
    'cask app paths preserves an app target containing spaces'; or set test_status 1

set -l cask_spaced_pretty (printf '%s\n' $cask_spaced_json | jq .)
assert_equal '/Applications/Google Chrome.app' "$(u_cask_app_paths google-chrome $cask_spaced_pretty)" \
    'cask app paths handles spaces in multiline JSON'; or set test_status 1

# Callers consume the output through a command substitution and check the exit
# status, so a late malformed artifact only has to fail the call.
set -l cask_late_bad_json '{"casks":[{"token":"mixed","artifacts":[{"app":["Good.app"],"target":"/Applications/Good.app"},{"app":["Bad.app"]}]}]}'
u_cask_app_paths mixed $cask_late_bad_json >/dev/null 2>&1
assert_equal 1 $status 'cask app paths rejects a late malformed artifact'; or set test_status 1

# ---------------------------------------------------------------------------
# In-memory lifecycle state helpers
# ---------------------------------------------------------------------------

set -g U_SKIPS
u_record_skip cursor 'first reason'
u_record_skip cursor 'second reason'
assert_equal 1 (count $U_SKIPS) 'record skip keeps one row per token'; or set test_status 1
assert_equal 'cursor|first reason' "$(string replace -a \t '|' -- $U_SKIPS[1])" \
    'record skip keeps the first recorded reason'; or set test_status 1
u_token_skipped cursor
assert_equal 0 $status 'token skipped finds a recorded token'; or set test_status 1
u_token_skipped calm
assert_equal 1 $status 'token skipped misses an unrecorded token'; or set test_status 1

set -g U_FAILURES
u_record_failure cask-upgrade cursor 'brew upgrade --cask failed with status 9'
assert_equal 'cask-upgrade|cursor|brew upgrade --cask failed with status 9' \
    "$(string replace -a \t '|' -- $U_FAILURES[1])" \
    'record failure keeps category, subject, and detail'; or set test_status 1
u_token_has_failure cursor
assert_equal 0 $status 'token has failure finds a recorded subject'; or set test_status 1
u_token_has_failure calm
assert_equal 1 $status 'token has failure misses an unrecorded subject'; or set test_status 1

set -g U_CLOSED
u_record_closed cursor /Applications/Cursor.app
u_record_closed cursor /Applications/Cursor.app
assert_equal 1 (count $U_CLOSED) 'record closed keeps one row per app'; or set test_status 1

# u_reopen_closed — the same pass serves per-cask restore, the final sweep, and
# the signal/exit handlers, so it is tested directly instead of via signals.

set -g u_test_open_calls
set -g u_test_open_fail
function open
    set -ga u_test_open_calls $argv[1]
    if contains -- $argv[1] $u_test_open_fail
        return 1
    end
    return 0
end

set -g U_CLOSED "cursor"\t"/Applications/Cursor.app" "calm"\t"/Applications/Calm.app"
set -g U_FAILURES
u_reopen_closed cursor
assert_equal 0 $status 'reopen closed succeeds for one token'; or set test_status 1
assert_equal /Applications/Cursor.app "$u_test_open_calls[1]" \
    'reopen closed opens the requested token app'; or set test_status 1
assert_equal 1 (count $u_test_open_calls) 'reopen closed leaves other tokens closed'; or set test_status 1
assert_equal 1 (count $U_CLOSED) 'reopen closed consumes only the requested token rows'; or set test_status 1

u_reopen_closed
assert_equal 0 $status 'reopen closed sweeps every remaining row'; or set test_status 1
assert_equal /Applications/Calm.app "$u_test_open_calls[2]" \
    'reopen closed opens the remaining app in the sweep'; or set test_status 1
assert_equal 0 (count $U_CLOSED) 'reopen closed empties the closed list'; or set test_status 1

set -g U_CLOSED "cursor"\t"/Applications/Cursor.app"
set -g U_FAILURES
set -g u_test_open_calls
set -g u_test_open_fail /Applications/Cursor.app
u_reopen_closed
assert_equal 1 $status 'reopen closed reports a failed open'; or set test_status 1
assert_equal 1 (count $U_CLOSED) 'a failed open keeps its row for a later retry'; or set test_status 1
assert_equal 'app-reopen|cursor|unable to reopen /Applications/Cursor.app' \
    "$(string replace -a \t '|' -- $U_FAILURES[1])" \
    'a failed open records an app-reopen failure'; or set test_status 1

set -g u_test_open_fail
u_reopen_closed
assert_equal 0 $status 'a later pass retries a previously failed open'; or set test_status 1
assert_equal 0 (count $U_CLOSED) 'the retry consumes the recovered row'; or set test_status 1

# u_confirm_running_apps

set -g u_test_gum_calls 0
set -g u_test_gum_status 0
function gum
    set -g u_test_gum_calls (math $u_test_gum_calls + 1)
    return $u_test_gum_status
end

set -g U_APPS "cursor"\t"/Applications/Cursor.app"\t"com.cursor"\t"111" \
    "calm"\t"/Applications/Calm.app"\t"com.calm.Calm"\t""
set -g U_SKIPS
set -g u_test_confirm_output (u_confirm_running_apps)
assert_equal 0 $status 'confirm approves closing running applications'; or set test_status 1
assert_equal 1 $u_test_gum_calls 'confirm asks exactly once'; or set test_status 1
assert_equal 0 (count $U_SKIPS) 'an approved confirmation records no skips'; or set test_status 1
assert_equal 1 (count (string match -a -- '*Cursor (cursor)*' $u_test_confirm_output)) \
    'confirm lists the running application with its token'; or set test_status 1
assert_equal 0 (count (string match -a -- '*Calm*' $u_test_confirm_output)) \
    'confirm never lists an application that is not running'; or set test_status 1

set -g u_test_gum_status 1
set -g U_SKIPS
u_confirm_running_apps >/dev/null
assert_equal 2 $status 'confirm reports a deliberate decline'; or set test_status 1
assert_equal 'cursor|declined closing running applications' \
    "$(string replace -a \t '|' -- $U_SKIPS[1])" \
    'a decline skips the running token'; or set test_status 1
assert_equal 1 (count $U_SKIPS) 'a decline never skips a token that is not running'; or set test_status 1

set -g U_APPS "calm"\t"/Applications/Calm.app"\t"com.calm.Calm"\t""
set -g U_SKIPS
set -g u_test_gum_calls 0
u_confirm_running_apps >/dev/null
assert_equal 0 $status 'confirm passes when nothing is running'; or set test_status 1
assert_equal 0 $u_test_gum_calls 'confirm never prompts when nothing is running'; or set test_status 1

# u_stop_app — the lifecycle helper is scripted per running reconciliation; the
# final scripted entry persists, so a stubborn app stays alive for every poll.

set -g u_test_lifecycle_calls
set -g u_test_lifecycle_script
set -g u_test_lifecycle_op_status 0
set -g u_test_lifecycle_running_status 0
function u_lifecycle_operation --argument-names command bundle_id
    set -ga u_test_lifecycle_calls "$command $bundle_id $argv[3..-1]"
    if test "$command" != running
        return $u_test_lifecycle_op_status
    end
    if test $u_test_lifecycle_running_status -ne 0
        return $u_test_lifecycle_running_status
    end
    set -l head $u_test_lifecycle_script[1]
    if test (count $u_test_lifecycle_script) -gt 1
        set -e u_test_lifecycle_script[1]
    end
    if test "$head" != -; and test -n "$head"
        echo $head
    end
end
function sleep
end

set -g U_CLOSED
set -g U_FAILURES
set -g U_SKIPS
set -g u_test_lifecycle_script -
u_stop_app terminate cursor /Applications/Cursor.app com.cursor 111 >/dev/null
assert_equal 0 $status 'stop app succeeds when the app closes'; or set test_status 1
assert_equal 'terminate com.cursor 111' "$u_test_lifecycle_calls[1]" \
    'stop app terminates the exact original PIDs'; or set test_status 1
assert_equal 'running com.cursor 111' "$u_test_lifecycle_calls[2]" \
    'stop app reconciles against the exact original PIDs'; or set test_status 1
assert_equal 'cursor|/Applications/Cursor.app' "$(string replace -a \t '|' -- $U_CLOSED[1])" \
    'stop app records the closed application'; or set test_status 1

set -g u_test_lifecycle_calls
set -g U_CLOSED
set -g u_test_lifecycle_script 111
u_stop_app terminate cursor /Applications/Cursor.app com.cursor 111 >/dev/null
assert_equal 2 $status 'stop app reports an app that survives every poll'; or set test_status 1
assert_equal 11 (count $u_test_lifecycle_calls) 'stop app polls ten times before giving up'; or set test_status 1
assert_equal 0 (count $U_CLOSED) 'a surviving app is never recorded as closed'; or set test_status 1

set -g U_FAILURES
set -g U_SKIPS
set -g u_test_lifecycle_running_status 1
u_stop_app terminate cursor /Applications/Cursor.app com.cursor 111 >/dev/null
assert_equal 1 $status 'stop app fails when reconciliation cannot be trusted'; or set test_status 1
assert_equal 1 (count (string match -a -- 'app-running*' $U_FAILURES)) \
    'an unreliable reconciliation records a failure'; or set test_status 1
assert_equal 1 (count $U_SKIPS) 'an unreliable reconciliation skips the cask'; or set test_status 1
set -g u_test_lifecycle_running_status 0

set -g U_CLOSED
set -g U_FAILURES
set -g U_SKIPS
set -g u_test_lifecycle_op_status 70
set -g u_test_lifecycle_script -
u_stop_app terminate cursor /Applications/Cursor.app com.cursor 111 >/dev/null
assert_equal 0 $status 'stop app still reconciles after a helper failure'; or set test_status 1
assert_equal 1 (count (string match -a -- 'app-terminate*' $U_FAILURES)) \
    'a helper failure is recorded even when the app closed'; or set test_status 1
set -g u_test_lifecycle_op_status 0

# u_recheck_cask_apps

set -g U_APPS "cursor"\t"/Applications/Cursor.app"\t"com.cursor"\t"111"

function u_inspect_app
    printf '%s\t%s\t%s\n' /Applications/Cursor.app com.cursor 222
end
set -g U_SKIPS
u_recheck_cask_apps cursor
assert_equal 2 $status 'recheck skips when an application instance appeared'; or set test_status 1
assert_equal 'cursor|an application instance appeared before upgrade: /Applications/Cursor.app' \
    "$(string replace -a \t '|' -- $U_SKIPS[1])" \
    'recheck names the app that reappeared'; or set test_status 1

function u_inspect_app
    printf '%s\t%s\t%s\n' /Applications/Cursor.app com.cursor ''
end
set -g U_SKIPS
u_recheck_cask_apps cursor
assert_equal 0 $status 'recheck passes when no instance remains'; or set test_status 1

function u_inspect_app
    return 1
end
set -g U_SKIPS
set -g U_FAILURES
u_recheck_cask_apps cursor
assert_equal 1 $status 'recheck fails when it cannot be trusted'; or set test_status 1
assert_equal 1 (count (string match -a -- 'app-inspect*' $U_FAILURES)) \
    'an untrustworthy recheck records a failure'; or set test_status 1

# ---------------------------------------------------------------------------
# End-to-end cases through PATH mocks
#
# These cases replace brew, osascript, gum, and friends with real executables
# placed first in PATH, so the production functions have to invoke them exactly
# the way a real run would. The fish-function shadows above are erased and the
# production functions restored first.
# ---------------------------------------------------------------------------

functions -e brew gum nvim bat open sleep u_lifecycle_operation u_inspect_app
set -g U_APPS
set -g U_CLOSED
set -g U_SKIPS
set -g U_FAILURES
source "$repo_root/bin/u"

set -g u_mock_root (mktemp -d)
set -gx U_MOCK_DIR "$u_mock_root/fixtures"
set -gx U_MOCK_LOG "$u_mock_root/calls.log"
set -g u_mock_bin "$u_mock_root/bin"
# Executable Fish mocks must not load the user's configuration and reorder PATH
# back to the real maintenance tools.
set -gx XDG_CONFIG_HOME "$u_mock_root/config"
mkdir -p "$U_MOCK_DIR" "$u_mock_bin" "$XDG_CONFIG_HOME"
touch "$U_MOCK_LOG"

# The mocks pin the whole invocation shape, so a production change that drops
# --json=v2 or -l JavaScript fails here instead of only in a real run.
echo '#!/usr/bin/env fish
echo "brew $argv" >>"$U_MOCK_LOG"
if test "$argv[1]" = info; and test "$argv[2]" = --cask; and test "$argv[3]" = --json=v2; and test (count $argv) -ge 4
    if test -e "$U_MOCK_DIR/exit-brew-info"
        exit (string trim <"$U_MOCK_DIR/exit-brew-info")
    end
    cat "$U_MOCK_DIR/cask-info.json"
    exit 0
end
if test "$argv[1]" = outdated; and test "$argv[2]" = --json=v2
    cat "$U_MOCK_DIR/outdated.json"
    if test -e "$U_MOCK_DIR/exit-brew-outdated"
        exit (string trim <"$U_MOCK_DIR/exit-brew-outdated")
    end
    exit 0
end
if test "$argv[1]" = upgrade; and contains -- "$argv[2]" --formula --cask
    printf "upgrading %s\n" (string join " " -- $argv[2..-1])
    set -l kind formula
    if test "$argv[2]" = --cask
        set kind cask
    end
    set -l exit_fixture "$U_MOCK_DIR/exit-brew-upgrade-$kind-"(string join + $argv[3..-1])
    if test -e "$exit_fixture"
        exit (string trim <"$exit_fixture")
    end
    exit 0
end
if contains -- "$argv[1]" update cleanup doctor
    if test -e "$U_MOCK_DIR/exit-brew-$argv[1]"
        exit (string trim <"$U_MOCK_DIR/exit-brew-$argv[1]")
    end
    exit 0
end
echo "brew mock: unexpected invocation: $argv" >>"$U_MOCK_LOG"
exit 64' >"$u_mock_bin/brew"

# The running queue for a bundle models liveness over time: inspect peeks at
# the head, each running reconciliation consumes one entry, and the last entry
# persists. A dash or empty entry means no instance is running. A bundle
# without a queue serves its inspect fixture verbatim.
echo '#!/usr/bin/env fish
echo "osascript $argv" >>"$U_MOCK_LOG"
if test "$argv[1]" != -l; or test "$argv[2]" != JavaScript; or not string match -q -- "*/u-cask-lifecycle.js" "$argv[3]"
    echo "osascript mock: unexpected invocation: $argv" >>"$U_MOCK_LOG"
    exit 64
end
set -l command "$argv[4]"
if test "$command" = inspect
    set -l fixture "$U_MOCK_DIR/inspect"(string replace -a / _ -- "$argv[5]")".json"
    if not test -e "$fixture"
        echo "osascript mock: no fixture for $argv[5]" >>"$U_MOCK_LOG"
        exit 66
    end
    set -l queue "$U_MOCK_DIR/running-"(string replace -a / _ -- (jq -r .bundleId <"$fixture"))
    if not test -e "$queue"
        cat "$fixture"
        exit 0
    end
    set -l lines (cat "$queue")
    set -l pids "[]"
    if test (count $lines) -gt 0; and test "$lines[1]" != -; and test -n "$lines[1]"
        set pids "[$lines[1]]"
    end
    jq --argjson pids "$pids" ".pids = \$pids" <"$fixture"
    exit 0
end
if contains -- "$command" running terminate force-terminate
    set -l bundle_key (string replace -a / _ -- "$argv[5]")
    set -l pids
    if test "$command" = running
        set -l queue "$U_MOCK_DIR/running-$bundle_key"
        if test -e "$queue"
            set -l lines (cat "$queue")
            if test (count $lines) -gt 0; and test "$lines[1]" != -; and test -n "$lines[1]"
                set pids (string split , -- "$lines[1]")
            end
            if test (count $lines) -gt 1
                printf "%s\n" $lines[2..-1] >"$queue"
            end
        end
    end
    printf "{\"bundleId\":\"%s\",\"pids\":[%s]}\n" "$argv[5]" (string join , $pids)
    exit 0
end
echo "osascript mock: unexpected invocation: $argv" >>"$U_MOCK_LOG"
exit 64' >"$u_mock_bin/osascript"

echo '#!/usr/bin/env fish
echo "gum $argv" >>"$U_MOCK_LOG"
if test "$argv[1]" = confirm
    if string match -q -- "*Force quit*" "$argv[2..-1]"; and test -e "$U_MOCK_DIR/gum-force-decline"
        exit 1
    end
    if string match -q -- "*Close these applications*" "$argv[2..-1]"; and test -e "$U_MOCK_DIR/gum-running-decline"
        exit 1
    end
    if test -e "$U_MOCK_DIR/gum-confirm-decline"
        exit 1
    end
end
if test "$argv[1]" = spin
    set -l separator (contains -i -- -- $argv)
    if test -n "$separator"
        set -l command_start (math $separator + 1)
        command $argv[$command_start..-1]
        exit $status
    end
end
exit 0' >"$u_mock_bin/gum"

echo '#!/usr/bin/env fish
echo "nvim $argv" >>"$U_MOCK_LOG"
exit 0' >"$u_mock_bin/nvim"

echo '#!/usr/bin/env fish
echo "bat $argv" >>"$U_MOCK_LOG"
exit 0' >"$u_mock_bin/bat"

echo '#!/usr/bin/env fish
/usr/bin/tee $argv
set -l tee_status $status
if test -e "$U_MOCK_DIR/exit-tee"
    exit (string trim <"$U_MOCK_DIR/exit-tee")
end
exit $tee_status' >"$u_mock_bin/tee"

echo '#!/usr/bin/env fish
echo "sleep $argv" >>"$U_MOCK_LOG"
exit 0' >"$u_mock_bin/sleep"

echo '#!/usr/bin/env fish
echo "open $argv" >>"$U_MOCK_LOG"
if test -e "$U_MOCK_DIR/open-always-fail"
    exit 1
end
exit 0' >"$u_mock_bin/open"

chmod +x "$u_mock_bin/brew" "$u_mock_bin/osascript" "$u_mock_bin/gum" "$u_mock_bin/nvim" "$u_mock_bin/bat" "$u_mock_bin/tee" "$u_mock_bin/sleep" "$u_mock_bin/open"
set -gx PATH "$u_mock_bin" $PATH

set -g u_cask_cursor_json '{"token":"cursor","artifacts":[{"app":["Cursor.app"],"target":"/Applications/Cursor.app"},{"binary":["cursor"],"target":"/opt/homebrew/bin/cursor"}]}'
set -g u_cask_calm_json '{"token":"calm","artifacts":[{"app":["Calm.app"],"target":"/Applications/Calm.app"}]}'
set -g u_cask_font_json '{"token":"font-hack","artifacts":[{"font":["Hack-Regular.ttf"]}]}'
set -g u_cask_bad_json '{"token":"bad-target","artifacts":[{"app":["Bad.app"]}]}'

function u_test_write_cask_info
    # Pretty-print so the parsers keep proving they read every argument line.
    printf '%s\n' $argv | jq . >"$U_MOCK_DIR/cask-info.json"
end

function u_test_write_inspect --argument-names bundle_path json
    printf '%s\n' $json | jq . >"$U_MOCK_DIR/inspect"(string replace -a / _ -- $bundle_path)".json"
end

function u_test_running --argument-names bundle_id
    printf '%s\n' $argv[2..-1] >"$U_MOCK_DIR/running-"(string replace -a / _ -- $bundle_id)
end

function u_test_reset
    for fixture in (command find "$U_MOCK_DIR" -maxdepth 1 -type f \( -name 'running-*' -o -name 'exit-*' -o -name 'gum-*' -o -name 'open-*' -o -name 'outdated.json' -o -name 'cask-info.json' \))
        rm -f "$fixture"
    end
    printf '' >"$U_MOCK_LOG"
end

function u_test_calls --argument-names pattern
    grep -c -e $pattern "$U_MOCK_LOG"
end

function u_test_call_line --argument-names pattern
    grep -n -m 1 -e "$pattern" "$U_MOCK_LOG" | string split -m 1 : | head -n 1
end

function assert_call_before --argument-names earlier_pattern later_pattern description
    set -l earlier_line (u_test_call_line "$earlier_pattern")
    set -l later_line (u_test_call_line "$later_pattern")

    if test -n "$earlier_line"; and test -n "$later_line"; and test "$earlier_line" -lt "$later_line"
        printf 'ok - %s\n' "$description"
        return 0
    end

    printf 'not ok - %s\n' "$description"
    printf '  earlier line: %s\n' (string escape -- "$earlier_line")
    printf '  later line:   %s\n' (string escape -- "$later_line")
    return 1
end

function u_test_output_contains --argument-names needle
    if string match -q -- "*$needle*" "$u_test_main_output"
        echo 1
    else
        echo 0
    end
end

function u_test_run_main --argument-names case_name
    set -l output_file "$u_mock_root/$case_name.out"
    env U_TEST_MODE=1 U_MOCK_DIR="$U_MOCK_DIR" U_MOCK_LOG="$U_MOCK_LOG" \
        fish --no-config -c 'source "$argv[1]"; u_main' "$repo_root/bin/u" >"$output_file" 2>&1
    set -g u_test_main_status $status
    set -g u_test_main_output (string collect <"$output_file")
end

u_test_write_inspect /Applications/Cursor.app '{"path":"/Applications/Cursor.app","bundleId":"com.todesktop.230313mzl4w4u92","pids":[111]}'
u_test_write_inspect /Applications/Calm.app '{"path":"/Applications/Calm.app","bundleId":"com.calm.Calm","pids":[]}'

# u_inspect_app

u_test_reset
assert_equal '/Applications/Cursor.app|com.todesktop.230313mzl4w4u92|111' \
    "$(u_inspect_app /Applications/Cursor.app | string replace -a \t '|')" \
    'inspect app emits path, bundle identifier, and PIDs'; or set test_status 1

assert_equal '/Applications/Calm.app|com.calm.Calm|' \
    "$(u_inspect_app /Applications/Calm.app | string replace -a \t '|')" \
    'inspect app emits an empty PID column for a stopped app'; or set test_status 1

u_inspect_app /Applications/Missing.app >/dev/null 2>&1
assert_equal 1 $status 'inspect app propagates a helper failure'; or set test_status 1

u_inspect_app >/dev/null 2>&1
assert_equal 1 $status 'inspect app rejects an empty bundle path'; or set test_status 1

# Main flow

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[]}' >"$U_MOCK_DIR/outdated.json"
u_test_run_main no-outdated
assert_equal 0 $u_test_main_status 'main succeeds when no packages are outdated'; or set test_status 1
assert_equal 1 (u_test_calls '^nvim ') \
    'main performs all Neovim maintenance in one invocation'; or set test_status 1
assert_equal 1 (u_test_calls '^nvim --headless +Lazy! sync +MasonUpdate +TSUpdate +qa$') \
    'the Neovim invocation carries every maintenance command'; or set test_status 1
assert_equal 1 (u_test_calls '^brew update$') \
    'main end-to-end cases use the Homebrew update mock'; or set test_status 1
assert_equal 1 (u_test_calls '^brew outdated --json=v2$') \
    'main discovers outdated packages with one JSON call'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade ') \
    'main runs no upgrade when the outdated document is empty'; or set test_status 1
assert_equal 0 (u_test_calls '^brew cleanup ') \
    'main preserves the no-outdated path without cleanup'; or set test_status 1
assert_equal 1 (u_test_calls '^brew doctor$') \
    'main still doctors Homebrew when nothing is outdated'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[]}' >"$U_MOCK_DIR/outdated.json"
touch "$U_MOCK_DIR/gum-confirm-decline"
u_test_run_main confirm-decline
assert_equal 1 $u_test_main_status 'declining the initial confirmation aborts the run'; or set test_status 1
assert_equal 0 (u_test_calls '^nvim ') \
    'declining the initial confirmation stops before maintenance'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[]}' >"$U_MOCK_DIR/outdated.json"
printf '6\n' >"$U_MOCK_DIR/exit-brew-outdated"
u_test_run_main outdated-failure
assert_equal 6 $u_test_main_status 'outdated discovery preserves the Homebrew failure status'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade ') \
    'failed outdated discovery stops before package upgrades'; or set test_status 1
assert_equal 0 (u_test_calls '^brew doctor$') \
    'failed outdated discovery stops before Homebrew doctor'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[]}' >"$U_MOCK_DIR/outdated.json"
printf '4\n' >"$U_MOCK_DIR/exit-brew-doctor"
u_test_run_main doctor-failure
assert_equal 1 $u_test_main_status 'Homebrew doctor failure produces an aggregate failure'; or set test_status 1
assert_equal 1 (u_test_output_contains 'all [brew-doctor]: brew doctor failed') \
    'main surfaces a Homebrew doctor failure in final details'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[{"name":"jq"},{"name":"fish"}],"casks":[]}' >"$U_MOCK_DIR/outdated.json"
u_test_run_main formula-only
assert_equal 0 $u_test_main_status 'main succeeds after a formula-only upgrade'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --formula jq fish$') \
    'main upgrades named formulae in one formula-only command'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade --cask ') \
    'formula-only updates never invoke a cask upgrade'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[{"name":"jq"}],"casks":[{"name":"font-hack"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_font_json']}'
printf '7\n' >"$U_MOCK_DIR/exit-brew-upgrade-formula-jq"
u_test_run_main formula-failure
assert_equal 7 $u_test_main_status 'formula upgrade failure is fail-fast'; or set test_status 1
assert_equal 0 (u_test_calls '^brew info --cask ') \
    'formula failure stops before cask preparation'; or set test_status 1
assert_equal 0 (u_test_calls '^brew doctor$') \
    'formula failure stops before Homebrew doctor'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"font-hack"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_font_json']}'
u_test_run_main non-app-cask
assert_equal 0 $u_test_main_status 'main upgrades a non-app cask'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask font-hack$') \
    'a non-app cask upgrades in its own cask-only command'; or set test_status 1
assert_equal 0 (u_test_calls '^osascript ') \
    'a non-app cask uses no application lifecycle operations'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"font-hack"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_font_json']}'
printf '8\n' >"$U_MOCK_DIR/exit-brew-cleanup"
u_test_run_main cleanup-failure
assert_equal 1 $u_test_main_status 'Homebrew cleanup failure produces an aggregate failure'; or set test_status 1
assert_equal 1 (u_test_calls '^brew doctor$') \
    'main still doctors Homebrew after cleanup fails'; or set test_status 1
assert_equal 1 (u_test_output_contains 'all [brew-cleanup]: brew cleanup --prune=all failed') \
    'main surfaces a Homebrew cleanup failure in final details'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"cursor"},{"name":"calm"}]}' >"$U_MOCK_DIR/outdated.json"
printf '3\n' >"$U_MOCK_DIR/exit-brew-info"
u_test_run_main info-failure
assert_equal 1 $u_test_main_status 'a failed batched metadata call fails the run'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade --cask ') \
    'no cask upgrades without trustworthy metadata'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Failed casks (2): cursor, calm') \
    'a failed metadata call fails every outdated cask'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"bad-target"},{"name":"calm"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_bad_json','$u_cask_calm_json']}'
u_test_run_main preparation-failure
assert_equal 1 $u_test_main_status 'cask preparation failure produces a final failure'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade --cask bad-target$') \
    'main never upgrades a cask with unreliable app metadata'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask calm$') \
    'main continues to a later cask after preparation fails'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Failed casks (1): bad-target') \
    'main names a preparation failure in the failed-cask group'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[{"name":"jq"}],"casks":[{"name":"cursor"},{"name":"calm"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_cursor_json','$u_cask_calm_json']}'
# The queue models the running app closing when stopped; the pre-upgrade
# recheck observes that closed state through the same queue.
u_test_running com.todesktop.230313mzl4w4u92 111 -
u_test_run_main eligible-casks
assert_equal 0 $u_test_main_status 'main upgrades eligible casks independently'; or set test_status 1
assert_call_before '^brew upgrade --formula jq$' '^brew info --cask --json=v2 cursor calm$' \
    'main completes the formula phase before preparing casks'; or set test_status 1
assert_equal 1 (u_test_calls '^brew info --cask --json=v2 cursor calm$') \
    'main fetches metadata for every outdated cask in one batched call'; or set test_status 1
assert_call_before '^brew info --cask --json=v2 cursor calm$' '^gum confirm Close these applications' \
    'main prepares every cask before consolidated approval'; or set test_status 1
assert_equal 1 (u_test_calls '^gum confirm Close these applications') \
    'main obtains one consolidated lifecycle approval'; or set test_status 1
assert_call_before ' terminate com\.todesktop' '^brew upgrade --cask cursor$' \
    'main stops a running app before its cask upgrade'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask cursor$') \
    'main upgrades the first eligible cask individually'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask calm$') \
    'main upgrades the later eligible cask individually'; or set test_status 1
assert_equal 1 (u_test_calls '^open /Applications/Cursor.app$') \
    'main reopens an initially running app after its cask upgrade'; or set test_status 1
assert_call_before '^brew upgrade --cask cursor$' '^open /Applications/Cursor.app$' \
    'main reopens an app only after its cask attempt'; or set test_status 1
assert_call_before '^open /Applications/Cursor.app$' '^brew upgrade --cask calm$' \
    'main reopens one cask before attempting the next'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Cask summary: 2 upgraded, 0 skipped, 0 failed') \
    'main prints successful cask aggregate counts'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Upgraded casks (2): cursor, calm') \
    'main names upgraded casks separately'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Skipped casks (0): none') \
    'main reports an empty skipped-cask group separately'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Failed casks (0): none') \
    'main reports an empty failed-cask group separately'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"cursor"},{"name":"calm"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_cursor_json','$u_cask_calm_json']}'
printf '9\n' >"$U_MOCK_DIR/exit-brew-upgrade-cask-cursor"
u_test_running com.todesktop.230313mzl4w4u92 111 -
u_test_run_main cask-failure
assert_equal 1 $u_test_main_status 'one cask failure produces final nonzero status'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask cursor$') \
    'main attempts the failing cask once'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask calm$') \
    'main continues to a later cask after one cask fails'; or set test_status 1
assert_equal 1 (u_test_calls '^open /Applications/Cursor.app$') \
    'main reopens the failed cask application'; or set test_status 1
assert_equal 1 (u_test_calls '^brew cleanup --prune=all$') \
    'main cleans up Homebrew after a cask-level failure'; or set test_status 1
assert_equal 1 (u_test_calls '^brew doctor$') \
    'main doctors Homebrew after a cask-level failure'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Cask summary: 1 upgraded, 0 skipped, 1 failed') \
    'main prints failed casks in aggregate counts'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Failed casks (1): cursor') \
    'main names failed casks separately'; or set test_status 1
assert_equal 1 (u_test_output_contains 'brew upgrade phase completed with failures') \
    'main never prints an unconditional success message after a cask failure'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"cursor"},{"name":"font-hack"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_cursor_json','$u_cask_font_json']}'
touch "$U_MOCK_DIR/gum-running-decline"
u_test_run_main deliberate-skip
assert_equal 0 $u_test_main_status 'a deliberate lifecycle decline is not a command failure'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade --cask cursor$') \
    'main does not upgrade a deliberately skipped running-app cask'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask font-hack$') \
    'main still upgrades a non-running cask after a deliberate skip'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Skipped casks (1): cursor') \
    'main reports deliberately skipped casks separately'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Cask summary: 1 upgraded, 1 skipped, 0 failed') \
    'main keeps skip and failure counts separate'; or set test_status 1
assert_equal 1 (u_test_output_contains 'brew upgrade phase completed with skipped casks') \
    'main identifies a phase that completed with deliberate skips'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"cursor"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_cursor_json']}'
u_test_running com.todesktop.230313mzl4w4u92 111
touch "$U_MOCK_DIR/gum-force-decline"
u_test_run_main force-decline
assert_equal 0 $u_test_main_status 'declining force termination remains a deliberate skip'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade --cask cursor$') \
    'main never upgrades a cask whose force termination was declined'; or set test_status 1
assert_equal 0 (u_test_calls '^open ') \
    'an app that never closed is never reopened'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Skipped casks (1): cursor') \
    'main classifies a declined force termination as skipped'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Failed casks (0): none') \
    'main does not misclassify a declined force termination as failed'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"cursor"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_cursor_json']}'
u_test_running com.todesktop.230313mzl4w4u92 111
u_test_run_main force-failure
assert_equal 1 $u_test_main_status 'an unsuccessful approved force termination fails the run'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade --cask cursor$') \
    'main never upgrades a cask whose application could not be stopped'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Failed casks (1): cursor') \
    'main classifies an unsuccessful force termination as failed'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"cursor"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_cursor_json']}'
# Running at prepare, closed after one poll, but a new instance appears
# before the upgrade.
u_test_running com.todesktop.230313mzl4w4u92 111 - 222
u_test_run_main recheck-appears
assert_equal 0 $u_test_main_status 'an instance appearing before upgrade is a deliberate skip'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade --cask cursor$') \
    'main never upgrades under an application instance that appeared'; or set test_status 1
assert_equal 1 (u_test_calls '^open /Applications/Cursor.app$') \
    'main reopens the app it closed when the recheck skips'; or set test_status 1
assert_equal 1 (u_test_output_contains 'an application instance appeared before upgrade') \
    'main names the recheck skip reason'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Skipped casks (1): cursor') \
    'main classifies a recheck skip as skipped'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"cursor"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_cursor_json']}'
u_test_running com.todesktop.230313mzl4w4u92 111 -
touch "$U_MOCK_DIR/open-always-fail"
u_test_run_main reopen-failure
assert_equal 1 $u_test_main_status 'a failed reopen produces final nonzero status'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask cursor$') \
    'the upgrade itself still ran before the failed reopen'; or set test_status 1
assert_equal 3 (u_test_calls '^open /Applications/Cursor.app$') \
    'the per-cask reopen, final sweep, and exit handler each retry the open'; or set test_status 1
assert_equal 1 (u_test_output_contains 'unable to reopen /Applications/Cursor.app') \
    'main surfaces the reopen failure in final details'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"calm"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_write_cask_info '{"casks":['$u_cask_calm_json']}'
printf '1\n' >"$U_MOCK_DIR/exit-tee"
u_test_run_main tee-failure
assert_equal 0 $u_test_main_status 'a tee failure does not replace successful brew pipeline status'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Cask summary: 1 upgraded, 0 skipped, 0 failed') \
    'main counts the cask upgrade from brew status rather than tee status'; or set test_status 1

rm -rf "$u_mock_root"
exit $test_status
