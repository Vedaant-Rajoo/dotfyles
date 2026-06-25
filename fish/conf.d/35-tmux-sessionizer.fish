status is-interactive
or return

# Launch tmux-sessionizer with Ctrl-o (ctrl-f/g/r/v are taken by fzf.fish).
function _tmux_sessionizer_launch
    tmux-sessionizer
    commandline -f repaint
end

bind \co _tmux_sessionizer_launch

# Mirror the binding into vi insert mode if vi/hybrid bindings are ever enabled.
if string match -rq 'fish_(vi|hybrid)_key_bindings' "$fish_key_bindings"
    bind -M insert \co _tmux_sessionizer_launch
end
