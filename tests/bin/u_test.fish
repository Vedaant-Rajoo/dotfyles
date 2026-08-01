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

set -g U_STATE_DIR (mktemp -d)

set -l test_status 0
assert_function u_main 'source exposes u_main'; or set test_status 1
assert_function u_discover_outdated 'source exposes u_discover_outdated'; or set test_status 1
assert_function u_cask_app_paths 'source exposes u_cask_app_paths'; or set test_status 1
assert_function u_inspect_app 'source exposes u_inspect_app'; or set test_status 1
assert_function u_prepare_cask 'source exposes u_prepare_cask'; or set test_status 1
assert_function u_confirm_running_apps 'source exposes u_confirm_running_apps'; or set test_status 1
assert_function u_stop_cask_apps 'source exposes u_stop_cask_apps'; or set test_status 1
assert_function u_reopen_token_apps 'source exposes u_reopen_token_apps'; or set test_status 1
assert_function u_cleanup 'source exposes u_cleanup'; or set test_status 1
assert_no_mock_calls; or set test_status 1

# u_discover_outdated

u_discover_outdated '{"formulae":[],"casks":[]}'
assert_equal 0 $status 'discover accepts empty outdated JSON'; or set test_status 1
assert_equal '' "$(cat "$U_STATE_DIR/formulae.tsv")" \
    'discover writes no formula records for empty JSON'; or set test_status 1
assert_equal '' "$(cat "$U_STATE_DIR/casks.tsv")" \
    'discover writes no cask records for empty JSON'; or set test_status 1

u_discover_outdated '{"formulae":[{"name":"jq"}],"casks":[{"name":"cursor"}]}'
assert_equal 0 $status 'discover accepts one formula and one cask'; or set test_status 1
assert_equal jq "$(cat "$U_STATE_DIR/formulae.tsv")" \
    'discover records the outdated formula name'; or set test_status 1
assert_equal cursor "$(cat "$U_STATE_DIR/casks.tsv")" \
    'discover records the outdated cask name'; or set test_status 1

u_discover_outdated '{"formulae":[{"name":"jq"},{"name":"fish"}],"casks":[]}'
assert_equal 0 $status 'discover accepts several formulae'; or set test_status 1
assert_equal 'jq
fish' "$(cat "$U_STATE_DIR/formulae.tsv")" \
    'discover records one formula per line'; or set test_status 1
assert_equal '' "$(cat "$U_STATE_DIR/casks.tsv")" \
    'discover truncates stale cask records'; or set test_status 1

u_discover_outdated 'not json' 2>/dev/null
assert_equal 1 $status 'discover rejects invalid JSON'; or set test_status 1

u_discover_outdated '{"formulae":[{"installed_versions":["1.0"]}],"casks":[]}' 2>/dev/null
assert_equal 1 $status 'discover rejects a formula record without a name'; or set test_status 1

u_discover_outdated '{"formulae":[],"casks":[{"installed_versions":["1.0"]}]}' 2>/dev/null
assert_equal 1 $status 'discover rejects a cask record without a name'; or set test_status 1

# Real callers pass unquoted command substitutions, which fish splits into one
# argument per line. The functions must consume every line, not just the first.
set -l pretty_outdated (printf '%s\n' '{"formulae":[{"name":"jq"}],"casks":[{"name":"cursor"}]}' | jq .)
assert_equal 12 (count $pretty_outdated) 'pretty outdated fixture splits into several arguments'; or set test_status 1
u_discover_outdated $pretty_outdated
assert_equal 0 $status 'discover accepts multiline pretty-printed JSON'; or set test_status 1
assert_equal jq "$(cat "$U_STATE_DIR/formulae.tsv")" \
    'discover records formulae from multiline JSON'; or set test_status 1
assert_equal cursor "$(cat "$U_STATE_DIR/casks.tsv")" \
    'discover records casks from multiline JSON'; or set test_status 1

# A malformed record after a valid one must leave no partial state behind.
u_discover_outdated '{"formulae":[{"name":"jq"},{"installed_versions":["1.0"]}],"casks":[{"name":"cursor"}]}' 2>/dev/null
assert_equal 1 $status 'discover rejects a late malformed formula record'; or set test_status 1
assert_equal jq "$(cat "$U_STATE_DIR/formulae.tsv")" \
    'discover leaves previous formula records intact after a parse failure'; or set test_status 1
assert_equal cursor "$(cat "$U_STATE_DIR/casks.tsv")" \
    'discover leaves previous cask records intact after a parse failure'; or set test_status 1

set -l saved_state_dir $U_STATE_DIR
set -g U_STATE_DIR "$saved_state_dir/missing"
u_discover_outdated '{"formulae":[],"casks":[]}' 2>/dev/null
assert_equal 1 $status 'discover rejects a missing state directory'; or set test_status 1
set -g U_STATE_DIR $saved_state_dir

# u_cask_app_paths

set -l cask_app_json '{"casks":[{"token":"cursor","artifacts":[{"app":["Cursor.app"],"target":"/Applications/Cursor.app"},{"binary":["cursor"],"target":"/opt/homebrew/bin/cursor"}]}]}'
assert_equal /Applications/Cursor.app "$(u_cask_app_paths $cask_app_json)" \
    'cask app paths emits only the app artifact target'; or set test_status 1

set -l cask_non_app_json '{"casks":[{"token":"font-hack","artifacts":[{"font":["Hack-Regular.ttf"]},{"binary":["hack"],"target":"/opt/homebrew/bin/hack"}]}]}'
u_cask_app_paths $cask_non_app_json >/dev/null
assert_equal 0 $status 'cask app paths accepts a cask without app artifacts'; or set test_status 1
assert_equal '' "$(u_cask_app_paths $cask_non_app_json)" \
    'cask app paths emits nothing for a cask without app artifacts'; or set test_status 1

set -l cask_two_apps_json '{"casks":[{"token":"multi","artifacts":[{"app":["One.app"],"target":"/Applications/One.app"},{"app":["Two.app"],"target":"/Applications/Two.app"}]}]}'
assert_equal '/Applications/One.app
/Applications/Two.app' "$(u_cask_app_paths $cask_two_apps_json)" \
    'cask app paths emits every app artifact target'; or set test_status 1

set -l cask_missing_target_json '{"casks":[{"token":"bad","artifacts":[{"app":["Bad.app"]}]}]}'
u_cask_app_paths $cask_missing_target_json >/dev/null 2>&1
assert_equal 1 $status 'cask app paths rejects a missing app target'; or set test_status 1

set -l cask_relative_target_json '{"casks":[{"token":"bad","artifacts":[{"app":["Bad.app"],"target":"Bad.app"}]}]}'
u_cask_app_paths $cask_relative_target_json >/dev/null 2>&1
assert_equal 1 $status 'cask app paths rejects a non-absolute app target'; or set test_status 1

u_cask_app_paths 'not json' >/dev/null 2>&1
assert_equal 1 $status 'cask app paths rejects invalid JSON'; or set test_status 1

set -l cask_spaced_json '{"casks":[{"token":"google-chrome","artifacts":[{"app":["Google Chrome.app"],"target":"/Applications/Google Chrome.app"}]}]}'
assert_equal '/Applications/Google Chrome.app' "$(u_cask_app_paths $cask_spaced_json)" \
    'cask app paths preserves an app target containing spaces'; or set test_status 1

