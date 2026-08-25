local function assert_equal(actual, expected, message)
  assert(actual == expected, string.format("%s: esperado %s, recibido %s", message, expected, actual))
end

assert_equal(vim.env.NVIM_APPNAME, "nvim-writing", "perfil aislado")
assert(vim.version.ge(vim.version(), { 0, 12, 4 }), "Neovim debe ser >= 0.12.4")

for _, command in ipairs({
  "WriteNew",
  "WriteRoot",
  "WritePreview",
  "WritePreviewStop",
  "WriteBuild",
  "WriteExport",
  "WriteLanguage",
  "WriteCitation",
  "WriteTheme",
  "WriteGoogle",
  "WriteDictionary",
  "WriteFocus",
  "WriteHealth",
}) do
  assert_equal(vim.fn.exists(":" .. command), 2, "comando " .. command)
end

local function highlight(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end

assert_equal(vim.g.colors_name, "writing-monochrome-dark", "tema oscuro inicial")
assert_equal(vim.o.background, "dark", "background oscuro")
assert_equal(highlight("Normal").bg, 0x0D1117, "fondo oscuro")
assert_equal(highlight("Normal").fg, 0xF0F0F0, "texto oscuro")
assert_equal(highlight("SpellBad").sp, 0xD05858, "rojo del corrector")
assert(highlight("SpellBad").undercurl, "el corrector debe usar undercurl")
assert_equal(highlight("@markup.heading.1.markdown").fg, 0x5079BE, "heading Markdown")
assert_equal(highlight("@keyword.typst").fg, 0xB05CCC, "keyword Typst")
assert_equal(highlight("@lsp.type.heading.typst").fg, 0x5079BE, "heading semántico Tinymist")
assert_equal(highlight("@function.macro.latex").fg, 0x5079BE, "macro LaTeX")
assert_equal(highlight("Added").fg, 0x8B949E, "grupo Added neutral")
assert(next(highlight("@spell")) == nil, "@spell no debe tapar el highlighting documental")
assert(vim.wo.relativenumber, "los números relativos deben permanecer activos")
assert(vim.o.guicursor:match("i%-ci%-ve:ver25"), "cursor de inserción visible")
for _, parser in ipairs({ "markdown", "markdown_inline", "typst", "latex", "bibtex" }) do
  assert(#vim.api.nvim_get_runtime_file("parser/" .. parser .. ".so", false) > 0, "falta parser " .. parser)
end
assert_equal(vim.treesitter.language.get_lang("plaintex"), "latex", "plaintex usa parser LaTeX")
local plaintex_buffer = vim.api.nvim_create_buf(true, true)
vim.api.nvim_buf_set_lines(plaintex_buffer, 0, -1, false, { "Texto \\textbf{visible}." })
vim.bo[plaintex_buffer].filetype = "plaintex"
assert(pcall(vim.treesitter.start, plaintex_buffer), "Treesitter debe iniciar en plaintex")
vim.api.nvim_buf_delete(plaintex_buffer, { force = true })

vim.cmd("WriteTheme light")
assert_equal(vim.g.colors_name, "writing-monochrome-light", "tema claro")
assert_equal(vim.o.background, "light", "background claro")
assert_equal(highlight("Normal").bg, 0xFAFAFA, "fondo claro")
assert_equal(highlight("Normal").fg, 0x20232A, "texto claro")
assert_equal(highlight("SpellBad").sp, 0xD05858, "rojo del corrector claro")
vim.cmd("WriteTheme toggle")
assert_equal(vim.g.colors_name, "writing-monochrome-dark", "toggle vuelve al oscuro")

for _, mapping in ipairs({
  { lhs = "<leader>wt", mode = "n" },
  { lhs = "<leader>wg", mode = "n" },
  { lhs = "<leader>wg", mode = "x" },
  { lhs = "<leader>wd", mode = "n" },
  { lhs = "<leader>wd", mode = "x" },
}) do
  assert(next(vim.fn.maparg(mapping.lhs, mapping.mode, false, true)) ~= nil, "falta mapping " .. mapping.lhs)
end

local lookup = require("writing.core.lookup")
assert_equal(
  lookup.encode_component("canción & café/te?#%"),
  "canci%C3%B3n%20%26%20caf%C3%A9%2Fte%3F%23%25",
  "percent encoding RFC3986"
)
local original_ui_open = vim.ui.open
local original_ui_select = vim.ui.select
local opened_url
vim.ui.open = function(url)
  opened_url = url
  return {}, nil
end
assert(lookup.google("canción & café/te"), "consulta Google")
assert_equal(
  opened_url,
  "https://www.google.com/search?q=canci%C3%B3n%20%26%20caf%C3%A9%2Fte",
  "URL Google"
)

local lookup_source = vim.api.nvim_get_current_buf()
local lookup_buffer = vim.api.nvim_create_buf(true, true)
vim.api.nvim_set_current_buf(lookup_buffer)
vim.api.nvim_buf_set_lines(lookup_buffer, 0, -1, false, { "canción &", "café/te" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd("normal! vj$")
assert_equal(lookup.subject(true), "canción & café/te", "consulta desde selección multilínea")
vim.cmd("normal! v")
vim.wo.spell = true
vim.bo.spelllang = "en_us"
assert(lookup.dictionary(nil, "colour"), "diccionario inglés inferido")
assert_equal(opened_url, "https://www.merriam-webster.com/dictionary/colour", "URL Merriam-Webster")
vim.bo.spelllang = "es,en_us"
vim.ui.select = function(items, _, on_choice)
  on_choice(items[1])
end
assert(lookup.dictionary(nil, "palabra"), "selector de diccionario bilingüe")
assert_equal(opened_url, "https://dle.rae.es/palabra", "URL RAE")
local selected_when_spell_off = false
vim.wo.spell = false
vim.ui.select = function(items, _, on_choice)
  selected_when_spell_off = true
  on_choice(items[2])
end
assert(lookup.dictionary(nil, "word"), "selector de diccionario con spell apagado")
assert(selected_when_spell_off, "spell off no debe inferir el spelllang residual")
assert_equal(opened_url, "https://www.merriam-webster.com/dictionary/word", "URL elegida con spell off")
vim.api.nvim_set_current_buf(lookup_source)
vim.api.nvim_buf_delete(lookup_buffer, { force = true })
vim.ui.open = original_ui_open
vim.ui.select = original_ui_select

local word_count = require("writing.core.word_count")
assert_equal(word_count.count_words("canción Título Pérez café"), 4, "tokenización Unicode")
assert_equal(word_count.count_words("uno—dos"), 2, "puntuación entre palabras")
local original_iskeyword = vim.bo.iskeyword
vim.bo.iskeyword = "a-z"
assert_equal(word_count.count_words("canción Título Pérez café"), 4, "tokenización independiente de iskeyword")
vim.bo.iskeyword = original_iskeyword
local function compute_prose(filetype, source, cwd)
  local finished = false
  local result
  local failure
  word_count.compute(filetype, source, cwd, function(count, error_message)
    result = count
    failure = error_message
    finished = true
  end)
  assert(vim.wait(5000, function()
    return finished
  end, 10), "timeout del contador " .. filetype)
  assert(not failure, "falló el contador " .. filetype .. ": " .. tostring(failure))
  return result
end

assert_equal(
  compute_prose("text", "uno—dos\nvim: una frase real:\nvim: set spell spelllang=es :\n", vim.uv.cwd()),
  6,
  "conteo TXT conserva prosa parecida a una modeline"
)
local markdown_prose = [[
---
title: Título visible
author: Ana Pérez
keywords:
  - secreto_oculto
---

# Uno dos

Texto **tres cuatro** con [cinco](https://example.invalid) y `código oculto`.

$$x + y = z$$

![alternativa oculta](imagen.png)

Cita [@clave_oculta].

```lua
código oculto
```
]]
assert_equal(compute_prose("markdown", markdown_prose, vim.uv.cwd()), 15, "prosa Markdown renderizada")
local markdown_metadata = [[
---
title: Título principal
subtitle: Subtítulo visible
author: Ana Pérez
date: 2026
abstract: Resumen visible escrito
keywords: [secreto, oculto]
---

Cuerpo final.
]]
assert_equal(compute_prose("markdown", markdown_metadata, vim.uv.cwd()), 12, "metadata visible Markdown")
assert_equal(
  compute_prose("markdown", "Antes ![alt oculto](imagen.png) después.\n", vim.uv.cwd()),
  2,
  "alt inline no renderizado"
)
assert_equal(
  compute_prose("markdown", "![Pie visible escrito](imagen.png)\n", vim.uv.cwd()),
  3,
  "caption Markdown visible"
)
local markdown_structures = [[
1. uno dos
2. tres cuatro

Texto con nota[^1].

[^1]: cinco seis
]]
assert_equal(
  compute_prose("markdown", markdown_structures, vim.uv.cwd()),
  9,
  "listas y notas no cuentan sus marcadores"
)

local latex_prose = [[
\documentclass{article}
\title{Título visible}
\author{Ana Pérez}
\begin{document}
\maketitle
\section{Primera parte}
Hola, mundo. Texto \textbf{fuerte}.
\cite{clave_oculta}
\label{etiqueta_oculta}
\[ x + y = z \]
\begin{verbatim}
código oculto
\end{verbatim}
\end{document}
]]
assert_equal(compute_prose("tex", latex_prose, vim.uv.cwd()), 10, "prosa LaTeX renderizada")
assert_equal(
  compute_prose("typst", "#figure([Texto visible dentro], caption: [Pie visible])\n", vim.uv.cwd()),
  5,
  "contenido y caption de figura Typst"
)

local count_buffer = vim.api.nvim_create_buf(true, true)
vim.api.nvim_set_current_buf(count_buffer)
vim.bo.filetype = "text"
vim.api.nvim_buf_set_lines(count_buffer, 0, -1, false, { "una dos" })
local count_finished = false
word_count.refresh(count_buffer, function()
  count_finished = true
end)
assert(vim.wait(1000, function()
  return count_finished
end, 10), "conteo inicial del statusline")
assert_equal(word_count.status(), "2 palabras", "statusline con conteo fresco")
vim.api.nvim_buf_set_lines(count_buffer, 0, -1, false, { "una dos—tres" })
word_count.schedule(count_buffer, 10000)
assert_equal(word_count.status(), "~2 palabras", "statusline marca el último conteo como pendiente")
vim.api.nvim_set_current_buf(lookup_source)
vim.api.nvim_buf_delete(count_buffer, { force = true })

local filetype_buffer = vim.api.nvim_create_buf(true, true)
vim.api.nvim_set_current_buf(filetype_buffer)
vim.api.nvim_buf_set_lines(filetype_buffer, 0, -1, false, { "visible [etiqueta](https://oculto.example)" })
vim.bo.filetype = "text"
word_count.schedule(filetype_buffer, 0)
assert(vim.wait(1000, function()
  local count, error_message, stale = word_count.last(filetype_buffer)
  return count == 5 and not error_message and not stale
end, 10), "conteo TXT para probar cambio de filetype")
vim.bo.filetype = "markdown"
assert(vim.wait(5000, function()
  local count, error_message, stale = word_count.last(filetype_buffer)
  return count == 2 and not error_message and not stale
end, 10), "el caché debe incluir el filetype")
vim.api.nvim_set_current_buf(lookup_source)
vim.api.nvim_buf_delete(filetype_buffer, { force = true })

local dependency_root = vim.fn.tempname() .. "-nvim-writing-count-dependency"
assert_equal(vim.fn.mkdir(dependency_root, "p"), 1, "crear fixture de dependencia")
local dependency_main = vim.fs.joinpath(dependency_root, "main.typ")
local dependency_part = vim.fs.joinpath(dependency_root, "part.typ")
assert_equal(
  vim.fn.writefile({ '#import "part.typ": part', "#part" }, dependency_main),
  0,
  "crear main del contador"
)
assert_equal(vim.fn.writefile({ "#let part = [uno dos]" }, dependency_part), 0, "crear import del contador")
local dependency_main_buffer = vim.fn.bufadd(dependency_main)
vim.fn.bufload(dependency_main_buffer)
vim.bo[dependency_main_buffer].filetype = "typst"
word_count.schedule(dependency_main_buffer, 0)
assert(vim.wait(5000, function()
  local count, error_message, stale = word_count.last(dependency_main_buffer)
  return count == 2 and not error_message and not stale
end, 10), "conteo inicial con import Typst")
local unchanged_main_tick = vim.api.nvim_buf_get_changedtick(dependency_main_buffer)

local dependency_part_buffer = vim.fn.bufadd(dependency_part)
vim.fn.bufload(dependency_part_buffer)
vim.bo[dependency_part_buffer].filetype = "typst"
vim.api.nvim_set_current_buf(dependency_part_buffer)
vim.api.nvim_buf_set_lines(dependency_part_buffer, 0, -1, false, { "#let part = [uno dos tres]" })
vim.cmd.write()
assert_equal(
  vim.api.nvim_buf_get_changedtick(dependency_main_buffer),
  unchanged_main_tick,
  "el main no cambió al guardar el import"
)
vim.api.nvim_set_current_buf(dependency_main_buffer)
assert(vim.wait(5000, function()
  local count, error_message, stale = word_count.last(dependency_main_buffer)
  return count == 3 and not error_message and not stale
end, 10), "BufWritePost debe invalidar dependencias cacheadas")

vim.api.nvim_buf_set_lines(dependency_main_buffer, 0, -1, false, { "#let =" })
word_count.schedule(dependency_main_buffer, 0)
assert(vim.wait(5000, function()
  local count, error_message, stale = word_count.last(dependency_main_buffer)
  return count == 3 and error_message ~= nil and stale
end, 10), "un error de parse debe conservar el último conteo como stale")
assert_equal(word_count.status(), "~3 palabras", "statusline después de un error de parse")
vim.api.nvim_set_current_buf(lookup_source)
vim.api.nvim_buf_delete(dependency_main_buffer, { force = true })
vim.api.nvim_buf_delete(dependency_part_buffer, { force = true })
assert_equal(vim.fn.delete(dependency_root, "rf"), 0, "limpieza del fixture de dependencia")

local undo_map = vim.fn.maparg("<leader>u", "n", false, true)
assert(next(undo_map) ~= nil, "falta el binding del undo tree nativo")
assert_equal(undo_map.desc, "Abrir undo tree nativo", "descripción del binding de undo")
assert_equal(vim.fn.exists(":UndotreeToggle"), 0, "mbbill/undotree no debe estar cargado")
local undo_source = vim.api.nvim_get_current_buf()
undo_map.callback()
assert_equal(vim.bo.filetype, "nvim-undotree", "<leader>u abre el undo tree nativo")
vim.wait(10)
undo_map.callback()
assert_equal(vim.api.nvim_get_current_buf(), undo_source, "<leader>u vuelve al documento")
assert_equal(vim.fn.exists(":Undotree"), 2, "undo tree nativo disponible")
assert_equal(vim.fn.exists(":LivePreview"), 2, "live-preview.nvim disponible")

local templates = require("writing.core.templates").list()
assert_equal(#templates, 5, "número de plantillas")

local essay = vim.fs.joinpath(vim.fn.stdpath("config"), "templates", "typst", "essay", "main.typ")
local context = require("writing.core.project").resolve_path(essay)
assert_equal(context.root_source, "writing-json", "prioridad del manifest")
assert(context.main:match("/templates/typst/essay/main%.typ$"), "main Typst incorrecto")
assert(context.build_dir:match("/templates/typst/essay/build$"), "build incorrecto")
assert_equal(#context.errors, 0, "contexto válido")
assert_equal(
  compute_prose("typst", table.concat(vim.fn.readfile(essay), "\n"), vim.fs.dirname(essay)),
  32,
  "prosa Typst renderizada"
)

assert_equal(vim.fn.exists(":Oil"), 2, "Oil disponible")

require("lazy").load({ plugins = { "lualine.nvim" } })
local lualine_config = require("lualine.config").get_config()
assert(not lualine_config.options.icons_enabled, "Lualine debe ser textual y mínima")
assert_equal(#lualine_config.sections.lualine_a, 1, "Lualine: modo")
assert_equal(#lualine_config.sections.lualine_b, 0, "Lualine: sección B vacía")
assert_equal(#lualine_config.sections.lualine_c, 1, "Lualine: archivo")
assert_equal(#lualine_config.sections.lualine_x, 2, "Lualine: palabras e idioma")
assert_equal(#lualine_config.sections.lualine_y, 1, "Lualine: progreso")
assert_equal(#lualine_config.sections.lualine_z, 0, "Lualine: sección Z vacía")
assert_equal(#lualine_config.extensions, 0, "Lualine sin extensiones que añadan contenido")
vim.cmd("WriteTheme light")
lualine_config = require("lualine.config").get_config()
assert_equal(lualine_config.options.theme.normal.a.bg, "#E8EBF0", "Lualine cambia al tema claro")
vim.cmd("WriteTheme dark")
lualine_config = require("lualine.config").get_config()
assert_equal(lualine_config.options.theme.normal.a.bg, "#21262D", "Lualine vuelve al tema oscuro")
local _, icon_highlight = require("nvim-web-devicons").get_icon("main.typ", "typ", { default = true })
assert_equal(icon_highlight, "DevIconDefault", "iconos monocromáticos")
require("lazy").load({ plugins = { "fzf-lua" } })
require("fzf-lua").setup_highlights(true)
require("writing.core.theme").refresh()
assert_equal(highlight("FzfLuaBufFlagCur").fg, 0x8B949E, "flag de fzf monocromático")
assert_equal(highlight("FzfLuaPathLineNr").fg, 0x8B949E, "línea de fzf monocromática")
assert_equal(highlight("FzfLuaLivePrompt").fg, 0x8B949E, "prompt de fzf monocromático")
assert_equal(highlight("fzf1").fg, 0x8B949E, "paleta terminal de fzf monocromática")

local initial_tabs = vim.fn.tabpagenr("$")
vim.cmd.tabnew()
assert_equal(vim.fn.tabpagenr("$"), initial_tabs + 1, "tabpage nativa creada")
vim.cmd.tabclose()
assert_equal(vim.fn.tabpagenr("$"), initial_tabs, "tabpage nativa cerrada")

local destination = vim.fn.tempname() .. "-nvim-writing-project"
local created, create_error = require("writing.core.templates").create("essay", destination)
assert(created, create_error)
assert(vim.uv.fs_stat(vim.fs.joinpath(destination, "main.typ")), "WriteNew no copió main.typ")
assert(vim.uv.fs_stat(vim.fs.joinpath(destination, ".writing.json")), "WriteNew no copió el manifest")
assert_equal(
  require("tabby.feature.tab_name").get(0),
  vim.fs.basename(destination) .. "/main.typ",
  "Tabby usa parent/file.ext"
)
vim.cmd.tabnew()
vim.cmd.tabprevious()
assert_equal(vim.o.tabline, "%!TabbyRenderTabline()", "Tabby usa el renderer moderno configurado")
local rendered_tabline = vim.fn.TabbyRenderTabline()
assert(rendered_tabline:find("×", 1, true), "Tabby conserva el botón de cierre")
assert(not rendered_tabline:find(" nvim-writing ", 1, true), "Tabby no debe mostrar branding")
vim.cmd.tabnext()
vim.cmd.tabclose()
local original_select = vim.ui.select
vim.ui.select = function(items, _, on_choice)
  on_choice(items[1])
end
vim.cmd.WriteCitation()
vim.ui.select = original_select
assert(vim.api.nvim_get_current_line():match("@ejemplo_ensayo_2024"), "WriteCitation no insertó una cita Typst")
local repeated, repeated_error = require("writing.core.templates").create("essay", destination)
assert(not repeated and repeated_error:match("nunca sobrescribe"), "WriteNew debe rechazar destinos existentes")
vim.cmd.bdelete({ bang = true })
assert_equal(vim.fn.delete(destination, "rf"), 0, "limpieza del proyecto temporal")

local markdown_destination = vim.fn.tempname() .. " nvim-writing markdown"
local markdown_created, markdown_error = require("writing.core.templates").create(
  "markdown-document",
  markdown_destination
)
assert(markdown_created, markdown_error)
local section_magic = "<!-- LTeX: language=en-US -->"
local markdown_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
table.insert(markdown_lines, math.max(2, #markdown_lines - 2), section_magic)
vim.api.nvim_buf_set_lines(0, 0, -1, false, markdown_lines)
vim.cmd("WriteLanguage! en")
assert(vim.tbl_contains(vim.api.nvim_buf_get_lines(0, 0, -1, false), section_magic), "se borró un magic comment de sección")
vim.cmd.write()
local markdown_main = vim.fs.joinpath(markdown_destination, "main.md")
vim.cmd.bdelete({ bang = true })
vim.api.nvim_cmd({ cmd = "edit", args = { markdown_main } }, {})
assert_equal(vim.bo.spelllang, "en_us", "idioma Markdown persistido al reabrir")

local preview = require("livepreview")
local preview_config = require("livepreview.config")
local original_port = preview_config.config.port
local original_ui_open = vim.ui.open
local opened_url

assert_equal(preview_config.config.address, "127.0.0.1", "preview Markdown ligado a localhost")
assert(original_port > 0 and original_port < 65536, "puerto Markdown efímero válido")

local probe = assert(vim.uv.new_tcp(), "crear socket de prueba")
assert(probe:bind("127.0.0.1", 0), "reservar puerto de preview")
local free_port = assert(probe:getsockname(), "obtener puerto de preview").port
probe:close()
preview_config.set({ port = free_port })
vim.ui.open = function(url)
  opened_url = url
end

local function http_request(request)
  local client = assert(vim.uv.new_tcp(), "crear cliente HTTP de prueba")
  local chunks = {}
  local done = false
  local request_error

  client:connect("127.0.0.1", free_port, function(connect_error)
    if connect_error then
      request_error = connect_error
      done = true
      client:close()
      return
    end
    client:write(request)
    client:read_start(function(read_error, chunk)
      if read_error then
        request_error = read_error
      end
      if chunk then
        chunks[#chunks + 1] = chunk
        local response = table.concat(chunks)
        local header_end = response:find("\r\n\r\n", 1, true)
        local content_length = response:match("[Cc]ontent%-[Ll]ength:%s*(%d+)")
        if header_end and content_length and #response >= header_end + 3 + tonumber(content_length) then
          done = true
          client:read_stop()
          if not client:is_closing() then
            client:close()
          end
        end
        return
      end
      done = true
      if not client:is_closing() then
        client:close()
      end
    end)
  end)

  assert(vim.wait(2000, function()
    return done
  end, 10), "timeout en petición HTTP de preview")
  assert(not request_error, request_error)
  return table.concat(chunks)
end

local preview_server = require("livepreview.server")

local function assert_no_preview_clients(message)
  assert(vim.wait(1000, function()
    return #preview_server.connecting_clients == 0
  end, 10), message)
end

local function open_websocket(request)
  local client = assert(vim.uv.new_tcp(), "crear cliente WebSocket de prueba")
  local state = { response = "", handshake = false, closed = false }

  client:connect("127.0.0.1", free_port, function(connect_error)
    if connect_error then
      state.error = connect_error
      state.closed = true
      client:close()
      return
    end
    client:write(request)
    client:read_start(function(read_error, chunk)
      if read_error then
        state.error = read_error
      end
      if chunk then
        state.response = state.response .. chunk
        state.handshake = state.response:find("\r\n\r\n", 1, true) ~= nil
        return
      end
      state.closed = true
      if not client:is_closing() then
        client:close()
      end
    end)
  end)

  assert(vim.wait(2000, function()
    return state.handshake or state.closed
  end, 10), "timeout en handshake WebSocket de preview")
  assert(not state.error, state.error)
  return client, state
end

local preview_ok, preview_error = xpcall(function()
  vim.cmd.WritePreview()
  assert(preview.is_running(), "WritePreview no inició el servidor Markdown")
  assert_equal(vim.uv.fs_realpath(preview.serverObj.webroot), vim.uv.fs_realpath(markdown_destination), "webroot Markdown")
  assert(opened_url and opened_url:match("^http://127%.0%.0%.1:%d+/main%.md$"), "URL de preview inesperada")

  local normal_response = http_request(table.concat({
    "GET /main.md HTTP/1.1",
    ("Host: 127.0.0.1:%d"):format(free_port),
    "Accept: text/html",
    "Connection: close",
    "",
    "",
  }, "\r\n"))
  assert(normal_response:match("^HTTP/1%.1 200 OK"), "el documento Markdown debe poder servirse")
  local csp = normal_response:match("\r\nContent%-Security%-Policy: ([^\r\n]+)")
  local script_csp = "script%-src http://127%.0%.0%.1:" .. free_port .. "/live%-preview%.nvim/static/"
  assert(csp and csp:match(script_csp), "CSP sólo debe permitir scripts estáticos del plugin")
  assert(not csp:match("script%-src[^;]*unsafe%-inline"), "CSP no debe permitir scripts inline")
  local websocket_csp = "connect%-src 'self' ws://127%.0%.0%.1:" .. free_port
  assert(csp:match(websocket_csp), "CSP WebSocket local")
  assert_no_preview_clients("preview debe cerrar clientes HTTP normales")

  local traversal_response = http_request(table.concat({
    "GET /%2e%2e/%2e%2e/etc/passwd HTTP/1.1",
    ("Host: 127.0.0.1:%d"):format(free_port),
    "Connection: close",
    "",
    "",
  }, "\r\n"))
  assert(traversal_response:match("^HTTP/1%.1 403 Forbidden"), "preview debe bloquear path traversal")
  assert_no_preview_clients("preview debe cerrar clientes HTTP rechazados")

  local plugin_traversal_response = http_request(table.concat({
    "GET /live-preview.nvim/%2e%2e/%2e%2e/etc/passwd HTTP/1.1",
    ("Host: 127.0.0.1:%d"):format(free_port),
    "Connection: close",
    "",
    "",
  }, "\r\n"))
  assert(
    plugin_traversal_response:match("^HTTP/1%.1 403 Forbidden"),
    "preview debe confinar también los assets del plugin"
  )
  assert_no_preview_clients("preview debe cerrar clientes de assets rechazados")

  local escaped_path = vim.fs.joinpath(markdown_destination, "escaped.txt")
  assert(vim.uv.fs_symlink("/etc/passwd", escaped_path), "crear symlink de prueba")
  local symlink_response = http_request(table.concat({
    "GET /escaped.txt HTTP/1.1",
    ("Host: 127.0.0.1:%d"):format(free_port),
    "Connection: close",
    "",
    "",
  }, "\r\n"))
  assert(symlink_response:match("^HTTP/1%.1 403 Forbidden"), "preview debe bloquear symlinks fuera del webroot")
  assert_no_preview_clients("preview debe cerrar clientes de symlinks rechazados")

  local websocket_response = http_request(table.concat({
    "GET / HTTP/1.1",
    ("Host: 127.0.0.1:%d"):format(free_port),
    "Upgrade: websocket",
    "Connection: Upgrade",
    "Origin: https://example.invalid",
    "Sec-WebSocket-Version: 13",
    "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==",
    "",
    "",
  }, "\r\n"))
  assert(websocket_response:match("^HTTP/1%.1 403 Forbidden"), "preview debe rechazar WebSockets cross-origin")
  assert_no_preview_clients("preview debe olvidar WebSockets rechazados")

  local websocket_client, websocket_state = open_websocket(table.concat({
    "GET / HTTP/1.1",
    ("Host: 127.0.0.1:%d"):format(free_port),
    "Upgrade: websocket",
    "Connection: Upgrade",
    ("Origin: http://127.0.0.1:%d"):format(free_port),
    "Sec-WebSocket-Version: 13",
    "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==",
    "",
    "",
  }, "\r\n"))
  assert(websocket_state.response:match("^HTTP/1%.1 101 Switching Protocols"), "preview debe aceptar su mismo Origin")
  assert_equal(#preview_server.connecting_clients, 1, "WebSocket same-origin registrado durante el preview")

  vim.cmd.WritePreviewStop()
  assert(not preview.is_running(), "WritePreviewStop no detuvo el servidor Markdown")
  assert_equal(#preview_server.connecting_clients, 0, "WritePreviewStop debe vaciar los clientes")
  assert(vim.wait(1000, function()
    return websocket_state.closed
  end, 10), "WritePreviewStop debe cerrar el WebSocket same-origin")
  if not websocket_client:is_closing() then
    websocket_client:close()
  end
end, debug.traceback)

if preview.is_running() then
  preview.close()
end
preview_config.set({ port = original_port })
vim.ui.open = original_ui_open
assert(preview_ok, preview_error)

vim.cmd.bdelete({ bang = true })
assert_equal(vim.fn.delete(markdown_destination, "rf"), 0, "limpieza del proyecto Markdown")

local root = vim.fn.tempname() .. "-nvim-writing-root"
local outside = vim.fn.tempname() .. "-nvim-writing-outside"
assert_equal(vim.fn.mkdir(root, "p"), 1, "crear root temporal")
assert_equal(vim.fn.mkdir(outside, "p"), 1, "crear destino externo temporal")
assert(vim.uv.fs_symlink(outside, vim.fs.joinpath(root, "out")), "crear symlink de escape")
assert_equal(vim.fn.writefile({ "= Prueba" }, vim.fs.joinpath(root, "main.typ")), 0, "crear main temporal")
assert_equal(vim.fn.writefile({ vim.json.encode({
  schemaVersion = 1,
  main = "main.typ",
  buildDir = "out/build",
}) }, vim.fs.joinpath(root, ".writing.json")), 0, "crear manifest temporal")
local escaped_context = require("writing.core.project").resolve_path(vim.fs.joinpath(root, "main.typ"))
assert(#escaped_context.errors > 0, "buildDir mediante symlink debe ser inválido")
assert(table.concat(escaped_context.errors, "; "):match("symlink"), "el error debe explicar el symlink")
assert_equal(vim.fn.delete(root, "rf"), 0, "limpieza del root temporal")
assert_equal(vim.fn.delete(outside, "rf"), 0, "limpieza del destino externo")

local git_root = vim.fn.tempname() .. "-nvim-writing-git-root"
local external_main = vim.fn.tempname() .. "-nvim-writing-external-main.typ"
assert_equal(vim.fn.mkdir(vim.fs.joinpath(git_root, ".git"), "p"), 1, "crear repo temporal")
assert_equal(vim.fn.writefile({ "= Externo" }, external_main), 0, "crear main externo")
local linked_main = vim.fs.joinpath(git_root, "linked.typ")
assert(vim.uv.fs_symlink(external_main, linked_main), "crear symlink de main")
local linked_context = require("writing.core.project").resolve_path(linked_main)
assert(table.concat(linked_context.errors, "; "):match("main escapa"), "main predeterminado debe permanecer en root")
assert_equal(vim.fn.delete(git_root, "rf"), 0, "limpieza del repo temporal")
assert_equal(vim.fn.delete(external_main), 0, "limpieza del main externo")

local protected_link = vim.fn.tempname() .. "-nvim-writing-protected-link"
assert(vim.uv.fs_symlink(vim.fn.stdpath("cache"), protected_link), "crear symlink a runtime")
local protected_destination = vim.fs.joinpath(protected_link, "blocked-project")
local forbidden, forbidden_error = require("writing.core.templates").create("essay", protected_destination)
assert(not forbidden and forbidden_error:match("configuración o su runtime"), "WriteNew debe resolver symlinks")
assert(not vim.uv.fs_lstat(vim.fs.joinpath(vim.fn.stdpath("cache"), "blocked-project")), "WriteNew escapó al runtime")
assert(vim.uv.fs_unlink(protected_link), "limpieza del symlink protegido")

print("nvim-writing smoke: OK")
