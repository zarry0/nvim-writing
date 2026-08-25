local function root()
  return require("writing.core.project").resolve(0).root
end

return {
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local fzf = require("fzf-lua")
      fzf.setup({
        defaults = { formatter = "path.filename_first" },
        files = { formatter = "path.filename_first", cwd_prompt = false },
        fzf_colors = true,
      })
      require("writing.core.theme").refresh()
      fzf.register_ui_select()
    end,
    keys = {
      {
        "<leader>ff",
        function() require("fzf-lua").files({ cwd = root() }) end,
        desc = "Buscar archivos",
      },
      {
        "<leader>fs",
        function() require("fzf-lua").live_grep({ cwd = root() }) end,
        desc = "Buscar texto",
      },
      { "<leader>/", function() require("fzf-lua").blines() end, desc = "Buscar en el archivo" },
      { "<leader><leader>", function() require("fzf-lua").buffers() end, desc = "Buscar buffers" },
      {
        "<leader>fc",
        function() require("fzf-lua").files({ cwd = vim.fn.stdpath("config") }) end,
        desc = "Buscar en la configuración",
      },
      { "<leader>fo", function() require("fzf-lua").lsp_document_symbols() end, desc = "Outline" },
      { "<leader>fv", function() require("fzf-lua").grep_visual() end, mode = "v", desc = "Buscar selección" },
      { "<leader>fr", function() require("fzf-lua").registers() end, desc = "Buscar registros" },
      { "<leader>fz", function() require("fzf-lua").builtin() end, desc = "Buscar finder" },
    },
  },
}