set -l cask_app_pretty (printf '%s\n' $cask_app_json | jq .)
assert_equal 21 (count $cask_app_pretty) 'pretty cask fixture splits into several arguments'; or set test_status 1
assert_equal /Applications/Cursor.app "$(u_cask_app_paths $cask_app_pretty)" \
    'cask app paths accepts multiline pretty-printed JSON'; or set test_status 1

set -l cask_spaced_pretty (printf '%s\n' $cask_spaced_json | jq .)
assert_equal '/Applications/Google Chrome.app' "$(u_cask_app_paths $cask_spaced_pretty)" \
    'cask app paths handles spaces in multiline JSON'; or set test_status 1

# A malformed artifact after a valid one must not leak partial stdout.
set -l cask_late_bad_json '{"casks":[{"token":"mixed","artifacts":[{"app":["Good.app"],"target":"/Applications/Good.app"},{"app":["Bad.app"]}]}]}'
assert_equal '' "$(u_cask_app_paths $cask_late_bad_json 2>/dev/null)" \
    'cask app paths emits nothing when a later artifact is malformed'; or set test_status 1
u_cask_app_paths $cask_late_bad_json >/dev/null 2>&1
assert_equal 1 $status 'cask app paths rejects a late malformed artifact'; or set test_status 1

# ---------------------------------------------------------------------------
# Lifecycle discovery and consolidated confirmation
#
# These cases replace brew, osascript, and gum with real executables placed
# first in PATH, so the production functions have to invoke them exactly the
# way a real run would. The fish-function mocks above would shadow PATH, so
# they are erased first.
# ---------------------------------------------------------------------------

functions -e brew gum

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
if test (count $argv) -eq 4; and test "$argv[1]" = info; and test "$argv[2]" = --cask; and test "$argv[3]" = --json=v2
    set -l fixture "$U_MOCK_DIR/cask-$argv[-1].json"
    if test -e "$fixture"
        cat "$fixture"
        exit 0
    end
    echo "brew mock: no fixture for $argv[-1]" >>"$U_MOCK_LOG"
    exit 1
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
    set -l token_key (string join + $argv[3..-1])
    set -l exit_fixture "$U_MOCK_DIR/exit-brew-upgrade-$kind-$token_key"
    if test -e "$exit_fixture"
        exit (string trim <"$exit_fixture")
    end
    exit 0
end
if contains -- "$argv[1]" update cleanup doctor
    set -l exit_fixture "$U_MOCK_DIR/exit-brew-$argv[1]"
    if test -e "$exit_fixture"
        exit (string trim <"$exit_fixture")
    end
    exit 0
end
echo "brew mock: unexpected invocation: $argv" >>"$U_MOCK_LOG"
exit 64' >"$u_mock_bin/brew"

echo '#!/usr/bin/env fish
echo "osascript $argv" >>"$U_MOCK_LOG"
if test "$argv[1]" != -l; or test "$argv[2]" != JavaScript; or not string match -q -- "*/u-cask-lifecycle.js" "$argv[3]"
    echo "osascript mock: unexpected invocation: $argv" >>"$U_MOCK_LOG"
    exit 64
end

set -l command "$argv[4]"
if test "$command" = inspect; and test (count $argv) -eq 5
    set -l fixture "$U_MOCK_DIR/inspect"(string replace -a / _ -- "$argv[5]")".json"
    if test -e "$fixture"
        cat "$fixture"
        exit 0
    end
    echo "osascript mock: no fixture for $argv[5]" >>"$U_MOCK_LOG"
    exit 66
end

if contains -- "$command" running terminate force-terminate; and test (count $argv) -ge 5
    set -l bundle_id "$argv[5]"
    set -l bundle_key (string replace -a / _ -- "$bundle_id")
    set -l operation_key "$bundle_key-$command"
    set -l post_fixture "$U_MOCK_DIR/post-$operation_key"
    if test -e "$post_fixture"
        cp "$post_fixture" "$U_MOCK_DIR/running-$bundle_key"
    end

    set -l exit_fixture "$U_MOCK_DIR/exit-$operation_key"
    if test -e "$exit_fixture"; and not begin
            test "$command" = running
            and test -e "$U_MOCK_DIR/defer-running-error-until-force"
            and not test -e "$U_MOCK_DIR/force-seen-$bundle_key"
        end
        set -l exit_status (string trim <"$exit_fixture")
        if test "$exit_status" -ne 0
            if test "$command" = running
                if test -e "$U_MOCK_DIR/signal-running-error-SIGINT"; and not test -e "$U_MOCK_DIR/signal-sent"
                    touch "$U_MOCK_DIR/signal-sent"
                    kill -INT "$U_TEST_FISH_PID"
                end
                if test -e "$U_MOCK_DIR/signal-running-error-SIGTERM"; and test -e "$U_MOCK_DIR/force-seen-$bundle_key"; and not test -e "$U_MOCK_DIR/signal-sent"
                    touch "$U_MOCK_DIR/signal-sent"
                    kill -TERM "$U_TEST_FISH_PID"
                end
            end
            exit "$exit_status"
        end
    end

    set -l pids
    if test "$command" = force-terminate
        touch "$U_MOCK_DIR/force-seen-$bundle_key"
    end

    if test "$command" = running
        set -l queue "$U_MOCK_DIR/running-$bundle_key"
        if test -e "$queue"
            set -l lines (cat "$queue")
            if test (count $lines) -gt 0; and test "$lines[1]" != -
                set pids (string split , -- "$lines[1]")
            end
            if test (count $lines) -gt 1
                printf "%s\n" $lines[2..-1] >"$queue"
            end
        end
    end

    printf "{\"bundleId\":\"%s\",\"pids\":[%s]}\n" "$bundle_id" (string join , $pids)

    if test "$command" = running
        if test -e "$U_MOCK_DIR/signal-graceful-SIGINT"; and not test -e "$U_MOCK_DIR/signal-sent"
            touch "$U_MOCK_DIR/signal-sent"
            kill -INT "$U_TEST_FISH_PID"
        end
        if test -e "$U_MOCK_DIR/signal-force-SIGTERM"; and test -e "$U_MOCK_DIR/force-seen-$bundle_key"; and not test -e "$U_MOCK_DIR/signal-sent"
            touch "$U_MOCK_DIR/signal-sent"
            kill -TERM "$U_TEST_FISH_PID"
        end
    end

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
if test -e "$U_MOCK_DIR/signal-on-first-open"; and not test -e "$U_MOCK_DIR/signal-sent"
    touch "$U_MOCK_DIR/signal-sent"
    kill -INT "$U_TEST_FISH_PID"
end
if test -e "$U_MOCK_DIR/open-always-fail"
    exit 1
end
if test -e "$U_MOCK_DIR/open-fail-once"; and not test -e "$U_MOCK_DIR/open-failed"
    touch "$U_MOCK_DIR/open-failed"
    exit 1
end
exit 0' >"$u_mock_bin/open"

echo '#!/usr/bin/env fish
if test -e "$U_MOCK_DIR/fail-app-state-rollback"; and string match -q -- "*/apps.tsv" "$argv[-1]"
    set -l count_file "$U_MOCK_DIR/apps-mv-count"
    set -l count 0
    if test -e "$count_file"
        set count (string trim <"$count_file")
    end
    set count (math $count + 1)
    printf "%s\n" $count >"$count_file"
    if test $count -eq 3
        exit 1
    end
end
/bin/mv $argv' >"$u_mock_bin/mv"

