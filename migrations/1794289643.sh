echo "Uninstall AeroSpace and its tap, which the Brewfile no longer installs"

# A machine without Homebrew, or without AeroSpace, has nothing to retire.
command -v brew >/dev/null || exit 0
casks="$(brew list --cask -1)"
if grep -qx aerospace <<<"$casks"; then
  brew uninstall --cask aerospace
fi

# The tap served only AeroSpace; without it, brew update stops fetching it.
if brew tap | grep -qx nikitabobko/tap; then
  brew untap nikitabobko/tap
fi
