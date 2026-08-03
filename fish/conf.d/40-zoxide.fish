status is-interactive
or return

if not command -q zoxide
    return
end

# `zoxide init` output is cached like pyenv's and regenerated when the zoxide
# binary is newer than the cache. A Homebrew bottle can install with an mtime
# older than the cache it supersedes, in which case the stale cache is kept —
# benign, since the init code rarely changes.
# Escape hatch: rm ~/.cache/fish/zoxide-init.fish; reload
set -l cache $__fish_cache_dir/zoxide-init.fish

if test (command -s zoxide) -nt $cache
    set -l init (zoxide init fish --cmd cd 2>/dev/null)
    # A generator that dies midway still prints something, so nonempty output
    # is not enough on its own — the exit status decides whether to trust it.
    set -l generated $status

    # Temp file plus rename: a failed generation leaves the old cache intact.
    if test $generated -eq 0 -a -n "$init"
        mkdir -p $__fish_cache_dir
        and printf '%s\n' $init >$cache.$fish_pid
        and mv -f $cache.$fish_pid $cache
        or rm -f $cache.$fish_pid
    end
end

test -s $cache; and source $cache
