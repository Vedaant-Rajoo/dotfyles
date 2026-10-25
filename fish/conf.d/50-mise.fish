# Node and Python come from mise. mise/mise.toml sets the machine defaults, and
# a project's .node-version, .python-version, or mise.toml overrides them.
#
# Every shell, interactive or not, uses mise's shims, which choose the version
# from the working directory each time a runtime starts. `mise activate` is not
# used: it takes the shims off PATH, so a project pinning a version that is not
# installed would quietly run Homebrew's dependency Node or Python instead of
# failing. Shims also spawn no mise process at shell startup.

# Homebrew's mise installs a vendor_conf.d snippet that runs `mise activate` in
# every Fish shell. It runs after this file and honors this variable.
set -g MISE_FISH_AUTO_ACTIVATE 0

# -m moves the shims ahead of everything a parent process put on PATH.
set -l mise_data $XDG_DATA_HOME/mise
set -q MISE_DATA_DIR
and set mise_data $MISE_DATA_DIR
fish_add_path -gPm $mise_data/shims
