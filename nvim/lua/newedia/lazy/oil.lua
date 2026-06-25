return {
	"stevearc/oil.nvim",
	lazy = false,
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"nvim-telescope/telescope.nvim",
	},
	keys = {
		{ "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
		{ "<leader>e", "<cmd>Oil<cr>", desc = "Open file explorer" },
		{ "<leader>E", "<cmd>Oil --float<cr>", desc = "Open floating file explorer" },
	},
	opts = {
		default_file_explorer = true,

		columns = {
			"icon",
		},

		delete_to_trash = true,
		skip_confirm_for_simple_edits = true,
		watch_for_changes = true,

		win_options = {
			wrap = false,
			signcolumn = "no",
			cursorcolumn = false,
			foldcolumn = "0",
			spell = false,
			list = false,
			conceallevel = 3,
			concealcursor = "nvic",
		},

		view_options = {
			show_hidden = true,
			natural_order = "fast",
			case_insensitive = true,
			sort = {
				{ "type", "asc" },
				{ "name", "asc" },
			},
			is_always_hidden = function(name)
				return name == ".git" or name == "node_modules" or name == ".DS_Store"
			end,
		},

		keymaps = {
			["g?"] = "actions.show_help",
			["<CR>"] = "actions.select",
			["<C-s>"] = { "actions.select", opts = { vertical = true } },
			["<C-h>"] = { "actions.select", opts = { horizontal = true } },
			["<C-t>"] = { "actions.select", opts = { tab = true } },
			["<C-p>"] = "actions.preview",
			["<C-c>"] = "actions.close",
			["<C-l>"] = "actions.refresh",
			["-"] = "actions.parent",
			["_"] = "actions.open_cwd",
			["`"] = "actions.cd",
			["~"] = "actions.tcd",
			["g."] = "actions.toggle_hidden",
			["<leader>pf"] = {
				desc = "Find files in oil directory",
				callback = function()
					require("newedia.oil_telescope").find_files()
				end,
			},
			["<leader>ps"] = {
				desc = "Grep in oil directory",
				callback = function()
					require("newedia.oil_telescope").live_grep()
				end,
			},
		},
	},
}
