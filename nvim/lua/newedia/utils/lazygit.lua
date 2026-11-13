-- Lazygit in a snacks float. Its `e` command (lazygit/config.yml) quits lazygit
-- and calls focus_origin() through $NVIM before opening the file.
local M = {}

function M.open()
	M.origin_win = vim.api.nvim_get_current_win()
	Snacks.lazygit()
end

function M.focus_origin()
	if M.origin_win and vim.api.nvim_win_is_valid(M.origin_win) then
		vim.api.nvim_set_current_win(M.origin_win)
	end
end

return M
