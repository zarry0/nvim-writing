local M = {}

local settings = require("writing.settings")
local languages = {
  es = { spell = "es", ltex = "es-ES" },
  en = { spell = "en_us", ltex = "en-US" },
  both = { spell = "es,en_us", ltex = settings.primary_ltex_language },
  off = { spell = nil, ltex = nil },
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "WriteLanguage" })
end

function M.names()
  return { "es", "en", "both", "off" }
end

local function custom_wordlists(language)
  local root = vim.fs.joinpath(vim.fn.stdpath("config"), "wordlists")
  if language == "es" then
    return vim.fs.joinpath(root, "es.utf-8.add")
  elseif language == "en" then
    return vim.fs.joinpath(root, "en.utf-8.add")
  elseif language == "both" then
    return table.concat({
      vim.fs.joinpath(root, "es.utf-8.add"),
      vim.fs.joinpath(root, "en.utf-8.add"),
    }, ",")
  end
  return ""
end

local function notify_ltex(spec)
  local bufnr = vim.api.nvim_get_current_buf()
  local function update_client(client)
    client.settings = client.settings or {}
    client.settings.ltex = client.settings.ltex or {}
    client.settings.ltex.language = spec.ltex
    client.config.settings = client.settings
    client:notify("workspace/didChangeConfiguration", { settings = client.settings })
  end

  if not spec.ltex then
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "ltex_plus" })) do
      vim.lsp.buf_detach_client(bufnr, client.id)
    end
    return
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "ltex_plus" })
  if #clients == 0 and vim.lsp.config.ltex_plus then
    local config = vim.deepcopy(vim.lsp.config.ltex_plus)
    config.root_dir = require("writing.core.project").resolve(bufnr).root
    config.settings = config.settings or {}
    config.settings.ltex = config.settings.ltex or {}
    config.settings.ltex.language = spec.ltex
    local client_id = vim.lsp.start(config, { bufnr = bufnr })
    local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
    if client then
      update_client(client)
    end
    return
  end

  for _, client in ipairs(clients) do
    update_client(client)
  end
end

function M.apply(name)
  local spec = languages[name]
  if not spec then
    return nil, "Idioma desconocido: " .. tostring(name)
  end

  vim.b.writing_language = name
  if spec.spell then
    vim.opt_local.spell = true
    vim.opt_local.spelllang = spec.spell
    vim.opt_local.spellfile = custom_wordlists(name)
  else
    vim.opt_local.spell = false
    vim.opt_local.spellfile = ""
  end
  notify_ltex(spec)
  notify("Idioma del buffer: " .. name)
  return true
end

local function markers(filetype, name)
  local spec = languages[name]
  local spell = spec.spell and ("set spell spelllang=" .. spec.spell) or "set nospell"
  local ltex = spec.ltex and ("language=" .. spec.ltex) or "enabled=false"

  if filetype == "markdown" then
    return "<!-- vim: " .. spell .. ": -->", "<!-- LTeX: " .. ltex .. " -->", "<!-- nvim-writing: managed-ltex -->"
  elseif filetype == "typst" then
    return "// vim: " .. spell .. ":", "// LTeX: " .. ltex, "// nvim-writing: managed-ltex"
  elseif filetype == "tex" or filetype == "plaintex" then
    return "% vim: " .. spell .. ":", "% LTeX: " .. ltex, "% nvim-writing: managed-ltex"
  elseif filetype == "text" then
    return "vim: " .. spell .. ":", nil, nil
  end
  return nil, nil, nil
end

local function insertion_index(lines, filetype)
  if filetype ~= "markdown" or lines[1] ~= "---" then
    return 0
  end
  for index = 2, math.min(#lines, 100) do
    if lines[index] == "---" or lines[index] == "..." then
      return index
    end
  end
  return 0
end

local function is_modeline(line)
  return line:match("^%s*<!%-%- vim: .*spell")
    or line:match("^%s*// vim: .*spell")
    or line:match("^%s*%% vim: .*spell")
    or line:match("^%s*vim: .*spell")
end

local function is_managed_ltex_marker(lines, index)
  local line = lines[index]
  if line:match("nvim%-writing: managed%-ltex") then
    return true
  end
  local previous = lines[index - 1] or ""
  return previous:match("nvim%-writing: managed%-ltex") ~= nil and line:match("LTeX:") ~= nil
end

function M.persist(name)
  local modeline, ltex, managed_ltex = markers(vim.bo.filetype, name)
  if not modeline then
    return nil, "Este tipo de archivo no admite metadata persistente"
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local filtered = {}
  for index, line in ipairs(lines) do
    if not is_modeline(line) and not is_managed_ltex_marker(lines, index) then
      filtered[#filtered + 1] = line
    end
  end

  if vim.bo.filetype == "text" then
    if #filtered > 0 and filtered[#filtered] ~= "" then
      filtered[#filtered + 1] = ""
    end
    filtered[#filtered + 1] = modeline
  elseif vim.bo.filetype == "markdown" then
    local at = insertion_index(filtered, vim.bo.filetype)
    if ltex then
      table.insert(filtered, at + 1, managed_ltex)
      table.insert(filtered, at + 2, ltex)
      table.insert(filtered, at + 3, "")
    end
    if #filtered > 0 and filtered[#filtered] ~= "" then
      filtered[#filtered + 1] = ""
    end
    filtered[#filtered + 1] = modeline
  else
    local at = insertion_index(filtered, vim.bo.filetype)
    local additions = ltex and { modeline, managed_ltex, ltex, "" } or { modeline, "" }
    for offset = #additions, 1, -1 do
      table.insert(filtered, at + 1, additions[offset])
    end
  end

  vim.api.nvim_buf_set_lines(0, 0, -1, false, filtered)
  notify("Idioma persistido en el archivo: " .. name)
  return true
end

local function source_is_newer(source, compiled)
  local source_stat = vim.uv.fs_stat(source)
  local compiled_stat = vim.uv.fs_stat(compiled)
  if not source_stat then
    return false
  end
  if not compiled_stat then
    return true
  end
  if source_stat.mtime.sec ~= compiled_stat.mtime.sec then
    return source_stat.mtime.sec > compiled_stat.mtime.sec
  end
  return source_stat.mtime.nsec > compiled_stat.mtime.nsec
end

function M.ensure_wordlists()
  local root = vim.fs.joinpath(vim.fn.stdpath("config"), "wordlists")
  for _, language in ipairs({ "es", "en" }) do
    local source = vim.fs.joinpath(root, language .. ".utf-8.add")
    if source_is_newer(source, source .. ".spl") then
      local ok, error_message = pcall(vim.api.nvim_cmd, {
        cmd = "mkspell",
        bang = true,
        args = { source },
      }, { output = true })
      if not ok then
        notify("No se pudo compilar " .. source .. ": " .. tostring(error_message), vim.log.levels.WARN)
      end
    end
  end
end

function M.command(opts)
  local function select(name)
    if not name then
      return
    end
    local ok, error_message = M.apply(name)
    if not ok then
      notify(error_message, vim.log.levels.ERROR)
      return
    end
    if opts.bang then
      local persisted, persist_error = M.persist(name)
      if not persisted then
        notify(persist_error, vim.log.levels.ERROR)
      end
    end
  end

  if opts.args == "" then
    vim.ui.select(M.names(), { prompt = "Idioma: " }, select)
  else
    select(opts.args)
  end
end

return M
