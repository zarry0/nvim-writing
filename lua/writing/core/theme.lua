local M = {}

local listeners = {}

local palettes = {
  dark = {
    background = "dark",
    bg = "#0D1117",
    bg_dim = "#161B22",
    bg_alt = "#21262D",
    bg_soft = "#30363D",
    fg = "#F0F0F0",
    muted = "#8B949E",
    dim = "#484F58",
    red = "#D05858",
    yellow = "#BE7E05",
    green = "#608E32",
    cyan = "#3A8B84",
    blue = "#5079BE",
    purple = "#B05CCC",
  },
  light = {
    background = "light",
    bg = "#FAFAFA",
    bg_dim = "#EEF1F4",
    bg_alt = "#E8EBF0",
    bg_soft = "#DDE2E7",
    fg = "#20232A",
    muted = "#8790A0",
    dim = "#BAC3CB",
    red = "#D05858",
    yellow = "#BE7E05",
    green = "#608E32",
    cyan = "#3A8B84",
    blue = "#5079BE",
    purple = "#B05CCC",
  },
}

local function set(name, value)
  vim.api.nvim_set_hl(0, name, value)
end

local function set_many(names, value)
  for _, name in ipairs(names) do
    set(name, value)
  end
end

local function neutralize_late_plugin_groups(p)
  local prefixes = {
    "BlinkCmp",
    "CmpItem",
    "DevIcon",
    "FzfLua",
    "Lazy",
    "LspInfo",
    "Mason",
    "Oil",
    "Snacks",
    "WhichKey",
    "fzf",
  }
  for name, current in pairs(vim.api.nvim_get_hl(0, {})) do
    local matches = false
    for _, prefix in ipairs(prefixes) do
      if vim.startswith(name, prefix) then
        matches = true
        break
      end
    end
    if matches then
      local value = { fg = p.muted }
      if current.bg then
        value.bg = p.bg_alt
      end
      for _, attribute in ipairs({ "bold", "italic", "reverse", "strikethrough", "underline", "undercurl" }) do
        if current[attribute] then
          value[attribute] = true
        end
      end
      set(name, value)
    end
  end
end

