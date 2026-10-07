#!/usr/bin/env fish
# Tests for git/hooks/commit-msg and the rule text it prints, git/commit-style.md.
# Run: fish tests/git/hooks/commit-msg_test.fish

set -g repo_root (path resolve (dirname (status filename))/../../..)
source $repo_root/tests/lib/harness.fish

set -g hook $repo_root/git/hooks/commit-msg
set -g rules $repo_root/git/commit-style.md
set -g msgfile (harness_tmpdir)/msg
# Hooks run inside git; a caller's git environment must not leak into fixtures.
set -e GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

function fixture_git --argument-names dir
    git -C $dir -c user.name=test -c user.email=test@example.com $argv[2..-1]
end

# The hook reads its scope vocabulary from the index of the repository it runs
# in, so unit checks run inside a fixture repository with known paths.
set -g fixture (harness_tmpdir)
mkdir -p $fixture/fish/conf.d $fixture/nvim $fixture/bin $fixture/docs $fixture/zed
touch $fixture/fish/conf.d/x.fish $fixture/nvim/init.lua $fixture/bin/bootstrap \
    $fixture/Brewfile $fixture/.gitignore $fixture/README.md $fixture/docs/setup.md \
    $fixture/zed/settings.json
git -C $fixture init -q
fixture_git $fixture add -A
fixture_git $fixture commit -q --no-verify -m init

# The hook allows by exiting 0 and denies by exiting 1 with the reason on
# stderr. Any other exit code is surfaced verbatim so a crash fails the
# comparison loudly instead of counting as either verdict. Each message
# argument becomes one line of the message file; the hook runs in $PWD.
function check --argument-names expected description
    printf '%s\n' $argv[3..-1] >$msgfile
    $hook $msgfile 2>/dev/null
    set -l code $status
    set -l actual unexpected:$code
    test $code -eq 0; and set actual allow
    test $code -eq 1; and set actual deny
    assert_equal $expected $actual $description
end

cd $fixture

# --- scopes -------------------------------------------------------------

check allow "a directory scope is allowed" 'fish: add tmux sessionizer keybind'
check allow "a nested scope is allowed" 'fish/conf.d: cache zoxide init output'
check allow "two scopes are allowed" 'fish, nvim: switch both to gruvbox'
check allow "treewide is allowed" 'treewide: drop zig tooling'
check allow "a nested file is a scope" 'bootstrap: install rustup'
check allow "a file scope drops its case and extension" 'brewfile: add the zed cask'
check allow "a dotfile scope drops its dot" 'gitignore: ignore zed prompts'
check allow "a directory named like a type is a scope" 'docs: fix setup typos'
check deny "a conventional type and scope are denied" 'feat(fish): add tmux sessionizer keybind'
printf '%s\n' 'feat(fish): Added keybind' >$msgfile
string match -q '*not imperative*' -- ($hook $msgfile 2>&1)
and harness_pass "a conventional subject also reports its description problems"
or harness_fail "a conventional subject also reports its description problems"
check deny "a bare conventional type is denied" 'chore: prune gitignore entries'
check deny "a breaking-change marker is denied" 'fish!: drop the legacy linker'
check deny "an unknown scope is denied" 'config: tweak settings'
check deny "an unknown nested segment is denied" 'fish/nope: add a thing'
check deny "an uppercase scope is denied" 'Fish: add keybind'
check deny "scopes need a space after the comma" 'fish,nvim: switch both to gruvbox'
check deny "a subject without a scope is denied" 'add tmux sessionizer keybind'

# --- description --------------------------------------------------------

check deny "a capitalized description is denied" 'fish: Add keybind'
check allow "later words keep their case" 'brewfile: add zed and sort Brewfile'
check allow "quotes inside the subject stay allowed" 'fish: add "quoted" flag'
check deny "a trailing period is denied" 'fish: add keybind.'
check deny "past tense is denied" 'fish: added keybind'
check deny "a gerund is denied" 'fish: adding keybind'
check deny "third person is denied" 'fish: adds keybind'
check allow "an -eed verb is imperative" 'nvim: speed up startup'
check allow "an -ss verb is imperative" 'fish: bypass the greeting'
check allow "an imperative lookalike passes" 'nvim: embed the lsp status'

