local group = vim.api.nvim_create_augroup("newedia", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
	group = group,
	callback = function()
		vim.hl.on_yank()
	end,
})

vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
	group = group,
	callback = function()
		vim.wo.cursorline = true
	end,
})

vim.api.nvim_create_autocmd("WinLeave", {
	group = group,
	callback = function()
		vim.wo.cursorline = false
	end,
})
