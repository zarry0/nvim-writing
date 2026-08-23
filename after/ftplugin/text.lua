vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.textwidth = 0
vim.opt_local.spell = true
vim.opt_local.spelllang = require("writing.settings").default_language
vim.opt_local.spellfile = table.concat({
  vim.fs.joinpath(vim.fn.stdpath("config"), "wordlists", "es.utf-8.add"),
  vim.fs.joinpath(vim.fn.stdpath("config"), "wordlists", "en.utf-8.add"),
}, ",")