# --- length limit -------------------------------------------------------

check allow "a subject at the 72-char limit is allowed" "fish: "(string repeat -n 66 a)
check deny "a subject over the 72-char limit is denied" "fish: "(string repeat -n 67 a)

# --- bodies and trailers ------------------------------------------------

check allow "a why body is allowed" 'fish: add keybind' '' 'Sessions were three keystrokes away.'
check allow "a bulleted body is allowed" 'fish: add keybind' '' '- bind ctrl-f' '- document it'
check allow "a trailer is allowed" 'fish: add keybind' '' 'Co-Authored-By: Claude <noreply@anthropic.com>'
check allow "a body then trailers are allowed" 'fish: add keybind' '' 'Why.' '' \
    'Co-Authored-By: Claude <noreply@anthropic.com>' 'Signed-off-by: V <v@example.com>'
check deny "an unknown trailer is denied" 'fish: add keybind' '' 'Note: see the readme'
check allow "a url line is prose, not a trailer" 'fish: add keybind' '' 'https://example.com/x'
check deny "a body without a blank line is denied" 'fish: add keybind' 'second line'

# --- git syntax stripping -----------------------------------------------

check allow "comment lines are ignored" 'fish: add keybind' '# Please enter the commit message' '# On branch main'
check allow "a commented-out trailer is ignored" 'fish: add keybind' '' '# Note: a comment, not a trailer'
check allow "diff below a scissors line is ignored" 'fish: add keybind' \
    '# ------------------------ >8 ------------------------' 'diff --git a/x b/x' '+Note: not a trailer'
check deny "a bad subject above the scissors line is still denied" 'feat: x' \
    '# ------------------------ >8 ------------------------' 'diff --git a/x b/x'
check allow "an empty message is left for git to reject" ''
check allow "an all-comments message is left for git to reject" '# nothing here' '# at all'

# --- git-generated subjects ---------------------------------------------

check allow "a merge commit subject passes through" "Merge branch 'topic'"
check allow "an autosquash fixup subject passes through" 'fixup! Whatever Case The Original Had'
check allow "an autosquash squash subject passes through" 'squash! feat: x'
check allow "a git revert subject with its body passes through" 'Revert "feat(x): y"' '' 'This reverts commit 1234567890abcdef.'

# --- index edge cases ---------------------------------------------------

fixture_git $fixture rm -rq zed
check allow "a directory this commit deletes is still a scope" 'zed: remove settings'

set -g unborn (harness_tmpdir)
mkdir $unborn/src
touch $unborn/src/main.c
git -C $unborn init -q
git -C $unborn add -A
cd $unborn
check allow "a repository without commits uses its index" 'src: add main'

# --- rule text ----------------------------------------------------------
# Every example in commit-style.md must get the verdict it claims, judged
# against this repository's own paths.

cd $repo_root
set -l good (string match -rg '^- good: `([^`]+)`' <$rules)
set -l bad (string match -rg '^- bad: `([^`]+)`' <$rules)
test (count $good) -gt 0 -a (count $bad) -gt 0
and harness_pass "commit-style.md has good and bad examples"
or harness_fail "commit-style.md has good and bad examples"
for example in $good
    check allow "commit-style.md good example passes: $example" $example
end
for example in $bad
    check deny "commit-style.md bad example fails: $example" $example
end

# --- opt-in through a config hook ---------------------------------------
# The steps docs/setup.md gives for other repositories, run for real.

set -g optin (harness_tmpdir)
mkdir $optin/src
touch $optin/src/main.c
git -C $optin init -q
git -C $optin config set hook.scoped-commits.command $hook
git -C $optin config set hook.scoped-commits.event commit-msg
fixture_git $optin add -A
fixture_git $optin commit -q -m 'feat: add main' 2>/dev/null
assert_equal 1 $status "an opted-in repository blocks a conventional subject"
fixture_git $optin commit -q -m 'src: add main' 2>/dev/null
assert_equal 0 $status "an opted-in repository accepts a scoped subject"

harness_exit
