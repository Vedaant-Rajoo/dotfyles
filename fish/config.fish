# Keep the entrypoint intentionally small.
set -g fish_greeting

# Machine-local shell secrets, not versioned. Loaded for all sessions
# (interactive or not) so scripts and non-TTY launches inherit them.
#
# Claude Code no longer belongs here and this file is normally absent: its
# credential comes from apiKeyHelper reading claude/auth-token, and the base URL
# and model ids are tracked in claude/settings.json. Do not re-export
# ANTHROPIC_AUTH_TOKEN — Claude refuses to choose between it and apiKeyHelper
# and warns that auth may not work.
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