chmod +x "$u_mock_bin/brew" "$u_mock_bin/osascript" "$u_mock_bin/gum" "$u_mock_bin/nvim" "$u_mock_bin/bat" "$u_mock_bin/tee" "$u_mock_bin/sleep" "$u_mock_bin/open" "$u_mock_bin/mv"
set -gx PATH "$u_mock_bin" $PATH

function u_test_write_cask --argument-names token json
    # Pretty-print so the parsers keep proving they read every argument line.
    printf '%s\n' $json | jq . >"$U_MOCK_DIR/cask-$token.json"
end

function u_test_write_inspect --argument-names bundle_path json
    printf '%s\n' $json | jq . >"$U_MOCK_DIR/inspect"(string replace -a / _ -- $bundle_path)".json"
end

function u_test_reset
    rm -f "$U_STATE_DIR/apps.tsv" "$U_STATE_DIR/skips.tsv" "$U_STATE_DIR/failures.tsv" "$U_STATE_DIR/reopen-fallback.tsv"
    rm -f "$U_MOCK_DIR"/gum-confirm-decline "$U_MOCK_DIR"/gum-running-decline "$U_MOCK_DIR"/gum-force-decline
    for fixture in (command find "$U_MOCK_DIR" -maxdepth 1 -type f \( -name 'running-*' -o -name 'exit-*' -o -name 'post-*' -o -name 'signal-*' -o -name 'force-seen-*' -o -name 'open-fail-*' -o -name 'open-always-fail' -o -name 'open-failed' -o -name 'defer-running-*' -o -name 'outdated.json' -o -name 'apps-mv-count' -o -name 'fail-app-state-rollback' \))
        rm -f "$fixture"
    end
    set -e U_FALLBACK_OPEN_ATTEMPTED
    printf '' >"$U_MOCK_LOG"
end

function u_test_calls --argument-names pattern
    grep -c -e $pattern "$U_MOCK_LOG"
end

function u_test_state --argument-names name
    if test -e "$U_STATE_DIR/$name"
        string replace -a \t '|' <"$U_STATE_DIR/$name"
    end
end

function u_test_state_count --argument-names name
    if test -e "$U_STATE_DIR/$name"
        count (cat "$U_STATE_DIR/$name")
        return 0
    end
    echo 0
end

function u_test_matches
    count (string match -a -- "*$argv[1]*" $argv[2..-1])
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

function u_test_run_main --argument-names case_name preserve_state
    set -g U_STATE_DIR "$u_mock_root/state-$case_name"
    if test "$preserve_state" != 1
        rm -rf "$U_STATE_DIR"
    end
    mkdir -p "$U_STATE_DIR"
    set -l output_file "$u_mock_root/$case_name.out"
    env U_TEST_MODE=1 U_STATE_DIR="$U_STATE_DIR" U_MOCK_DIR="$U_MOCK_DIR" U_MOCK_LOG="$U_MOCK_LOG" \
        fish --no-config -c 'source "$argv[1]"; u_main' "$repo_root/bin/u" >"$output_file" 2>&1
    set -g u_test_main_status $status
    set -g u_test_main_output (string collect <"$output_file")
    if test $u_test_main_status -eq 127
        cp "$output_file" "/tmp/u-test-$case_name.out"
    end
end

u_test_write_cask cursor '{"casks":[{"token":"cursor","artifacts":[{"app":["Cursor.app"],"target":"/Applications/Cursor.app"},{"binary":["cursor"],"target":"/opt/homebrew/bin/cursor"}]}]}'
u_test_write_cask google-chrome '{"casks":[{"token":"google-chrome","artifacts":[{"app":["Google Chrome.app"],"target":"/Applications/Google Chrome.app"}]}]}'
u_test_write_cask calm '{"casks":[{"token":"calm","artifacts":[{"app":["Calm.app"],"target":"/Applications/Calm.app"}]}]}'
u_test_write_cask font-hack '{"casks":[{"token":"font-hack","artifacts":[{"font":["Hack-Regular.ttf"]}]}]}'
u_test_write_cask multi '{"casks":[{"token":"multi","artifacts":[{"app":["One.app"],"target":"/Applications/One.app"},{"app":["Two.app"],"target":"/Applications/Two.app"}]}]}'
u_test_write_cask bad-target '{"casks":[{"token":"bad-target","artifacts":[{"app":["Bad.app"]}]}]}'
u_test_write_cask ghost '{"casks":[{"token":"ghost","artifacts":[{"app":["Ghost.app"],"target":"/Applications/Ghost.app"}]}]}'

u_test_write_inspect /Applications/Cursor.app '{"path":"/Applications/Cursor.app","bundleId":"com.todesktop.230313mzl4w4u92","pids":[111]}'
u_test_write_inspect '/Applications/Google Chrome.app' '{"path":"/Applications/Google Chrome.app","bundleId":"com.google.Chrome","pids":[222,333]}'
u_test_write_inspect /Applications/Calm.app '{"path":"/Applications/Calm.app","bundleId":"com.calm.Calm","pids":[]}'
u_test_write_inspect /Applications/One.app '{"path":"/Applications/One.app","bundleId":"com.example.One","pids":[]}'
u_test_write_inspect /Applications/Two.app '{"path":"/Applications/Two.app","bundleId":"com.example.Two","pids":[444]}'
u_test_write_inspect /Applications/Broken.app '{"path":"/Applications/Broken.app","bundleId":"","pids":[]}'
u_test_write_inspect /Applications/Double.app '{"path":"/Applications/Double.app","bundleId":"com.example.Double","pids":[]}
{"path":"/Applications/Double.app","bundleId":"com.example.Other","pids":[555]}'

# Casks whose metadata command succeeds while describing no cask at all.
printf '' >"$U_MOCK_DIR/cask-silent.json"
printf '   \n' >"$U_MOCK_DIR/cask-blank.json"
u_test_write_cask no-casks '{"casks":[]}'

# u_inspect_app

u_test_reset
assert_equal '/Applications/Cursor.app|com.todesktop.230313mzl4w4u92|111' \
    "$(u_inspect_app /Applications/Cursor.app | string replace -a \t '|')" \
    'inspect app emits path, bundle identifier, and PIDs'; or set test_status 1

assert_equal '/Applications/Calm.app|com.calm.Calm|' \
    "$(u_inspect_app /Applications/Calm.app | string replace -a \t '|')" \
    'inspect app emits an empty PID column for a stopped app'; or set test_status 1

assert_equal '/Applications/Google Chrome.app|com.google.Chrome|222,333' \
    "$(u_inspect_app '/Applications/Google Chrome.app' | string replace -a \t '|')" \
    'inspect app joins several PIDs and keeps spaces in the path'; or set test_status 1

u_inspect_app /Applications/Broken.app >/dev/null 2>&1
assert_equal 1 $status 'inspect app rejects output without a bundle identifier'; or set test_status 1

assert_equal '' "$(u_inspect_app /Applications/Broken.app 2>/dev/null)" \
    'inspect app emits nothing for unusable helper output'; or set test_status 1

u_inspect_app /Applications/Missing.app >/dev/null 2>&1
assert_equal 1 $status 'inspect app propagates a helper failure'; or set test_status 1

u_inspect_app >/dev/null 2>&1
assert_equal 1 $status 'inspect app rejects an empty bundle path'; or set test_status 1

