#!/usr/bin/env fish

set -g repo_root (path resolve (dirname (status filename))/../..)
source $repo_root/tests/lib/harness.fish

set -g root (harness_tmpdir)
set -gx HOME $root/home
set -gx XDG_STATE_HOME $root/state
set -gx MOCK_LOG $root/calls.log
set -gx MOCK_DIR $root/fixtures
mkdir -p $HOME $MOCK_DIR $root/bin

# npx and gh are replaced by executables first in PATH; gh serves one tree
# fixture per repository and fails for any repository without one.
printf '#!/bin/sh\necho "npx $*" >>"$MOCK_LOG"\n' >$root/bin/npx
printf '#!/bin/sh\necho "gh $*" >>"$MOCK_LOG"\nf="$MOCK_DIR/tree-$(echo "$2" | cut -d/ -f2-3 | tr / _).json"\ntest -e "$f" || exit 1\ncat "$f"\n' >$root/bin/gh
chmod +x $root/bin/npx $root/bin/gh
set -gx PATH $root/bin $PATH

set -g AGENT_SKILLS_TEST_MODE 1
source $repo_root/bin/agent-skills
set -g agent_skills_lock $root/skill-lock.json

function write_lock
    printf '%s\n' '{"version":3,"skills":{
        "tdd":{"source":"acme/skills","sourceType":"github","sourceUrl":"https://github.com/acme/skills.git","skillPath":"skills/tdd/SKILL.md","skillFolderHash":"t1"},
        "grill":{"source":"acme/skills","sourceType":"github","sourceUrl":"https://github.com/acme/skills.git","skillPath":"skills/grill/SKILL.md","skillFolderHash":"g1"},
        "solo":{"source":"bob/solo","sourceType":"github","sourceUrl":"https://github.com/bob/solo.git","skillPath":"SKILL.md","skillFolderHash":"root1"},
        "local":{"source":"https://example.com/x.git","sourceType":"git","sourceUrl":"https://example.com/x.git","skillPath":"SKILL.md"}
    }}' >$agent_skills_lock
end

function add_skill --argument-names name
    mkdir -p $HOME/.agents/skills/$name
    for file in SKILL.md $argv[2..-1]
        touch $HOME/.agents/skills/$name/$file
    end
end

function calls --argument-names pattern
    grep -c -e $pattern $MOCK_LOG
end

write_lock

# link: both lock paths lead to the tracked lock; a real file is kept aside.

mkdir -p $HOME/.agents
echo untracked >$HOME/.agents/.skill-lock.json
agent_skills_link_lock 2>/dev/null
assert_equal 0 $status 'link succeeds'
assert_equal $agent_skills_lock (readlink $HOME/.agents/.skill-lock.json) 'the home lock links to the tracked lock'
assert_equal $agent_skills_lock (readlink $XDG_STATE_HOME/skills/.skill-lock.json) 'the XDG lock links to the tracked lock'
assert_equal untracked (cat $HOME/.agents/.skill-lock.json.*.bak) 'an untracked lock is moved aside, not deleted'
agent_skills_link_lock
assert_equal 1 (count $HOME/.agents/.skill-lock.json.*.bak) 'a correct link is left alone'

# Antigravity: every top-level file is linked; stale links and their emptied
# directories go, while real files stay.

add_skill tdd DEEPENING.md
mkdir -p $HOME/.gemini/config/skills/gone $HOME/.gemini/config/skills/tdd $HOME/.gemini/config/skills/mine
ln -s $root/missing $HOME/.gemini/config/skills/gone/SKILL.md
ln -s $root/missing $HOME/.gemini/config/skills/tdd/OLD.md
touch $HOME/.gemini/config/skills/mine/SKILL.md
agent_skills_link_antigravity
assert_equal $HOME/.agents/skills/tdd/SKILL.md (readlink $HOME/.gemini/config/skills/tdd/SKILL.md) 'SKILL.md is linked for Antigravity'
assert_equal $HOME/.agents/skills/tdd/DEEPENING.md (readlink $HOME/.gemini/config/skills/tdd/DEEPENING.md) 'sibling files are linked for Antigravity'
test -L $HOME/.gemini/config/skills/tdd/OLD.md
assert_equal 1 $status 'a dangling file link is removed'
test -d $HOME/.gemini/config/skills/gone
assert_equal 1 $status 'a removed skill leaves no Antigravity directory'
test -f $HOME/.gemini/config/skills/mine/SKILL.md
assert_equal 0 $status 'real files in the Antigravity folder are kept'

# restore: only missing skills are installed, one CLI call per source.

printf '' >$MOCK_LOG
agent_skills_restore
assert_equal 0 $status 'restore succeeds'
assert_equal 1 (calls '^npx -y skills@1.7.4 add https://github.com/acme/skills.git -g -a claude-code codex -s grill -y$') \
    'restore installs only the missing skill of a partly installed source'
assert_equal 1 (calls '^npx -y skills@1.7.4 add https://github.com/bob/solo.git -g -a claude-code codex -s solo -y$') \
    'restore installs a missing single-skill source'
assert_equal 3 (calls '^npx ') 'restore makes one install call per source with missing skills'

# update: only skills whose folder hash moved are re-installed.

printf '%s\n' '{"sha":"rootX","tree":[{"path":"skills/tdd","type":"tree","sha":"t2"},{"path":"skills/grill","type":"tree","sha":"g1"}]}' >$MOCK_DIR/tree-acme_skills.json
printf '%s\n' '{"sha":"root1","tree":[]}' >$MOCK_DIR/tree-bob_solo.json
printf '' >$MOCK_LOG
agent_skills_update 2>$root/update.err
assert_equal 0 $status 'update succeeds'
assert_equal 1 (calls '^gh api repos/acme/skills/git/trees/HEAD?recursive=1$') 'update reads each GitHub tree once'
assert_equal 1 (calls '^npx -y skills@1.7.4 add https://github.com/acme/skills.git -g -a claude-code codex -s tdd -y$') \
    'update re-installs only the skill whose folder changed'
assert_equal 0 (calls '^npx .*bob/solo') 'a root SKILL.md compares against the whole tree'
assert_equal 1 (grep -c 'local is not a default-branch GitHub source' $root/update.err) \
    'update names skills it cannot check'

rm $MOCK_DIR/tree-bob_solo.json
printf '%s\n' '{"sha":"rootX","tree":[]}' >$MOCK_DIR/tree-acme_skills.json
printf '' >$MOCK_LOG
agent_skills_update 2>/dev/null
assert_equal 1 $status 'an unreadable tree fails the update'
assert_equal 1 (calls '^npx -y skills@1.7.4 add https://github.com/acme/skills.git -g -a claude-code codex -s tdd grill -y$') \
    'a skill folder missing upstream is handed to the CLI'

harness_exit
