# Claude Code → CLIProxyAPI.
# Secrets (BASE_URL / AUTH_TOKEN) live in local/ — not versioned.
set -l secrets $__fish_config_dir/local/claude-code.fish
if test -f $secrets
	source $secrets
end
