status is-interactive
or return

if command -q eza
    abbr --add -g ls 'eza --group-directories-first'
    abbr --add -g ll 'eza --long --all --header --git --group-directories-first'
    abbr --add -g lt 'eza --tree --level=2 --group-directories-first'
end

if command -q zoxide
    abbr --add -g z cd
    abbr --add -g zz cdi
end

if command -q bat
    abbr --add -g cat 'bat --style=plain'
end

if command -q trash
    abbr --add -g rm trash
end

abbr --add -g g git
abbr --add -g ga 'git add'
abbr --add -g gc 'git commit -v'
abbr --add -g gd 'git diff'
abbr --add -g gs 'git status --short --branch'

if command -q nvim
    alias vim nvim
    alias vi nvim
end