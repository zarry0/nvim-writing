local settings = require("writing.settings")

local function spell_language()
  if not vim.wo.spell then
    return "OFF"
  end
  local languages = {}
  for token in vim.bo.spelllang:gmatch("[^,]+") do
    token = token:lower()
    if token == "es" or token:match("^es[_-]") then
      languages.ES = true
    elseif token == "en" or token:match("^en[_-]") then
      languages.EN = true
    end
  end
  if languages.ES and languages.EN then
    return "ES+EN"
  end
  if languages.ES then
    return "ES"
  end
  if languages.EN then
    return "EN"
  end
  return vim.bo.spelllang:upper()
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

local function status_filename()
  local label = tab_label(vim.api.nvim_get_current_tabpage())
  if vim.bo.modified then
    label = label .. " [+]"
  end
  return label
end

local function lualine_options()
  return {
    options = {
      theme = require("writing.core.theme").lualine_theme(),
      globalstatus = true,
      icons_enabled = false,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = {},
      lualine_c = { status_filename },
      lualine_x = { require("writing.core.word_count").status, spell_language },
      lualine_y = { "progress" },
      lualine_z = {},
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { status_filename },
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
    tabline = {},
    extensions = {},
  }
end

return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
    opts = { default = true, color_icons = false },
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
      require("tabby.feature.tab_name").set_default_option({ name_fallback = tab_label })
      require("tabby").setup({
        line = function(line)
          return {
            line.tabs().foreach(function(tab)
              local hl = tab.is_current() and theme.current or theme.inactive
              return {
                { " " .. tab.name(), hl = hl },
                tab.close_btn(" × "),
                hl = hl,
                margin = " ",
              }
            end),
            line.spacer(),
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
    config = function()
      local lualine = require("lualine")
      lualine.setup(lualine_options())
      require("writing.core.theme").on_change(function()
        lualine.setup(lualine_options())
      end)
    end,
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
