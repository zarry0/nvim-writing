local M = {}

local settings = require("writing.settings")

local function version_of(executable)
  local result = vim.system({ executable, "--version" }, { text = true }):wait(3000)
  if result.code ~= 0 then
    return nil
  end
  return vim.split(result.stdout or "", "\n", { trimempty = true })[1]
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

  for _, executable in ipairs({ "git", "typst", "pandoc", "fzf", "rg", "fd", "lazygit", "tree-sitter" }) do
    if vim.fn.executable(executable) == 1 then
      vim.health.ok(executable .. ": " .. (version_of(executable) or "instalado"))
    else
      local critical = executable == "git" or executable == "typst"
      local report = critical and vim.health.error or vim.health.warn
      report("No se encontró " .. executable)
    end
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