u_inspect_app /Applications/Double.app >/dev/null 2>&1
assert_equal 1 $status 'inspect app rejects more than one inspect record'; or set test_status 1

assert_equal '' "$(u_inspect_app /Applications/Double.app 2>/dev/null)" \
    'inspect app emits nothing when the helper describes several bundles'; or set test_status 1

# u_prepare_cask

u_test_reset
u_prepare_cask cursor
assert_equal 0 $status 'prepare accepts an app cask'; or set test_status 1
assert_equal 1 (u_test_calls ' inspect ') \
    'prepare inspects exactly one artifact for a cask with one app'; or set test_status 1
assert_equal 1 (u_test_calls ' inspect /Applications/Cursor.app$') \
    'prepare inspects only the app artifact target'; or set test_status 1
assert_equal 'cursor|/Applications/Cursor.app|com.todesktop.230313mzl4w4u92|111|1|0|0' \
    "$(u_test_state apps.tsv)" \
    'prepare records the running app state row'; or set test_status 1

u_test_reset
u_prepare_cask font-hack
assert_equal 0 $status 'prepare accepts a cask without app artifacts'; or set test_status 1
assert_equal 0 (u_test_calls ' inspect ') \
    'prepare never inspects a cask without app artifacts'; or set test_status 1
assert_equal '' "$(u_test_state apps.tsv)" \
    'prepare records no app state for a non-app cask'; or set test_status 1

u_test_reset
u_prepare_cask calm
assert_equal 0 $status 'prepare accepts a stopped app cask'; or set test_status 1
assert_equal 'calm|/Applications/Calm.app|com.calm.Calm||0|0|0' "$(u_test_state apps.tsv)" \
    'prepare records a stopped app as not running'; or set test_status 1

u_test_reset
u_prepare_cask multi
assert_equal 0 $status 'prepare accepts a multi-app cask'; or set test_status 1
assert_equal 2 (u_test_calls ' inspect ') \
    'prepare inspects every app artifact of a multi-app cask'; or set test_status 1
assert_equal 'multi|/Applications/One.app|com.example.One||0|0|0
multi|/Applications/Two.app|com.example.Two|444|1|0|0' "$(u_test_state apps.tsv)" \
    'prepare records one row per app artifact'; or set test_status 1

# fish does not apply a caller's redirection to a command substitution inside
# the callee, so this case still prints its expected parser diagnostic.
u_test_reset
u_prepare_cask bad-target 2>/dev/null
assert_equal 1 $status 'prepare rejects a cask with an unusable app target'; or set test_status 1
assert_equal 0 (u_test_calls ' inspect ') \
    'prepare never inspects when app targets are unreliable'; or set test_status 1
assert_equal '' "$(u_test_state apps.tsv)" \
    'prepare records no app state for unreliable metadata'; or set test_status 1
assert_equal 1 (u_test_state_count skips.tsv) \
    'prepare skips a cask with unreliable app targets'; or set test_status 1

u_test_reset
u_prepare_cask ghost 2>/dev/null
assert_equal 1 $status 'prepare rejects a cask whose app cannot be inspected'; or set test_status 1
assert_equal '' "$(u_test_state apps.tsv)" \
    'prepare records no app state when inspection fails'; or set test_status 1
assert_equal 1 (u_test_state_count failures.tsv) \
    'prepare records one failure when inspection fails'; or set test_status 1

u_test_reset
u_prepare_cask unknown-cask 2>/dev/null
assert_equal 1 $status 'prepare rejects a cask without Homebrew metadata'; or set test_status 1
assert_equal 0 (u_test_calls ' inspect ') \
    'prepare never inspects when brew info fails'; or set test_status 1
assert_equal 1 (u_test_state_count failures.tsv) \
    'prepare records one failure when brew info fails'; or set test_status 1
assert_equal 1 (u_test_state_count skips.tsv) \
    'prepare skips a cask whose metadata command fails'; or set test_status 1

# Metadata that describes no cask is unknown state, never "no applications".
for silent_token in silent blank no-casks
    u_test_reset
    u_prepare_cask $silent_token 2>/dev/null
    assert_equal 1 $status "prepare rejects $silent_token cask metadata"; or set test_status 1
    assert_equal 0 (u_test_calls ' inspect ') \
        "prepare never inspects for $silent_token cask metadata"; or set test_status 1
    assert_equal '' "$(u_test_state apps.tsv)" \
        "prepare records no app state for $silent_token cask metadata"; or set test_status 1
    assert_equal 1 (u_test_state_count skips.tsv) \
        "prepare skips a cask with $silent_token metadata"; or set test_status 1
end

# u_confirm_running_apps

u_test_reset
u_confirm_running_apps >/dev/null
assert_equal 0 $status 'confirm accepts an empty application state'; or set test_status 1
assert_equal 0 (u_test_calls '^gum confirm') \
    'confirm never prompts without recorded applications'; or set test_status 1

u_test_reset
u_prepare_cask calm
u_prepare_cask font-hack
u_confirm_running_apps >/dev/null
assert_equal 0 $status 'confirm accepts casks whose apps are not running'; or set test_status 1
assert_equal 0 (u_test_calls '^gum confirm') \
    'confirm never prompts when no recorded app is running'; or set test_status 1
assert_equal '' "$(u_test_state skips.tsv)" \
    'confirm skips nothing when no recorded app is running'; or set test_status 1

u_test_reset
u_prepare_cask cursor
u_prepare_cask google-chrome
u_prepare_cask calm
u_prepare_cask font-hack
set -l confirm_output (u_confirm_running_apps)
assert_equal 0 $status 'confirm accepts an approved consolidated prompt'; or set test_status 1
assert_equal 1 (u_test_calls '^gum confirm') \
    'confirm asks exactly one consolidated question'; or set test_status 1
assert_equal 1 (u_test_matches 'Cursor (cursor)' $confirm_output) \
    'confirm lists the running Cursor app once'; or set test_status 1
assert_equal 1 (u_test_matches 'Google Chrome (google-chrome)' $confirm_output) \
    'confirm lists the running Google Chrome app once'; or set test_status 1
assert_equal 0 (u_test_matches Calm $confirm_output) \
    'confirm never lists an app that is not running'; or set test_status 1
assert_equal '' "$(u_test_state skips.tsv)" \
    'an approved prompt skips nothing'; or set test_status 1

u_test_reset
u_prepare_cask cursor
u_prepare_cask google-chrome
u_prepare_cask calm
u_prepare_cask font-hack
touch "$U_MOCK_DIR/gum-confirm-decline"
u_confirm_running_apps >/dev/null
assert_equal 2 $status 'confirm reports a deliberate consolidated-prompt skip'; or set test_status 1
assert_equal 1 (u_test_calls '^gum confirm') \
    'a declined prompt is still asked exactly once'; or set test_status 1
assert_equal 'cursor
google-chrome' "$(cut -f1 "$U_STATE_DIR/skips.tsv" | sort)" \
    'a declined prompt skips only the running-app casks'; or set test_status 1
assert_equal '' "$(u_test_state failures.tsv)" \
    'a declined prompt records no command failure'; or set test_status 1

u_test_reset
u_prepare_cask cursor
touch "$U_MOCK_DIR/gum-confirm-decline"
functions -c u_record_skip u_record_skip_real
function u_record_skip
    return 1
