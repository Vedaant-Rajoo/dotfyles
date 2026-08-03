#!/usr/bin/env fish
# Tests for git/hooks/commit-msg.
# Run: fish tests/git/hooks/commit-msg_test.fish
#
# The retired Claude-hook suite also asserted shell-string extraction (quoting
# styles, -m forms, heredocs); the git hook receives the final message file
# from git, so that entire class of cases no longer exists.

set -g repo (path resolve (status dirname)/../../..)
set -g hook $repo/git/hooks/commit-msg
set -g failures 0
set -g checks 0
set -g workdir (mktemp -d /tmp/commit-msg-test.XXXXXX)

function check --argument-names label expected actual
    set -g checks (math $checks + 1)
    if test "$expected" = "$actual"
        printf 'ok   %s\n' $label
    else
        set -g failures (math $failures + 1)
        printf 'FAIL %s\n       expected: %s\n       actual:   %s\n' $label $expected $actual
    end
end

# The hook allows by exiting 0 and denies by exiting 1 with the reason on
# stderr. Any other exit code is surfaced verbatim so a crash fails the
# comparison loudly instead of counting as either verdict. Each argument
# becomes one line of the message file.
function decision
    printf '%s\n' $argv >$workdir/msg
    $hook $workdir/msg 2>/dev/null
    set -l code $status
    switch $code
        case 0
            echo allow
        case 1
            echo deny
        case '*'
            echo unexpected:$code
    end
end

# --- subjects -----------------------------------------------------------

check "a conventional subject is allowed" allow (decision 'feat(fish): add tmux sessionizer keybind')
check "an uppercase subject is denied" deny (decision 'Fix: Subject')
check "a non-conventional bare word subject is denied" deny (decision 'subject-word')
check "quotes inside the subject stay allowed" allow (decision 'fix: add "quoted" flag')
check "a breaking-change marker is allowed" allow (decision 'feat!: drop the legacy linker')
check "a scoped breaking change is allowed" allow (decision 'feat(bin)!: drop the legacy linker')

# --- length limit -------------------------------------------------------

check "a subject at the 100-char limit is allowed" allow (decision "fix: "(string repeat -n 95 a))
check "a subject over the 100-char limit is denied" deny (decision "fix: "(string repeat -n 96 a))

# --- bodies and trailers ------------------------------------------------

check "a prose body is denied" deny (decision 'fix: subject' '' 'prose body here')
check "a trailer after the subject is allowed" allow (decision 'fix: a' '' 'Co-Authored-By: Claude <noreply@anthropic.com>')
check "multiple trailers are allowed" allow (decision 'fix: a' '' 'Co-Authored-By: Claude <noreply@anthropic.com>' 'Signed-off-by: V <v@example.com>')
check "a body alongside a trailer is still denied" deny (decision 'fix: a' '' 'prose body here' 'Co-Authored-By: Claude <noreply@anthropic.com>')

# --- git syntax stripping -----------------------------------------------

check "comment lines are ignored" allow (decision 'fix: subject' '# Please enter the commit message' '# On branch main')
check "a commented-out body does not count as prose" allow (decision 'fix: subject' '' '# this line is a comment, not prose')
check "diff below a scissors line is ignored" allow (decision 'fix: subject' '# ------------------------ >8 ------------------------' 'diff --git a/x b/x' '+not prose')
check "a body above the scissors line is still denied" deny (decision 'fix: subject' '' 'prose body here' '# ------------------------ >8 ------------------------' 'diff --git a/x b/x')
check "an empty message is left for git to reject" allow (decision '')
check "an all-comments message is left for git to reject" allow (decision '# nothing here' '# at all')

# --- git-generated subjects ---------------------------------------------

check "a merge commit subject passes through" allow (decision "Merge branch 'topic'")
check "an autosquash fixup subject passes through" allow (decision 'fixup! Whatever Case The Original Had')
check "an autosquash squash subject passes through" allow (decision 'squash! feat: x')
check "a git revert subject with its body passes through" allow (decision 'Revert "feat(x): y"' '' 'This reverts commit 1234567890abcdef.')

# --- summary ------------------------------------------------------------

rm -rf $workdir
printf '\n%d checks, %d failures\n' $checks $failures
test $failures -eq 0
