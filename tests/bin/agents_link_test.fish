#!/usr/bin/env fish
# Tests for bin/agents_link Cursor hook ownership handling.
# Run: fish tests/bin/agents_link_test.fish

set -g repo (path resolve (status dirname)/../..)
set -g bin $repo/bin/agents_link
set -g failures 0
set -g checks 0
set -g workdir (mktemp -d /tmp/agents-link-test.XXXXXX)

function teardown --on-event fish_exit
    test -n "$workdir"; and rm -rf $workdir
end

function check --argument-names label expected actual
    set -g checks (math $checks + 1)
    if test "$expected" = "$actual"
        printf 'ok   %s\n' $label
    else
        set -g failures (math $failures + 1)
        printf 'FAIL %s\n       expected: %s\n       actual:   %s\n' $label $expected $actual
    end
end

# Each case gets a fresh fake home with an installed-Cursor marker so
# link_cursor runs rather than skipping. Everything agents_link writes lands
# under this home; the repository is only read.
function fresh_home
    set -l home $workdir/home-(random)
    mkdir -p $home/.cursor
    echo $home
end

function run_link --argument-names home
    env HOME=$home $bin cursor >/dev/null 2>&1
    echo $status
end

set -g hooks_rel .cursor/hooks.json
set -g backup_rel .cursor/hooks.json.pre-agents-link-backup

# --- generated file lifecycle ------------------------------------------

set h1 (fresh_home)
check "a fresh run succeeds" 0 (run_link $h1)
check "a fresh run writes the cursor hooks" 0 (test -f $h1/$hooks_rel; echo $status)
check "the generated hooks point into agents/hooks" 0 (grep -q $repo/agents/hooks/ $h1/$hooks_rel; echo $status)

check "a rerun over our own file succeeds" 0 (run_link $h1)
check "a rerun over our own file takes no backup" 1 (test -e $h1/$backup_rel; echo $status)

# A stale previous generation — still wholly ours — is replaced outright, so
# format changes can never wedge on an accumulated backup.
jq '.version = 0' $h1/$hooks_rel >$h1/stale.json
mv $h1/stale.json $h1/$hooks_rel
check "a stale generation is replaced" 0 (run_link $h1)
check "a stale generation is replaced without a backup" 1 (test -e $h1/$backup_rel; echo $status)
check "the replaced file is current again" 1 (jq -r .version $h1/$hooks_rel)

# --- user-extended file -------------------------------------------------
#
# A generated file the user added a custom hook to contains our marker but is
# not wholly ours. Overwriting it silently destroys configuration this repo
# never owned.

set h2 (fresh_home)
run_link $h2 >/dev/null
jq '.hooks["x-custom"] = [{"command":"/usr/local/bin/custom-hook"}]' $h2/$hooks_rel >$h2/mixed.json
mv $h2/mixed.json $h2/$hooks_rel
check "a user-extended file still regenerates" 0 (run_link $h2)
check "a user-extended file is backed up first" 0 (test -f $h2/$backup_rel; echo $status)
check "the backup preserves the custom hook" 0 (grep -q /usr/local/bin/custom-hook $h2/$backup_rel 2>/dev/null; echo $status)
check "the regenerated file is wholly ours again" 1 (grep -q /usr/local/bin/custom-hook $h2/$hooks_rel; echo $status)

# A second extension while its backup still stands must refuse, not overwrite
# either copy.
jq '.hooks["x-custom"] = [{"command":"/usr/local/bin/second-hook"}]' $h2/$hooks_rel >$h2/mixed2.json
mv $h2/mixed2.json $h2/$hooks_rel
check "a second extension with a standing backup fails" 1 (run_link $h2)
check "the standing-backup refusal leaves the file alone" 0 (grep -q /usr/local/bin/second-hook $h2/$hooks_rel; echo $status)

# --- foreign file -------------------------------------------------------

set h3 (fresh_home)
printf '{"version":1,"hooks":{"custom":[{"command":"/opt/foreign-hook"}]}}\n' >$h3/$hooks_rel
check "a foreign file is backed up" 0 (run_link $h3)
check "the foreign backup preserves its content" 0 (grep -q /opt/foreign-hook $h3/$backup_rel 2>/dev/null; echo $status)
check "the foreign file is replaced with ours" 0 (grep -q $repo/agents/hooks/ $h3/$hooks_rel; echo $status)

# --- summary ------------------------------------------------------------

printf '\n%d checks, %d failures\n' $checks $failures
test $failures -eq 0
