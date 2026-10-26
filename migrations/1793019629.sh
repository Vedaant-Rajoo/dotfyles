echo "Uninstall LinearMouse, which Vorssaint replaces and the Brewfile no longer installs"

# A machine without Homebrew, or without LinearMouse, has nothing to retire.
command -v brew >/dev/null || exit 0
casks="$(brew list --cask -1)"
grep -qx linearmouse <<<"$casks" || exit 0

brew uninstall --cask linearmouse
