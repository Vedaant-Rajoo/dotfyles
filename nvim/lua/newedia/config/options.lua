-- Leader is set first so every later mapping picks it up.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.mouse = ""
opt.clipboard = "unnamedplus"

opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true
opt.iskeyword:append("-")
