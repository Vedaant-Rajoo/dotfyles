#!/usr/bin/env fish
# Safety contracts for bin/bootstrap: a dry run plans without mutating, opt-in
# steps stay opt-in, and a real run refuses to start where it would do harm.
# Run: fish tests/bin/bootstrap_test.fish
#
# Every command bootstrap could reach is a logging stub first on PATH, and HOME
# is an empty sandbox, so nothing here touches this machine. uname is stubbed
# too, which makes the platform under test explicit.

set -g repo_root (path resolve (dirname (status filename))/../..)
source $repo_root/tests/lib/harness.fish

set -g sandbox (harness_tmpdir)
set -g home $sandbox/home
set -g stubs $sandbox/bin
set -g calls $sandbox/calls.log
mkdir -p $home $stubs

for name in bat brew chsh curl defaults dscl fish gh git jq killall launchctl mise npm npx open osascript rustup sudo xcode-select
    printf '#!/bin/sh\necho "%s $*" >>"%s"\n' $name $calls >$stubs/$name
    chmod +x $stubs/$name
end
# Bootstrap reads its Homebrew prefix from the live brew, even in a dry run.
printf '#!/bin/sh\necho "brew $*" >>"%s"\n[ "$1" = --prefix ] && echo "%s/homebrew"\nexit 0\n' $calls $sandbox >$stubs/brew
printf '#!/bin/sh\n[ "$1" = -m ] && echo arm64 || echo "$STUB_UNAME"\n' >$stubs/uname
chmod +x $stubs/brew $stubs/uname

# Runs bootstrap with a clean environment; sets bootstrap_status, _output
# (stdout), _errors (stderr), and _calls (every stub invocation).
function run_bootstrap --argument-names platform
    printf '' >$calls
    env -i HOME=$home USER=$USER PATH=$stubs:/usr/bin:/bin STUB_UNAME=$platform \
        /bin/bash $repo_root/bin/bootstrap $argv[2..-1] >$sandbox/out 2>$sandbox/err
    set -g bootstrap_status $status
    set -g bootstrap_output (cat $sandbox/out)
    set -g bootstrap_errors (cat $sandbox/err)
    set -g bootstrap_calls (cat $calls)
end

function plans --argument-names pattern
    count (string match -r -- "^would run: $pattern" $bootstrap_output)
end

run_bootstrap Darwin --dry-run
assert_equal 0 $bootstrap_status 'a dry run succeeds on a machine with nothing installed'
assert_equal 'brew --prefix' "$bootstrap_calls" 'a dry run invokes nothing but the read-only Homebrew prefix query'
assert_equal '' "$(find $home -mindepth 1)" 'a dry run leaves the home directory untouched'
assert_equal 1 (plans 'mise install$') 'a dry run plans installing the declared runtimes'
assert_equal 0 (plans '.*macdefaults') 'macOS defaults are not planned unless requested'
assert_equal 0 (plans 'brew services start herdr') 'the Herdr service is not planned unless requested'

run_bootstrap Darwin --dry-run --with-defaults --with-herdr-service
assert_equal 1 (plans '.*bin/macdefaults') '--with-defaults plans macOS defaults'
assert_equal 1 (plans 'brew services start herdr') '--with-herdr-service plans the Herdr service'
assert_equal 'brew --prefix' "$bootstrap_calls" 'an opted-in dry run still mutates nothing'

# A real run from any clone but ~/.config, such as a worktree, would wire this
# machine to files that are not its live configuration.
run_bootstrap Darwin
assert_equal 1 $bootstrap_status 'a real run outside ~/.config fails'
assert_equal 1 (count (string match -e "$home/.config" -- $bootstrap_errors)) 'the refusal names the required location'
assert_equal '' "$bootstrap_calls" 'a refused run invokes nothing'

run_bootstrap Linux --dry-run
assert_equal 1 $bootstrap_status 'Linux is refused rather than half-configured'
assert_equal 1 (count (string match -e 'README.md#linux' -- $bootstrap_errors)) 'the Linux refusal points at the manual steps'
assert_equal '' "$bootstrap_calls" 'the Linux refusal invokes nothing'

run_bootstrap Darwin --dry-rn
assert_equal 1 $bootstrap_status 'a mistyped flag fails'
assert_equal 1 (count (string match -e 'usage:' -- $bootstrap_errors)) 'a mistyped flag prints usage'
assert_equal '' "$bootstrap_calls" 'a mistyped flag invokes nothing'

harness_exit