local function document_highlights(p)
  local headings = {
    [1] = p.blue,
    [2] = p.purple,
    [3] = p.cyan,
    [4] = p.green,
    [5] = p.yellow,
    [6] = p.red,
  }
  for level, color in pairs(headings) do
    for _, language in ipairs({ "markdown", "markdown_inline", "typst", "latex" }) do
      set("@markup.heading." .. level .. "." .. language, { fg = color, bold = true })
    end
  end

  set_many({ "@markup.heading.markdown", "@markup.heading.typst", "@markup.heading.latex" }, {
    fg = p.blue,
    bold = true,
  })
  set_many({ "@markup.strong.markdown_inline", "@markup.strong.typst", "@markup.strong.latex" }, {
    fg = p.fg,
    bold = true,
  })
  set_many({ "@markup.italic.markdown_inline", "@markup.italic.typst", "@markup.italic.latex" }, {
    fg = p.fg,
    italic = true,
  })
  set("@markup.strikethrough.markdown_inline", { fg = p.muted, strikethrough = true })

  for _, language in ipairs({ "markdown", "markdown_inline", "typst", "latex" }) do
    set("@markup.link." .. language, { fg = p.cyan })
    set("@markup.link.label." .. language, { fg = p.cyan })
    set("@markup.link.url." .. language, { fg = p.blue, underline = true })
    set("@markup.raw." .. language, { fg = p.green })
    set("@markup.raw.block." .. language, { fg = p.green })
    set("@markup.math." .. language, { fg = p.purple })
    set("@punctuation.bracket." .. language, { fg = p.purple })
    set("@punctuation.delimiter." .. language, { fg = p.muted })
    set("@punctuation.special." .. language, { fg = p.red })
  end

  set("@markup.list.markdown", {
    fg = p.yellow,
    bold = true,
  })
  set("@markup.list.checked.markdown", { fg = p.green, bold = true })
  set("@markup.list.unchecked.markdown", { fg = p.yellow, bold = true })
  set("@markup.quote.markdown", { fg = p.fg, italic = true })
  set("@keyword.directive.markdown", { fg = p.purple })
  set("@string.escape.markdown", { fg = p.yellow })
  set("@label.markdown", { fg = p.cyan })
  set("@conceal.markdown_inline", { fg = p.purple })
  set("@character.special.markdown_inline", { fg = p.red })

  set_many({ "@keyword.typst", "@keyword.conditional.typst", "@keyword.import.typst", "@keyword.repeat.typst" }, {
    fg = p.purple,
  })
  set("@function.call.typst", { fg = p.blue })
  set_many({ "@string.typst", "@markup.raw.typst", "@markup.raw.block.typst" }, { fg = p.green })
  set_many({ "@number.typst", "@operator.typst" }, { fg = p.yellow })
  set_many({ "@boolean.typst", "@constant.typst" }, { fg = p.purple })
  set_many({ "@label.typst", "@variable.member.typst" }, { fg = p.cyan })
  set("@comment.typst", { fg = p.muted, italic = true })

  set_many({ "@function.latex", "@function.macro.latex", "@keyword.directive.latex", "@keyword.import.latex" }, {
    fg = p.blue,
  })
  set_many({ "@keyword.conditional.latex", "@module.latex" }, { fg = p.purple })
  set_many({ "@label.latex", "@markup.link.latex", "@markup.link.url.latex" }, { fg = p.cyan })
  set_many({ "@string.latex", "@string.regexp.latex", "@string.special.path.latex", "@constant.latex" }, { fg = p.green })
  set_many({ "@operator.latex", "@punctuation.bracket.latex", "@punctuation.delimiter.latex" }, { fg = p.yellow })
  set_many({ "@variable.latex", "@variable.parameter.latex" }, { fg = p.fg })
  set("@comment.latex", { fg = p.muted, italic = true })

  set_many({ "@lsp.type.function.typst", "@lsp.type.method.typst" }, { fg = p.blue })
  set_many({ "@lsp.type.keyword.typst", "@lsp.type.macro.typst" }, { fg = p.purple })
  set("@lsp.type.heading.typst", { fg = p.blue, bold = true })
  set("@lsp.type.string.typst", { fg = p.green })
  set("@lsp.type.number.typst", { fg = p.yellow })
  set_many({ "@lsp.type.label.typst", "@lsp.type.namespace.typst" }, { fg = p.cyan })
  set_many({ "@lsp.type.variable.typst", "@lsp.type.parameter.typst" }, { fg = p.fg })
end

