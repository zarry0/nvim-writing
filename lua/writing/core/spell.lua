local M = {}

local uv = vim.uv or vim.loop
local namespace = vim.api.nvim_create_namespace("nvim-writing-spell-ignore")
local states = {}
local synchronize_ltex
local supported_filetypes = { text = true, markdown = true, typst = true, tex = true, plaintex = true }
local sidecar_name = ".nvim-writing-spell.json"
local maximum_sidecar_size = 64 * 1024
local maximum_words_per_file = 1024
local maximum_punctuated_words_per_file = 32
local maximum_word_bytes = 256

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Ortografía" })
end

local function normalize_word(text)
  text = vim.trim((text or ""):gsub("%s+", " "))
  if text == "" then
    return nil, "No hay una palabra o selección"
  end
  if text:find("%s") then
    return nil, "Selecciona una sola palabra"
  end
  if #text > maximum_word_bytes or text:find("[%z\1-\31]") then
    return nil, "La palabra no es válida para la lista ortográfica"
  end
  return text, nil
end

local function visual_text()
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
  return table.concat(lines, " ")
end

local function subject(query, visual)
  if query and query ~= "" then
    return normalize_word(query)
  end
  return normalize_word(visual and visual_text() or vim.fn.expand("<cword>"))
end

local function personal_subject(query, visual)
  local word, word_error = subject(query, visual)
  if not word then
    return nil, word_error
  end
  if word:find("/", 1, true) or word:sub(1, 1) == "#" then
    return nil, "La palabra contiene sintaxis reservada de spellfile"
  end
  return word, nil
end

local function wordlist_root()
  return vim.fs.joinpath(vim.fn.stdpath("config"), "wordlists")
end

