# ui.sh — status-line output shared by the agent pipeline scripts.
# Sourced, never executed; defines USE_GUM and say() only.
#
# Pretty output through gum only when interactive; pipes, logs, and tests get
# the plain deterministic format.
USE_GUM=0
if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
	USE_GUM=1
fi

say() {
	local status="$1"
	shift
	if [[ "$USE_GUM" -eq 0 ]]; then
		printf '%-8s%s\n' "$status" "$*"
		return
	fi
	local color=7
	case "$status" in
	OK | ok: | linked: | wrote: | seeded: | moved: | done:) color=2 ;;
	STALE | relink: | backup: | pruned: | kept: | next:) color=3 ;;
	BROKEN | MISSING | error:) color=1 ;;
	SKIP | INFO) color=4 ;;
	esac
	printf '%s%s\n' "$(CLICOLOR_FORCE=1 gum style --bold --foreground "$color" "$(printf '%-8s' "$status")")" "$*"
}
