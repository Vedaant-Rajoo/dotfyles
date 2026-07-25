-- nvim-treesitter `main` branch. The old `master` branch does not support
-- Nvim 0.12: it registers query directives with the removed `all = false`
-- option, so `match[id]` arrives as a TSNode[] where the handler expects a
-- single node, and markdown code fences crash the highlighter.
--
-- `main` is a from-scratch rewrite: no `configs.setup`, no `ensure_installed`,
-- and features are opt-in per buffer rather than enabled by the plugin.
-- Requires the `tree-sitter` CLI (0.26.1+) to build parsers.

local parsers = {
	"bash",
	"css",
	"gitignore",
	"go",
	"html",
	"javascript",
	"json",
	"lua",
	"python",
	"query",
	"rust",
	"tsx",
	"typescript",
	"vim",
	"vimdoc",
	"zig",
}

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false, -- main does not support lazy-loading
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter").setup()

			-- Install anything missing. Async, so it does not block startup.
			local installed = require("nvim-treesitter.config").get_installed("parsers")
			local have = {}
			for _, lang in ipairs(installed) do
				have[lang] = true
			end

			local missing = {}
			for _, lang in ipairs(parsers) do
				if not have[lang] then
					missing[#missing + 1] = lang
				end
			end

			if #missing > 0 then
				require("nvim-treesitter").install(missing)
			end

			-- `main` enables nothing on its own, so turn on highlighting,
			-- folds, and indentation per buffer.
			local group = vim.api.nvim_create_augroup("NewediaTreesitter", { clear = true })
			vim.api.nvim_create_autocmd("FileType", {
				group = group,
				callback = function(args)
					if vim.bo[args.buf].buftype ~= "" then
						return
					end

					local lang = vim.treesitter.language.get_lang(args.match)
					if not lang or not vim.tbl_contains(parsers, lang) then
						return
					end

					-- Still installing, or built against a different ABI.
					if not pcall(vim.treesitter.start, args.buf, lang) then
						return
					end

					vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
					vim.wo.foldmethod = "expr"
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		config = function()
			require("nvim-treesitter-textobjects").setup({
				select = {
					lookahead = true,
				},
			})

			local select = require("nvim-treesitter-textobjects.select")
			vim.keymap.set({ "x", "o" }, "af", function()
				select.select_textobject("@function.outer", "textobjects")
			end, { desc = "a function" })
			vim.keymap.set({ "x", "o" }, "if", function()
				select.select_textobject("@function.inner", "textobjects")
			end, { desc = "inner function" })
		end,
	},
}
