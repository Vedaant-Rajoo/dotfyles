#!/usr/bin/env fish
# Tests for the zoxide startup init cache in fish/conf.d.
# Run: fish tests/fish/conf.d/init-cache_test.fish
#
# Each case runs the real conf.d module in a child fish with --no-config and a
# sandboxed HOME/XDG_CACHE_HOME/XDG_CONFIG_HOME, so $__fish_cache_dir and
# $__fish_config_dir land inside the sandbox. `zoxide` is a stub script on a
# fake PATH that logs every invocation and emits known init code, which is what
# lets us assert the cache is used instead of the tool.

set -g repo (path resolve (status dirname)/../../..)
set -g zoxide_conf $repo/fish/conf.d/40-zoxide.fish
set -g fish_bin (status fish-path)
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

# A sandbox is a fake home plus a fake PATH holding the stub.
function fresh_sandbox
    set -l root $workdir/sandbox-(random)
    mkdir -p $root/home $root/cache $root/config $root/bin

    printf '%s\n' \
        '#!/bin/sh' \
        "printf '%s\n' \"\$*\" >>\"\$STUB_ZOXIDE_LOG\"" \
        'if [ -n "$STUB_ZOXIDE_FAIL" ]; then' \
        "  echo 'set -gx ZOXIDE_STUB_MARKER partial'" \
        '  exit 1' \
        'fi' \
        "echo 'set -gx ZOXIDE_STUB_MARKER applied'" >$root/bin/zoxide

    chmod +x $root/bin/zoxide
    echo $root
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

set -g zoxide_cache_rel cache/fish/zoxide-init.fish

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
