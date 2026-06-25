return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "master",
		build = ":TSUpdate",
		lazy = false,
		dependencies = {
			{
				"nvim-treesitter/nvim-treesitter-textobjects",
				branch = "master",
			},
		},
		init = function()
			local parsers = {
				"lua",
				"vim",
				"vimdoc",
				"query",
				"javascript",
				"typescript",
				"tsx",
				"html",
				"css",
				"json",
				"gitignore",
				"go",
				"python",
				"rust",
				"zig",
				"bash"
			}

			local group = vim.api.nvim_create_augroup("NewediaTreesitter", { clear = true })
			vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
				group = group,
				callback = function()
					if vim.bo.buftype ~= "" then
						return
					end

					pcall(vim.treesitter.start, 0)
				end,
			})

			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "VeryLazy",
				once = true,
				callback = function()
					require("nvim-treesitter.configs").setup({
						ensure_installed = parsers,
						sync_install = false,
						textobjects = {
							select = {
								enable = true,
								lookahead = true,
								keymaps = {
									["af"] = "@function.outer",
									["if"] = "@function.inner",
								},
							},
						},
					})
				end,
			})
		end,
	},
}
