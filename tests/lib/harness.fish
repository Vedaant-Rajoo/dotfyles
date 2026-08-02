# Shared scaffolding for tests/**/*_test.fish. Source it after computing the
# repo root, assert, then end the suite with harness_exit:
#
#     set -g repo_root (path resolve (dirname (status filename))/../..)
#     source $repo_root/tests/lib/harness.fish
#
# Output is one TAP-style line per assertion ("ok - …" / "not ok - …"), so
# every suite reads the same and a single runner can parse them all. Suite-
# specific assertions build on harness_pass/harness_fail so counting, output,
# and the exit path live only here.

set -g harness_checks 0
set -g harness_failures 0
set -g harness_tmpdirs

function harness_pass --argument-names description
    set -g harness_checks (math $harness_checks + 1)
    printf 'ok - %s\n' $description
end

# Extra arguments become indented detail lines under the failure.
function harness_fail --argument-names description
    set -g harness_checks (math $harness_checks + 1)
    set -g harness_failures (math $harness_failures + 1)
    printf 'not ok - %s\n' $description
    for detail in $argv[2..-1]
        printf '  %s\n' $detail
    end
    return 1
end

function assert_equal --argument-names expected actual description
    if test "$expected" = "$actual"
        harness_pass $description
    else
        harness_fail $description \
            'expected: '(string escape -- "$expected") \
            'actual:   '(string escape -- "$actual")
    end
end

# Temporary directories obtained here are removed when the suite exits, even
# when it dies mid-run, so failed runs never leave fixtures behind.
function harness_tmpdir
    set -l dir (mktemp -d)
    set -ga harness_tmpdirs $dir
    echo $dir
end

function harness_cleanup_tmpdirs --on-event fish_exit
    test -n "$harness_tmpdirs"; and rm -rf -- $harness_tmpdirs
end

function harness_exit
    if test $harness_failures -gt 0
        printf '%d of %d checks failed\n' $harness_failures $harness_checks
        exit 1
    end
    printf 'all %d checks passed\n' $harness_checks
    exit 0
end
