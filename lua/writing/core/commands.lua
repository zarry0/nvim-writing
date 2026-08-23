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

local function preview()
  local context, error_message = require("writing.core.project").require_valid(0)
  if not context then
    notify(error_message, vim.log.levels.ERROR)
    return
  end
  if vim.fn.fnamemodify(context.main, ":e") ~= "typ" then
    notify("El preview live está disponible para Typst", vim.log.levels.ERROR)
    return
  end
  if vim.fn.exists(":TypstPreviewToggle") ~= 2 then
    notify("typst-preview.nvim aún no está disponible", vim.log.levels.ERROR)
    return
  end
  vim.api.nvim_cmd({ cmd = "TypstPreviewToggle" }, {})
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
    desc = "Alternar preview live de Typst",
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
  map("n", "<leader>wp", "<cmd>WritePreview<CR>", { desc = "Writing: preview" })
  map("n", "<leader>wb", "<cmd>WriteBuild<CR>", { desc = "Writing: compilar" })
  map("n", "<leader>wep", "<cmd>WriteExport pdf<CR>", { desc = "Writing: exportar PDF" })
  map("n", "<leader>wed", "<cmd>WriteExport docx<CR>", { desc = "Writing: exportar DOCX" })
  map("n", "<leader>wl", "<cmd>WriteLanguage<CR>", { desc = "Writing: idioma" })
  map("n", "<leader>wc", "<cmd>WriteCitation<CR>", { desc = "Writing: cita" })
  map("n", "<leader>wr", "<cmd>WriteRoot<CR>", { desc = "Writing: mostrar raíz" })
  map("n", "<leader>wf", "<cmd>WriteFocus<CR>", { desc = "Writing: concentración" })
  map("n", "<leader>wh", "<cmd>WriteHealth<CR>", { desc = "Writing: health" })
end

return M
