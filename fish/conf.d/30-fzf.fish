status is-interactive
or return

if functions --query fzf_configure_bindings
    fzf_configure_bindings \
        --directory=ctrl-f \
        --git_status=ctrl-g \
        --history=ctrl-r \
        --variables=ctrl-v
end