local function language_targets(bufnr)
  local found = {}
  for token in vim.bo[bufnr].spelllang:gmatch("[^,]+") do
    token = token:lower()
    if (token == "es" or token:match("^es[_-]")) and not found.es then
      found.es = {
        id = "es",
        label = "Español",
        ltex = "es-ES",
        path = vim.fs.joinpath(wordlist_root(), "es.utf-8.add"),
      }
    elseif (token == "en" or token:match("^en[_-]")) and not found.en then
      found.en = {
        id = "en",
        label = "English",
        ltex = "en-US",
        path = vim.fs.joinpath(wordlist_root(), "en.utf-8.add"),
      }
    end
  end

  local targets = {}
  for _, id in ipairs({ "es", "en" }) do
    if found[id] then
      targets[#targets + 1] = found[id]
    end
  end
  return targets
end

function M.configure(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or (bufnr or vim.api.nvim_get_current_buf())
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local paths = vim.tbl_map(function(target)
    return target.path
  end, language_targets(bufnr))
  vim.api.nvim_buf_call(bufnr, function()
    vim.opt_local.spellfile = paths
  end)
end

local function read_wordlist(path)
  local words = {}
  local seen = {}
  local file = io.open(path, "r")
  if not file then
    return words
  end
  for line in file:lines() do
    line = vim.trim(line)
    if line ~= "" and not line:match("^#") then
      local word = vim.trim(line:match("^([^/]+)") or "")
      if word ~= "" and not seen[word] then
        seen[word] = true
        words[#words + 1] = word
      end
    end
  end
  file:close()
  table.sort(words)
  return words
end

function M.ltex_dictionary()
  return {
    ["es-ES"] = read_wordlist(vim.fs.joinpath(wordlist_root(), "es.utf-8.add")),
    ["en-US"] = read_wordlist(vim.fs.joinpath(wordlist_root(), "en.utf-8.add")),
  }
end

local function refresh_ltex_dictionary()
  local dictionary = M.ltex_dictionary()
  for _, client in ipairs(vim.lsp.get_clients({ name = "ltex_plus" })) do
    client.settings = client.settings or {}
    client.settings.ltex = client.settings.ltex or {}
    client.settings.ltex.dictionary = dictionary
    client.config.settings = client.settings
    client:notify("workspace/didChangeConfiguration", { settings = client.settings })
  end
end

local function run_spell_command(bufnr, command, word, target)
  local paths = {}
  vim.api.nvim_buf_call(bufnr, function()
    paths = vim.opt_local.spellfile:get()
  end)
  local index
  for position, path in ipairs(paths) do
    if vim.fs.normalize(path) == vim.fs.normalize(target.path) then
      index = position
      break
    end
  end
  if not index then
    notify("No se encontró la lista " .. target.label, vim.log.levels.ERROR)
    return false
  end

  local ok, error_message = pcall(vim.api.nvim_buf_call, bufnr, function()
    vim.api.nvim_cmd({ cmd = command, range = { index }, args = { word } }, {})
  end)
  if not ok then
    notify("No se pudo actualizar la lista: " .. tostring(error_message), vim.log.levels.ERROR)
    return false
  end
  refresh_ltex_dictionary()
  return true
end

local function personal(action, query, visual)
  local bufnr = vim.api.nvim_get_current_buf()
  if not vim.wo.spell then
    notify("El corrector ortográfico está desactivado", vim.log.levels.WARN)
    return false
  end
  local word, word_error = personal_subject(query, visual)
  if not word then
    notify(word_error, vim.log.levels.WARN)
    return false
  end
  local targets = language_targets(bufnr)
  if #targets == 0 then
    notify("El idioma actual no tiene una lista personal configurada", vim.log.levels.WARN)
    return false
  end
  M.configure(bufnr)

  local command = action == "add" and "spellgood" or "spellundo"
  local verb = action == "add" and "añadida" or "eliminada"
  local function apply(target)
    if target and run_spell_command(bufnr, command, word, target) then
      notify(string.format("%s %s de la lista %s", word, verb, target.label))
    end
  end

  if #targets == 1 then
    apply(targets[1])
  else
    vim.ui.select(targets, {
      prompt = action == "add" and "Añadir al idioma: " or "Eliminar del idioma: ",
      format_item = function(item)
        return item.label
      end,
    }, apply)
  end
  return true
end

function M.add_personal(query, visual)
  return personal("add", query, visual)
end

function M.remove_personal(query, visual)
  return personal("remove", query, visual)
end

local function is_safe_relative(path)
  if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" or path:match("^%a:[/\\]") then
    return false
  end
  for segment in path:gmatch("[^/\\]+") do
    if segment == ".." then
      return false
    end
  end
  return true
end

local function validate_store(store)
  if type(store) ~= "table" or store.schemaVersion ~= 1 or type(store.files) ~= "table" then
    return nil, "El sidecar ortográfico no usa schemaVersion 1"
  end
  for relative, words in pairs(store.files) do
    if not is_safe_relative(relative) or not vim.islist(words) or #words > maximum_words_per_file then
      return nil, "El sidecar ortográfico contiene una entrada inválida"
    end
    local seen = {}
    local punctuated = 0
    for _, word in ipairs(words) do
      local normalized = normalize_word(word)
      if not normalized or normalized ~= word or seen[word] then
        return nil, "El sidecar ortográfico contiene una palabra inválida"
      end
      seen[word] = true
      if vim.fn.match(word, "\\%#=2[^[:lower:][:upper:][:digit:]_]") >= 0 then
        punctuated = punctuated + 1
      end
    end
    if punctuated > maximum_punctuated_words_per_file then
      return nil, "El sidecar ortográfico contiene demasiados términos con puntuación"
    end
  end
  return store, nil
end

local function read_regular_contents(path)
  local stat = uv.fs_lstat(path)
  if not stat then
    return false, nil
  end
  if stat.type ~= "file" then
    return nil, sidecar_name .. " debe ser un archivo regular, no un symlink o directorio"
  end
  if stat.size > maximum_sidecar_size then
    return nil, sidecar_name .. " supera 64 KiB"
  end
  local file, open_error = io.open(path, "r")
  if not file then
    return nil, "No se pudo leer " .. sidecar_name .. ": " .. tostring(open_error)
  end
  local contents = file:read("*a")
  file:close()
  return contents, nil
end

local function read_store(path)
  local contents, read_error = read_regular_contents(path)
  if read_error then
    return nil, read_error, nil
  end
  if contents == false then
    return { schemaVersion = 1, files = {} }, nil, false
  end
  local ok, decoded = pcall(vim.json.decode, contents)
  if not ok then
    return nil, sidecar_name .. " no contiene JSON válido", nil
  end
  local store, validation_error = validate_store(decoded)
  return store, validation_error, validation_error and nil or contents
end

local function content_is_unchanged(path, expected)
  local current, read_error = read_regular_contents(path)
  if read_error then
    return nil, read_error
  end
  if current ~= expected then
    return nil, sidecar_name .. " cambió desde que se leyó y no se sobrescribirá"
  end
  return true, nil
end

local function write_store(path, store, expected_contents)
  local valid, validation_error = validate_store(store)
  if not valid then
    return nil, validation_error
  end
  local unchanged, change_error = content_is_unchanged(path, expected_contents)
  if not unchanged then
    return nil, change_error
  end
  local contents = vim.json.encode(store) .. "\n"
  if #contents > maximum_sidecar_size then
    return nil, sidecar_name .. " superaría 64 KiB"
  end
  local temporary = string.format("%s.tmp.%d.%s", path, vim.fn.getpid(), tostring(uv.hrtime()))
  local descriptor, open_error = uv.fs_open(temporary, "wx", 384)
  if not descriptor then
    return nil, "No se pudo crear el temporal ortográfico: " .. tostring(open_error)
  end
  local offset = 0
  local write_error
  while offset < #contents do
    local written
    written, write_error = uv.fs_write(descriptor, contents:sub(offset + 1), offset)
    if not written or written <= 0 then
      break
    end
    offset = offset + written
  end
  uv.fs_close(descriptor)
  if offset ~= #contents then
    uv.fs_unlink(temporary)
    return nil, "No se pudo escribir el sidecar ortográfico: " .. tostring(write_error)
  end
  unchanged, change_error = content_is_unchanged(path, expected_contents)
  if not unchanged then
    uv.fs_unlink(temporary)
    return nil, change_error
  end
  local renamed, rename_error = uv.fs_rename(temporary, path)
  if not renamed then
    uv.fs_unlink(temporary)
    return nil, "No se pudo publicar el sidecar ortográfico: " .. tostring(rename_error)
  end
  return true, nil
end

local function file_context(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil, "Guarda el archivo antes de crear una excepción local"
  end
  name = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
  local project = require("writing.core.project")
  local context = project.resolve(bufnr)
  if #context.errors > 0 or not project.is_real_inside(context.root, name) then
    return nil, "No se pudo establecer una raíz segura para la excepción"
  end
  local relative = vim.fs.relpath(context.root, name)
  if not is_safe_relative(relative) then
    return nil, "El archivo no pertenece a la raíz de escritura"
  end
  local path = vim.fs.joinpath(context.root, sidecar_name)
  if not project.is_real_inside(context.root, path) then
    return nil, "El sidecar ortográfico escaparía de la raíz"
  end
  return { root = context.root, relative = relative, path = path }, nil
end

local function word_pattern(word)
  local characters = vim.fn.strchars(word)
  local first = vim.fn.strcharpart(word, 0, 1)
  local last = vim.fn.strcharpart(word, characters - 1, 1)
  local prefix = vim.fn.match(first, "\\k") == 0 and "\\<" or ""
  local suffix = vim.fn.match(last, "\\k") == 0 and "\\>" or ""
  return "\\V" .. prefix .. word:gsub("\\", "\\\\") .. suffix
end

local function apply_marks(bufnr)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  local state = states[bufnr]
  if not state or #state.words == 0 then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  vim.api.nvim_buf_call(bufnr, function()
    local keyword_words = {}
    local punctuated_words = {}
    for _, word in ipairs(state.words) do
      if vim.fn.match(word, "^\\k\\+$") == 0 then
        keyword_words[word] = true
      else
        punctuated_words[#punctuated_words + 1] = word
      end
    end

    local function mark(row, first, last)
      vim.api.nvim_buf_set_extmark(bufnr, namespace, row - 1, first, {
        end_row = row - 1,
        end_col = last,
        spell = false,
        priority = 200,
      })
    end

    for row, line in ipairs(lines) do
      if next(keyword_words) then
        local start = 0
        while start <= #line do
          local match = vim.fn.matchstrpos(line, "\\k\\+", start)
          local first, last = match[2], match[3]
          if first < 0 or last <= first then
            break
          end
          if keyword_words[match[1]] then
            mark(row, first, last)
          end
          start = last
        end
      end

      for _, word in ipairs(punctuated_words) do
        local pattern = word_pattern(word)
        local start = 0
        while start <= #line do
          local match = vim.fn.matchstrpos(line, pattern, start)
          local first, last = match[2], match[3]
          if first < 0 or last <= first then
            break
          end
          mark(row, first, last)
          start = last
        end
      end
    end
  end)
end

local function load_file_ignores(bufnr, report_errors)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local previous_words = vim.deepcopy(states[bufnr] and states[bufnr].words or {})
  if not supported_filetypes[vim.bo[bufnr].filetype] then
    states[bufnr] = nil
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    if #previous_words > 0 and synchronize_ltex then
      synchronize_ltex(bufnr)
    end
    return
  end
  local context, context_error = file_context(bufnr)
  if not context then
    states[bufnr] = nil
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    if report_errors and vim.api.nvim_buf_get_name(bufnr) ~= "" then
      notify(context_error, vim.log.levels.WARN)
    end
    if #previous_words > 0 and synchronize_ltex then
      synchronize_ltex(bufnr)
    end
    return
  end
  local store, store_error = read_store(context.path)
  if not store then
    states[bufnr] = nil
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    if report_errors then
      notify(store_error, vim.log.levels.ERROR)
    end
    if #previous_words > 0 and synchronize_ltex then
      synchronize_ltex(bufnr)
    end
    return
  end
  local words = vim.deepcopy(store.files[context.relative] or {})
  states[bufnr] = { context = context, words = words }
  apply_marks(bufnr)
  if not vim.deep_equal(previous_words, words) and synchronize_ltex then
    synchronize_ltex(bufnr)
  end
end

local function schedule_marks(bufnr)
  local state = states[bufnr]
  if not state then
    return
  end
  state.generation = (state.generation or 0) + 1
  local generation = state.generation
  vim.defer_fn(function()
    if states[bufnr] == state and state.generation == generation then
      apply_marks(bufnr)
    end
  end, 120)
end

local function current_diagnostic_word(bufnr, diagnostic)
  if diagnostic.lnum ~= diagnostic.end_lnum then
    return nil
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, diagnostic.lnum, diagnostic.lnum + 1, false)[1]
  return line and line:sub(diagnostic.col + 1, diagnostic.end_col) or nil
end

local function is_spelling_diagnostic(diagnostic)
  local code = diagnostic.code
  if type(code) == "table" then
    code = code.value or code.code
  end
  return type(code) == "string" and code:match("^MORFOLOGIK_RULE_") ~= nil
end

local function filter_existing_ltex(bufnr)
  local ignored = {}
  for _, word in ipairs(states[bufnr] and states[bufnr].words or {}) do
    ignored[word] = true
  end
  if not next(ignored) then
    return
  end
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "ltex_plus" })) do
    local diagnostic_namespace = vim.lsp.diagnostic.get_namespace(client.id, false)
    local filtered = vim.tbl_filter(function(diagnostic)
      return not (is_spelling_diagnostic(diagnostic) and ignored[current_diagnostic_word(bufnr, diagnostic)])
    end, vim.diagnostic.get(bufnr, { namespace = diagnostic_namespace }))
    vim.diagnostic.set(diagnostic_namespace, bufnr, filtered)
  end
