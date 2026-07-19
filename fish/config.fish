# Keep the entrypoint intentionally small.
set -g fish_greeting

if not status is-interactive
    return
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Claude Code → CLIProxyAPI.
# Secrets (BASE_URL / AUTH_TOKEN) live in local/ — not versioned.
set -l secrets $__fish_config_dir/local/claude-code.fish
if test -f $secrets
    source $secrets
end
