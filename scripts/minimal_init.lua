vim.opt.rtp:append('.')
vim.opt.rtp:append('./test_deps/plenary.nvim/')

vim.cmd([[runtime! plugin/plenary.vim]])
