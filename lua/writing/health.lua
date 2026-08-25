local M = {}

local settings = require("writing.settings")

local function version_of(executable)
  local result = vim.system({ executable, "--version" }, { text = true }):wait(3000)
  if result.code ~= 0 then
    return nil
  end
  return vim.split(result.stdout or "", "\n", { trimempty = true })[1]
end

local function meets_minimum(version_line, minimum)
  local version_string = version_line and version_line:match("%d+%.%d+%.?%d*")
  local parsed = version_string and vim.version.parse(version_string) or nil
  return parsed ~= nil and vim.version.ge(parsed, minimum)
end

function M.check()
  vim.health.start("nvim-writing")

  if vim.version.ge(vim.version(), { 0, 12, 4 }) then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("Se requiere Neovim " .. settings.required_neovim)
  end

  if vim.env.NVIM_APPNAME == "nvim-writing" then
    vim.health.ok("NVIM_APPNAME=nvim-writing")
  else
    vim.health.error("El perfil no está aislado: NVIM_APPNAME=" .. tostring(vim.env.NVIM_APPNAME))
  end

  vim.health.info("config: " .. vim.fn.stdpath("config"))
  vim.health.info("data: " .. vim.fn.stdpath("data"))
  vim.health.info("state: " .. vim.fn.stdpath("state"))
  vim.health.info("cache: " .. vim.fn.stdpath("cache"))

  for _, requirement in ipairs({
    { name = "git", critical = true },
    { name = "typst", critical = true },
    { name = "pandoc", critical = true, minimum = { 3, 10, 0 }, label = "3.10" },
    { name = "tree-sitter", critical = true, minimum = { 0, 26, 1 }, label = "0.26.1" },
    { name = "fzf" },
    { name = "rg" },
    { name = "fd" },
    { name = "lazygit" },
  }) do
    local executable = requirement.name
    if vim.fn.executable(executable) == 1 then
      local version_line = version_of(executable)
      if requirement.minimum and not meets_minimum(version_line, requirement.minimum) then
        vim.health.error(
          executable .. " debe ser >= " .. requirement.label .. "; detectado: " .. (version_line or "desconocido")
        )
      else
        vim.health.ok(executable .. ": " .. (version_line or "instalado"))
      end
    else
      local report = requirement.critical and vim.health.error or vim.health.warn
      report("No se encontró " .. executable)
    end
  end

  local prose_filter = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "pandoc-prose.lua")
  if vim.uv.fs_stat(prose_filter) then
    vim.health.ok("Filtro del contador semántico disponible")
  else
    vim.health.error("Falta scripts/pandoc-prose.lua")
  end

  local opener
  for _, candidate in ipairs(vim.fn.has("mac") == 1 and { "open" } or { "xdg-open", "gio" }) do
    if vim.fn.executable(candidate) == 1 then
      opener = candidate
      break
    end
  end
  if opener then
    vim.health.ok("Opener del navegador: " .. opener)
  else
    vim.health.warn("No se encontró un opener del navegador (xdg-open/gio en Linux)")
  end

  for _, executable in ipairs({ "tinymist", "ltex-ls-plus" }) do
    if vim.fn.executable(executable) == 1 then
      vim.health.ok(executable .. " disponible")
    else
      vim.health.warn(executable .. " no está disponible; revisa :Mason")
    end
  end

  if #vim.api.nvim_get_runtime_file("spell/es.utf-8.spl", false) > 0 then
    vim.health.ok("Diccionario español disponible")
  else
    vim.health.warn("Falta el diccionario español; ejecuta :set spelllang=es y acepta la descarga")
  end

  if #vim.api.nvim_get_runtime_file("spell/en.utf-8.spl", false) > 0 then
    vim.health.ok("Diccionario inglés disponible")
  else
    vim.health.warn("Falta el diccionario inglés")
  end

  for _, name in ipairs(require("writing.core.templates").list()) do
    vim.health.ok("Plantilla registrada: " .. name)
  end

  local context = require("writing.core.project").resolve(0)
  vim.health.info(table.concat(require("writing.core.project").display(context), "\n"))
  for _, error_message in ipairs(context.errors) do
    vim.health.error(error_message)
  end
end

return M