local function base_highlights(p)
  neutralize_late_plugin_groups(p)
  set("Normal", { fg = p.fg, bg = p.bg })
  set("NormalNC", { fg = p.fg, bg = p.bg })
  set("NormalFloat", { fg = p.fg, bg = p.bg_dim })
  set("FloatBorder", { fg = p.dim, bg = p.bg_dim })
  set("FloatTitle", { fg = p.fg, bg = p.bg_dim, bold = true })
  set("Cursor", { fg = p.bg, bg = p.fg })
  set("lCursor", { fg = p.bg, bg = p.fg })
  set("CursorIM", { fg = p.bg, bg = p.fg })
  set("TermCursor", { fg = p.bg, bg = p.fg })
  set("CursorLine", { bg = p.bg_dim })
  set("CursorColumn", { bg = p.bg_dim })
  set("CursorLineNr", { fg = p.fg, bg = p.bg_dim, bold = true })
  set("LineNr", { fg = p.dim, bg = p.bg })
  set("SignColumn", { fg = p.muted, bg = p.bg })
  set("FoldColumn", { fg = p.dim, bg = p.bg })
  set("ColorColumn", { bg = p.bg_dim })
  set("EndOfBuffer", { fg = p.bg })
  set("NonText", { fg = p.dim })
  set("Whitespace", { fg = p.dim })
  set("SpecialKey", { fg = p.dim })
  set("Conceal", { fg = p.dim })
  set("Visual", { bg = p.bg_soft })
  set("VisualNOS", { bg = p.bg_soft })
  set("Search", { fg = p.bg, bg = p.fg, bold = true })
  set("IncSearch", { fg = p.bg, bg = p.fg, bold = true })
  set("CurSearch", { fg = p.bg, bg = p.fg, bold = true })
  set("Substitute", { fg = p.bg, bg = p.fg, bold = true })
  set("MatchParen", { fg = p.fg, bg = p.bg_alt, bold = true })
  set("Pmenu", { fg = p.fg, bg = p.bg_dim })
  set("PmenuSel", { fg = p.bg, bg = p.fg, bold = true })
  set("PmenuSbar", { bg = p.bg_alt })
  set("PmenuThumb", { bg = p.muted })
  set("WinSeparator", { fg = p.dim, bg = p.bg })
  set("VertSplit", { fg = p.dim, bg = p.bg })
  set("WinBar", { fg = p.fg, bg = p.bg })
  set("WinBarNC", { fg = p.muted, bg = p.bg })
  set("StatusLine", { fg = p.fg, bg = p.bg_alt })
  set("StatusLineNC", { fg = p.muted, bg = p.bg_dim })
  set("TabLineFill", { fg = p.muted, bg = p.bg_dim })
  set("TabLine", { fg = p.muted, bg = p.bg_dim })
  set("TabLineSel", { fg = p.fg, bg = p.bg_alt, bold = true })
  set("MsgArea", { fg = p.fg, bg = p.bg })
  set("ModeMsg", { fg = p.fg, bold = true })
  set("MoreMsg", { fg = p.fg })
  set("OkMsg", { fg = p.fg })
  set("Question", { fg = p.fg, bold = true })
  set("ErrorMsg", { fg = p.fg, bold = true })
  set("WarningMsg", { fg = p.fg })
  set("Directory", { fg = p.fg, bold = true })
  set("Title", { fg = p.fg, bold = true })
  set("QuickFixLine", { bg = p.bg_alt, bold = true })

  set_many({ "SpellBad", "SpellCap", "SpellRare", "SpellLocal" }, { undercurl = true, sp = "#D05858" })
  set("DiagnosticError", { fg = p.fg, bold = true })
  set("DiagnosticWarn", { fg = p.fg })
  set("DiagnosticInfo", { fg = p.muted })
  set("DiagnosticHint", { fg = p.muted })
  set("DiagnosticOk", { fg = p.fg })
  set_many({ "DiagnosticUnderlineError", "DiagnosticUnderlineWarn", "DiagnosticUnderlineInfo", "DiagnosticUnderlineHint" }, {
    undercurl = true,
    sp = p.muted,
  })
  set("DiagnosticUnderlineOk", { undercurl = true, sp = p.muted })
  set("DiagnosticVirtualTextError", { fg = p.fg, bg = p.bg_dim, bold = true })
  set("DiagnosticVirtualTextWarn", { fg = p.fg, bg = p.bg_dim })
  set("DiagnosticVirtualTextInfo", { fg = p.muted, bg = p.bg_dim })
  set("DiagnosticVirtualTextHint", { fg = p.muted, bg = p.bg_dim })

  local monochrome_syntax = {
    "Comment",
    "Constant",
    "String",
    "Character",
    "Number",
    "Boolean",
    "Float",
    "Identifier",
    "Function",
    "Statement",
    "Conditional",
    "Repeat",
    "Label",
    "Operator",
    "Keyword",
    "Exception",
    "PreProc",
    "Include",
    "Define",
    "Macro",
    "PreCondit",
    "Type",
    "StorageClass",
    "Structure",
    "Typedef",
    "Special",
    "SpecialChar",
    "Tag",
    "Delimiter",
    "SpecialComment",
    "Debug",
  }
  set_many(monochrome_syntax, { fg = p.fg })
  set("Comment", { fg = p.muted, italic = true })
  set("Underlined", { fg = p.fg, underline = true })
  set("Ignore", { fg = p.dim })
  set("Error", { fg = p.fg, undercurl = true, sp = p.muted })
  set("Todo", { fg = p.fg, bold = true })

  set_many({ "GitSignsAdd", "GitSignsChange", "GitSignsDelete", "GitSignsTopdelete", "GitSignsChangedelete" }, {
    fg = p.muted,
  })
  set_many({ "Added", "Changed", "Removed" }, { fg = p.muted })
  set("DiffAdd", { bg = p.bg_dim })
  set("DiffChange", { bg = p.bg_alt })
  set("DiffDelete", { fg = p.dim, bg = p.bg_dim })
  set("DiffText", { fg = p.fg, bg = p.bg_soft, bold = true })

  set("DevIconDefault", { fg = p.muted })
  set("OilDir", { fg = p.fg, bold = true })
  set("OilDirIcon", { fg = p.muted })
  set("OilLink", { fg = p.muted, underline = true })
  set("OilLinkTarget", { fg = p.dim })
  set("OilHidden", { fg = p.dim })
  set("FzfLuaNormal", { fg = p.fg, bg = p.bg_dim })
  set("FzfLuaBorder", { fg = p.dim, bg = p.bg_dim })
  set("FzfLuaCursor", { fg = p.fg, bg = p.bg_alt })
  set("FzfLuaCursorLine", { fg = p.fg, bg = p.bg_alt })
  set("FzfLuaSearch", { fg = p.fg, bold = true })
  set("FzfLuaHeaderText", { fg = p.fg, bold = true })
  set("WhichKey", { fg = p.fg, bold = true })
  set("WhichKeyDesc", { fg = p.fg })
  set("WhichKeyGroup", { fg = p.muted })
  set("WhichKeySeparator", { fg = p.dim })
