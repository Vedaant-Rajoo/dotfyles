#!/usr/bin/env fish
# Contracts for bin/migrate: each migration runs once, in order; a failure
# stays pending and holds back later ones; an empty queue succeeds.
# Run: fish tests/bin/migrate_test.fish

set -g repo_root (path resolve (dirname (status filename))/../..)
source $repo_root/tests/lib/harness.fish

set -g sandbox (harness_tmpdir)
set -g home $sandbox/home
set -g state $home/.local/state/dotfyles/migrations
set -g stubs $sandbox/bin
set -g fixtures $sandbox/fixtures
set -g calls $sandbox/calls.log
mkdir -p $home $stubs $fixtures

# Runs a migrate script with a clean environment and stub commands first on
# PATH; sets migrate_status and migrate_output.
function run_migrate --argument-names script
    printf '' >$calls
    set -g migrate_output (env -i HOME=$home PATH=$stubs:/usr/bin:/bin FIXTURES=$fixtures \
        /bin/bash $script $argv[2..-1] </dev/null 2>&1)
    set -g migrate_status $status
end

# --- the runner, against a fixture repository ---------------------------------

set -g fixture_repo $sandbox/repo
mkdir -p $fixture_repo/bin $fixture_repo/migrations
cp $repo_root/bin/migrate $fixture_repo/bin/migrate
set -g ran $sandbox/ran.log

function fixture_migration --argument-names name body
    printf 'echo "fixture %s"\n%s\n' $name $body >$fixture_repo/migrations/$name.sh
end

# Created out of order: the runner, not the filesystem, decides the order.
fixture_migration 300 "echo 300 >>$ran"
fixture_migration 100 "echo 100 >>$ran; touch ran-here"
fixture_migration 200 "echo 200 >>$ran"

run_migrate $fixture_repo/bin/migrate --pending
assert_equal 0 $migrate_status '--pending succeeds when migrations are pending'
assert_equal '100.sh 200.sh 300.sh' "$migrate_output" '--pending lists pending migrations in run order'

run_migrate $fixture_repo/bin/migrate
assert_equal 0 $migrate_status 'pending migrations run successfully'
assert_equal '100 200 300' "$(string join ' ' (cat $ran))" 'pending migrations run once each, in name order'
test -e $home/ran-here
assert_equal 0 $status 'migrations run from the home directory'

run_migrate $fixture_repo/bin/migrate
assert_equal '100 200 300' "$(string join ' ' (cat $ran))" 'a completed migration never runs again'
run_migrate $fixture_repo/bin/migrate --pending
assert_equal 1 $migrate_status '--pending fails when nothing is pending'
assert_equal '' "$migrate_output" '--pending lists nothing when nothing is pending'

# A failing command mid-migration fails it, even without an explicit exit.
fixture_migration 400 "echo 400-start >>$ran; false; echo 400-end >>$ran"
fixture_migration 500 "echo 500 >>$ran"
run_migrate $fixture_repo/bin/migrate
assert_equal 1 $migrate_status 'a failing migration fails the run'
assert_equal '100 200 300 400-start' "$(string join ' ' (cat $ran))" \
    'a failing command stops its migration, and later migrations wait'
run_migrate $fixture_repo/bin/migrate --pending
assert_equal '400.sh 500.sh' "$migrate_output" 'a failed migration and those after it stay pending'

fixture_migration 400 "echo 400-fixed >>$ran"
run_migrate $fixture_repo/bin/migrate
assert_equal '100 200 300 400-start 400-fixed 500' "$(string join ' ' (cat $ran))" \
    'once fixed, the held-back migrations run in order'

run_migrate $fixture_repo/bin/migrate --pendng
assert_equal 64 $migrate_status 'a mistyped option fails with a usage error'

# --- the shipped migrations ------------------------------------------------------

# None ship while the configuration lives on a single machine; bootstrap and
# bin/u still call the runner, so an empty queue must succeed.
rm -rf $state
run_migrate $repo_root/bin/migrate
assert_equal 0 $migrate_status 'with no migrations shipped, a run succeeds'
run_migrate $repo_root/bin/migrate --pending
assert_equal 1 $migrate_status 'with no migrations shipped, nothing is pending'

harness_exit
