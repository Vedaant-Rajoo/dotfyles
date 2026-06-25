return {
	"neovim/nvim-lspconfig",
	dependencies = {
		"mason-org/mason.nvim",
		"mason-org/mason-lspconfig.nvim",
		"j-hui/fidget.nvim",
		{
			"folke/lazydev.nvim",
			ft = "lua",
			opts = {
				library = {
					{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
					"lazy.nvim",
				},
			},
		},
		"saghen/blink.cmp",
	},
	config = function()
		vim.g.zig_fmt_autosave = 0

		require("fidget").setup({})
		require("mason").setup()

		vim.lsp.config("*", {
			capabilities = require("blink.cmp").get_lsp_capabilities(),
		})

		vim.lsp.config("lua_ls", {
			settings = {
				Lua = {
					runtime = { version = "LuaJIT" },
					format = {
						enable = true,
						defaultConfig = {
							indent_style = "space",
							indent_size = "2",
						},
					},
				},
			},
		})

		vim.lsp.config("zls", {
			root_markers = { "build.zig", "zls.json", ".git" },
			settings = {
				zls = {
					enable_inlay_hints = true,
					enable_snippets = true,
					warn_style = true,
				},
			},
		})

		vim.lsp.config("tailwindcss", {
			filetypes = {
				"html",
				"css",
				"scss",
				"javascript",
				"javascriptreact",
				"typescript",
				"typescriptreact",
				"svelte",
				"vue",
			},
		})

		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls",
				"gopls",
				"rust_analyzer",
				"zls",
				"vtsls",
				"tailwindcss",
				"bashls",
				"basedpyright",
				"ruff",
			},
			automatic_enable = {
				exclude = { "stylua" },
			},
		})

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("NewediaLspAttach", { clear = true }),
			callback = function(event)
				local client = vim.lsp.get_client_by_id(event.data.client_id)
				if not client then
					return
				end

				local bufnr = event.buf
				local opts = { buffer = bufnr, remap = false }
				local builtin = require("telescope.builtin")

				vim.keymap.set("n", "gd", builtin.lsp_definitions, opts)
				vim.keymap.set("n", "gr", builtin.lsp_references, opts)
				vim.keymap.set("n", "gi", builtin.lsp_implementations, opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
				vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
				vim.keymap.set("n", "[d", function()
					vim.diagnostic.jump({ count = -1, float = true })
				end, opts)
				vim.keymap.set("n", "]d", function()
					vim.diagnostic.jump({ count = 1, float = true })
				end, opts)
			end,
		})

		vim.diagnostic.config({
			virtual_text = true,
			severity_sort = true,
			float = {
				focusable = false,
				style = "minimal",
				border = "rounded",
				source = "always",
				header = "",
				prefix = "",
			},
		})
	end,
}
