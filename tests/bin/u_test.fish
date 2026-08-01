#!/usr/bin/env fish

set -l repo_root (cd (dirname (status filename))/../..; and pwd)
set -g u_test_mock_calls

function assert_function
    set -l function_name $argv[1]
    set -l description $argv[2]

    if functions -q $function_name
        printf 'ok - %s\n' $description
        return 0
    end

    printf 'not ok - %s\n' $description
    return 1
end

function assert_no_mock_calls
    if test (count $u_test_mock_calls) -eq 0
        return 0
    end

    printf 'not ok - source runs top-level commands in test mode: %s\n' (string join ', ' $u_test_mock_calls)
    return 1
end

function gum
    set -ga u_test_mock_calls gum
    return 0
end

function nvim
    set -ga u_test_mock_calls nvim
    return 0
end

function brew
    set -ga u_test_mock_calls brew
    return 0
end

function bat
    set -ga u_test_mock_calls bat
    return 0
end

set -lx U_TEST_MODE 1
source "$repo_root/bin/u"

set -l test_status 0
assert_function u_main 'source exposes u_main'; or set test_status 1
assert_no_mock_calls; or set test_status 1
exit $test_status
