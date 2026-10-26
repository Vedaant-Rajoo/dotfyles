echo "Retire Homebrew's prettier and prettierd, and the Node only they needed; projects carry prettier now"

command -v brew >/dev/null || exit 0
formulae="$(brew list --formula -1)"
retired="$(grep -xE 'prettier|prettierd' <<<"$formulae" || true)"
[[ -n $retired ]] || exit 0

# Uninstalling them also autoremoves Homebrew's Node unless another formula
# still needs it, so mise's Node has to be in place first.
if ! mise which node >/dev/null 2>&1; then
	echo "mise has not installed Node yet; run mise install, then bin/migrate" >&2
	exit 1
fi
# shellcheck disable=SC2086 # formula names, one word each
brew uninstall $retired
