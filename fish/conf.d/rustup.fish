# Rustup only installs this after `rustup`/`cargo` setup — skip cleanly otherwise.
if test -f "$HOME/.cargo/env.fish"
	source "$HOME/.cargo/env.fish"
end
