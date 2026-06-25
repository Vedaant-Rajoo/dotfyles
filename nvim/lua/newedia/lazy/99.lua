return {
	"ThePrimeagen/99",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
		"saghen/blink.cmp",
		-- Bridges 99's nvim-cmp-style completion source into blink.cmp.
		-- v2.* pairs with blink.cmp v1.*; opts = {} ensures setup() runs.
		{ "saghen/blink.compat", version = "2.*", lazy = true, opts = {} },
	},
	config = function()
		local _99 = require("99")

		_99.setup({
			-- Cursor Agent provider. See `cursor-agent models` for the full list.
			-- glm-5.2-high = "GLM 5.2"; glm-5.2-max = "GLM 5.2 Max".
			provider = _99.Providers.CursorAgentProvider,
			model = "composer-2.5",

			show_in_flight_requests = true,

			md_files = {
				"AGENTS.md",
			},

			completion = {
				source = "blink",
				-- custom_rules = {
				-- 	"~/.config/nvim/rules/",
				-- },
			},
		})

		vim.keymap.set("n", "<leader>9s", function()
			_99.search()
		end, { desc = "99 search" })
		vim.keymap.set("v", "<leader>9vv", function()
			_99.visual()
		end, { desc = "99 visual" })
		vim.keymap.set("v", "<leader>9vp", function()
			_99.visual_prompt()
		end, { desc = "99 visual prompt" })
		vim.keymap.set("n", "<leader>9x", function()
			_99.stop_all_requests()
		end, { desc = "99 stop all requests" })
		vim.keymap.set("n", "<leader>9i", function()
			_99.info()
		end, { desc = "99 info" })
		vim.keymap.set("n", "<leader>9l", function()
			_99.view_logs()
		end, { desc = "99 view logs" })
		vim.keymap.set("n", "<leader>9n", function()
			_99.next_request_logs()
		end, { desc = "99 next request logs" })
		vim.keymap.set("n", "<leader>9p", function()
			_99.prev_request_logs()
		end, { desc = "99 prev request logs" })

		-- Telescope pickers (telescope.nvim is installed).
		-- Selection applies to subsequent requests in the current session.
		vim.keymap.set("n", "<leader>9m", function()
			require("99.extensions.telescope").select_model()
		end, { desc = "99 select model" })
		-- Note: reference uses <leader>9p for this, but that's taken by prev logs,
		-- so the provider picker lives on <leader>9P (capital).
		vim.keymap.set("n", "<leader>9P", function()
			require("99.extensions.telescope").select_provider()
		end, { desc = "99 select provider" })
	end,
}
