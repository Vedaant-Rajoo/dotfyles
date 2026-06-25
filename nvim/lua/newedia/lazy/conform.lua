return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("conform").setup({
			format_on_save = {
				timeout_ms = 5000,
				lsp_format = "fallback",
			},
			formatters_by_ft = {
				lua = { "stylua" },
				go = { "goimports", "gofmt", stop_after_first = true },
				python = { "ruff_format", "black", stop_after_first = true },
				rust = { "rustfmt" },
				zig = { "zigfmt" },
				sh = { "shfmt" },
				bash = { "shfmt" },
				javascript = { "prettierd", "prettier", stop_after_first = true },
				typescript = { "prettierd", "prettier", stop_after_first = true },
				typescriptreact = { "prettierd", "prettier", stop_after_first = true },
				javascriptreact = { "prettierd", "prettier", stop_after_first = true },
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
