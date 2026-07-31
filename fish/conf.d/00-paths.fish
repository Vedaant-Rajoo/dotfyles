# Shared PATH setup for interactive and non-interactive Fish sessions.
#
# Order matters: each `fish_add_path -gPm` prepends, so later entries win.
# 1. Homebrew — formatters (stylua, ruff, prettier, shfmt, …) and other CLI tools
# 2. Official Go (go.dev pkg at /usr/local/go) — preferred for `go` and `gofmt`
#
# `-m` (--move) is required, not cosmetic: macOS `path_helper` seeds PATH from
# /etc/paths (which lists /usr/bin) and only then appends /etc/paths.d/*, where
# Homebrew installs its own entry. /opt/homebrew/bin therefore already exists in
# PATH — behind /usr/bin — before Fish runs, and without --move `fish_add_path`
# leaves an already-present directory where it sits instead of promoting it.
# Dropping -m silently restores system Ruby/jq/openssl over the Homebrew ones.

fish_add_path -gPm /opt/homebrew/bin
fish_add_path -gPm /usr/local/go/bin
fish_add_path -gPm $HOME/.local/bin
fish_add_path -gPm $HOME/.config/bin

if test -d $HOME/.node_modules/bin
	fish_add_path -gPm $HOME/.node_modules/bin
end

if test -d $HOME/.yarn/bin
	fish_add_path -gPm $HOME/.yarn/bin
end
