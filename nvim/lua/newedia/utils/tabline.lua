-- Custom tabline: each tab is a trapezoid (wider at the bottom) holding the
-- active window's file name and icon. Shown from 2 tabs on (showtabline=1).
local M = {}

local hl_ready = false

local function set_hl()
	local c = require("catppuccin.palettes").get_palette("mocha")
	local set = vim.api.nvim_set_hl
	set(0, "NewediaTabActive", { fg = c.base, bg = c.yellow, bold = true })
	set(0, "NewediaTabActiveSep", { fg = c.yellow })
	set(0, "NewediaTabInactive", { fg = c.subtext0, bg = c.surface0 })
	set(0, "NewediaTabInactiveSep", { fg = c.surface0 })
	set(0, "TabLineFill", {})
	hl_ready = true
end

-- A colorscheme change clears custom groups; redefine them on the next render.
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("newedia_tabline", { clear = true }),
	callback = function()
		hl_ready = false
	end,
})

local function label(tab)
	local buf = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tab))
	local modified = vim.bo[buf].modified and "[+] " or ""
	if vim.bo[buf].buftype == "terminal" then
		return modified .. "[Terminal]"
	end
	local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
	if name == "" then
		return modified .. "[No Name]"
	end
	local icon = require("mini.icons").get("file", name)
	if vim.fn.strchars(name) > 20 then
		name = vim.fn.strcharpart(name, 0, 17) .. "..."
	end
	return modified .. icon .. " " .. name
end

function M.render()
	if not hl_ready then
		set_hl()
	end
	local current = vim.api.nvim_get_current_tabpage()
	local parts = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local hl = tab == current and "NewediaTabActive" or "NewediaTabInactive"
		-- Lower-right and lower-left triangles slant both edges outward going down.
		parts[#parts + 1] = ("%%#%sSep#\u{E0BA}%%#%s#   %s   %%#%sSep#\u{E0B8}"):format(
			hl,
			hl,
			label(tab):gsub("%%", "%%%%"),
			hl
		)
	end
	return table.concat(parts) .. "%#TabLineFill#"
end

return M
