return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "modern",
		spec = {
			-- Groups (prefixes)
			{ "<leader>9", group = "99 (AI)" },
			{ "<leader>9v", group = "99 visual", mode = "v" },
			{ "<leader>9m", desc = "99 select model" },
			{ "<leader>9P", desc = "99 select provider" },
			{ "<leader>f", group = "find (fzf)" },
			{ "<leader>z", group = "zen mode" },
			{ "<leader>g", group = "git" },
			{ "<leader>t", group = "trouble" },
			{ "<leader>c", group = "code (lsp)" },
			{ "<leader>r", group = "rename (lsp)" },

			-- Oil (oil.lua)
			{ "<leader>e", desc = "File explorer" },
			{ "<leader>E", desc = "Floating file explorer" },
			{ "-", desc = "Open parent directory" },

			-- fzf-lua (fzf-lua.lua)
			{ "<leader>ff", desc = "Find files" },
			{ "<leader>fg", desc = "Live grep" },
			{ "<leader>fb", desc = "Find buffers" },
			{ "<leader>fr", desc = "Recent files" },
			{ "<leader>fc", desc = "Find config files" },

			-- Telescope (telescope.lua, kept for 99 and help)
			{ "<leader>vh", desc = "Help tags" },

			-- Harpoon (harpoon.lua)
			{ "<leader>a", desc = "Harpoon add file" },
			{ "<leader>A", desc = "Harpoon prepend file" },

			-- LSP (lsp.lua, buffer-local on attach)
			{ "<leader>rn", desc = "Rename symbol" },
			{ "<leader>ca", desc = "Code action" },

			-- Format / diagnostics / git / undo / zen
			{ "<leader>fm", desc = "Format buffer" },
			{ "<leader>tt", desc = "Toggle Trouble" },
			{ "<leader>gs", desc = "Git status" },
			{ "<leader>u", desc = "Toggle Undotree" },
			{ "<leader>zz", desc = "Zen mode" },
			{ "<leader>zZ", desc = "Zen mode (full)" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer local keymaps (which-key)",
		},
	},
}
