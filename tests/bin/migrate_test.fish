#!/usr/bin/env fish
# Contracts for bin/migrate and the migrations it ships: each runs once, in
# order; a failure stays pending and holds back later ones; a new machine is
# left untouched; an old one loses only what this configuration retired.
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

rm -rf $state
printf '%s\n' '#!/bin/sh' 'echo "brew $*" >>"'$calls'"' \
    'case "$1" in' \
    'list) [ -e "$FIXTURES/brew-list-fails" ] && exit 1; cat "$FIXTURES/brew-list" 2>/dev/null ;;' \
    'esac' 'exit 0' >$stubs/brew
# mise can run every command except those listed in the mise-lacks fixture.
printf '%s\n' '#!/bin/sh' 'echo "mise $*" >>"'$calls'"' \
    '[ "$1" = which ] && grep -qx "$2" "$FIXTURES/mise-lacks" 2>/dev/null && exit 1' 'exit 0' >$stubs/mise
printf '%s\n' '#!/bin/sh' 'echo "npm $*" >>"'$calls'"' >$stubs/npm
chmod +x $stubs/brew $stubs/mise $stubs/npm

function uninstalled
    string match -rg '^brew uninstall (.*)' <$calls | string split ' ' | sort | string join ' '
end

function npm_calls
    string match -r '^npm .*' <$calls
end

function shipped_pending
    run_migrate $repo_root/bin/migrate --pending
    count $migrate_output
end

set -g shipped (count $repo_root/migrations/*.sh)

# A new machine: none of the retired formulae are installed.
printf '%s\n' bat fish mise >$fixtures/brew-list
run_migrate $repo_root/bin/migrate
assert_equal 0 $migrate_status 'on a new machine every shipped migration succeeds'
assert_equal '' "$(uninstalled)" 'on a new machine the migrations uninstall nothing'
assert_equal '' "$(npm_calls)" 'on a new machine the migrations leave global npm packages alone'
assert_equal 0 (shipped_pending) 'on a new machine every shipped migration is recorded as done'

# An old machine whose mise cannot run Bun yet, as when `mise install` failed to
# resolve bun@latest; mise lists nothing as missing then.
rm -rf $state
printf '%s\n' bat bun fnm mise node pnpm prettier prettierd pyenv pyenv-virtualenv >$fixtures/brew-list
echo bun >$fixtures/mise-lacks
run_migrate $repo_root/bin/migrate
assert_equal 1 $migrate_status 'retiring the old managers waits until mise can run every replacement'
assert_equal '' "$(uninstalled)" 'nothing is uninstalled while a replacement is missing'
assert_equal $shipped (shipped_pending) 'the waiting migration and every later one stay pending'

# The same machine once mise has the defaults.
rm -f $fixtures/mise-lacks
mkdir -p $home/.pyenv/versions/3.14.4 $home/.config/fish/completions
touch $home/.config/fish/completions/pyenv.fish
run_migrate $repo_root/bin/migrate
assert_equal 0 $migrate_status 'an old machine finishes every shipped migration once mise is ready'
assert_equal 'bun fnm pnpm prettier prettierd pyenv pyenv-virtualenv' "$(uninstalled)" \
    'an old machine loses the retired managers and global prettier, and Homebrew decides about its Node'
test -d $home/.pyenv/versions/3.14.4
assert_equal 0 $status 'old Python installs are kept for virtualenvs that point into them'
test -e $home/.config/fish/completions/pyenv.fish
assert_equal 1 $status 'the generated pyenv completions are removed'

# Homebrew autoremoves the Node it installed for prettier, so prettier stays
# until mise can run Node, even where nothing else needs retiring.
rm -rf $state
printf '%s\n' node prettier >$fixtures/brew-list
echo node >$fixtures/mise-lacks
run_migrate $repo_root/bin/migrate
assert_equal 1 $migrate_status 'retiring prettier waits until mise can run Node'
assert_equal '' "$(uninstalled)" 'prettier is kept while mise cannot run Node'
rm -f $fixtures/mise-lacks

# bin/bootstrap stopped installing the Augment CLI.
rm -rf $state
printf '%s\n' mise >$fixtures/brew-list
mkdir -p $home/.node_modules/lib/node_modules/@augmentcode/auggie
run_migrate $repo_root/bin/migrate
assert_equal 0 $migrate_status 'a machine with the Augment CLI finishes every shipped migration'
assert_equal 'npm uninstall --global @augmentcode/auggie' "$(npm_calls)" \
    'a machine with the Augment CLI loses it, and no other global npm package'

# When Homebrew cannot report what is installed, nothing is assumed retired.
rm -rf $state
touch $fixtures/brew-list-fails
run_migrate $repo_root/bin/migrate
assert_equal 1 $migrate_status 'an unreadable Homebrew inventory fails the migration'
assert_equal $shipped (shipped_pending) 'a migration that could not read Homebrew stays pending'
rm -f $fixtures/brew-list-fails

harness_exit
