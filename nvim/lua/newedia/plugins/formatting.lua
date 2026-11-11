local web = { "oxfmt", "prettierd", "prettier", stop_after_first = true }

require("conform").setup({
	formatters_by_ft = {
		javascript = web,
		typescript = web,
		javascriptreact = web,
		typescriptreact = web,
		json = web,
		css = web,
		scss = web,
		less = web,
		html = web,
		markdown = web,
		mdx = web,
		yaml = web,
		lua = { "stylua" },
		sh = { "shfmt" },
		fish = { "fish_indent" },
	},
	formatters = {
		-- Only in projects with an oxfmt config, so prettier projects keep prettier.
		oxfmt = { require_cwd = true },
	},
	format_on_save = function(buf)
		if vim.b[buf].disable_autoformat then
			return
		end
		return { timeout_ms = 1000, lsp_format = "fallback" }
	end,
})
