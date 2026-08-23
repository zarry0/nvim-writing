local M = {}

local project = require("writing.core.project")
local uv = vim.uv or vim.loop
local active = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "nvim-writing" })
end

local function executable(name)
  if vim.fn.executable(name) ~= 1 then
    notify("Falta la dependencia externa: " .. name, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function quickfix(title, output)
  local lines = vim.split(output or "Error sin salida", "\n", { trimempty = true })
  vim.fn.setqflist({}, "r", { title = title, lines = lines })
  vim.cmd.copen()
end

local function run(kind, argv, context, expected_output, callback)
  local key = context.root .. "\0" .. kind
  if active[key] then
    notify("Ya hay una operación " .. kind .. " en curso", vim.log.levels.WARN)
    return
  end

  active[key] = true
  notify("Ejecutando " .. kind .. "…")
  vim.system(argv, { cwd = context.root, text = true }, function(result)
    vim.schedule(function()
      active[key] = nil
      if result.code ~= 0 then
        local output = (result.stderr or "") .. "\n" .. (result.stdout or "")
        notify(kind .. " falló; revisa quickfix", vim.log.levels.ERROR)
        quickfix("Write " .. kind, output)
        return
      end
      if expected_output and not uv.fs_stat(expected_output) then
        notify(kind .. " terminó sin crear " .. expected_output, vim.log.levels.ERROR)
        return
      end
      notify(kind .. " terminado: " .. (expected_output or "ok"))
      if callback then
        callback(expected_output, result)
      end
    end)
  end)
end

local function modified_buffers(root)
  local found = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].modified then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" and project.is_inside(root, name) then
        found[#found + 1] = bufnr
      end
    end
  end
  return found
end

local function prepare(context, write_modified)
  local buffers = modified_buffers(context.root)
  if #buffers == 0 then
    return true
  end
  if not write_modified then
    notify("Hay buffers modificados en el proyecto; guarda o usa el comando con !", vim.log.levels.WARN)
    return false
  end
  for _, bufnr in ipairs(buffers) do
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd.write()
    end)
  end
  return true
end

local function pandoc_citation_args(argv, context)
  if context.bibliography and uv.fs_stat(context.bibliography) then
    vim.list_extend(argv, { "--citeproc", "--bibliography", context.bibliography })
  end
  if context.reference_doc and uv.fs_stat(context.reference_doc) then
    vim.list_extend(argv, { "--reference-doc", context.reference_doc })
  end
end

function M.export(kind, opts)
  opts = opts or {}
  local context, error_message = project.require_valid(0)
  if not context then
    notify(error_message, vim.log.levels.ERROR)
    return
  end
  if not prepare(context, opts.write_modified) then
    return
  end

  local extension = vim.fn.fnamemodify(context.main, ":e"):lower()
  local stem = vim.fn.fnamemodify(context.main, ":t:r")
  if not project.is_real_inside(context.root, context.build_dir) then
    notify("buildDir resolvió fuera del proyecto; se canceló la exportación", vim.log.levels.ERROR)
    return
  end
  vim.fn.mkdir(context.build_dir, "p")
  if not project.is_real_inside(context.root, context.build_dir) then
    notify("buildDir resolvió fuera del proyecto; se canceló la exportación", vim.log.levels.ERROR)
    return
  end

  if kind == "pdf" and extension == "typ" then
    if not executable("typst") then
      return
    end
    local output = vim.fs.joinpath(context.build_dir, stem .. ".pdf")
    run("PDF", { "typst", "compile", "--root", context.root, context.main, output }, context, output)
    return
  end

  if kind == "pdf" and extension == "md" then
    if not executable("pandoc") or not executable("typst") then
      return
    end
    local output = vim.fs.joinpath(context.build_dir, stem .. ".pdf")
    local argv = {
      "pandoc",
      "--from=markdown",
      "--standalone",
      "--pdf-engine=typst",
      "--resource-path=" .. context.root,
      "--output",
      output,
      context.main,
    }
    pandoc_citation_args(argv, context)
    run("PDF", argv, context, output)
    return
  end

  if kind == "docx" and (extension == "typ" or extension == "md") then
    if not executable("pandoc") then
      return
    end
    local output = vim.fs.joinpath(context.build_dir, stem .. ".docx")
    local argv = {
      "pandoc",
      "--from=" .. (extension == "typ" and "typst" or "markdown"),
      "--to=docx",
      "--standalone",
      "--resource-path=" .. context.root,
      "--output",
      output,
      context.main,
    }
    pandoc_citation_args(argv, context)
    if extension == "typ" then
      notify("DOCX desde Typst es una conversión semántica; el diseño puede variar", vim.log.levels.WARN)
    end
    run("DOCX", argv, context, output)
    return
  end

  notify("No hay exportador " .. kind .. " para ." .. extension, vim.log.levels.ERROR)
end

function M.build(opts)
  M.export("pdf", opts)
end

return M
