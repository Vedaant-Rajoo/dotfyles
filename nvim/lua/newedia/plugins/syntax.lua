require("nvim-treesitter").install({
	"astro",
	"bash",
	"c",
	"cmake",
	"cpp",
	"css",
	"diff",
	"fish",
	"gitignore",
	"go",
	"graphql",
	"html",
	"http",
	"java",
	"javascript",
	"jsdoc",
	"json",
	"lua",
	"luadoc",
	"luap",
	"markdown",
	"markdown_inline",
	"printf",
	"python",
	"query",
	"regex",
	"rust",
	"scss",
	"sql",
	"svelte",
	"toml",
	"tsx",
	"typescript",
	"vim",
	"vimdoc",
	"xml",
	"yaml",
})

local group = vim.api.nvim_create_augroup("newedia_treesitter", { clear = true })

-- Highlight and indent with Treesitter wherever a parser exists.
vim.api.nvim_create_autocmd("FileType", {
	group = group,
	callback = function(ev)
		if pcall(vim.treesitter.start, ev.buf) then
			vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

-- Parsers must match the plugin version, so rebuild them after it updates.
vim.api.nvim_create_autocmd("PackChanged", {
	group = group,
	callback = function(ev)
		if ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
			if not ev.data.active then
				vim.cmd.packadd("nvim-treesitter")
			end
			vim.cmd("TSUpdate")
		end
	end,
})

require("todo-comments").setup()

require("nvim-highlight-colors").setup({
	render = "background",
	enable_tailwind = false,
})
-- nvim-highlight-colors paints colors; the LSP's document colors would double them.
vim.lsp.document_color.enable(false)
