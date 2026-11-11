require("catppuccin").setup({
	flavour = "mocha",
	transparent_background = true,
})
vim.cmd.colorscheme("catppuccin")

require("tiny-cmdline").setup({
	position = { x = "50%", y = "20%" },
})
