local map = vim.keymap.set

map("n", "]]", function()
	Snacks.words.jump(vim.v.count1)
end, { desc = "Next reference" })
map("n", "[[", function()
	Snacks.words.jump(-vim.v.count1)
end, { desc = "Previous reference" })

map("n", ";f", function()
	Snacks.picker.files({ hidden = true })
end, { desc = "Find files" })
map("n", ";r", function()
	Snacks.picker.grep({ hidden = true })
end, { desc = "Live grep" })
map("n", ";;", function()
	Snacks.picker.resume()
end, { desc = "Resume last picker" })
map("n", "\\\\", function()
	Snacks.picker.buffers()
end, { desc = "Buffers" })
map("n", ";e", function()
	Snacks.picker.diagnostics()
end, { desc = "Diagnostics" })
map("n", ";n", function()
	Snacks.picker.notifications()
end, { desc = "Notification history" })
map("n", ";h", function()
	Snacks.picker.git_diff()
end, { desc = "Git hunks" })

map("n", "sf", function()
	require("oil").open_float(nil, { preview = {} })
end, { desc = "File explorer" })
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("newedia_oil_keymaps", { clear = true }),
	pattern = "oil",
	callback = function(ev)
		map("n", "h", require("oil.actions").parent.callback, { buffer = ev.buf, desc = "Parent directory" })
		map("n", "q", require("oil").close, { buffer = ev.buf, desc = "Close oil" })
	end,
})

-- vtsls's "go to source definition" skips the .d.ts to reach the real code.
local function goto_source_definition()
	local client = vim.lsp.get_clients({ bufnr = 0, name = "vtsls" })[1]
	if not client then
		return Snacks.picker.lsp_implementations()
	end
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	client:exec_cmd({
		title = "Go to source definition",
		command = "typescript.goToSourceDefinition",
		arguments = { params.textDocument.uri, params.position },
	}, { bufnr = 0 }, function(err, result)
		if err or not result or vim.tbl_isempty(result) then
			vim.notify("No source definition found", vim.log.levels.WARN)
			return
		end
		vim.lsp.util.show_document(result[1], client.offset_encoding, { focus = true })
	end)
end

-- Buffer-local, so these only exist where a server is attached; nowait lets
-- `gr` win over Neovim's default gr* mappings without a timeout.
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("newedia_lsp_keymaps", { clear = true }),
	callback = function(ev)
		local function bmap(mode, lhs, rhs, desc)
			map(mode, lhs, rhs, { buffer = ev.buf, desc = desc, nowait = true })
		end
		bmap("n", "gd", function()
			Snacks.picker.lsp_definitions()
		end, "Go to definition")
		bmap("n", "gD", function()
			Snacks.picker.lsp_declarations()
		end, "Go to declaration")
		bmap("n", "gy", function()
			Snacks.picker.lsp_type_definitions()
		end, "Go to type definition")
		bmap("n", "gr", function()
			Snacks.picker.lsp_references()
		end, "References")
		bmap("n", "gI", goto_source_definition, "Go to source definition / implementation")
		bmap("n", ";c", function()
			Snacks.picker.lsp_incoming_calls()
		end, "Incoming calls")
		bmap("n", "K", vim.lsp.buf.hover, "Hover docs")
		bmap("n", "gK", vim.lsp.buf.signature_help, "Signature help")
		bmap("i", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
		bmap("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
		bmap("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol")
		bmap("n", "<leader>cR", function()
			Snacks.rename.rename_file()
		end, "Rename file")
	end,
})

-- Diagnostics and formatting also work without a language server.
map("n", "<C-j>", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
map("n", "<leader>f", function()
	require("conform").format({ lsp_format = "fallback" })
end, { desc = "Format buffer" })
map("n", "<leader>cl", "<cmd>checkhealth vim.lsp<cr>", { desc = "LSP info" })
