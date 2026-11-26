# Verify with: brew bundle check --file=Brewfile
# mise/mise.toml owns the language runtimes; bin/bootstrap installs them with
# mise, plus Rust, npm globals, and native CLI installers. Homebrew still
# installs its own Go, Node, Python, or Ruby when a formula here depends on one.

# Taps
tap "anomalyco/tap"
tap "ardia-browser/tap"
tap "cristipufu/tap"
tap "driceroland/tap"

# Shell
brew "fish"

# Core CLI tools
brew "bat"
brew "btop"
brew "eza"
brew "fd"
brew "ffmpeg"
brew "fzf"
brew "gnu-tar"
brew "gum"
brew "jq"
brew "mole"
brew "ripgrep"
brew "tlrc"
brew "trash"
brew "xz"
brew "zoxide"

# Git and repository tooling
brew "gh"
brew "git-delta"
brew "gitleaks"
brew "lazygit"

# Security keys
brew "ykman"
cask "yubico-authenticator"

# Toolchains and package managers
brew "mise"
brew "sccache"
brew "cocoapods"
brew "luarocks"
brew "mas"
brew "proton-pass-cli"

# Formatters and linters
brew "black"
brew "gofumpt"
brew "goimports"
brew "ruff"
brew "shellcheck"

# Editors and terminal workflow
brew "herdr"
brew "neovim"
brew "tree-sitter-cli"

# Product CLIs
brew "anomalyco/tap/opencode-v2", trusted: true

# Developer apps and terminal tools
cask "codex"
cask "font-jetbrains-mono-nerd-font"
cask "font-maple-mono-nf"
cask "ghostty"
cask "orbstack"
cask "t3-code@nightly"

# Productivity and desktop UI
cask "alcove"
cask "karabiner-elements"
cask "markedit"
cask "omniwm"
cask "raycast"
cask "rectangle-pro"
cask "shottr"
cask "cristipufu/tap/strata", trusted: true
cask "vorssaint"
cask "wallspace"
cask "wispr-flow"

# Browsers, communication, and networking
cask "ardia-browser/tap/ardia@nightly", trusted: true
cask "driceroland/tap/search"
cask "firefox"
cask "google-chrome"
cask "legcord"
cask "tailscale-app"

# Hardware and system utilities
cask "logitech-g-hub"
cask "wakatime"

# Games
cask "league-of-legends"
# Steam is not a cask: the cask ships Valve's Intel-only stub and needs Rosetta.
# bin/bootstrap installs the universal bootstrapper via i1rr/steam-arm64-mac.

# Mac App Store apps (requires App Store sign-in)
mas "Hush", id: 1544743900
mas "Tampermonkey", id: 6738342400
# NepTunes (App Store 1006739057) runs as a TestFlight beta; mas cannot see beta installs, so join it in TestFlight.
mas "TestFlight", id: 899247664
mas "Wipr", id: 1662217862
mas "Xcode", id: 497799835