end

local function terminal_colors(p)
  vim.g.terminal_color_0 = p.bg
  vim.g.terminal_color_1 = p.muted
  vim.g.terminal_color_2 = p.fg
  vim.g.terminal_color_3 = p.muted
  vim.g.terminal_color_4 = p.fg
  vim.g.terminal_color_5 = p.muted
  vim.g.terminal_color_6 = p.fg
  vim.g.terminal_color_7 = p.fg
  vim.g.terminal_color_8 = p.dim
  vim.g.terminal_color_9 = p.muted
  vim.g.terminal_color_10 = p.fg
  vim.g.terminal_color_11 = p.muted
  vim.g.terminal_color_12 = p.fg
  vim.g.terminal_color_13 = p.muted
  vim.g.terminal_color_14 = p.fg
  vim.g.terminal_color_15 = p.fg
end

function M.palette(style)
  return palettes[style or vim.o.background] or palettes.dark
end

function M.name(style)
  return "writing-monochrome-" .. style
end

function M.apply(style)
  style = style or "dark"
  if style == "toggle" then
    style = vim.o.background == "dark" and "light" or "dark"
  end
  if not palettes[style] then
    return false, "Tema desconocido: " .. tostring(style)
  end

  local p = palettes[style]
  vim.o.background = p.background
  vim.cmd("highlight clear")
  vim.g.colors_name = M.name(style)
  base_highlights(p)
  document_highlights(p)
  terminal_colors(p)

  vim.api.nvim_exec_autocmds("ColorScheme", {
    modeline = false,
    pattern = vim.g.colors_name,
  })

  -- Algunos plugins recrean sus grupos durante ColorScheme; estas reglas son
  -- la frontera final que mantiene UI e iconos monocromáticos.
  M.refresh()

  for _, listener in ipairs(listeners) do
    pcall(listener, style, p)
  end
  vim.cmd("redraw")
  return true, style
end

function M.refresh()
  local p = M.palette()
  base_highlights(p)
  document_highlights(p)
  terminal_colors(p)
end

function M.lualine_theme()
  local p = M.palette()
  local function section(fg, bold)
    return {
      a = { fg = fg, bg = p.bg_alt, gui = bold and "bold" or nil },
      b = { fg = fg, bg = p.bg_alt },
      c = { fg = fg, bg = p.bg_alt },
    }
  end
  return {
    normal = section(p.fg, true),
    insert = section(p.fg, true),
    visual = section(p.fg, true),
    replace = section(p.fg, true),
    command = section(p.fg, true),
    terminal = section(p.fg, true),
    inactive = section(p.muted, false),
  }
end

function M.on_change(callback)
  listeners[#listeners + 1] = callback
end

function M.setup()
  local settings = require("writing.settings")
  local style = settings.theme_variant == "light" and "light" or "dark"
  M.apply(style)
  local group = vim.api.nvim_create_augroup("nvim-writing-theme", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "LazyLoad",
    callback = function()
      vim.schedule(M.refresh)
    end,
    desc = "Reaplicar UI monocromática después de cargar un plugin",
  })
end

return M
