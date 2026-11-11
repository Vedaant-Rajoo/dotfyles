require("gitsigns").setup()

-- craftzdog's fork groups changes into whole hunks, the way `git diff` does.
require("mini.diff").setup()

require("codediff").setup({
	-- TODO: set compact = true again once a Neovim release includes commit
	-- dcbb99a92 ("fix(treesitter): foldminlines error after buffer is wiped in
	-- autocmd"). Neovim 0.12.6 errors with "Invalid buffer id" when codediff's
	-- compact mode sets foldminlines, so it starts off for now; `gc` toggles it.
	diff = { compact = false, compact_context_lines = 8, compact_sync_folds = true },
	explorer = {
		view_mode = "tree",
		width = 50,
		auto_open_on_cursor = true,
		line_stats = { enabled = true },
	},
})
