local settings = require("writing.settings")

local function prose_word_count()
  if not vim.tbl_contains({ "text", "markdown", "typst", "tex", "plaintex" }, vim.bo.filetype) then
    return ""
  end
  local count = vim.fn.wordcount()
  return tostring(count.visual_words or count.words or 0) .. " palabras"
end

local function spell_language()
  if not vim.wo.spell then
    return "spell off"
  end
  return vim.bo.spelllang:gsub("en_us", "EN"):gsub("es", "ES")
end

local function tab_label(tabid)
  local winid = vim.api.nvim_tabpage_get_win(tabid)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return "[Sin nombre]"
  end
  if path:match("^oil://") then
    local directory = path:gsub("^oil://", ""):gsub("/$", "")
    return "Oil:" .. vim.fs.basename(directory)
  end
  if path:match("^term://") then
    return "[Terminal]"
  end
  path = vim.fs.normalize(path)
  local filename = vim.fs.basename(path)
  local parent = vim.fs.basename(vim.fs.dirname(path))
  return parent ~= "" and (parent .. "/" .. filename) or filename
end

return {
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        compile = false,
        dimInactive = true,
        commentStyle = { italic = true },
      })
      if settings.theme == "kanagawa" then
        local ok = pcall(vim.cmd.colorscheme, "kanagawa-" .. settings.theme_variant)
        if not ok then
          vim.cmd.colorscheme("habamax")
        end
      end
    end,
  },
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
    opts = { default = true },
  },
  {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      input = { enabled = true },
      lazygit = { enabled = true },
      quickfile = { enabled = true },
      terminal = { enabled = true },
      zen = {
        enabled = true,
        win = { width = settings.zen_width },
      },
    },
    keys = {
      { "<leader>tt", function() Snacks.terminal() end, desc = "Abrir terminal" },
      {
        "<leader>lg",
        function()
          Snacks.lazygit({ cwd = require("writing.core.project").git_root(0) })
        end,
        desc = "Abrir LazyGit",
      },
      {
        "<leader>gl",
        function()
          Snacks.lazygit.log({ cwd = require("writing.core.project").git_root(0) })
        end,
        desc = "Abrir log de Git",
      },
    },
  },
  {
    "stevearc/oil.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      default_file_explorer = true,
      columns = { "icon" },
      skip_confirm_for_simple_edits = false,
      view_options = { show_hidden = true },
    },
    keys = {
      { "<leader>e", "<cmd>Oil<CR>", desc = "Abrir Oil" },
      { "-", "<cmd>Oil<CR>", desc = "Abrir directorio padre" },
    },
  },
  {
    "nanozuki/tabby.nvim",
    version = "2.*",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local theme = {
        fill = "TabLineFill",
        current = "TabLineSel",
        inactive = "TabLine",
      }
      require("tabby").setup({
        line = function(line)
          return {
            line.tabs().foreach(function(tab)
              local hl = tab.is_current() and theme.current or theme.inactive
              return {
                { " " .. tab.number() .. " ", hl = hl },
                { tab.name(), hl = hl },
                tab.close_btn(" × "),
                hl = hl,
                margin = " ",
              }
            end),
            line.spacer(),
            { " nvim-writing ", hl = theme.inactive },
            hl = theme.fill,
          }
        end,
        option = {
          tab_name = { name_fallback = tab_label },
          buf_name = { mode = "tail" },
        },
      })
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 4 } },
        lualine_x = { prose_word_count, spell_language, "lsp_status", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      tabline = {},
      extensions = { "lazy", "mason", "oil", "quickfix" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>w", group = "Writing" },
        { "<leader>we", group = "Exportar" },
        { "<leader>f", group = "Buscar" },
        { "<leader>g", group = "Git" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Mostrar bindings locales",
      },
    },
  },
}
