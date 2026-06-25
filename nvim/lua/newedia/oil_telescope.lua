local M

M = {}

-- Resolve the directory oil is currently showing. Falls back to the current
-- file's directory (or cwd) when called outside an oil buffer.
local function oil_dir()
	local ok, oil = pcall(require, "oil")
	if ok then
		local dir = oil.get_current_dir()
		if dir and dir ~= "" then
			return dir
		end
	end
	local bufdir = vim.fn.expand("%:p:h")
	if bufdir ~= "" then
		return bufdir
	end
	return vim.fn.getcwd()
end

function M.find_files()
	require("telescope.builtin").find_files({
		cwd = oil_dir(),
		hidden = true,
	})
end

function M.live_grep()
	require("telescope.builtin").live_grep({
		cwd = oil_dir(),
	})
end

return M
