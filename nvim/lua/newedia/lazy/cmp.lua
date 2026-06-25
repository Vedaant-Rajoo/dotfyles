return {
	"saghen/blink.cmp",
	version = "1.*",
	event = { "InsertEnter", "CmdlineEnter" },
	opts = {
		keymap = {
			preset = "none",
			["<C-p>"] = { "select_prev", "fallback" },
			["<C-n>"] = { "select_next", "fallback" },
			["<C-y>"] = { "accept" },
			["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
		},
		completion = {
			documentation = { auto_show = true, auto_show_delay_ms = 200 },
			accept = { auto_brackets = { enabled = true } },
		},
		sources = {
			default = { "lsp", "path", "snippets", "buffer" },
		},
		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
}
