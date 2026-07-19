status is-interactive
or return

# Launch herdr-sessionizer with Ctrl-o (ctrl-f/g/r/v are taken by fzf.fish).
# One of its launch surfaces alongside Ghostty cmd+s, prefix+f in Herdr, and the CLI.
function _herdr_sessionizer_launch
	herdr-sessionizer
	commandline -f repaint
end

bind \co _herdr_sessionizer_launch

# Mirror the binding into vi insert mode if vi/hybrid bindings are ever enabled.
if string match -rq 'fish_(vi|hybrid)_key_bindings' "$fish_key_bindings"
	bind -M insert \co _herdr_sessionizer_launch
end
