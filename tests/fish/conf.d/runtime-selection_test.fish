#!/usr/bin/env fish
# Which runtimes answer in a configured Fish shell, interactive or not: every
# tool mise/mise.toml declares, project overrides of Node and Python, and the
# rustup proxies. Run: fish tests/fish/conf.d/runtime-selection_test.fish
#
# Every case starts a real Fish, with a clean environment, against copies of
# fish/ and mise/ in a sandboxed home, so the shell starts the way a login on a
# bootstrapped machine does. mise is real; the runtimes it selects are stubs
# that print their version. Needs mise on PATH, or MISE_TEST_BIN set to one.

set -g repo_root (path resolve (dirname (status filename))/../../..)
source $repo_root/tests/lib/harness.fish

set -g real_mise $MISE_TEST_BIN
test -n "$real_mise"; or set real_mise (command -s mise)
if test -z "$real_mise"
    harness_fail 'mise is available' 'install it from the Brewfile, or set MISE_TEST_BIN'
    harness_exit
end

set -g fish_bin (status fish-path)
set -g sandbox (harness_tmpdir)
set -g home $sandbox/home
set -g mise_log $sandbox/mise-calls.log
set -g projects $home/projects

mkdir -p $home/.config $home/.local/bin $home/.local/share $home/.cargo/bin $home/.node_modules/bin $projects
cp -R $repo_root/fish $repo_root/mise $home/.config/
touch $mise_log

set -g project_node 22.1.0
set -g project_python 3.12.1
# A real release, so a regression that downloads it is caught, not masked.
set -g missing_node 18.20.8

function sandbox_env
    env -i HOME=$home USER=$USER TERM=dumb PATH=/usr/bin:/bin:/usr/sbin:/sbin $argv
end

# Setup runs mise from the sandbox home, offline, so neither this machine's
# config nor the network takes part.
function in_home
    sandbox_env MISE_OFFLINE=1 /bin/sh -c 'cd "$HOME" && exec "$@"' sh $argv
end

function stub --argument-names path output
    mkdir -p (path dirname $path)
    printf '#!/bin/sh\necho "%s"\n' $output >$path
    chmod +x $path
end

function command_name --argument-names tool
    test "$tool" = python; and echo python3; or echo $tool
end

# A stub install of a tool, at the directory where mise expects that backend's
# binaries; pnpm's, for one, sit at the install root rather than in bin/.
function stub_install --argument-names tool tool_version
    mkdir -p $home/.local/share/mise/installs/$tool/$tool_version
    set -l bin_dir (in_home $real_mise bin-paths $tool@$tool_version 2>/dev/null)[1]
    test -n "$bin_dir"; or set bin_dir $home/.local/share/mise/installs/$tool/$tool_version/bin
    stub $bin_dir/(command_name $tool) $tool_version
end

# The machine defaults are whatever [tools] in the tracked config declares. A
# release line such as "24" gets an install inside it, and "latest" any version.
set -g default_commands
set -g default_versions
set -l in_tools 0
for line in (cat $repo_root/mise/mise.toml)
    if string match -qr '^\[' -- $line
        test "$line" = '[tools]'; and set in_tools 1; or set in_tools 0
        continue
    end
    test $in_tools -eq 1; or continue
    string match -qr '^\s*(#.*)?$' -- $line; and continue
    set -l pair (string match -rg '^([a-z][a-z0-9-]*) = "(.+)"$' -- $line)
    or begin
        harness_fail 'every [tools] entry in mise/mise.toml has a form this suite checks' $line
        continue
    end
    set -l parts (string split . -- $pair[2])
    test "$pair[2]" = latest; and set parts 1
    while test (count $parts) -lt 3
        set -a parts 0
    end
    set -l tool_version (string join . -- $parts)
    stub_install $pair[1] $tool_version
    set -a default_commands (command_name $pair[1])
    set -a default_versions $tool_version
    set -g default_$pair[1] $tool_version
end
set -g defaults_probe "echo "(string join ' ' -- "("$default_commands")")

stub_install node $project_node
stub_install python $project_python

# ~/.local/bin is where mise's own installer puts it, and it sits ahead of
# Homebrew, so this logging wrapper is the mise every shell finds by name.
printf '#!/bin/sh\necho "$*" >>"%s"\nexec "%s" "$@"\n' $mise_log $real_mise >$home/.local/bin/mise
chmod +x $home/.local/bin/mise

# What Homebrew's mise formula installs: activation in every Fish shell.
mkdir -p $home/.local/share/fish/vendor_conf.d
printf '%s\n' 'if [ "$MISE_FISH_AUTO_ACTIVATE" != "0" ]' '  mise activate fish | source' 'end' \
    >$home/.local/share/fish/vendor_conf.d/mise-activate.fish

