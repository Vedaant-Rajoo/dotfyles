# Common tool preferences.

if command -q nvim
    set -gx EDITOR nvim
else if command -q vim
    set -gx EDITOR vim
end

set -q EDITOR
and set -gx VISUAL $EDITOR
