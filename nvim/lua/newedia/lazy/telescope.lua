return {
    "nvim-telescope/telescope.nvim",

    dependencies = {
        "nvim-lua/plenary.nvim",
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },

    config = function()
        require('telescope').setup({})

        local preview_utils = require("telescope.previewers.utils")
        preview_utils.ts_highlighter = function(bufnr, ft)
            if not ft or ft == "" then
                return false
            end

            local lang = vim.treesitter.language.get_lang(ft) or ft
            if lang == "" then
                return false
            end

            return pcall(vim.treesitter.start, bufnr, lang)
        end

        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>vh', builtin.help_tags, {})
        vim.keymap.set('n', '<leader>pf', builtin.find_files, { desc = 'Project files' })
        vim.keymap.set('n', '<leader>ps', builtin.live_grep, { desc = 'Project grep (live)' })
        vim.keymap.set('n', '<leader>pws', function()
            local word = vim.fn.expand('<cword>')
            builtin.grep_string({ search = word })
        end, { desc = 'Project grep word under cursor' })
        vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
        vim.keymap.set('n', '<leader>fr', builtin.oldfiles, { desc = 'Recent files' })
        vim.keymap.set('n', '<leader>fc', function()
            builtin.find_files({ cwd = vim.fn.stdpath('config') })
        end, { desc = 'Find config files' })
    end
}

