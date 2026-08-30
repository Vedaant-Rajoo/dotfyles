# Rust comes from the official rustup installer, run by bin/bootstrap. Its
# proxies -- cargo, rustc, rustup, rustfmt, clippy-driver, rust-analyzer -- all
# live in ~/.cargo/bin, and no Homebrew formula provides Rust any more.
#
# Bootstrap passes `--no-modify-path` for a concrete reason: rustup-init writes
# its own PATH snippet to $XDG_CONFIG_HOME/fish/conf.d/rustup.fish, and
# XDG_CONFIG_HOME is ~/.config -- this repository -- so a default install would
# overwrite this tracked file. .gitignore carries a matching
# `!fish/conf.d/rustup.fish` rule for the same reason. PATH is wired here, in
# version control, instead of by the installer.
#
# `-m` is required for the reason 00-paths.fish documents: an entry already in
# PATH is only promoted to the front when it is moved. This file has no numeric
# prefix, so it loads after 00-paths.fish and the proxies land ahead of
# /opt/homebrew/bin.

if test -d $HOME/.cargo/bin
	fish_add_path -gPm $HOME/.cargo/bin
end
