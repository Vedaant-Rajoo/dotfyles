echo "Uninstall Amphetamine and TrashMe 3, which the Brewfile no longer installs"

# A machine without mas, or without these apps, has nothing to retire.
command -v mas >/dev/null || exit 0
installed="$(mas list | awk '{print $1}')"
retired="$(grep -xE '937984704|1490879410' <<<"$installed" || true)"
[[ -n $retired ]] || exit 0

# mas needs root to remove App Store apps.
# shellcheck disable=SC2086 # App Store ids, one word each
sudo mas uninstall $retired
