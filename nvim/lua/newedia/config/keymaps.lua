local map = vim.keymap.set

-- Registers: keep the last yank (register 0) safe while editing around it.
map({ "n", "x" }, "x", '"_x', { desc = "Delete char without copying" })
map({ "n", "x" }, "<leader>d", '"_d', { desc = "Delete without copying" })
map({ "n", "x" }, "<leader>c", '"_c', { desc = "Change without copying" })
map({ "n", "x" }, "<leader>p", '"0p', { desc = "Paste the last yank" })
map("n", "dw", 'vb"_d', { desc = "Delete word backwards without copying" })

map("n", "+", "<C-a>", { desc = "Increment number" })
map("n", "-", "<C-x>", { desc = "Decrement number" })
map("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })

map("n", "te", "<cmd>tabedit<cr>", { desc = "New tab" })
map("n", "<Tab>", "<cmd>tabnext<cr>", { desc = "Next tab" })
map("n", "<S-Tab>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })

map("n", "ss", "<cmd>split<cr>", { desc = "Split below" })
map("n", "sv", "<cmd>vsplit<cr>", { desc = "Split right" })
map("n", "sh", "<C-w>h", { desc = "Window left" })
map("n", "sj", "<C-w>j", { desc = "Window below" })
map("n", "sk", "<C-w>k", { desc = "Window above" })
map("n", "sl", "<C-w>l", { desc = "Window right" })

map("n", "<leader>o", "o<Esc>^Da", { desc = "Open line below without comment" })
map("n", "<leader>O", "O<Esc>^Da", { desc = "Open line above without comment" })
