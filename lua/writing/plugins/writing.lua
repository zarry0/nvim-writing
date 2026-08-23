local settings = require("writing.settings")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")
      treesitter.setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
      treesitter.install(settings.treesitter_parsers)
    end,
  },
  {
    "echasnovski/mini.pairs",
    version = "*",
    event = "InsertEnter",
    opts = {},
  },
}
