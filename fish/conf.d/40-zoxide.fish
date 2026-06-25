status is-interactive
or return

if command -q zoxide
    zoxide init fish --cmd cd | source
end
