return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("conform").setup({
			format_on_save = {
				timeout_ms = 5000,
				lsp_format = "fallback",
			},
			-- prettier comes from each project's node_modules, so a file outside a
			-- project often has no formatter. This silences the notice for every
			-- filetype, so a missing stylua or shfmt goes unreported too.
			notify_no_formatters = false,
			formatters_by_ft = {
				lua = { "stylua" },
				go = { "goimports", "gofmt", stop_after_first = true },
				python = { "ruff_format", "black", stop_after_first = true },
				rust = { "rustfmt" },
				sh = { "shfmt" },
				bash = { "shfmt" },
				javascript = { "prettier" },
				typescript = { "prettier" },
				typescriptreact = { "prettier" },
				javascriptreact = { "prettier" },
				html = { "prettier" },
				css = { "prettier" },
				json = { "prettier" },
			},
		})

		vim.keymap.set("n", "<leader>fm", function()
			require("conform").format({ bufnr = 0 })
		end, { desc = "Format buffer" })
	end,
}
