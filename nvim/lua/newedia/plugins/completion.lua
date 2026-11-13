local function kind_hl(ctx)
	local _, hl = require("mini.icons").get("lsp", ctx.kind)
	return hl
end

require("blink.cmp").setup({
	keymap = { preset = "enter" },
	completion = {
		accept = { auto_brackets = { enabled = true } },
		documentation = { auto_show = true, auto_show_delay_ms = 200 },
		ghost_text = { enabled = false },
		menu = {
			draw = {
				treesitter = { "lsp" },
				components = {
					kind_icon = {
						text = function(ctx)
							return (require("mini.icons").get("lsp", ctx.kind))
						end,
						highlight = kind_hl,
					},
					kind = { highlight = kind_hl },
				},
			},
		},
	},
	cmdline = {
		completion = {
			menu = {
				auto_show = function()
					return vim.fn.getcmdtype() == ":"
				end,
			},
			list = { selection = { preselect = false } },
		},
	},
})

require("mini.pairs").setup({
	modes = { insert = true, command = true },
})
