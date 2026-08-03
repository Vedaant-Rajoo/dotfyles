#!/usr/bin/env fish
# Tests for bin/agents_link: Cursor hook ownership and the adopt subcommand.
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

# Unparsable JSON cannot be proven ours, so it is treated as foreign and
# preserved in the backup.
set h4 (fresh_home)
printf 'not json at all\n' >$h4/$hooks_rel
check "an unparsable file is backed up" 0 (run_link $h4)
check "the unparsable backup preserves its content" 0 (grep -q "not json at all" $h4/$backup_rel 2>/dev/null; echo $status)
check "the unparsable file is replaced with ours" 0 (grep -q $repo/agents/hooks/ $h4/$hooks_rel; echo $status)

# --- adopt subcommand ---------------------------------------------------
#
# Validation-failure cases and dry-run touch nothing, so they run against the
# real repository script with a fake home. Only the happy path mutates its
# repo, and that one runs against a disposable skeleton clone.

set h5 (fresh_home)
mkdir -p $h5/.agents/skills/zz-adopt-fixture
printf 'name: zz-adopt-fixture\ndescription: test fixture\n' >$h5/.agents/skills/zz-adopt-fixture/SKILL.md

check "adopt without a name is a usage error" 1 (env HOME=$h5 $bin adopt >/dev/null 2>&1; echo $status)
check "check before adopt is a usage error" 1 (env HOME=$h5 $bin --check adopt >/dev/null 2>&1; echo $status)
check "adopt rejects linker flags" 1 (env HOME=$h5 $bin adopt --check zz-adopt-fixture >/dev/null 2>&1; echo $status)
check "adopt rejects an uppercase name" 1 (env HOME=$h5 $bin adopt UPPER >/dev/null 2>&1; echo $status)
check "adopt rejects a missing source" 1 (env HOME=$h5 $bin adopt no-such-skill >/dev/null 2>&1; echo $status)
check "adopt dry-run succeeds" 0 (env HOME=$h5 $bin adopt --dry-run zz-adopt-fixture >/dev/null 2>&1; echo $status)
check "adopt dry-run moves nothing" 0 (test -d $h5/.agents/skills/zz-adopt-fixture; echo $status)
check "adopt dry-run creates nothing in the repo" 1 (test -e $repo/agents/skills/zz-adopt-fixture; echo $status)

mkdir -p $h5/.agents/skills/no-skill-md
check "adopt rejects a source without SKILL.md" 1 (env HOME=$h5 $bin adopt no-skill-md >/dev/null 2>&1; echo $status)

mkdir -p $h5/.agents/skills/wrong-name
printf 'name: something-else\n' >$h5/.agents/skills/wrong-name/SKILL.md
check "adopt rejects a frontmatter name mismatch" 1 (env HOME=$h5 $bin adopt wrong-name >/dev/null 2>&1; echo $status)

# A fixture named after a real repo skill hits the existing-destination refusal.
mkdir -p $h5/.agents/skills/html-planning
printf 'name: html-planning\n' >$h5/.agents/skills/html-planning/SKILL.md
check "adopt refuses an existing destination" 1 (env HOME=$h5 $bin adopt html-planning >/dev/null 2>&1; echo $status)
check "the refused source is untouched" 0 (test -d $h5/.agents/skills/html-planning; echo $status)

# Happy path: a skeleton repo with just enough of bin/ and agents/ for the
# move plus a reprojection into the same fake home.
set skel $workdir/skel
mkdir -p $skel/bin/lib $skel/agents/skills $skel/agents/subagents $skel/agents/hooks/scripts $skel/claude
cp $repo/bin/agents_link $repo/bin/agents_render $skel/bin/
cp $repo/bin/lib/ui.sh $skel/bin/lib/
printf '# rules\n' >$skel/agents/AGENTS.md
printf '{"version":1,"hooks":[]}\n' >$skel/agents/hooks/manifest.json

set h6 (fresh_home)
mkdir -p $h6/.agents/skills/adoptee
printf 'name: adoptee\ndescription: test fixture\n' >$h6/.agents/skills/adoptee/SKILL.md
check "adopt moves the skill and reprojects" 0 (env HOME=$h6 $skel/bin/agents_link adopt adoptee >/dev/null 2>&1; echo $status)
check "the adopted skill is canonical" 0 (test -f $skel/agents/skills/adoptee/SKILL.md; echo $status)
check "the shared link points back at the canonical copy" 0 (test -L $h6/.agents/skills/adoptee; echo $status)

# --- summary ------------------------------------------------------------

printf '\n%d checks, %d failures\n' $checks $failures
test $failures -eq 0
