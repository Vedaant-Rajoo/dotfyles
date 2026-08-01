#!/usr/bin/env fish

set -l repo_root (path resolve (dirname (status filename))/../..)
set -l helper "$repo_root/bin/u-cask-lifecycle.js"
set -l test_status 0
set -l temp_dir (mktemp -d)

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

function assert_json
    set -l json $argv[1]
    set -l filter $argv[2]
    set -l description $argv[3]

    if printf '%s\n' "$json" | jq -e "$filter" >/dev/null 2>&1
        printf 'ok - %s\n' $description
        return 0
    end

    printf 'not ok - %s\n' $description
    printf '  output: %s\n' (string escape -- "$json")
    return 1
end

osascript -l JavaScript "$helper" >"$temp_dir/missing.out" 2>"$temp_dir/missing.err"
assert_equal 64 $status 'missing command exits 64'; or set test_status 1

osascript -l JavaScript "$helper" unknown >"$temp_dir/unknown.out" 2>"$temp_dir/unknown.err"
assert_equal 64 $status 'unknown command exits 64'; or set test_status 1

osascript -l JavaScript "$helper" inspect "$temp_dir/NotAnApplication.app" >"$temp_dir/nonexistent.out" 2>"$temp_dir/nonexistent.err"
assert_equal 66 $status 'nonexistent bundle exits 66'; or set test_status 1

set -l inspect_json (osascript -l JavaScript "$helper" inspect /System/Applications/Calculator.app 2>"$temp_dir/inspect.err")
assert_equal 0 $status 'inspect accepts the Calculator bundle'; or set test_status 1
assert_json "$inspect_json" \
    '(.path | type == "string" and length > 0) and (.bundleId | type == "string" and length > 0) and (.pids | type == "array" and all(.[]; type == "number"))' \
    'inspect emits a bundle identifier and numeric PID array'; or set test_status 1

set -l running_json (osascript -l JavaScript "$helper" running com.example.missing 2147483647 2>"$temp_dir/running.err")
assert_equal 0 $status 'running accepts a nonexistent exact PID'; or set test_status 1
assert_json "$running_json" \
    '.bundleId == "com.example.missing" and .pids == []' \
    'running emits an empty array for a nonexistent exact PID'; or set test_status 1

osacompile -l JavaScript -o "$temp_dir/u-cask-lifecycle.scpt" "$helper" >"$temp_dir/compile.out" 2>"$temp_dir/compile.err"
assert_equal 0 $status 'helper compiles as JavaScript for Automation'; or set test_status 1

rm -rf "$temp_dir"
exit $test_status
