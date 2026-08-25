local settings = require("writing.settings")

return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = { preset = "super-tab" },
      completion = {
        list = { selection = { preselect = false, auto_insert = false } },
        menu = {
          auto_show = function()
            return vim.bo.filetype == "typst"
          end,
        },
        documentation = { auto_show = false },
      },
      sources = { default = { "lsp", "path", "snippets" } },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    version = "2.*",
    lazy = false,
    dependencies = {
      { "mason-org/mason.nvim", version = "2.*", opts = {} },
      "neovim/nvim-lspconfig",
    },
    config = function()
      local project = require("writing.core.project")

      local function root_dir(bufnr, on_dir)
        local path = vim.api.nvim_buf_get_name(bufnr)
        if path ~= "" then
          on_dir(project.resolve_path(path).root)
        end
      end

      vim.lsp.config("tinymist", {
        root_dir = root_dir,
        settings = {
          formatterMode = "typstyle",
          formatterProseWrap = false,
          exportPdf = "never",
          semanticTokens = "enable",
        },
      })

      vim.lsp.config("ltex_plus", {
        root_dir = root_dir,
        filetypes = { "text", "markdown", "typst", "tex", "plaintex", "bib" },
        settings = {
          ltex = {
            language = settings.primary_ltex_language,
            dictionary = require("writing.core.spell").ltex_dictionary(),
            diagnosticSeverity = {
              MORFOLOGIK_RULE_ES = "error",
              MORFOLOGIK_RULE_EN_US = "error",
              default = "information",
            },
          },
        },
      })

      require("mason-lspconfig").setup({
        ensure_installed = { "tinymist", "ltex_plus" },
        automatic_enable = { "tinymist", "ltex_plus" },
      })
    end,
  },
}
