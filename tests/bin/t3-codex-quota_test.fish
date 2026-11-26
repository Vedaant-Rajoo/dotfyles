#!/usr/bin/env fish
set -g repo_root (path resolve (dirname (status filename))/../..)
source $repo_root/tests/lib/harness.fish

python3 $repo_root/tests/bin/t3-codex-quota_test.py </dev/null
assert_equal 0 $status 'native Codex quota feed handles limits, authorization, failure, and cleanup'
harness_exit
