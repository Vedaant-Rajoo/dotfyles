return {
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			workspace = {
				checkThirdParty = false,
				-- The Neovim runtime plus vim.pack's plugins, so plugin APIs complete.
				library = { vim.env.VIMRUNTIME, vim.fn.stdpath("data") .. "/site/pack/core/opt" },
			},
			hint = { enable = true, paramType = true },
			diagnostics = { disable = { "trailing-space", "incomplete-signature-doc" } },
		},
	},
}
