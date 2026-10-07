# Verify with: brew bundle check --file=Brewfile
# bin/bootstrap manages Node, Python, Rust, npm globals, and native CLI installers.

# Taps
tap "anomalyco/tap"
tap "driceroland/tap"
tap "nguyenphutrong/tap"

# Shell
brew "fish"

# Core CLI tools
brew "bat"
brew "eza"
brew "fd"
brew "ffmpeg"
brew "fzf"
brew "gnu-tar"
brew "gum"
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

# Security keys
brew "ykman"
cask "yubico-authenticator"

# Toolchains and package managers
brew "fnm"
brew "go"
brew "pyenv"
brew "pyenv-virtualenv"
brew "sccache"
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
brew "tree-sitter-cli"

# Product CLIs
brew "anomalyco/tap/opencode-v2", trusted: true

# Developer apps and terminal tools
cask "codex"
cask "cursor"
cask "font-jetbrains-mono-nerd-font"
cask "ghostty"
cask "orbstack"
cask "nguyenphutrong/tap/quotio"
cask "t3-code@nightly"
cask "zed"

# Productivity and desktop UI
cask "alcove"
cask "bartender"
cask "dockdoor"
cask "linearmouse"
cask "raycast"
cask "rectangle-pro"
cask "shottr"
cask "wallspace"
cask "wispr-flow"

# Browsers, communication, and networking
cask "driceroland/tap/search"
cask "firefox"
cask "google-chrome"
cask "legcord"
cask "proton-pass"
cask "tailscale-app"

# Hardware and system utilities
cask "logitech-g-hub"
cask "macs-fan-control"
cask "music-presence"
cask "wakatime"

# Games
cask "league-of-legends"
# Steam is not a cask: the cask ships Valve's Intel-only stub and needs Rosetta.
# bin/bootstrap installs the universal bootstrapper via i1rr/steam-arm64-mac.

# Mac App Store apps (requires App Store sign-in)
mas "Amphetamine", id: 937984704
mas "Hush", id: 1544743900
mas "Proton Pass for Safari", id: 6502835663
mas "Tampermonkey", id: 6738342400
# NepTunes (App Store 1006739057) runs as a TestFlight beta; mas cannot see beta installs, so join it in TestFlight.
mas "TestFlight", id: 899247664
mas "TrashMe 3", id: 1490879410
mas "Wipr", id: 1662217862
mas "Xcode", id: 497799835
