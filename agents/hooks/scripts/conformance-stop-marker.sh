#!/usr/bin/env bash
set -euo pipefail

# Normal sessions are a no-op. The live conformance runner opts in with a
# machine-local marker path so hook wiring can be tested without notifications.
if [[ -n "${AGENTS_CONFORM_MARKER:-}" ]]; then
	printf 'stop\n' >>"$AGENTS_CONFORM_MARKER"
fi
