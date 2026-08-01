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

rm -rf "$U_STATE_DIR"
exit $test_status
