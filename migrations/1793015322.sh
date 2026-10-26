echo "Uninstall Bartender, DockDoor, Hyperkey, and Macs Fan Control, which the Brewfile no longer installs"

# A machine without Homebrew, or without these casks, has nothing to retire.
command -v brew >/dev/null || exit 0
casks="$(brew list --cask -1)"
retired="$(grep -xE 'bartender|dockdoor|hyperkey|macs-fan-control' <<<"$casks" || true)"
[[ -n $retired ]] || exit 0

# shellcheck disable=SC2086 # cask tokens, one word each
brew uninstall --cask $retired
