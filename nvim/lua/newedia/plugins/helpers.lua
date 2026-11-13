-- The helix preset is a 30–60 column popup in the bottom-right corner with a
-- rounded border; the default delay and mini.icons icons are kept.
require("which-key").setup({
	preset = "helix",
	-- which-key never auto-triggers on a single letter other than g and z.
	triggers = {
		{ "<auto>", mode = "nxso" },
		{ "s", mode = "n" },
	},
	spec = {
		{ "<leader>b", group = "buffers" },
		{ "<leader>c", group = "code" },
		{ "<leader>d", group = "diff" },
		{ "<leader>g", group = "git" },
		{ ";", group = "picker" },
		{ "s", group = "splits" },
	},
})

-- Suggests one better command for an inefficient pattern once idle. It has no
-- releases, so vim.pack tracks main.
require("tobira").setup()

-- vim-wakatime runs its own setup() when it loads; calling it again re-applies
-- options. It reuses ~/.wakatime.cfg and ~/.wakatime/wakatime-cli. The status
-- bar would add today's time to lualine's x section.
require("wakatime").setup({ status_bar_enabled = false })
