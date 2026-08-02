set -q PYENV_ROOT
or set -gx PYENV_ROOT $HOME/.pyenv

if not command -q pyenv
    return
end

fish_add_path -gP $PYENV_ROOT/bin

# `pyenv init` shells out on every startup, so its output is cached and only
# regenerated when the pyenv binary is newer than the cache (a missing cache
# counts as stale). The init bakes in this root's shim path, so the filename is
# keyed by PYENV_ROOT — a shell with a different root must never source another
# root's cache. `string escape` is a builtin, so keying costs no process.
# Escape hatch: rm ~/.cache/fish/pyenv-init-*.fish; reload
set -l cache $__fish_cache_dir/pyenv-init-(string escape --style=var -- $PYENV_ROOT).fish

if test (command -s pyenv) -nt $cache
    set -l init (pyenv init - --no-rehash fish 2>/dev/null)
    # A generator that dies midway still prints something, so nonempty output
    # is not enough on its own — the exit status decides whether to trust it.
    set -l generated $status

    if test $generated -eq 0 -a -n "$init"
        # pyenv's init eagerly sources its completions. Install them as a real
        # completion file so Fish loads them on demand, then drop the eager line.
        set -l completions (string match -r "^source '(.*)'" -- $init)[2]
        set -l installed $__fish_config_dir/completions/pyenv.fish

        if test -n "$completions"
            # Copy then rename, so a half-written completion file is never
            # visible and the eager line is only dropped once it is installed.
            if cp $completions $installed.$fish_pid 2>/dev/null
                and mv -f $installed.$fish_pid $installed 2>/dev/null
                set init (string match -v -- "source '*'" $init)
            else
                rm -f $installed.$fish_pid
            end
        end

        # Write to a pid-suffixed temp file and rename, so a failed generation
        # never clobbers a good cache and no shell reads a half-written one.
        mkdir -p $__fish_cache_dir
        and printf '%s\n' $init >$cache.$fish_pid
        and mv -f $cache.$fish_pid $cache
        or rm -f $cache.$fish_pid
    end
end

test -s $cache; and source $cache
