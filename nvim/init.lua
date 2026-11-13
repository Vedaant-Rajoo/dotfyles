vim.loader.enable()

_G.Newedia = require("newedia.utils")

require("newedia.config.options")
require("newedia.config.keymaps")
require("newedia.config.autocmds")
require("newedia.config.commands")
require("newedia.config.workarounds")

require("newedia.plugins")
