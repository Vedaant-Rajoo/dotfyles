#!/usr/bin/env fish
# Tests for the q function in fish/functions/q.fish.
# Run: fish tests/fish/functions/q_test.fish
#
# Each case runs the real function in a child fish with --no-config, with
# XDG_CONFIG_HOME at the repository so $__fish_config_dir finds the tracked
# prompt file. `claude` and `codex` are stubs first on PATH that log their
# arguments, so no harness runs and no inference is spent.

set -g repo_root (path resolve (status dirname)/../../..)
source $repo_root/tests/lib/harness.fish

set -g fish_bin (status fish-path)
set -g sys (string collect <$repo_root/fish/q-prompt.md)

function fresh_sandbox
    set -l root (harness_tmpdir)
    mkdir -p $root/home $root/bin
    for tool in claude codex
        printf '%s\n' \
            '#!/bin/sh' \
            "printf '%s\n' \"\$@\" >>\"\$STUB_LOG_DIR/$tool.log\"" \
            "echo '$tool answer'" \
            'exit "${STUB_STATUS:-0}"' >$root/bin/$tool
        chmod +x $root/bin/$tool
    end
    echo $root
end

# Runs q with the given words; stdin comes from $q_stdin, closed when unset.
function q_run --argument-names root
    set -l input /dev/null
    set -q q_stdin; and set input $q_stdin
    env HOME=$root/home \
        XDG_CONFIG_HOME=$repo_root \
        PATH=$root/bin:/usr/bin:/bin \
        STUB_LOG_DIR=$root \
        STUB_STATUS=$stub_status \
        $fish_bin --no-config -c "source $repo_root/fish/functions/q.fish; q \$argv" -- $argv[2..-1] <$input >$root/stdout 2>$root/stderr
end

function last_arg --argument-names log
    test -f $log; and tail -n 1 $log
end

function logged --argument-names log
    test -f $log; and echo yes; or echo no
end

# --- claude by default ----------------------------------------------------

set s (fresh_sandbox)
q_run $s how do I list ports
assert_equal 0 $status 'q exits 0 when claude answers'
assert_equal 'how do I list ports' "$(last_arg $s/claude.log)" 'q passes the question to claude as one argument'
string match -q -- "*$sys*" "$(cat $s/claude.log)"
assert_equal 0 $status 'claude receives the prompt file as its system prompt'
assert_equal no (logged $s/codex.log) 'q without -x leaves codex alone'
assert_equal 'claude answer' "$(cat $s/stdout)" 'q prints the answer claude gives'

set s (fresh_sandbox)
set -g stub_status 1
q_run $s anything
assert_equal 1 $status 'q exits non-zero when claude fails'
set -e stub_status

# --- codex with -x --------------------------------------------------------

set s (fresh_sandbox)
q_run $s -x what does ls -la do
assert_equal 'what does ls -la do' "$(last_arg $s/codex.log)" 'q -x passes the question, dashes included, to codex'
string match -q -- "*developer_instructions=$sys*" "$(cat $s/codex.log)"
assert_equal 0 $status 'codex receives the prompt file as developer instructions'
assert_equal no (logged $s/claude.log) 'q -x leaves claude alone'
assert_equal 'codex answer' "$(cat $s/stdout)" 'q -x prints the answer codex gives'

set s (fresh_sandbox)
set -g stub_status 1
q_run $s -x anything
assert_equal 1 $status 'q -x exits non-zero when codex fails'
string match -q '*codex failed*' "$(cat $s/stderr)"
assert_equal 0 $status 'q -x says on stderr that codex failed'
set -e stub_status

# --- the answer is shown, never run --------------------------------------

set s (fresh_sandbox)
printf '%s\n' '#!/bin/sh' "echo \"touch $s/ran; cd /\"" >$s/bin/claude
q_run $s anything
test -e $s/ran
assert_equal 1 $status 'q never runs the commands in an answer'
assert_equal "touch $s/ran; cd /" "$(cat $s/stdout)" 'q prints a command answer as text'

# --- no words: ask for the question ---------------------------------------

set s (fresh_sandbox)
q_run $s
assert_equal 1 $status 'q with no words and no input exits non-zero'
assert_equal no (logged $s/claude.log) 'q with no words and no input runs nothing'

set s (fresh_sandbox)
printf '%s\n' "what's using *.log | port 80" >$s/input
set -g q_stdin $s/input
q_run $s
set -e q_stdin
assert_equal "what's using *.log | port 80" "$(last_arg $s/claude.log)" 'a typed question keeps quotes, globs and pipes as text'

harness_exit
