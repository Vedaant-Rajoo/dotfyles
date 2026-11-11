-- Mason owns every language server and formatter (see the ownership table in
-- README.md).
require("mason").setup()
require("mason-tool-installer").setup({
	ensure_installed = {
		"lua-language-server",
		"vtsls",
		"eslint-lsp",
		"oxlint",
		"tailwindcss-language-server",
		"css-lsp",
		"rust-analyzer",
		"prettier",
		"prettierd",
		"oxfmt",
		"stylua",
		"shfmt",
	},
	run_on_start = true,
	auto_update = false,
})

-- blink.cmp's completion capabilities, plus file renames (e.g. from oil) so
-- servers update imports. Per-server settings live in after/lsp/<name>.lua.
vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities({
		workspace = {
			fileOperations = { didRename = true, willRename = true },
		},
	}),
})

vim.lsp.enable({ "eslint", "oxlint", "lua_ls", "cssls", "vtsls", "tailwindcss", "rust_analyzer" })
vim.lsp.inlay_hint.enable()
