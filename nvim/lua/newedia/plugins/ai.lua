-- Inline suggestions as you type. Run `:Copilot auth` once per machine.
require("copilot").setup({
	suggestion = {
		auto_trigger = true,
		-- The keys live in plugins/keymaps.lua.
		keymap = {
			accept = false,
			accept_word = false,
			accept_line = false,
			next = false,
			prev = false,
			dismiss = false,
		},
	},
	-- copilot.lua turns these two off by default; notes and docs benefit too.
	filetypes = { markdown = true, help = true },
})
