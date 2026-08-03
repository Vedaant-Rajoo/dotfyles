#!/usr/bin/env fish

set -g repo_root (path resolve (dirname (status filename))/../..)
source $repo_root/tests/lib/harness.fish

set -l helper "$repo_root/bin/u-cask-lifecycle.js"
set -l temp_dir (harness_tmpdir)

function assert_json --argument-names json filter description
    if printf '%s\n' "$json" | jq -e "$filter" >/dev/null 2>&1
        harness_pass $description
    else
        harness_fail $description 'output: '(string escape -- "$json")
    end
end

osascript -l JavaScript "$helper" >"$temp_dir/missing.out" 2>"$temp_dir/missing.err"
assert_equal 64 $status 'missing command exits 64'

osascript -l JavaScript "$helper" unknown >"$temp_dir/unknown.out" 2>"$temp_dir/unknown.err"
assert_equal 64 $status 'unknown command exits 64'

osascript -l JavaScript "$helper" inspect "$temp_dir/NotAnApplication.app" >"$temp_dir/nonexistent.out" 2>"$temp_dir/nonexistent.err"
assert_equal 66 $status 'nonexistent bundle exits 66'

set -l inspect_json (osascript -l JavaScript "$helper" inspect /System/Applications/Calculator.app 2>"$temp_dir/inspect.err")
assert_equal 0 $status 'inspect accepts the Calculator bundle'
assert_json "$inspect_json" \
    '(.path == "/System/Applications/Calculator.app") and (.bundleId | type == "string" and length > 0) and (.pids | type == "array" and all(.[]; type == "number"))' \
    'inspect emits the exact bundle path, an identifier, and numeric PIDs'

set -l running_json (osascript -l JavaScript "$helper" running com.example.missing 2147483647 2>"$temp_dir/running.err")
assert_equal 0 $status 'running accepts a nonexistent exact PID'
assert_json "$running_json" \
    '.bundleId == "com.example.missing" and .pids == []' \
    'running emits an empty array for a nonexistent exact PID'

osacompile -l JavaScript -o "$temp_dir/u-cask-lifecycle.scpt" "$helper" >"$temp_dir/compile.out" 2>"$temp_dir/compile.err"
assert_equal 0 $status 'helper compiles as JavaScript for Automation'

harness_exit
