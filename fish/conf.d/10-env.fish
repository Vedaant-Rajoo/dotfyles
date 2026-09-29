# Common tool preferences.

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
