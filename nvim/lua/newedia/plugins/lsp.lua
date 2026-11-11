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

-- File renames (e.g. from oil) let servers update imports. Per-server
-- settings live in after/lsp/<name>.lua.
vim.lsp.config("*", {
	capabilities = {
		workspace = {
			fileOperations = { didRename = true, willRename = true },
		},
	},
})

vim.lsp.enable({ "eslint", "oxlint", "lua_ls", "cssls", "vtsls", "tailwindcss", "rust_analyzer" })