end

synchronize_ltex = function(bufnr)
  filter_existing_ltex(bufnr)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "ltex_plus" })) do
    client:notify("workspace/didChangeConfiguration", { settings = client.settings or {} })
  end
end

local function diagnostic_text(bufnr, range, encoding)
  if not range or range.start.line ~= range["end"].line then
    return nil
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line + 1, false)[1]
  if not line then
    return nil
  end
  local first = vim.str_byteindex(line, encoding, range.start.character, false)
  local last = vim.str_byteindex(line, encoding, range["end"].character, false)
  return line:sub(first + 1, last)
end

local function install_ltex_filter()
  local previous = vim.lsp.handlers["textDocument/publishDiagnostics"]
  vim.lsp.handlers["textDocument/publishDiagnostics"] = function(error_message, result, context, config)
    local client = context and vim.lsp.get_client_by_id(context.client_id) or nil
    if not error_message and result and client and client.name == "ltex_plus" and result.uri then
      local bufnr = vim.uri_to_bufnr(result.uri)
      local ignored = {}
      for _, word in ipairs(states[bufnr] and states[bufnr].words or {}) do
        ignored[word] = true
      end
      if next(ignored) then
        result = vim.deepcopy(result)
        result.diagnostics = vim.tbl_filter(function(diagnostic)
          return not (
            is_spelling_diagnostic(diagnostic)
            and ignored[diagnostic_text(bufnr, diagnostic.range, client.offset_encoding or "utf-16")]
          )
        end, result.diagnostics or {})
      end
    end
    return previous(error_message, result, context, config)
  end
