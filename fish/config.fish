# Keep the entrypoint intentionally small.
set -g fish_greeting

if not status is-interactive
    return
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :


# Added by Antigravity CLI installer
set -gx PATH "/Users/newedia/.local/bin" $PATH
