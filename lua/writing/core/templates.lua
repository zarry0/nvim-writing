local M = {}

local uv = vim.uv or vim.loop
local registry = {
  ["markdown-document"] = { path = { "markdown", "document" }, main = "main.md" },
  ["markdown-essay"] = { path = { "markdown", "essay" }, main = "main.md" },
  ["typst-document"] = { path = { "typst", "document" }, main = "main.typ" },
  ["typst-essay"] = { path = { "typst", "essay" }, main = "main.typ" },
  ["typst-screenplay"] = { path = { "typst", "screenplay" }, main = "main.typ" },
}
local aliases = {
  document = "typst-document",
  essay = "typst-essay",
  screenplay = "typst-screenplay",
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "WriteNew" })
end

function M.list()
  local names = vim.tbl_keys(registry)
  table.sort(names)
  return names
end

local function template_path(name)
  name = aliases[name] or name
  local item = registry[name]
  if not item then
    return nil, "Plantilla desconocida: " .. tostring(name)
  end
  return vim.fs.joinpath(vim.fn.stdpath("config"), "templates", unpack(item.path)), item
end

local function forbidden_destination(path)
  local project = require("writing.core.project")
  for _, base in ipairs({
    vim.fn.stdpath("config"),
    vim.fn.stdpath("data"),
    vim.fn.stdpath("state"),
    vim.fn.stdpath("cache"),
  }) do
    if project.is_inside(base, path) or project.is_real_inside(base, path) then
      return true
    end
  end
  return false
end

local function copy_tree(source, destination)
  if not uv.fs_stat(destination) then
    local ok, error_message = uv.fs_mkdir(destination, 493)
    if not ok then
      return nil, error_message
    end
  end

  local scanner, scan_error = uv.fs_scandir(source)
  if not scanner then
    return nil, scan_error
  end

  while true do
    local name, kind = uv.fs_scandir_next(scanner)
    if not name then
      break
    end
    local from = vim.fs.joinpath(source, name)
    local to = vim.fs.joinpath(destination, name)
    if kind == "directory" then
      local child_ok, child_error = copy_tree(from, to)
      if not child_ok then
        return nil, child_error
      end
    elseif kind == "file" then
      if uv.fs_lstat(to) then
        return nil, "Colisión al copiar la plantilla: " .. to
      end
      local copied, copy_error = uv.fs_copyfile(from, to)
      if not copied then
        return nil, copy_error
      end
    else
      return nil, "La plantilla contiene un tipo de archivo no permitido: " .. from
    end
  end
  return true
end

local function remove_tree(path)
  local scanner = uv.fs_scandir(path)
  if scanner then
    while true do
      local name, kind = uv.fs_scandir_next(scanner)
      if not name then
        break
      end
      local child = vim.fs.joinpath(path, name)
      if kind == "directory" then
        remove_tree(child)
      else
        uv.fs_unlink(child)
      end
    end
  end
  uv.fs_rmdir(path)
end

function M.create(name, destination)
  name = aliases[name] or name
  local source, item_or_error = template_path(name)
  if not source then
    return nil, item_or_error
  end
  local item = item_or_error
  if not uv.fs_stat(source) then
    return nil, "No existe la plantilla maestra: " .. source
  end

  destination = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(destination), ":p")):gsub("/$", "")
  if forbidden_destination(destination) then
    return nil, "El destino no puede estar dentro de la configuración o su runtime"
  end
  if uv.fs_lstat(destination) then
    return nil, "El destino ya existe; WriteNew nunca sobrescribe"
  end

  local parent = vim.fs.dirname(destination)
  if not uv.fs_stat(parent) then
    vim.fn.mkdir(parent, "p")
  end
  local parent_stat = uv.fs_stat(parent)
  if not parent_stat or parent_stat.type ~= "directory" then
    return nil, "El directorio padre no es válido: " .. parent
  end

  local temporary, temp_error = uv.fs_mkdtemp(vim.fs.joinpath(parent, ".nvim-writing-XXXXXX"))
  if not temporary then
    return nil, temp_error
  end
  local copied, copy_error = copy_tree(source, temporary)
  if not copied then
    remove_tree(temporary)
    return nil, "No se pudo copiar la plantilla: " .. tostring(copy_error)
  end
  if forbidden_destination(destination) then
    remove_tree(temporary)
    return nil, "El destino resolvió dentro de la configuración o su runtime"
  end
  if uv.fs_lstat(destination) then
    remove_tree(temporary)
    return nil, "El destino apareció durante la copia; WriteNew no sobrescribió"
  end
  local renamed, rename_error = uv.fs_rename(temporary, destination)
  if not renamed then
    remove_tree(temporary)
    return nil, "No se pudo crear el proyecto: " .. tostring(rename_error)
  end

  local main = vim.fs.joinpath(destination, item.main)
  vim.api.nvim_cmd({ cmd = "edit", args = { main } }, {})
  notify("Proyecto creado en " .. destination)
  return destination
end

local function request_destination(name)
  vim.ui.input({ prompt = "Directorio destino: ", default = (uv.cwd() or ".") .. "/" }, function(value)
    if not value or value == "" then
      return
    end
    local _, error_message = M.create(name, value)
    if error_message then
      notify(error_message, vim.log.levels.ERROR)
    end
  end)
end

function M.command(opts)
  local args = opts.fargs
  local name = args[1]
  if not name then
    vim.ui.select(M.list(), { prompt = "Plantilla: " }, function(choice)
      if choice then
        request_destination(choice)
      end
    end)
    return
  end
  name = aliases[name] or name
  if not registry[name] then
    notify("Plantilla desconocida: " .. name, vim.log.levels.ERROR)
    return
  end
  local destination = table.concat(args, " ", 2)
  if destination == "" then
    request_destination(name)
    return
  end
  local _, error_message = M.create(name, destination)
  if error_message then
    notify(error_message, vim.log.levels.ERROR)
  end
end

return M
