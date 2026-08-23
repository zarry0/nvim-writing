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
  "WriteFocus",
  "WriteHealth",
}) do
  assert_equal(vim.fn.exists(":" .. command), 2, "comando " .. command)
end

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

assert_equal(vim.fn.exists(":Oil"), 2, "Oil disponible")

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