end
u_confirm_running_apps >/dev/null
set -l unrecorded_confirmation_status $status
functions -e u_record_skip
functions -c u_record_skip_real u_record_skip
functions -e u_record_skip_real
assert_equal 1 $unrecorded_confirmation_status \
    'confirm fails closed when a declined decision cannot be recorded'; or set test_status 1
assert_equal cursor "$U_CONFIRM_RUNNING_TOKENS" \
    'confirm retains the affected token when recording fails'; or set test_status 1
assert_equal '' "$(u_test_state skips.tsv)" \
    'confirm never claims an unrecorded decision was persisted'; or set test_status 1

u_test_reset
u_prepare_cask multi
touch "$U_MOCK_DIR/gum-confirm-decline"
u_confirm_running_apps >/dev/null
assert_equal 2 $status 'confirm reports a deliberate multi-app cask skip'; or set test_status 1
assert_equal 'multi|declined closing running applications' "$(u_test_state skips.tsv)" \
    'a declined prompt skips a multi-app cask exactly once'; or set test_status 1

# u_stop_cask_apps, u_reopen_token_apps, and u_cleanup
#
# Every lifecycle command below is the PATH mock above. These tests never invoke
# AppKit or terminate a real process.

function u_test_write_apps
    printf '%b\n' $argv >"$U_STATE_DIR/apps.tsv"
end

function u_test_running --argument-names bundle_id
    set -l states $argv[2..-1]
    for index in (seq (count $states))
        if test -z "$states[$index]"
            set states[$index] -
        end
    end
    printf '%s\n' $states >"$U_MOCK_DIR/running-$bundle_id"
end

function u_test_post_operation --argument-names bundle_id command
    set -l state "$argv[3]"
    if test -z "$state"
        set state -
    end
    printf '%s\n' "$state" >"$U_MOCK_DIR/post-$bundle_id-$command"
end

u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111,222\t1\t0\t0'
u_test_running com.cursor.Cursor '111,222' ''
u_stop_cask_apps cursor
assert_equal 0 $status 'stop accepts graceful termination before timeout'; or set test_status 1
assert_equal 1 (u_test_calls ' terminate com.cursor.Cursor 111 222$') \
    'stop requests graceful termination for every exact recorded PID'; or set test_status 1
assert_equal 2 (u_test_calls ' running com.cursor.Cursor 111 222$') \
    'stop polls exact recorded PIDs until graceful termination finishes'; or set test_status 1
assert_equal 2 (u_test_calls '^sleep 1$') \
    'stop waits one second before each graceful running check'; or set test_status 1
assert_equal 0 (u_test_calls ' force-terminate ') \
    'stop never force-terminates an app that exits gracefully'; or set test_status 1
assert_equal 'cursor|/Applications/Cursor.app|com.cursor.Cursor|111,222|1|1|0' "$(u_test_state apps.tsv)" \
    'graceful termination marks the app closed for later reopen'; or set test_status 1

u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0'
u_test_running com.cursor.Cursor 111
touch "$U_MOCK_DIR/gum-force-decline"
u_stop_cask_apps cursor >/dev/null
assert_equal 2 $status 'stop reports a deliberate skip when force termination is declined'; or set test_status 1
assert_equal 10 (u_test_calls ' running com.cursor.Cursor 111$') \
    'stop performs no more than ten running checks before force confirmation'; or set test_status 1
assert_equal 10 (u_test_calls '^sleep 1$') \
    'stop waits no more than ten one-second polling intervals'; or set test_status 1
assert_equal 1 (u_test_calls '^gum confirm Force quit Cursor') \
    'a still-running app gets one dedicated force confirmation'; or set test_status 1
assert_equal 0 (u_test_calls ' force-terminate ') \
    'declining force confirmation never invokes force termination'; or set test_status 1
assert_equal 'cursor|application remained running after force termination was declined' "$(u_test_state skips.tsv)" \
    'declined force termination skips the complete cask'; or set test_status 1

u_test_reset
printf 'google-chrome\tprior skip\n' >"$U_STATE_DIR/skips.tsv"
u_test_write_apps 'chrome\t/Applications/Chrome.app\tcom.example.Chrome\t111\t1\t0\t0'
u_test_running com.example.Chrome 111
touch "$U_MOCK_DIR/gum-force-decline"
u_stop_cask_apps chrome >/dev/null
assert_equal 'chrome
google-chrome' "$(cut -f1 "$U_STATE_DIR/skips.tsv" | sort)" \
    'skip deduplication matches the exact cask token field'; or set test_status 1

u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0'
u_test_running com.cursor.Cursor 111
u_test_post_operation com.cursor.Cursor force-terminate ''
u_stop_cask_apps cursor >/dev/null
assert_equal 0 $status 'accepted force termination makes the cask eligible'; or set test_status 1
assert_equal 1 (u_test_calls ' force-terminate com.cursor.Cursor 111$') \
    'accepted force confirmation targets only the exact recorded PID'; or set test_status 1
assert_equal 11 (u_test_calls ' running com.cursor.Cursor 111$') \
    'stop reconciles exact PIDs after force termination'; or set test_status 1
assert_equal 'cursor|/Applications/Cursor.app|com.cursor.Cursor|111|1|1|0' "$(u_test_state apps.tsv)" \
    'successful force termination tracks the app for reopen'; or set test_status 1
assert_equal '' "$(u_test_state skips.tsv)" \
    'successful force termination does not skip the cask'; or set test_status 1

# A multi-PID helper operation can close one process and then exit 70. The
# coordinator must query every original PID again, preserve that partial close
# for cleanup, and skip rather than assume the remaining process stopped.
u_test_reset
u_test_write_apps 'chrome\t/Applications/Google Chrome.app\tcom.google.Chrome\t222,333\t1\t0\t0'
u_test_running com.google.Chrome '222,333'
u_test_post_operation com.google.Chrome force-terminate 333
printf '70\n' >"$U_MOCK_DIR/exit-com.google.Chrome-force-terminate"
u_stop_cask_apps chrome >/dev/null
assert_equal 1 $status 'failed force termination rejects the cask'; or set test_status 1
assert_equal 11 (u_test_calls ' running com.google.Chrome 222 333$') \
    'helper errors are reconciled against every originally recorded PID'; or set test_status 1
assert_equal 'chrome|/Applications/Google Chrome.app|com.google.Chrome|222,333|1|0|0' "$(u_test_state apps.tsv)" \
    'a multi-PID app remains open while any recorded PID is still running'; or set test_status 1
assert_equal 'chrome|force termination helper failed' "$(u_test_state skips.tsv)" \
    'failed force termination skips the complete cask'; or set test_status 1

u_test_reset
u_test_write_apps 'chrome\t/Applications/Google Chrome.app\tcom.google.Chrome\t222,333\t1\t0\t0'
u_test_running com.google.Chrome '222,333'
u_test_post_operation com.google.Chrome force-terminate ''
printf '70\n' >"$U_MOCK_DIR/exit-com.google.Chrome-force-terminate"
u_stop_cask_apps chrome >/dev/null
assert_equal 1 $status 'a force helper error skips even when reconciliation finds the app closed'; or set test_status 1
assert_equal 'chrome|/Applications/Google Chrome.app|com.google.Chrome|222,333|1|1|0' "$(u_test_state apps.tsv)" \
    'helper-error reconciliation preserves reopen tracking when every PID closed'; or set test_status 1
assert_equal 'chrome|force termination helper failed' "$(u_test_state skips.tsv)" \
    'a force helper error skips the complete cask after successful reconciliation'; or set test_status 1

