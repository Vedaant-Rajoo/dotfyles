# Keep the entrypoint intentionally small.
set -g fish_greeting

# Claude Code → CLIProxyAPI.
# Secrets (BASE_URL / AUTH_TOKEN) live in local/ — not versioned.
# Loaded for all sessions (interactive or not) so scripts and non-TTY
# launches inherit the proxy vars; Claude itself also reads the same
# values from ~/.claude/settings.local.json.
set -l secrets $__fish_config_dir/local/claude-code.fish
if test -f $secrets
    source $secrets
end

if not status is-interactive
    return
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
