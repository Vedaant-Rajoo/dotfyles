#!/bin/sh
# apiKeyHelper — print the credential Claude Code sends upstream.
#
# Claude Code runs this through /bin/sh and uses stdout as both the X-Api-Key
# header and the Authorization bearer token. Keeping the credential behind a
# command instead of a literal is what lets claude/settings.json be tracked:
# this file is versioned, the token it reads never is.
#
# Reads, in order of preference:
#   $CLAUDE_AUTH_TOKEN_FILE      explicit override
#   ~/.config/claude/auth-token  the gitignored default, seeded by claude_link
set -eu

token_file="${CLAUDE_AUTH_TOKEN_FILE:-$HOME/.config/claude/auth-token}"

if [ ! -r "$token_file" ]; then
	echo "api-key-helper: no readable token at $token_file" >&2
	echo "api-key-helper: write your CLIProxyAPI token there, then retry" >&2
	exit 1
fi

# First line only, stripped: stdout becomes a header value verbatim, so a stray
# newline or trailing space would travel with it.
head -n 1 "$token_file" | tr -d ' \t\r\n'