u_test_reset
u_test_write_apps \
    'multi\t/Applications/One.app\tcom.example.One\t111\t1\t0\t0' \
    'multi\t/Applications/Two.app\tcom.example.Two\t222\t1\t0\t0'
u_test_running com.example.One ''
u_test_running com.example.Two 222
touch "$U_MOCK_DIR/gum-force-decline"
u_stop_cask_apps multi >/dev/null
assert_equal 2 $status 'one declined artifact skips a multi-app cask'; or set test_status 1
assert_equal 'multi|/Applications/One.app|com.example.One|111|1|1|0
multi|/Applications/Two.app|com.example.Two|222|1|0|0' "$(u_test_state apps.tsv)" \
    'a multi-app failure keeps already closed artifacts tracked'; or set test_status 1
assert_equal 1 (u_test_state_count skips.tsv) \
    'a failed artifact skips its multi-app cask exactly once'; or set test_status 1

u_test_reset
u_test_write_apps \
    'multi\t/Applications/One.app\tcom.example.One\t\t0\t0\t0' \
    'multi\t/Applications/Two.app\tcom.example.Two\t222\t1\t1\t0'
u_reopen_token_apps multi
assert_equal 0 $status 'reopen accepts a token with closed tracked apps'; or set test_status 1
assert_equal 0 (u_test_calls 'open /Applications/One.app$') \
    'reopen never opens an app that was not initially running'; or set test_status 1
assert_equal 1 (u_test_calls 'open /Applications/Two.app$') \
    'reopen opens an initially running app that was closed'; or set test_status 1
assert_equal 'multi|/Applications/One.app|com.example.One||0|0|0
multi|/Applications/Two.app|com.example.Two|222|1|1|1' "$(u_test_state apps.tsv)" \
    'reopen marks only the successfully opened state row'; or set test_status 1

u_cleanup
u_cleanup
assert_equal 1 (u_test_calls 'open /Applications/Two.app$') \
    'overlapping cleanup paths do not reopen an app twice'; or set test_status 1

u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t1\t0'
touch "$U_MOCK_DIR/open-fail-once"
functions -c u_set_app_flags u_test_real_set_app_flags
set -g u_test_flag_writes 0
function u_set_app_flags
    set -g u_test_flag_writes (math $u_test_flag_writes + 1)
    if test $u_test_flag_writes -gt 1
        return 1
    end
    u_test_real_set_app_flags $argv
end
u_reopen_token_apps cursor
assert_equal 1 $status 'failed reopen with failed state rollback reports failure'; or set test_status 1
assert_equal 'cursor|/Applications/Cursor.app' "$(u_test_state reopen-fallback.tsv)" \
    'failed reopen rollback leaves a durable cleanup fallback'; or set test_status 1
functions -e u_set_app_flags
functions -c u_test_real_set_app_flags u_set_app_flags
functions -e u_test_real_set_app_flags
u_cleanup
assert_equal 2 (u_test_calls 'open /Applications/Cursor.app$') \
    'cleanup retries reopen after rollback publication fails'; or set test_status 1

u_test_reset
u_test_write_apps \
    'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t1\t0' \
    'chrome\t/Applications/Google Chrome.app\tcom.google.Chrome\t222,333\t1\t1\t0' \
    'calm\t/Applications/Calm.app\tcom.calm.Calm\t\t0\t0\t0'
u_cleanup
assert_equal 1 (u_test_calls 'open /Applications/Cursor.app$') \
    'early-exit cleanup reopens the first closed tracked app'; or set test_status 1
assert_equal 1 (u_test_calls 'open /Applications/Google Chrome.app$') \
    'early-exit cleanup reopens every closed tracked app'; or set test_status 1
assert_equal 0 (u_test_calls 'open /Applications/Calm.app$') \
    'early-exit cleanup ignores apps that were not initially running'; or set test_status 1
u_cleanup
assert_equal 2 (u_test_calls '^open ') \
    'early-exit cleanup remains idempotent when called again'; or set test_status 1

u_test_reset
u_test_write_apps \
    'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t1\t0' \
    'chrome\t/Applications/Google Chrome.app\tcom.google.Chrome\t222\t1\t1\t0'
touch "$U_MOCK_DIR/signal-on-first-open"
set -lx U_STATE_DIR "$U_STATE_DIR"
fish -c 'set -gx U_TEST_FISH_PID $fish_pid; source "$argv[1]"; u_cleanup; /bin/sleep 0.1' "$repo_root/bin/u"
assert_equal 'cursor|/Applications/Cursor.app|com.cursor.Cursor|111|1|1|1
chrome|/Applications/Google Chrome.app|com.google.Chrome|222|1|1|1' "$(u_test_state apps.tsv)" \
    'SIGINT overlapping normal cleanup reopens every closed tracked app'; or set test_status 1
assert_equal 2 (u_test_calls '^open ') \
    'overlapping signal cleanup opens each tracked app exactly once'; or set test_status 1

# Signals arriving after a lifecycle helper closes the app but before the state
# row is published must wait until reconciliation and publication complete.
u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0'
u_test_running com.cursor.Cursor ''
touch "$U_MOCK_DIR/signal-graceful-SIGINT"
fish -c 'set -gx U_TEST_FISH_PID $fish_pid; source "$argv[1]"; u_stop_cask_apps cursor; /bin/sleep 0.1' "$repo_root/bin/u"
assert_equal 'cursor|/Applications/Cursor.app|com.cursor.Cursor|111|1|1|1' "$(u_test_state apps.tsv)" \
    'SIGINT after graceful termination waits for closure publication before cleanup'; or set test_status 1
assert_equal 1 (u_test_calls 'open /Applications/Cursor.app$') \
    'SIGINT after graceful termination reopens the newly closed app'; or set test_status 1

u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0'
u_test_running com.cursor.Cursor 111
u_test_post_operation com.cursor.Cursor force-terminate ''
touch "$U_MOCK_DIR/signal-force-SIGTERM"
fish -c 'function gum; return 0; end; set -gx U_TEST_FISH_PID $fish_pid; source "$argv[1]"; u_stop_cask_apps cursor; /bin/sleep 0.1' "$repo_root/bin/u"
assert_equal 'cursor|/Applications/Cursor.app|com.cursor.Cursor|111|1|1|1' "$(u_test_state apps.tsv)" \
    'SIGTERM after force termination waits for closure publication before cleanup'; or set test_status 1
assert_equal 1 (u_test_calls 'open /Applications/Cursor.app$') \
    'SIGTERM after force termination reopens the newly closed app'; or set test_status 1

# If closure publication fails after exact-PID reconciliation proves the app is
# closed, stop must immediately reopen it rather than leave cleanup blind.
u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0'
u_test_running com.cursor.Cursor ''
functions -c u_set_app_flags u_test_real_set_app_flags
function u_set_app_flags
    return 1
end
u_stop_cask_apps cursor >/dev/null
assert_equal 1 $status 'closure publication failure rejects the cask'; or set test_status 1
assert_equal 1 (u_test_calls 'open /Applications/Cursor.app$') \
    'closure publication failure immediately reopens the closed app'; or set test_status 1
assert_equal 'cursor|/Applications/Cursor.app|com.cursor.Cursor|111|1|0|0' "$(u_test_state apps.tsv)" \
    'closure publication failure leaves the prior app state intact'; or set test_status 1
