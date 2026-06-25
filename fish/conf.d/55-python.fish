set -q PYENV_ROOT
or set -gx PYENV_ROOT $HOME/.pyenv

if not command -q pyenv
    return
end

fish_add_path -gP $PYENV_ROOT/bin

set -l pyenv_init (pyenv init - fish 2>/dev/null | string collect)

if test -n "$pyenv_init"
    echo $pyenv_init | source
end

status is-interactive
or return

set -l pyenv_virtualenv_init (pyenv virtualenv-init - 2>/dev/null | string collect)

if test -n "$pyenv_virtualenv_init"
    echo $pyenv_virtualenv_init | source
end
