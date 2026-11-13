require("oil").setup({
	columns = { "icon", "permissions", "size", "mtime" },
	view_options = { show_hidden = true },
	lsp_file_methods = { enabled = true, autosave_changes = true },
	float = { max_width = 200, border = "rounded" },
})
