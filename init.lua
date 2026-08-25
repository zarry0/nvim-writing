vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local required = { 0, 12, 4 }
if not vim.version.ge(vim.version(), required) then
  error("nvim-writing requiere Neovim 0.12.4 o posterior")
end

vim.g.have_nerd_font = vim.g.have_nerd_font ~= false

require("writing.config.options")
require("writing.core.theme").setup()
require("writing.config.keymaps")
require("writing.config.autocmds")
require("writing.core.language").ensure_wordlists()
require("writing.core.spell").setup()
require("writing.core.word_count").setup()
require("writing.config.lazy")
require("writing.core.commands").setup()