functions -e u_set_app_flags
functions -c u_test_real_set_app_flags u_set_app_flags
functions -e u_test_real_set_app_flags

u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0'
u_test_running com.cursor.Cursor ''
touch "$U_MOCK_DIR/open-fail-once"
functions -c u_set_app_flags u_test_real_set_app_flags
function u_set_app_flags
    return 1
end
u_stop_cask_apps cursor >/dev/null
assert_equal 1 $status 'closure publication and immediate reopen failure rejects the cask'; or set test_status 1
assert_equal 'cursor|/Applications/Cursor.app' "$(u_test_state reopen-fallback.tsv)" \
    'failed immediate reopen leaves a durable cleanup fallback'; or set test_status 1
functions -e u_set_app_flags
functions -c u_test_real_set_app_flags u_set_app_flags
functions -e u_test_real_set_app_flags
u_cleanup
assert_equal 2 (u_test_calls 'open /Applications/Cursor.app$') \
    'later cleanup retries a failed immediate reopen'; or set test_status 1
assert_equal '' "$(u_test_state reopen-fallback.tsv)" \
    'successful cleanup consumes the durable reopen fallback'; or set test_status 1

# A reconciliation error leaves the original PID outcome unknown. LaunchServices
# may accept open while that old process is still terminating, so the durable
# fallback must survive until a later check proves every original PID is gone.
u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0'
u_test_post_operation com.cursor.Cursor terminate ''
printf '70\n' >"$U_MOCK_DIR/exit-com.cursor.Cursor-running"
u_stop_cask_apps cursor >/dev/null
assert_equal 'cursor|/Applications/Cursor.app|com.cursor.Cursor|111' "$(u_test_state reopen-fallback.tsv)" \
    'reconciliation failure keeps exact PID metadata in the durable fallback'; or set test_status 1
rm -f "$U_MOCK_DIR/exit-com.cursor.Cursor-running"
u_test_running com.cursor.Cursor 111 ''
set -e U_FALLBACK_OPEN_ATTEMPTED
u_cleanup
assert_equal '' "$(u_test_state reopen-fallback.tsv)" \
    'cleanup waits to consume fallback until every original PID is gone'; or set test_status 1
u_cleanup
assert_equal 2 (u_test_calls 'open /Applications/Cursor.app$') \
    'cleanup relaunches once after positive original-PID closure reconciliation'; or set test_status 1

# If exact-PID reconciliation itself errors after the helper may have closed the
# app, the blocked attempt must restore or durably track the app before signals run.
u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0'
u_test_post_operation com.cursor.Cursor terminate ''
printf '70\n' >"$U_MOCK_DIR/exit-com.cursor.Cursor-running"
touch "$U_MOCK_DIR/signal-running-error-SIGINT"
fish -c 'set -gx U_TEST_FISH_PID $fish_pid; source "$argv[1]"; u_stop_cask_apps cursor; /bin/sleep 0.1' "$repo_root/bin/u"
assert_equal 1 (u_test_calls 'open /Applications/Cursor.app$') \
    'SIGINT after graceful reconciliation error cannot leave the app closed'; or set test_status 1

u_test_reset
u_test_write_apps 'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0'
u_test_running com.cursor.Cursor 111
u_test_post_operation com.cursor.Cursor force-terminate ''
printf '70\n' >"$U_MOCK_DIR/exit-com.cursor.Cursor-running"
touch "$U_MOCK_DIR/defer-running-error-until-force" "$U_MOCK_DIR/signal-running-error-SIGTERM"
fish -c 'function gum; return 0; end; set -gx U_TEST_FISH_PID $fish_pid; source "$argv[1]"; u_stop_cask_apps cursor; /bin/sleep 0.1' "$repo_root/bin/u"
assert_equal 1 (u_test_calls 'open /Applications/Cursor.app$') \
    'SIGTERM after force reconciliation error cannot leave the app closed'; or set test_status 1

# Fallback replacement must publish atomically. If writing the replacement row
# fails, the old durable record must remain byte-for-byte available to cleanup.
u_test_reset
printf 'calm\t/Applications/Calm.app\ncursor\t/Applications/Cursor.app\n' >"$U_STATE_DIR/reopen-fallback.tsv"
set -l prior_fallback (u_test_state reopen-fallback.tsv | string collect)
set -g u_test_fallback_writes 0
function printf
    set -g u_test_fallback_writes (math $u_test_fallback_writes + 1)
    if test $u_test_fallback_writes -eq 2
        return 1
    end
    builtin printf $argv
end
u_queue_reopen_fallback cursor /Applications/Cursor.app com.cursor.Cursor 111
set -l fallback_write_status $status
functions -e printf
assert_equal 1 $fallback_write_status 'fallback replacement reports a row-write failure'; or set test_status 1
assert_equal "$prior_fallback" "$(u_test_state reopen-fallback.tsv)" \
    'fallback replacement failure preserves the prior durable row'; or set test_status 1

# In the uncertain asynchronous path, open=0 is not proof of relaunch. A failed
# metadata publication must return nonzero and retain the prior recovery row.
u_test_reset
printf 'cursor\t/Applications/Cursor.app\n' >"$U_STATE_DIR/reopen-fallback.tsv"
set -l prior_fallback (u_test_state reopen-fallback.tsv | string collect)
function printf
    return 1
end
u_restore_or_queue_app cursor /Applications/Cursor.app 'test fallback failure' 1 com.cursor.Cursor 111
set -l restore_without_fallback_status $status
functions -e printf
assert_equal 1 $restore_without_fallback_status \
    'open success cannot mask uncertain fallback publication failure'; or set test_status 1
assert_equal 1 (u_test_calls 'open /Applications/Cursor.app$') \
    'uncertain fallback publication failure still attempts immediate reopen'; or set test_status 1
assert_equal "$prior_fallback" "$(u_test_state reopen-fallback.tsv)" \
    'open success plus fallback failure retains the prior recovery row'; or set test_status 1

# A failed row write must abort the atomic rewrite before mv publishes a partial
# file. The temporary function shadows only the state writer's printf call.
u_test_reset
u_test_write_apps \
    'cursor\t/Applications/Cursor.app\tcom.cursor.Cursor\t111\t1\t0\t0' \
    'calm\t/Applications/Calm.app\tcom.calm.Calm\t\t0\t0\t0'
set -l prior_apps (u_test_state apps.tsv | string collect)
function printf
    return 1
end
function mv
    set -ga u_test_mock_calls mv
    return 0
end
u_set_app_flags cursor /Applications/Cursor.app 1 0
set -l row_write_status $status
functions -e printf mv
assert_equal 1 $row_write_status 'state rewrite reports a row-write failure'; or set test_status 1
assert_equal 0 (u_test_matches mv $u_test_mock_calls) \
    'state rewrite never publishes after a row-write failure'; or set test_status 1
assert_equal "$prior_apps" "$(u_test_state apps.tsv)" \
    'state rewrite preserves the prior TSV after a row-write failure'; or set test_status 1

# ---------------------------------------------------------------------------
# u_main end-to-end phased upgrades
#
# Every executable that can update Homebrew or affect an application resolves to
# the temporary PATH mocks above. These cases never run a real upgrade or app.
# ---------------------------------------------------------------------------