end

local function update_file_ignore(action, query, visual)
  local bufnr = vim.api.nvim_get_current_buf()
  if not supported_filetypes[vim.bo[bufnr].filetype] then
    notify("Este tipo de archivo no admite excepciones ortográficas locales", vim.log.levels.WARN)
    return false
  end
  local word, word_error = subject(query, visual)
  if not word then
    notify(word_error, vim.log.levels.WARN)
    return false
  end
  local context, context_error = file_context(bufnr)
  if not context then
    notify(context_error, vim.log.levels.ERROR)
    return false
  end
  local store, store_error, original_contents = read_store(context.path)
  if not store then
    states[bufnr] = nil
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    synchronize_ltex(bufnr)
    notify(store_error .. "; no se modificó", vim.log.levels.ERROR)
    return false
  end
  local words = store.files[context.relative] or {}
  local index
  for position, existing in ipairs(words) do
    if existing == word then
      index = position
      break
    end
  end
  if action == "add" and not index then
    if #words >= maximum_words_per_file then
      notify("La lista local alcanzó su límite", vim.log.levels.ERROR)
      return false
    end
    words[#words + 1] = word
    table.sort(words)
  elseif action == "remove" and index then
    table.remove(words, index)
  elseif action == "add" then
    states[bufnr] = { context = context, words = vim.deepcopy(words) }
    apply_marks(bufnr)
    synchronize_ltex(bufnr)
    notify(word .. " ya estaba ignorada en este archivo")
    return true
  else
    states[bufnr] = { context = context, words = vim.deepcopy(words) }
    apply_marks(bufnr)
    synchronize_ltex(bufnr)
    notify(word .. " no estaba ignorada en este archivo", vim.log.levels.WARN)
    return false
  end
  store.files[context.relative] = words
  local written, write_error = write_store(context.path, store, original_contents)
  if not written then
    notify(write_error, vim.log.levels.ERROR)
    return false
  end
  states[bufnr] = { context = context, words = vim.deepcopy(words) }
  apply_marks(bufnr)
  synchronize_ltex(bufnr)
  notify(action == "add" and (word .. " se ignorará sólo en este archivo") or (word .. " vuelve a comprobarse"))
  return true
end

function M.ignore_file(query, visual)
  return update_file_ignore("add", query, visual)
end

function M.unignore_file(query, visual)
  return update_file_ignore("remove", query, visual)
end

function M.setup()
  install_ltex_filter()
  local group = vim.api.nvim_create_augroup("nvim-writing-spell", { clear = true })
  vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufWinEnter", "BufFilePost" }, {
    group = group,
    pattern = { "*" },
    callback = function(event)
      if supported_filetypes[vim.bo[event.buf].filetype] then
        M.configure(event.buf)
      end
      load_file_ignores(event.buf, false)
    end,
  })
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "spelllang",
    callback = function(event)
      local bufnr = event.buf
      if not bufnr or bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
      end
      -- Modelines run in a restricted context: changing spellfile there raises E523.
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
          M.configure(bufnr)
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    pattern = "*",
    callback = function(event)
      schedule_marks(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      load_file_ignores(vim.api.nvim_get_current_buf(), true)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(event)
      states[event.buf] = nil
    end,
  })
end

M.namespace = namespace
M.load_file_ignores = load_file_ignores
M.filter_existing_ltex = filter_existing_ltex
M._test = {
  is_spelling_diagnostic = is_spelling_diagnostic,
  personal_subject = personal_subject,
  run_spell_command = run_spell_command,
}

return M
