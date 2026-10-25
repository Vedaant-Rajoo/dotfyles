# Every shell, interactive or not, runs the language runtimes through mise's
# shims, which pick the version from the working directory each time a runtime
# starts. fish/README.md#runtimes explains why `mise activate` stays unused.

# Homebrew's mise installs a vendor_conf.d snippet that runs `mise activate` in
# every Fish shell. It runs after this file and honors this variable.
set -g MISE_FISH_AUTO_ACTIVATE 0

# Move the shims ahead of everything a parent process put on PATH. Unlike
# fish_add_path, this keeps the directory before it exists: mise creates it on
# its first install, which can happen inside an already running shell, as in
# bin/u.
set -l shims $XDG_DATA_HOME/mise/shims
set -q MISE_DATA_DIR
and set shims $MISE_DATA_DIR/shims
set -gx PATH $shims (string match -v -- $shims $PATH)
