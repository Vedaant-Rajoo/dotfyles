# Shared PATH setup for interactive and non-interactive Fish sessions.
#
# Order matters: each `fish_add_path -gP` prepends, so later entries win.
# 1. Homebrew — formatters (stylua, ruff, prettier, shfmt, …) and other CLI tools
# 2. Official Go (go.dev pkg at /usr/local/go) — preferred for `go` and `gofmt`

fish_add_path -gP /opt/homebrew/bin
fish_add_path -gP /usr/local/go/bin
fish_add_path -gP $HOME/.local/bin
fish_add_path -gP $HOME/.config/bin

if test -d $HOME/.node_modules/bin
	fish_add_path -gP $HOME/.node_modules/bin
end

if test -d $HOME/.yarn/bin
	fish_add_path -gP $HOME/.yarn/bin
end
