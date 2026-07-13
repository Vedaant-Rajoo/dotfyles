set -q XDG_DATA_HOME
or set -gx XDG_DATA_HOME $HOME/.local/share

set -q XDG_STATE_HOME
or set -gx XDG_STATE_HOME $HOME/.local/state

# Keep npm global installs on a stable user-owned path.
set -gx npm_config_prefix $HOME/.node_modules

set -gx FNM_DIR $XDG_DATA_HOME/fnm

# fnm lives outside PATH until we add it (matches ~/.bashrc).
if test -x $FNM_DIR/fnm
	fish_add_path -gP $FNM_DIR
else if not command -q fnm
	return
end

set -l fnm_multishell_dir $XDG_STATE_HOME/fnm_multishells

command mkdir -p $fnm_multishell_dir 2>/dev/null
or return

set -l fnm_env (fnm env --use-on-cd --shell fish 2>/dev/null | string collect)

if test -n "$fnm_env"
	echo $fnm_env | source
end