# A global npm CLI, and a rustc that would shadow the rustup proxy if Rust's
# PATH entry lost its place.
stub $home/.node_modules/bin/global-cli global-cli
stub $home/.cargo/bin/rustc rustup-proxy
stub $home/.local/bin/rustc shadowing-rustc

mkdir -p $projects/plain $projects/pinned $projects/nvmrc $projects/toml $projects/missing
echo $project_node >$projects/pinned/.node-version
# The form these projects actually use: a release line in .nvmrc.
echo v(string split . -- $project_node)[1] >$projects/nvmrc/.nvmrc
echo $project_python >$projects/pinned/.python-version
printf '[tools]\nnode = "%s"\npython = "%s"\n' $project_node $project_python >$projects/toml/mise.toml
echo $missing_node >$projects/missing/.node-version

# A worktree of this repository: its copy of the global config, with the pins
# a branch might bump, must not take over the shell inside the worktree.
mkdir -p $projects/worktree
cp -R $repo_root/mise $projects/worktree/
string replace -r '^node = .*' "node = \"$project_node\"" <$repo_root/mise/mise.toml |
    string replace -r '^python = .*' "python = \"$project_python\"" >$projects/worktree/mise/mise.toml

in_home $home/.local/bin/mise reshim
printf '' >$mise_log

# Runs a script in a fresh Fish started in a directory, interactive or as a
# script. stdin is closed, so a wrong runtime that opens its REPL fails the
# case instead of hanging the suite.
function in_shell --argument-names mode dir script
    set -l flags -c
    test "$mode" = interactive; and set flags -i -c
    sandbox_env /bin/sh -c 'cd "$1" && shift && exec "$@"' sh $dir $fish_bin $flags $script </dev/null 2>&1
end

for mode in interactive script
    assert_equal "$default_versions" "$(in_shell $mode $projects/plain $defaults_probe)" \
        "$mode shell: outside a project, every runtime mise/mise.toml declares answers from mise"
    assert_equal "$project_node $project_python" "$(in_shell $mode $projects/pinned 'echo (node) (python3)')" \
        "$mode shell: .node-version and .python-version override the defaults"
    assert_equal $project_node "$(in_shell $mode $projects/nvmrc 'node')" \
        "$mode shell: a release line in .nvmrc selects an installed version in that line"
    assert_equal "$project_node $project_python" "$(in_shell $mode $projects/toml 'echo (node) (python3)')" \
        "$mode shell: a project mise.toml overrides the defaults"
    assert_equal "$default_node $default_python" "$(in_shell $mode $projects/worktree 'echo (node) (python3)')" \
        "$mode shell: a worktree copy of the global config is not applied"
    assert_equal "$default_node $project_node $default_node" \
        "$(in_shell $mode $projects/plain 'set -l seen (node); cd ../pinned; set -a seen (node); cd ../plain; echo $seen (node)')" \
        "$mode shell: changing directory switches versions immediately"

    set -l installs_before (count $home/.local/share/mise/installs/node/*)
    set -l output (in_shell $mode $projects/missing 'node; echo status=$status')
    assert_equal status=1 "$output[-1]" \
        "$mode shell: a pinned version that is not installed fails"
    assert_equal 1 (count (string match -e 'mise install' -- $output)) \
        "$mode shell: the failure names mise install"
    assert_equal $installs_before (count $home/.local/share/mise/installs/node/*) \
        "$mode shell: a missing pinned version is never installed implicitly"

    assert_equal "$home/.node_modules $home/.node_modules/bin/global-cli" \
        "$(in_shell $mode $projects/pinned 'echo $npm_config_prefix (command -s global-cli)')" \
        "$mode shell: npm globals keep one prefix whichever Node is selected"
    assert_equal rustup-proxy "$(in_shell $mode $projects/pinned 'rustc')" \
        "$mode shell: rustc is the rustup proxy"
end

assert_equal "rustup-proxy $project_node" \
    "$(in_shell interactive $projects/plain 'emit fish_prompt; cd ../pinned; emit fish_prompt; echo (rustc) (node)')" \
    'interactive shell: prompts and directory changes keep the rustup proxy first'

# A script inherits its parent shell's PATH, but must follow its own directory.
assert_equal $project_node \
    "$(in_shell interactive $projects/plain "$fish_bin -c 'cd ../pinned; node'")" \
    'a script started from an interactive shell follows its own directory'

for mode in interactive script
    printf '' >$mise_log
    in_shell $mode $projects/plain true >/dev/null
    assert_equal '' "$(cat $mise_log)" \
        "$mode shell: startup runs no mise process, even with Homebrew's snippet"
end

harness_exit
