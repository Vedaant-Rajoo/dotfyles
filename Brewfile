# Full macOS machine manifest.
#
# On an already-configured machine, use `brew bundle check --file=Brewfile`.
# Do not use `brew bundle install` only to verify this file: it may adopt existing
# applications or run privileged package installers with system-level effects.

# Taps
tap "anomalyco/tap"
tap "nguyenphutrong/tap"
tap "supabase/tap"
tap "xykong/tap"

# Shell
# bin/bootstrap adds the Homebrew binary to /etc/shells and selects it with chsh.
# This snapshot machine still uses the official Fish pkg at /usr/local/bin/fish.
brew "fish"
# Prompt engine initialized by fish/conf.d/60-starship.fish.
brew "starship"

# Core CLI tools
brew "bat"
brew "eza"
brew "fd"
brew "fzf"
brew "gum"
# Required by bin/herdr-sessionizer.
brew "jq"
brew "ripgrep"
brew "tlrc"
brew "trash"
brew "xz"
brew "zoxide"

# Git and repository tooling
brew "gh"
brew "gitleaks"
brew "lazygit"

# Toolchains and package managers
# Node is installed and selected by bin/bootstrap; the version is pinned in
# .node-version, which fnm also reads directly through `fnm env --use-on-cd`.
brew "fnm"
# The only Go on PATH: the official /usr/local/go install is gone, so this
# supplies `go` and `gofmt` everywhere. See fish/conf.d/00-paths.fish.
brew "go"
# Python is installed and selected by bin/bootstrap; the version is pinned in
# .python-version, which pyenv also resolves directly through `pyenv init -`.
brew "pyenv"
brew "pyenv-virtualenv"
# rustup coexists on the snapshot machine; Homebrew Rust currently wins on PATH.
# See SYSTEM.md for provenance rather than changing either installation here.
brew "rust"
brew "bun"
brew "cocoapods"
brew "luarocks"
brew "mas"
brew "pnpm"
brew "proton-pass-cli"

# Formatters and linters
brew "black"
brew "gofumpt"
brew "goimports"
brew "prettier"
brew "prettierd"
brew "ruff"
brew "shellcheck"
brew "shfmt"
brew "stylua"

# Editors and terminal workflow
brew "herdr"
brew "neovim"
# Required at runtime by nvim-treesitter on its main branch.
brew "tree-sitter-cli"

# tmux is intentionally not declared. It was retired in favor of Herdr and is
# only installed locally as legacy state; bin/tmux-sessionizer is a Herdr shim.

# Product CLIs
brew "anomalyco/tap/opencode", trusted: true
brew "supabase/tap/supabase", trusted: true

# Developer apps and terminal tools
# Claude Code and cursor-agent use their native self-updating installers instead
# of the available claude-code and cursor-cli casks; bin/bootstrap handles Claude.
cask "codex"
cask "cursor"
cask "font-jetbrains-mono-nerd-font"
cask "ghostty"
cask "orbstack"
cask "t3-code@nightly"
cask "xykong/tap/flux-markdown", trusted: true

# Productivity and desktop UI
cask "alcove"
cask "bartender"
cask "dockdoor"
cask "hyperkey"
cask "linearmouse"
cask "nguyenphutrong/tap/quotio", trusted: true
# The installed Raycast uses the Beta channel selected inside the app; Homebrew
# exposes only the stable cask token.
cask "raycast"
cask "rectangle-pro"
cask "shottr"
cask "wallspace"
cask "wispr-flow"

# Browsers, communication, and networking
cask "google-chrome"
# Alternate Discord client; bin/legcord_link connects its tracked settings.
cask "legcord"
cask "proton-pass"
cask "tailscale-app"
cask "zen"

# Hardware and system utilities
cask "logitech-g-hub"
cask "macs-fan-control"
cask "music-presence"
cask "wakatime"

# Games
# This also installs the Riot Client.
cask "league-of-legends"

# Mac App Store applications. Sign in to the App Store before running bootstrap.
mas "Amphetamine", id: 937984704
mas "Hush", id: 1544743900
mas "NepTunes", id: 1006739057
mas "Proton Pass for Safari", id: 6502835663
mas "Tampermonkey", id: 6738342400
mas "TrashMe 3", id: 1490879410
mas "Wipr", id: 1662217862
mas "Xcode", id: 497799835

# npm globals are installed after fnm by bin/bootstrap. Brew Bundle's npm
# directive cannot pin versions and installs Homebrew Node when npm is absent.
