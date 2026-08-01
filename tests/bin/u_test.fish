#!/usr/bin/env fish

set -l repo_root (path resolve (dirname (status filename))/../..)
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
mkdir -p "$U_MOCK_DIR" "$u_mock_bin"
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
echo "brew mock: unexpected invocation: $argv" >>"$U_MOCK_LOG"
exit 64' >"$u_mock_bin/brew"

echo '#!/usr/bin/env fish
echo "osascript $argv" >>"$U_MOCK_LOG"
if test (count $argv) -eq 5; and test "$argv[1]" = -l; and test "$argv[2]" = JavaScript; and string match -q -- "*/u-cask-lifecycle.js" "$argv[3]"; and test "$argv[4]" = inspect
    set -l fixture "$U_MOCK_DIR/inspect"(string replace -a / _ -- "$argv[5]")".json"
    if test -e "$fixture"
        cat "$fixture"
        exit 0
    end
    echo "osascript mock: no fixture for $argv[5]" >>"$U_MOCK_LOG"
    exit 66
end
echo "osascript mock: unexpected invocation: $argv" >>"$U_MOCK_LOG"
exit 64' >"$u_mock_bin/osascript"

echo '#!/usr/bin/env fish
echo "gum $argv" >>"$U_MOCK_LOG"
if test "$argv[1]" = confirm; and test -e "$U_MOCK_DIR/gum-confirm-decline"
    exit 1
end
exit 0' >"$u_mock_bin/gum"

chmod +x "$u_mock_bin/brew" "$u_mock_bin/osascript" "$u_mock_bin/gum"
set -gx PATH "$u_mock_bin" $PATH

function u_test_write_cask --argument-names token json
    # Pretty-print so the parsers keep proving they read every argument line.
    printf '%s\n' $json | jq . >"$U_MOCK_DIR/cask-$token.json"
end

function u_test_write_inspect --argument-names bundle_path json
    printf '%s\n' $json | jq . >"$U_MOCK_DIR/inspect"(string replace -a / _ -- $bundle_path)".json"
end

function u_test_reset
    rm -f "$U_STATE_DIR/apps.tsv" "$U_STATE_DIR/skips.tsv" "$U_STATE_DIR/failures.tsv"
    rm -f "$U_MOCK_DIR/gum-confirm-decline"
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
assert_equal 1 $status 'confirm reports a declined consolidated prompt'; or set test_status 1
assert_equal 1 (u_test_calls '^gum confirm') \
    'a declined prompt is still asked exactly once'; or set test_status 1
assert_equal 'cursor
google-chrome' "$(cut -f1 "$U_STATE_DIR/skips.tsv" | sort)" \
    'a declined prompt skips only the running-app casks'; or set test_status 1
assert_equal '' "$(u_test_state failures.tsv)" \
    'a declined prompt records no command failure'; or set test_status 1

u_test_reset
u_prepare_cask multi
touch "$U_MOCK_DIR/gum-confirm-decline"
u_confirm_running_apps >/dev/null
assert_equal 1 $status 'confirm reports a declined prompt for a multi-app cask'; or set test_status 1
assert_equal 'multi|declined closing running applications' "$(u_test_state skips.tsv)" \
    'a declined prompt skips a multi-app cask exactly once'; or set test_status 1

rm -rf "$U_STATE_DIR" "$u_mock_root"
exit $test_status
