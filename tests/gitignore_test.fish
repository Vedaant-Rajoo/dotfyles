#!/usr/bin/env fish
# Credentials and runtime state never ride into a commit, and hand-written
# configuration is never silently ignored. Run: fish tests/gitignore_test.fish
#
# Checks .gitignore together with git/ignore, the global excludes file this
# repository installs, regardless of what the running machine has configured.

set -g repo_root (path resolve (dirname (status filename))/..)
source $repo_root/tests/lib/harness.fish

function ignored --argument-names path
    git -C $repo_root -c core.excludesFile=$repo_root/git/ignore check-ignore -q --no-index -- $path
    and echo ignored
    or echo tracked
end

for path in \
        fish/local/secrets.fish \
        fish/fish_variables \
        fish/conf.d/plugin-installed-by-fisher.fish \
        claude/.credentials.json \
        claude/history.jsonl \
        claude/projects/project/session.jsonl \
        claude/a-file-a-future-version-invents.json \
        opencode/opencode.json \
        github-copilot/apps.json \
        monid/state.json \
        herdr/session.json \
        herdr/herdr.sock.agent \
        herdr/session-snapshots/session-1-1-0.json \
        legcord/Cookies \
        .local/docs/research.md
    assert_equal ignored (ignored $path) "$path stays out of commits"
end

for path in \
        claude/settings.json \
        fish/conf.d/10-env.fish \
        fish/conf.d/50-mise.fish \
        fish/functions/reload.fish \
        herdr/config.toml \
        legcord/storage/settings.json \
        mise/mise.toml \
        agents/skill-lock.json
    assert_equal tracked (ignored $path) "$path can be committed"
end

harness_exit
