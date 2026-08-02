#!/usr/bin/env fish
# Tests for the pyenv and zoxide startup init caches in fish/conf.d.
# Run: fish tests/fish/conf.d/init-cache_test.fish
#
# Each case runs the real conf.d module in a child fish with --no-config and a
# sandboxed HOME/XDG_CACHE_HOME/XDG_CONFIG_HOME, so $__fish_cache_dir and
# $__fish_config_dir land inside the sandbox. `pyenv` and `zoxide` are stub
# scripts on a fake PATH that log every invocation and emit known init code,
# which is what lets us assert the cache is used instead of the tool.

set -g repo (path resolve (status dirname)/../../..)
set -g python_conf $repo/fish/conf.d/55-python.fish
set -g zoxide_conf $repo/fish/conf.d/40-zoxide.fish
set -g fish_bin /opt/homebrew/bin/fish
set -g failures 0
set -g checks 0
set -g workdir (mktemp -d /tmp/fish-init-cache-test.XXXXXX)

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

# A sandbox is a fake home plus a fake PATH holding the two stubs. The pyenv
# stub emits an eager completion `source` line the way the real one does, so
# the module's completion-stripping has something to strip.
function fresh_sandbox
    set -l root $workdir/sandbox-(random)
    mkdir -p $root/home $root/cache $root/config/fish/completions $root/bin
    printf 'complete -c pyenv -a stub\n' >$root/completions-src.fish

    printf '%s\n' \
        '#!/bin/sh' \
        "printf '%s\n' \"\$*\" >>\"\$STUB_PYENV_LOG\"" \
        'if [ -n "$STUB_PYENV_FAIL" ]; then' \
        "  echo 'set -gx PYENV_STUB_MARKER partial'" \
        '  exit 1' \
        'fi' \
        "echo 'set -gx PYENV_STUB_MARKER applied'" \
        'echo "set -gx PYENV_STUB_ROOT '\''$PYENV_ROOT'\''"' \
        'echo "source '\''$STUB_COMPLETIONS'\''"' >$root/bin/pyenv

    printf '%s\n' \
        '#!/bin/sh' \
        "printf '%s\n' \"\$*\" >>\"\$STUB_ZOXIDE_LOG\"" \
        'if [ -n "$STUB_ZOXIDE_FAIL" ]; then' \
        "  echo 'set -gx ZOXIDE_STUB_MARKER partial'" \
        '  exit 1' \
        'fi' \
        "echo 'set -gx ZOXIDE_STUB_MARKER applied'" >$root/bin/zoxide

    chmod +x $root/bin/pyenv $root/bin/zoxide
    echo $root
end

# PYENV_ROOT is only exported when the case asks for one, so the default case
# still exercises the module's own `$HOME/.pyenv` fallback.
function python_env --argument-names root fail pyenv_root
    printf '%s\n' \
        HOME=$root/home \
        XDG_CACHE_HOME=$root/cache \
        XDG_CONFIG_HOME=$root/config \
        PATH=$root/bin:/usr/bin:/bin \
        STUB_PYENV_LOG=$root/pyenv.log \
        STUB_COMPLETIONS=$root/completions-src.fish \
        STUB_PYENV_FAIL=$fail
    test -n "$pyenv_root"; and printf '%s\n' PYENV_ROOT=$pyenv_root
end

# Prints the marker the sourced init code set, and exits with the child shell's
# status. `fail` non-empty makes the stub fail the way a broken tool would.
function python_run --argument-names root fail pyenv_root
    env (python_env $root "$fail" "$pyenv_root") \
        $fish_bin --no-config -c "source $python_conf; printf '%s\n' \$PYENV_STUB_MARKER" 2>/dev/null
end

# Prints the PYENV_ROOT that was in effect when the sourced init was generated,
# which is what proves a shell did not pick up another root's cache.
function python_run_root --argument-names root fail pyenv_root
    env (python_env $root "$fail" "$pyenv_root") \
        $fish_bin --no-config -c "source $python_conf; printf '%s\n' \$PYENV_STUB_ROOT" 2>/dev/null
end

# zoxide's module is interactive-only, so its child shell needs -i.
function zoxide_run --argument-names root fail
    env HOME=$root/home \
        XDG_CACHE_HOME=$root/cache \
        XDG_CONFIG_HOME=$root/config \
        PATH=$root/bin:/usr/bin:/bin \
        STUB_ZOXIDE_LOG=$root/zoxide.log \
        STUB_ZOXIDE_FAIL=$fail \
        $fish_bin --no-config -ic "source $zoxide_conf; printf '%s\n' \$ZOXIDE_STUB_MARKER" 2>/dev/null
end

function log_lines --argument-names file
    if test -f $file
        wc -l <$file | string trim
    else
        echo 0
    end
end

# Backdating the cache is how we make the tool binary look newer without
# depending on filesystem timestamp resolution.
function backdate --argument-names file
    touch -t 200001010000 $file
