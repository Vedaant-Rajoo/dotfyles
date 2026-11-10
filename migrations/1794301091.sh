echo "Remove the plugins, language servers, and caches the retired lazy.nvim config installed"

data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
state="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/nvim"

# lazy.nvim, Mason, nvim-treesitter, and blink.cmp generated these; a new
# config reinstalls whatever it still uses.
rm -rf "$data/lazy" "$data/mason" "$data/site/parser" "$data/site/queries" \
  "$state/lazy" "$state/blink" "$cache"

# Marks, editing history, and undo history are the user's; keep them.
for kept in "$data/harpoon" "$state/shada" "$HOME/.vim/undodir"; do
  if [ -e "$kept" ]; then
    echo "Kept $kept; delete it by hand if the old config's history is not wanted"
  fi
done
