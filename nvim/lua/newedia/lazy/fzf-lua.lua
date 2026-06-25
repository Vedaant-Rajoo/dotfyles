return {
	"ibhagwan/fzf-lua",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	keys = {
		{
			"<leader>ff",
			function()
				require("fzf-lua").files()
			end,
			desc = "Find files",
		},
		{
			"<leader>fg",
			function()
				require("fzf-lua").live_grep()
			end,
			desc = "Live grep",
		},
		{
			"<leader>fb",
			function()
				require("fzf-lua").buffers()
			end,
			desc = "Find buffers",
		},
		{
			"<leader>fr",
			function()
				require("fzf-lua").oldfiles()
			end,
			desc = "Recent files",
		},
		{
			"<leader>fc",
			function()
				require("fzf-lua").files({ cwd = vim.fn.stdpath("config") })
			end,
			desc = "Find config files",
		},
	},
	opts = {
		winopts = {
			height = 0.85,
			width = 0.85,
			row = 0.5,
			col = 0.5,
			border = "rounded",
			preview = {
				layout = "vertical",
				vertical = "down:45%",
			},
		},
	},
}