end

# The pyenv cache filename embeds the escaped PYENV_ROOT, so tests look the
# cache up by pattern rather than by a fixed name.
function pyenv_cache_names --argument-names root
    ls $root/cache/fish 2>/dev/null | string match 'pyenv-init-*.fish'
end

function pyenv_cache --argument-names root
    echo $root/cache/fish/(pyenv_cache_names $root)[1]
end

set -g zoxide_cache_rel cache/fish/zoxide-init.fish

# --- pyenv: first source generates, second source reuses -----------------

set a (fresh_sandbox)
check "the first source applies the pyenv init" applied (python_run $a)
check "the first source creates the pyenv cache" 0 (test -s (pyenv_cache $a); echo $status)
check "the eager completion file is copied into the config" 0 (test -f $a/config/fish/completions/pyenv.fish; echo $status)
check "the installed completions match the source" 0 (cmp -s $a/completions-src.fish $a/config/fish/completions/pyenv.fish; echo $status)
check "a successful generation leaves no completion temp file" pyenv.fish (ls $a/config/fish/completions 2>/dev/null | string join ' ')
check "the cache drops the eager completion source line" 1 (grep -q "^source '" (pyenv_cache $a); echo $status)
check "the first source invokes pyenv once" 1 (log_lines $a/pyenv.log)

check "the second source still applies the pyenv init" applied (python_run $a)
check "the second source does not invoke pyenv again" 1 (log_lines $a/pyenv.log)

# --- pyenv: a cache older than the binary is regenerated -----------------

backdate (pyenv_cache $a)
check "a backdated cache still applies the pyenv init" applied (python_run $a)
check "a backdated cache is regenerated" 2 (log_lines $a/pyenv.log)

# --- pyenv: caches are keyed by PYENV_ROOT --------------------------------
#
# `pyenv init` bakes the effective root's shim path into its output, so a
# second root must never source the first root's cache — that would put the
# wrong Python on PATH.

set r (fresh_sandbox)
set -g root_a $r/roots/a
set -g root_b $r/roots/b
mkdir -p $root_a/bin $root_b/bin

check "the first root applies its own init" $root_a (python_run_root $r "" $root_a)
check "the second root applies its own init, not the first root's" $root_b (python_run_root $r "" $root_b)
check "the second root generates rather than reusing the first root's cache" 2 (log_lines $r/pyenv.log)
check "each root gets its own cache file" 2 (count (pyenv_cache_names $r))
check "returning to the first root still applies the first root's init" $root_a (python_run_root $r "" $root_a)
check "returning to the first root reuses its cache" 2 (log_lines $r/pyenv.log)

# --- pyenv: generation failures ------------------------------------------
#
# The failing stub prints a partial init — a marker of its own — before exiting
# nonzero, the way a real initializer that dies midway does. Output being
# nonempty is therefore not enough to trust it; the exit status decides.

set b (fresh_sandbox)
check "a failed first generation exits cleanly" 0 (python_run $b 1 >/dev/null; echo $status)
check "a failed first generation writes no cache" 0 (count (pyenv_cache_names $b))
check "a failed first generation leaves no temp file" "" (ls $b/cache/fish/ 2>/dev/null | string join ' ')

set c (fresh_sandbox)
python_run $c >/dev/null
set -g good_cache (pyenv_cache $c)
set -g good_sum (shasum $good_cache | string split ' ')[1]
backdate $good_cache
check "a failed regeneration still applies the old cache" applied (python_run $c 1)
check "a failed regeneration preserves the old cache byte for byte" $good_sum (shasum $good_cache 2>/dev/null | string split ' ')[1]
check "a failed regeneration leaves no temp file" (path basename $good_cache) (ls $c/cache/fish/ 2>/dev/null | string join ' ')

# --- zoxide ---------------------------------------------------------------

set z (fresh_sandbox)
check "the first interactive source applies the zoxide init" applied (zoxide_run $z)
check "the first interactive source creates the zoxide cache" 0 (test -s $z/$zoxide_cache_rel; echo $status)
check "the first interactive source invokes zoxide once" 1 (log_lines $z/zoxide.log)

check "the second interactive source still applies the zoxide init" applied (zoxide_run $z)
check "the second interactive source does not invoke zoxide again" 1 (log_lines $z/zoxide.log)

set -g good_zoxide_sum (shasum $z/$zoxide_cache_rel | string split ' ')[1]
backdate $z/$zoxide_cache_rel
check "a failed zoxide regeneration still applies the old cache" applied (zoxide_run $z 1)
check "a failed zoxide regeneration preserves the old cache byte for byte" $good_zoxide_sum (shasum $z/$zoxide_cache_rel 2>/dev/null | string split ' ')[1]

# --- summary --------------------------------------------------------------

printf '\n%d checks, %d failures\n' $checks $failures
test $failures -eq 0
