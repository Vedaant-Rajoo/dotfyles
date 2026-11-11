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

-- Git: signs and blame
local gitsigns = require("gitsigns")

-- The popup's own `q` only works inside it, so while it is open `q` in the
-- source buffer closes it too, then the mapping removes itself.
map("n", "<leader>gb", function()
	local buf = vim.api.nvim_get_current_buf()
	gitsigns.blame_line(nil, function()
		vim.schedule(function()
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.w[win].gitsigns_preview == "blame" then
					map("n", "q", function()
						pcall(vim.api.nvim_win_close, win, true)
					end, { buffer = buf, nowait = true, desc = "Close blame popup" })
					vim.api.nvim_create_autocmd("WinClosed", {
						pattern = tostring(win),
						once = true,
						callback = function()
							pcall(vim.keymap.del, "n", "q", { buffer = buf })
						end,
					})
				end
			end
		end)
	end)
end, { desc = "Blame line" })
map("n", "<leader>gB", gitsigns.blame, { desc = "Blame buffer" })
map("n", "<leader>go", function()
	local file = vim.api.nvim_buf_get_name(0)
	local lnum = vim.fn.line(".")
	local out = vim.system(
		{ "git", "blame", "--porcelain", "-L", lnum .. "," .. lnum, "--", file },
		{ cwd = vim.fs.dirname(file), text = true }
	):wait()
	local sha, orig_lnum = (out.stdout or ""):match("^(%x+) (%d+)")
	if out.code ~= 0 or not sha then
		vim.notify("git blame failed: " .. vim.trim(out.stderr or ""), vim.log.levels.WARN)
		return
	end
	if sha:match("^0+$") then
		vim.notify("This line isn't committed yet", vim.log.levels.INFO)
		return
	end
	gitsigns.show(sha .. ":%", { open = "tabnew" }, function()
		vim.schedule(function()
			pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(orig_lnum), 0 })
		end)
	end)
end, { desc = "Open file at the line's last commit" })
map("n", "<leader>gs", function()
	if #(gitsigns.get_hunks() or {}) > 0 then
		gitsigns.stage_buffer()
	else
		gitsigns.reset_buffer_index()
	end
end, { desc = "Stage or unstage buffer" })
map("n", "<leader>gh", gitsigns.stage_hunk, { desc = "Stage or unstage hunk" })

-- Git: diff overlay. In diff mode ]c/[c keep their built-in meaning.
map("n", "<leader>gd", function()
	MiniDiff.toggle_overlay()
end, { desc = "Toggle diff overlay" })
map("n", "]c", function()
	if vim.wo.diff then
		vim.cmd.normal({ "]c", bang = true })
	else
		MiniDiff.goto_hunk("next")
	end
end, { desc = "Next hunk" })
map("n", "[c", function()
	if vim.wo.diff then
		vim.cmd.normal({ "[c", bang = true })
	else
		MiniDiff.goto_hunk("prev")
	end
end, { desc = "Previous hunk" })

-- Git: diff view
map("n", "<leader>dv", function()
	-- shortcut: codediff exposes no public "is open" API, so this uses its
	-- lifecycle module; revisit if an update moves it.
	local lifecycle = require("codediff.ui.lifecycle")
	local tab = vim.api.nvim_get_current_tabpage()
	if lifecycle.get_session(tab) then
		lifecycle.close(tab)
	else
		vim.cmd("CodeDiff")
	end
end, { desc = "Toggle diff view" })
map("n", "<leader>dh", "<cmd>CodeDiff history %<cr>", { desc = "File history" })
map("n", "<leader>dH", "<cmd>CodeDiff history<cr>", { desc = "Repo history" })
