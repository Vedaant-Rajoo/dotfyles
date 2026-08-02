#!/usr/bin/env fish
# Tests for claude/hooks/commit-msg-guard.py.
# Run: fish tests/claude/hooks/commit-msg-guard_test.fish

set -g repo (path resolve (status dirname)/../../..)
set -g hook $repo/claude/hooks/commit-msg-guard.py
set -g failures 0
set -g checks 0

function check --argument-names label expected actual
    set -g checks (math $checks + 1)
    if test "$expected" = "$actual"
        printf 'ok   %s\n' $label
    else
        set -g failures (math $failures + 1)
        printf 'FAIL %s\n       expected: %s\n       actual:   %s\n' $label $expected $actual
    end
end

# The hook denies by printing a permissionDecision object and allows by
# printing nothing. Anything else is surfaced verbatim so a crash or a schema
# drift fails the comparison loudly instead of counting as either verdict.
function decision
    set -l out (jq -cn --arg command "$argv[1]" '{tool_input: {command: $command}}' | python3 $hook)
    if string match -q -- '*"permissionDecision": "deny"*' "$out"
        echo deny
        return
    end
    if test -z "$out"
        echo allow
        return
    end
    echo unexpected:$out
end

# --- pass-through -------------------------------------------------------

check "a non-commit command passes through" allow (decision 'git status')
check "a commit without an inline message passes through" allow (decision 'git commit --amend --no-edit')

# --- single-message forms ----------------------------------------------

check "a conventional subject is allowed" allow (decision 'git commit -m "feat(fish): add tmux sessionizer keybind"')
check "a combined -am flag is recognized" allow (decision 'git add -A && git commit -am "fix(nvim): restore folds"')
check "escaped quotes inside the subject stay allowed" allow (decision 'git commit -m "fix: add \"quoted\" flag"')
check "an uppercase subject is denied" deny (decision 'git commit -m "Fix: Subject"')
check "a non-conventional bare word subject is denied" deny (decision 'git commit -m subject-word')

# --- bodies through repeated -m ----------------------------------------

check "a double-quoted second -m body is denied" deny (decision 'git commit -m "fix: a" -m "prose body here"')
check "a single-quoted pair with a body is denied" deny (decision 'git commit -m \'fix: a\' -m \'prose body here\'')
check "a double-then-single mixed-quote body is denied" deny (decision 'git commit -m "fix: subject" -m \'prose body here\'')
check "a single-then-double mixed-quote body is denied" deny (decision 'git commit -m \'fix: subject\' -m "prose body here"')
check "a --message= then mixed-quote body is denied" deny (decision 'git commit --message="fix: subject" -m \'prose body here\'')

# --- trailers stay allowed ---------------------------------------------

check "a trailer after the subject is allowed" allow (decision 'git commit -m "fix: a" -m "Co-Authored-By: Claude <noreply@anthropic.com>"')
check "a mixed-quote trailer is still allowed" allow (decision 'git commit -m "fix: a" -m \'Co-Authored-By: Claude <noreply@anthropic.com>\'')

# --- heredoc form -------------------------------------------------------

set -l heredoc_body (printf 'git commit -F - <<\'EOF\'\nfix: subject\n\nprose body here\nEOF' | string collect)
check "a heredoc body is denied" deny (decision $heredoc_body)

set -l heredoc_clean (printf 'git commit -F - <<\'EOF\'\nfix: subject\nEOF' | string collect)
check "a heredoc subject alone is allowed" allow (decision $heredoc_clean)

# --- summary ------------------------------------------------------------

printf '\n%d checks, %d failures\n' $checks $failures
test $failures -eq 0
