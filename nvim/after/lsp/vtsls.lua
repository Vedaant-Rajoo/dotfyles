local ts = {
	updateImportsOnFileMove = { enabled = "always" },
	suggest = { completeFunctionCalls = true },
	inlayHints = {
		enumMemberValues = { enabled = true },
		functionLikeReturnTypes = { enabled = true },
		parameterNames = { enabled = "literals" },
		parameterTypes = { enabled = true },
		propertyDeclarationTypes = { enabled = true },
		variableTypes = { enabled = false },
	},
}

return {
	settings = {
		vtsls = {
			autoUseWorkspaceTsdk = true,
			experimental = {
				maxInlayHintLength = 30,
				completion = { enableServerSideFuzzyMatch = true },
			},
		},
		typescript = ts,
		javascript = ts,
	},
}
