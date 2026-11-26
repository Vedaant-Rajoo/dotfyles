#!/usr/bin/env fish
set -l repo (path resolve (dirname (status filename))/../..)
source $repo/tests/lib/harness.fish
set -l python (python3 -c 'import sys; print(sys.executable)')
set -l fixture (harness_tmpdir)
env -i HOME=$fixture XDG_CONFIG_HOME=$fixture/config XDG_STATE_HOME=$fixture/state XDG_CACHE_HOME=$fixture/cache PATH=/usr/bin:/bin \
    $python -B $repo/tests/bin/t3-9router-quota-fixture.py </dev/null
assert_equal 0 $status 'quota feed handles real window shapes, partial outages and unreportable limits'
harness_exit
