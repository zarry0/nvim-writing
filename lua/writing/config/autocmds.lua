local group = vim.api.nvim_create_augroup("nvim-writing", { clear = true })

vim.filetype.add({ extension = { typ = "typst" } })
vim.treesitter.language.register("latex", { "tex", "plaintex" })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  desc = "Resaltar texto copiado",
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "text", "markdown", "typst", "tex", "plaintex" },
  desc = "Opciones locales para prosa",
  callback = function(event)
    local settings = require("writing.settings")
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.textwidth = 0
    vim.opt_local.spell = true
    vim.opt_local.spelllang = settings.default_language
    vim.opt_local.formatoptions:remove({ "c", "r", "o", "t" })
    vim.b[event.buf].writing_language = settings.default_language
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "markdown", "typst", "tex", "plaintex", "bib" },
  desc = "Activar Treesitter si el parser está disponible",
  callback = function()
    pcall(vim.treesitter.start)
  end,
})
