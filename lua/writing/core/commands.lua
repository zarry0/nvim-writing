local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "nvim-writing" })
end

local function insert_citation()
  local project = require("writing.core.project")
  local context, error_message = project.require_valid(0)
  if not context then
    notify(error_message, vim.log.levels.ERROR)
    return
  end
  if not context.bibliography or vim.uv.fs_stat(context.bibliography) == nil then
    notify("No se encontró references.bib", vim.log.levels.ERROR)
    return
  end

  local entries = {}
  local seen = {}
  for line in io.lines(context.bibliography) do
    local kind, key = line:match("^%s*@([%w_-]+)%s*{%s*([^,%s]+)%s*,")
    kind = kind and kind:lower() or nil
    if key and not ({ comment = true, preamble = true, string = true })[kind] and not seen[key] then
      seen[key] = true
      entries[#entries + 1] = { key = key, kind = kind }
    end
  end
  table.sort(entries, function(a, b)
    return a.key < b.key
  end)
  if #entries == 0 then
    notify("La bibliografía no contiene entradas", vim.log.levels.WARN)
    return
  end

  vim.ui.select(entries, {
    prompt = "Cita: ",
    format_item = function(item)
      return item.key .. " [" .. item.kind .. "]"
    end,
  }, function(choice)
    if not choice then
      return
    end
    local insertion
    if vim.bo.filetype == "typst" then
      insertion = "@" .. choice.key
    elseif vim.bo.filetype == "tex" or vim.bo.filetype == "plaintex" then
      insertion = "\\cite{" .. choice.key .. "}"
    else
      insertion = "[@" .. choice.key .. "]"
    end
    vim.api.nvim_put({ insertion }, "c", true, true)
  end)
end

local function is_markdown_extension(extension)
  return extension == "md" or extension == "markdown"
end

local function preview()
  local context, error_message = require("writing.core.project").require_valid(0)
  if not context then
    notify(error_message, vim.log.levels.ERROR)
    return
  end

  local extension = vim.fn.fnamemodify(context.main, ":e"):lower()
  if extension == "typ" then
    if vim.fn.exists(":TypstPreview") ~= 2 then
      notify("typst-preview.nvim aún no está disponible", vim.log.levels.ERROR)
      return
    end
    vim.api.nvim_cmd({ cmd = "TypstPreview" }, {})
    return
  end

  if is_markdown_extension(extension) then
    if vim.fn.exists(":LivePreview") ~= 2 then
      notify("live-preview.nvim aún no está disponible", vim.log.levels.ERROR)
      return
    end
    vim.api.nvim_cmd({ cmd = "LivePreview", args = { "start", context.main } }, {})
    return
  end

  notify("El preview live está disponible para Markdown y Typst", vim.log.levels.ERROR)
end

local function preview_stop()
  local livepreview = package.loaded["livepreview"]
  if livepreview and livepreview.is_running() then
    vim.api.nvim_cmd({ cmd = "LivePreview", args = { "close" } }, {})
    return
  end

  local context = require("writing.core.project").resolve(0)
  local extension = context.main and vim.fn.fnamemodify(context.main, ":e"):lower() or ""

  if extension == "typ" and vim.fn.exists(":TypstPreviewStop") == 2 then
    vim.api.nvim_cmd({ cmd = "TypstPreviewStop" }, {})
    return
  end

  notify("No hay un preview activo compatible con este documento", vim.log.levels.WARN)
end

local function export_picker(opts)
  local function run(kind)
    if kind then
      require("writing.core.process").export(kind, { write_modified = opts.bang })
    end
  end
  if opts.args == "" then
    vim.ui.select({ "pdf", "docx" }, { prompt = "Formato: " }, run)
  else
    run(opts.args)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("WriteNew", function(opts)
    require("writing.core.templates").command(opts)
  end, {
    nargs = "*",
    complete = function()
      return require("writing.core.templates").list()
    end,
    desc = "Crear proyecto desde una plantilla",
  })

  vim.api.nvim_create_user_command("WriteRoot", function()
    local project = require("writing.core.project")
    notify(table.concat(project.display(project.resolve(0)), "\n"))
  end, { desc = "Mostrar contexto del documento" })

  vim.api.nvim_create_user_command("WritePreview", preview, {
    desc = "Iniciar preview live de Markdown o Typst",
  })

  vim.api.nvim_create_user_command("WritePreviewStop", preview_stop, {
    desc = "Detener preview live de Markdown o Typst",
  })

  vim.api.nvim_create_user_command("WriteBuild", function(opts)
    require("writing.core.process").build({ write_modified = opts.bang })
  end, { bang = true, desc = "Compilar salida principal" })

  vim.api.nvim_create_user_command("WriteExport", export_picker, {
    nargs = "?",
    bang = true,
    complete = function()
      return { "pdf", "docx" }
    end,
    desc = "Exportar PDF o DOCX",
  })

  vim.api.nvim_create_user_command("WriteLanguage", function(opts)
    require("writing.core.language").command(opts)
  end, {
    nargs = "?",
    bang = true,
    complete = function()
      return require("writing.core.language").names()
    end,
    desc = "Seleccionar idioma del documento",
  })

  vim.api.nvim_create_user_command("WriteCitation", insert_citation, {
    desc = "Buscar e insertar una cita",
  })

  vim.api.nvim_create_user_command("WriteTheme", function(opts)
    local requested = opts.args ~= "" and opts.args or "toggle"
    local ok, result = require("writing.core.theme").apply(requested)
    if ok then
      notify("Tema: " .. result)
    else
      notify(result, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    complete = function()
      return { "dark", "light", "toggle" }
    end,
    desc = "Cambiar tema claro u oscuro",
  })

  vim.api.nvim_create_user_command("WriteGoogle", function(opts)
    require("writing.core.lookup").google(opts.args)
  end, {
    nargs = "*",
    desc = "Buscar palabra o consulta en Google",
  })

  vim.api.nvim_create_user_command("WriteDictionary", function(opts)
    local arguments = vim.list_slice(opts.fargs)
    local language
    if arguments[1] == "es" or arguments[1] == "en" then
      language = table.remove(arguments, 1)
    end
    require("writing.core.lookup").dictionary(language, table.concat(arguments, " "))
  end, {
    nargs = "*",
    complete = function()
      return { "es", "en" }
    end,
    desc = "Consultar palabra en el diccionario",
  })

  vim.api.nvim_create_user_command("WriteFocus", function()
    if not _G.Snacks then
      notify("Snacks aún no está disponible", vim.log.levels.ERROR)
      return
    end
    Snacks.zen()
  end, { desc = "Alternar modo de concentración" })

  vim.api.nvim_create_user_command("WriteHealth", function()
    vim.api.nvim_cmd({ cmd = "checkhealth", args = { "writing" } }, {})
  end, { desc = "Revisar el perfil de escritura" })

  local map = vim.keymap.set
  map("n", "<leader>wn", "<cmd>WriteNew<CR>", { desc = "Writing: nuevo proyecto" })
  map("n", "<leader>wp", "<cmd>WritePreview<CR>", { desc = "Writing: iniciar preview" })
  map("n", "<leader>wP", "<cmd>WritePreviewStop<CR>", { desc = "Writing: detener preview" })
  map("n", "<leader>wb", "<cmd>WriteBuild<CR>", { desc = "Writing: compilar" })
  map("n", "<leader>wep", "<cmd>WriteExport pdf<CR>", { desc = "Writing: exportar PDF" })
  map("n", "<leader>wed", "<cmd>WriteExport docx<CR>", { desc = "Writing: exportar DOCX" })
  map("n", "<leader>wl", "<cmd>WriteLanguage<CR>", { desc = "Writing: idioma" })
  map("n", "<leader>wc", "<cmd>WriteCitation<CR>", { desc = "Writing: cita" })
  map("n", "<leader>wt", "<cmd>WriteTheme toggle<CR>", { desc = "Writing: alternar tema" })
  map("n", "<leader>wg", function()
    require("writing.core.lookup").google(nil, false)
  end, { desc = "Writing: buscar en Google" })
  map("x", "<leader>wg", function()
    require("writing.core.lookup").google(nil, true)
  end, { desc = "Writing: buscar selección en Google" })
  map("n", "<leader>wd", function()
    require("writing.core.lookup").dictionary(nil, nil, false)
  end, { desc = "Writing: consultar diccionario" })
  map("x", "<leader>wd", function()
    require("writing.core.lookup").dictionary(nil, nil, true)
  end, { desc = "Writing: consultar selección en diccionario" })
  map("n", "<leader>wr", "<cmd>WriteRoot<CR>", { desc = "Writing: mostrar raíz" })
  map("n", "<leader>wf", "<cmd>WriteFocus<CR>", { desc = "Writing: concentración" })
  map("n", "<leader>wh", "<cmd>WriteHealth<CR>", { desc = "Writing: health" })
end

return M
