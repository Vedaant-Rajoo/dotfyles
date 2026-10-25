# Common tool preferences.

set -q XDG_DATA_HOME
or set -gx XDG_DATA_HOME $HOME/.local/share

set -q XDG_STATE_HOME
or set -gx XDG_STATE_HOME $HOME/.local/state

# Keep npm global installs on a stable user-owned path, whichever Node version
# mise selects.
set -gx npm_config_prefix $HOME/.node_modules

if command -q nvim
    set -gx EDITOR nvim
else if command -q vim
    set -gx EDITOR vim
end

set -q EDITOR
and set -gx VISUAL $EDITOR

# fish 4.1+ queries the terminal (DA1) at startup. Harness ptys (Claude Code,
# T3 Code) never answer, so every spawn stalls 10s and warns. The flag is read
# at startup, so it must be universal; this makes the setting idempotent.
contains -- no-query-term $fish_features
or set -Ua fish_features no-query-term
