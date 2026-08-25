local M = {}

local states = {}
local disk_epoch = 0
local readers = {
  markdown = "markdown",
  typst = "typst",
  tex = "latex",
  plaintex = "latex",
}
local supported = { text = true, markdown = true, typst = true, tex = true, plaintex = true }

-- Force Vim's Unicode-aware regexp engine and use character classes that do
-- not depend on the active buffer's 'iskeyword' value.  This keeps async
-- Pandoc results deterministic even when the user changes buffers meanwhile.
local word_separator = [=[\%#=2[^[:lower:][:upper:][:digit:]]\+]=]

local function count_words(text)
  text = text:gsub("\194\160", " ")
  return #vim.fn.split(text, word_separator)
end

local function is_managed_text_modeline(line)
  return line:match("^%s*vim:%s+set%s+spell%s+spelllang=[^%s:]+%s*:%s*$")
    or line:match("^%s*vim:%s+set%s+nospell%s*:%s*$")
end

local function plain_text_source(source)
  local kept = {}
  for line in (source .. "\n"):gmatch("(.-)\n") do
    if not is_managed_text_modeline(line) then
      kept[#kept + 1] = line
    end
  end
  return table.concat(kept, "\n")
end

local function count_ast_words(payload)
  local ok, document = pcall(vim.json.decode, payload)
  if not ok or type(document) ~= "table" then
    return nil, "pandoc devolvió un AST JSON inválido"
  end

  local count = 0
  local function walk(node)
    if type(node) ~= "table" then
      return
    end
    if node.t == "Str" and type(node.c) == "string" then
      count = count + count_words(node.c)
      return
    end
    for _, value in pairs(node) do
      walk(value)
    end
  end
  walk(document.meta)
  walk(document.blocks)
  return count, nil
end

local function run_pandoc(reader, source, cwd, callback)
  local settings = require("writing.settings")
  if vim.fn.executable("pandoc") ~= 1 then
    callback(nil, "pandoc no está disponible")
    return nil
  end
  if #source > settings.word_count_max_source_bytes then
    callback(nil, "el buffer supera el límite del contador")
    return nil
  end

  local filter = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "pandoc-prose.lua")
  if not vim.uv.fs_stat(filter) then
    callback(nil, "falta scripts/pandoc-prose.lua")
    return nil
  end

  local directory = type(cwd) == "string" and cwd ~= "" and cwd or vim.uv.cwd()
  if not vim.uv.fs_stat(directory) then
    directory = vim.uv.cwd()
  end

  local ok, job = pcall(vim.system, {
    "pandoc",
    "--from=" .. reader,
    "--to=json",
    "--standalone",
    "--wrap=none",
    "--lua-filter=" .. filter,
  }, {
    cwd = directory,
    stdin = source,
    text = true,
    timeout = settings.word_count_timeout_ms,
  }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        local count, decode_error = count_ast_words(result.stdout or "")
        callback(count, decode_error)
      else
        local error_message = vim.trim(result.stderr or "")
        callback(nil, error_message ~= "" and error_message or ("pandoc terminó con " .. result.code))
      end
    end)
  end)

  if not ok then
    vim.schedule(function()
      callback(nil, tostring(job))
    end)
    return nil
  end
  return job
end

function M.compute(filetype, source, cwd, callback)
  if filetype == "text" then
    callback(count_words(plain_text_source(source)), nil)
    return nil
  end
  local reader = readers[filetype]
  if not reader then
    callback(nil, "filetype no compatible")
    return nil
  end
  return run_pandoc(reader, source, cwd, callback)
end

local function buffer_directory(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return vim.uv.cwd()
  end
  return vim.fs.dirname(vim.fs.normalize(name))
end

local function cache_key(bufnr)
  return table.concat({
    vim.api.nvim_buf_get_changedtick(bufnr),
    vim.bo[bufnr].filetype,
    disk_epoch,
  }, ":")
end

function M.refresh(bufnr, on_complete)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local filetype = vim.bo[bufnr].filetype
  if not supported[filetype] then
    states[bufnr] = nil
    return
  end

  local state = states[bufnr] or { generation = 0 }
  states[bufnr] = state
  local key = cache_key(bufnr)
  if state.result_key == key and state.count ~= nil and not state.error then
    state.stale = false
    if on_complete then
      on_complete(state.count, nil, false)
    end
    return
  end
  state.generation = state.generation + 1
  local generation = state.generation
  state.pending = true
  state.stale = state.count ~= nil
  state.scheduled_key = nil
  state.job_key = key

  if state.job then
    pcall(state.job.kill, state.job, 15)
    state.job = nil
  end

  local source = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") .. "\n"
  state.job = M.compute(filetype, source, buffer_directory(bufnr), function(count, error_message)
    local current = states[bufnr]
    if not current or current.generation ~= generation then
      return
    end
    current.job = nil
    current.job_key = nil
    current.pending = false
    current.error = error_message
    if count ~= nil then
      current.count = count
      current.result_key = key
      current.stale = vim.api.nvim_buf_is_loaded(bufnr) and cache_key(bufnr) ~= key
    else
      current.stale = current.count ~= nil
    end
    vim.cmd("redrawstatus")
    if on_complete then
      on_complete(current.count, current.error, current.stale)
    end
  end)
end

function M.schedule(bufnr, delay)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_loaded(bufnr) or not supported[vim.bo[bufnr].filetype] then
    return
  end

  local state = states[bufnr] or { generation = 0 }
  states[bufnr] = state
  local key = cache_key(bufnr)
  if state.result_key == key and state.count ~= nil and not state.error then
    state.stale = false
    return
  end
  if state.job_key == key or state.scheduled_key == key then
    return
  end
  state.schedule_id = (state.schedule_id or 0) + 1
  state.scheduled_key = key
  state.stale = state.count ~= nil
  vim.cmd("redrawstatus")
  local schedule_id = state.schedule_id
  vim.defer_fn(function()
    local current = states[bufnr]
    if current and current.schedule_id == schedule_id and vim.api.nvim_buf_is_loaded(bufnr) then
      current.scheduled_key = nil
      M.refresh(bufnr)
    end
  end, delay or require("writing.settings").word_count_debounce_ms)
end

function M.status()
  local bufnr = vim.api.nvim_get_current_buf()
  if not supported[vim.bo[bufnr].filetype] then
    return ""
  end
  local state = states[bufnr]
  if not state or state.count == nil then
    return "… palabras"
  end
  local prefix = state.stale and "~" or ""
  return string.format("%s%d %s", prefix, state.count, state.count == 1 and "palabra" or "palabras")
end

function M.last(bufnr)
  local state = states[bufnr or vim.api.nvim_get_current_buf()]
  return state and state.count or nil, state and state.error or nil, state and state.stale or false
end

local function schedule_event(event, delay)
  if vim.api.nvim_buf_is_loaded(event.buf) and supported[vim.bo[event.buf].filetype] then
    M.schedule(event.buf, delay)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("nvim-writing-word-count", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "text", "markdown", "typst", "tex", "plaintex" },
    callback = function(event)
      schedule_event(event, 0)
    end,
    desc = "Contar prosa renderizada según el filetype",
  })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function(event)
      schedule_event(event, 0)
    end,
    desc = "Contar prosa renderizada al enfocar",
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = group,
    callback = schedule_event,
    desc = "Actualizar conteo de prosa renderizada",
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(event)
      disk_epoch = disk_epoch + 1
      schedule_event(event)
    end,
    desc = "Invalidar conteos que pueden depender de imports guardados",
  })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function(event)
      disk_epoch = disk_epoch + 1
      schedule_event(event, 0)
    end,
    desc = "Invalidar dependencias que pudieron cambiar fuera de Neovim",
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(event)
      local state = states[event.buf]
      if state and state.job then
        pcall(state.job.kill, state.job, 15)
      end
      states[event.buf] = nil
    end,
    desc = "Liberar contador de prosa",
  })
  M.schedule(vim.api.nvim_get_current_buf(), 0)
end

M.count_words = count_words

return M