u_test_reset
set -g U_STATE_DIR "$u_mock_root/state-preexisting-fallback"
rm -rf "$U_STATE_DIR"
mkdir -p "$U_STATE_DIR"
printf 'cursor\t/Applications/Cursor.app\n' >"$U_STATE_DIR/reopen-fallback.tsv"
printf '%s\n' '{"formulae":[],"casks":[]}' >"$U_MOCK_DIR/outdated.json"
touch "$U_MOCK_DIR/open-always-fail"
u_test_run_main preexisting-fallback 1
assert_equal 1 $u_test_main_status 'main fails before maintenance when preserved recovery remains unresolved'; or set test_status 1
assert_equal 1 (test -s "$U_STATE_DIR/reopen-fallback.tsv"; and echo 1; or echo 0) \
    'main never truncates an unresolved pre-existing fallback'; or set test_status 1
assert_equal 0 (u_test_calls '^nvim ') \
    'main resolves preserved lifecycle state before other maintenance'; or set test_status 1
assert_equal 1 (u_test_output_contains 'unresolved lifecycle state preserved') \
    'main identifies the preserved recovery directory'; or set test_status 1

u_test_reset
set -g U_STATE_DIR "$u_mock_root/state-recovered-fallback"
rm -rf "$U_STATE_DIR"
mkdir -p "$U_STATE_DIR"
printf 'cursor\t/Applications/Cursor.app\n' >"$U_STATE_DIR/reopen-fallback.tsv"
printf '%s\n' '{"formulae":[],"casks":[]}' >"$U_MOCK_DIR/outdated.json"
u_test_run_main recovered-fallback 1
assert_equal 0 $u_test_main_status 'main continues after restoring preserved lifecycle state'; or set test_status 1
assert_equal 1 (u_test_calls '^open /Applications/Cursor.app$') \
    'main restores a preserved app before maintenance'; or set test_status 1
assert_equal 0 (test -s "$U_STATE_DIR/reopen-fallback.tsv"; and echo 1; or echo 0) \
    'main consumes a successfully restored pre-existing fallback'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[]}' >"$U_MOCK_DIR/outdated.json"
u_test_run_main no-outdated
assert_equal 0 $u_test_main_status 'main succeeds when no packages are outdated'; or set test_status 1
assert_equal 3 (u_test_calls '^nvim ') \
    'main end-to-end cases use the three Neovim mocks'; or set test_status 1
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
printf '6\n' >"$U_MOCK_DIR/exit-brew-outdated"
u_test_run_main outdated-failure
assert_equal 6 $u_test_main_status 'outdated discovery preserves the Homebrew failure status'; or set test_status 1
assert_equal 1 (u_test_calls '^brew outdated --json=v2$') \
    'failed outdated discovery still runs exactly once'; or set test_status 1
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
printf '7\n' >"$U_MOCK_DIR/exit-brew-upgrade-formula-jq"
u_test_run_main formula-failure
assert_equal 7 $u_test_main_status 'formula upgrade failure is fail-fast'; or set test_status 1
assert_equal 0 (u_test_calls '^brew info --cask ') \
    'formula failure stops before cask preparation'; or set test_status 1
assert_equal 0 (u_test_calls '^brew cleanup ') \
    'formula failure stops before Homebrew cleanup'; or set test_status 1
assert_equal 0 (u_test_calls '^brew doctor$') \
    'formula failure stops before Homebrew doctor'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"font-hack"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_run_main non-app-cask
assert_equal 0 $u_test_main_status 'main upgrades a non-app cask'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask font-hack$') \
    'a non-app cask upgrades in its own cask-only command'; or set test_status 1
assert_equal 0 (u_test_calls '^osascript ') \
    'a non-app cask uses no application lifecycle operations'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"font-hack"}]}' >"$U_MOCK_DIR/outdated.json"
printf '8\n' >"$U_MOCK_DIR/exit-brew-cleanup"
u_test_run_main cleanup-failure
assert_equal 1 $u_test_main_status 'Homebrew cleanup failure produces an aggregate failure'; or set test_status 1
assert_equal 1 (u_test_calls '^brew doctor$') \
    'main still doctors Homebrew after cleanup fails'; or set test_status 1
assert_equal 1 (u_test_output_contains 'all [brew-cleanup]: brew cleanup --prune=all failed') \
    'main surfaces a Homebrew cleanup failure in final details'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"bad-target"},{"name":"calm"}]}' >"$U_MOCK_DIR/outdated.json"
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
u_test_run_main eligible-casks
assert_equal 0 $u_test_main_status 'main upgrades eligible casks independently'; or set test_status 1
assert_call_before '^brew upgrade --formula jq$' '^brew info --cask --json=v2 cursor$' \
    'main completes the formula phase before preparing casks'; or set test_status 1
assert_call_before '^brew info --cask --json=v2 calm$' '^gum confirm Close these applications' \
    'main prepares every cask before consolidated approval'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask cursor$') \
    'main upgrades the first eligible cask individually'; or set test_status 1
assert_equal 1 (u_test_calls '^brew upgrade --cask calm$') \
    'main upgrades the later eligible cask individually'; or set test_status 1
assert_equal 1 (u_test_calls '^gum confirm Close these applications') \
    'main obtains one consolidated lifecycle approval'; or set test_status 1
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
printf '9\n' >"$U_MOCK_DIR/exit-brew-upgrade-cask-cursor"
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
u_test_running com.todesktop.230313mzl4w4u92 111
touch "$U_MOCK_DIR/gum-force-decline"
u_test_run_main force-decline
assert_equal 0 $u_test_main_status 'declining force termination remains a deliberate skip'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade --cask cursor$') \
    'main never upgrades a cask whose force termination was declined'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Skipped casks (1): cursor') \
    'main classifies a declined force termination as skipped'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Failed casks (0): none') \
    'main does not misclassify a declined force termination as failed'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"cursor"}]}' >"$U_MOCK_DIR/outdated.json"
u_test_running com.todesktop.230313mzl4w4u92 111
u_test_run_main force-failure
assert_equal 1 $u_test_main_status 'an unsuccessful approved force termination fails the run'; or set test_status 1
assert_equal 0 (u_test_calls '^brew upgrade --cask cursor$') \
    'main never upgrades a cask whose application could not be stopped'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Failed casks (1): cursor') \
    'main classifies an unsuccessful force termination as failed'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"calm"}]}' >"$U_MOCK_DIR/outdated.json"
printf '1\n' >"$U_MOCK_DIR/exit-tee"
u_test_run_main tee-failure
assert_equal 0 $u_test_main_status 'a tee failure does not replace successful brew pipeline status'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Cask summary: 1 upgraded, 0 skipped, 0 failed') \
    'main counts the cask upgrade from brew status rather than tee status'; or set test_status 1

u_test_reset
printf '%s\n' '{"formulae":[],"casks":[{"name":"cursor"}]}' >"$U_MOCK_DIR/outdated.json"
touch "$U_MOCK_DIR/open-always-fail" "$U_MOCK_DIR/fail-app-state-rollback"
u_test_run_main unresolved-fallback
assert_equal 1 $u_test_main_status 'unresolved durable reopen fallback produces final failure'; or set test_status 1
assert_equal 1 (test -s "$U_STATE_DIR/reopen-fallback.tsv"; and echo 1; or echo 0) \
    'main preserves unresolved durable reopen fallback state'; or set test_status 1
assert_equal 1 (u_test_output_contains 'Unresolved reopen fallback') \
    'main surfaces unresolved durable reopen fallback in final output'; or set test_status 1

rm -rf "$U_STATE_DIR" "$u_mock_root"
exit $test_status
