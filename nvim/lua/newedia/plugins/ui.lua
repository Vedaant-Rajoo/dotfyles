require("catppuccin").setup({
	flavour = "mocha",
	transparent_background = true,
})
vim.cmd.colorscheme("catppuccin")

require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

require("tiny-cmdline").setup({
	position = { x = "50%", y = "20%" },
})
