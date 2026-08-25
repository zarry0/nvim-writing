local M = {}

local providers = {
  google = function(encoded)
    return "https://www.google.com/search?q=" .. encoded
  end,
  es = function(encoded)
    return "https://dle.rae.es/" .. encoded
  end,
  en = function(encoded)
    return "https://www.merriam-webster.com/dictionary/" .. encoded
  end,
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "nvim-writing" })
end

local function normalize(text)
  return vim.trim((text or ""):gsub("%s+", " "))
end

local function encode_component(text)
  return (text:gsub(".", function(character)
    if character:match("[A-Za-z0-9._~-]") then
      return character
    end
    return string.format("%%%02X", string.byte(character))
  end))
end

local function visual_text()
  local mode = vim.fn.mode()
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
  return normalize(table.concat(lines, " "))
end

function M.subject(visual)
  if visual then
    return visual_text()
  end
  return normalize(vim.fn.expand("<cword>"))
end

local function inferred_dictionary_languages()
  local languages = {}
  if not vim.wo.spell then
    return languages
  end
  for token in vim.bo.spelllang:gmatch("[^,]+") do
    token = token:lower()
    if token == "es" or token:match("^es[_-]") then
      languages.es = true
    elseif token == "en" or token:match("^en[_-]") then
      languages.en = true
    end
  end
  return languages
end

local function open_url(url)
  local _, error_message = vim.ui.open(url)
  if error_message then
    notify("No se pudo abrir el navegador: " .. tostring(error_message), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.open(provider, query)
  query = normalize(query)
  if query == "" then
    notify("No hay una palabra o selección para consultar", vim.log.levels.WARN)
    return false
  end
  local build_url = providers[provider]
  if not build_url then
    notify("Proveedor de consulta desconocido: " .. tostring(provider), vim.log.levels.ERROR)
    return false
  end
  return open_url(build_url(encode_component(query)))
end

function M.google(query, visual)
  return M.open("google", query and query ~= "" and query or M.subject(visual))
end

function M.dictionary(language, query, visual)
  query = query and query ~= "" and normalize(query) or M.subject(visual)
  if query == "" then
    notify("No hay una palabra o selección para consultar", vim.log.levels.WARN)
    return false
  end

  if language == "es" or language == "en" then
    return M.open(language, query)
  end

  local inferred = inferred_dictionary_languages()
  if inferred.es and not inferred.en then
    return M.open("es", query)
  end
  if inferred.en and not inferred.es then
    return M.open("en", query)
  end

  vim.ui.select({
    { id = "es", label = "Español (RAE)" },
    { id = "en", label = "English (Merriam-Webster)" },
  }, {
    prompt = "Diccionario: ",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice then
      M.open(choice.id, query)
    end
  end)
  return true
end

M.encode_component = encode_component

return M
