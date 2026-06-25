# Zig (manual bundle from ziglang.org/download)
# Installed at ~/.local/opt/zig/current -> versioned extract directory.
set -l zig_home $HOME/.local/opt/zig/current

if test -d $zig_home
	fish_add_path -gP $zig_home
end
