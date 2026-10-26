echo "Retire fnm, pyenv, and Homebrew's Bun and pnpm, which mise now replaces"

# A machine without Homebrew, or without these formulae, has nothing to retire.
command -v brew >/dev/null || exit 0
formulae="$(brew list --formula -1)"
retired="$(grep -xE 'fnm|pyenv|pyenv-virtualenv|bun|pnpm' <<<"$formulae" || true)"
[[ -n $retired ]] || exit 0

# Uninstalling the old managers before mise can run every replacement would
# leave scripts with no Node or Python at all. Ask for each command, because
# `mise ls --missing` leaves out a "latest" tool it cannot resolve offline.
if ! command -v mise >/dev/null; then
	echo "mise is not installed; run brew install mise, then bin/migrate" >&2
	exit 1
fi
for command in node python3 bun pnpm; do
	if ! mise which "$command" >/dev/null 2>&1; then
		echo "mise has not installed $command yet; run mise install, then bin/migrate" >&2
		exit 1
	fi
done

# shellcheck disable=SC2086 # formula names, one word each
brew uninstall $retired

# Written by the retired pyenv Fish module.
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/pyenv.fish" \
	"${XDG_CACHE_HOME:-$HOME/.cache}"/fish/pyenv-init-*.fish

echo "Kept ~/.pyenv and ~/.local/share/fnm: delete them once no virtualenv points into ~/.pyenv/versions."
echo "Open a new shell to pick up mise's runtimes."
