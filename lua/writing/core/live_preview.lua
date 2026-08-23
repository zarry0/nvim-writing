local M = {}

local uv = vim.uv or vim.loop
local denied_route = {}
local hardened = false

local function remove_client(client)
  local clients = require("livepreview.server").connecting_clients
  for index = #clients, 1, -1 do
    if clients[index] == client then
      table.remove(clients, index)
    end
  end
end

local function close_client(client)
  if client:is_closing() then
    return
  end
  pcall(client.read_stop, client)
  client:close()
end

local function close_all_clients()
  local clients = require("livepreview.server").connecting_clients
  while #clients > 0 do
    close_client(table.remove(clients))
  end
end

local function close_after_write(client)
  remove_client(client)
  if client:is_closing() then
    return
  end
  client:shutdown(function()
    if not client:is_closing() then
      client:close()
    end
  end)
end

local function reject_websocket(client)
  local body = "403 Forbidden"
  local response = table.concat({
    "HTTP/1.1 403 Forbidden",
    "Content-Type: text/plain",
    "Content-Length: " .. #body,
    "Connection: close",
    "",
    body,
  }, "\r\n")

  client:write(response, function()
    close_after_write(client)
  end)
end

local function request_origin(request)
  local origin
  local count = 0
  for line in request:gmatch("[^\r\n]+") do
    local name, value = line:match("^([^:]+):%s*(.-)%s*$")
    if name and name:lower() == "origin" then
      count = count + 1
      origin = value
    end
  end
  return count == 1 and origin or nil
end

local function expected_origin()
  local config = require("livepreview.config").config
  return ("http://%s:%d"):format(config.address, config.port)
end

local function content_security_policy()
  local http_origin = expected_origin()
  local websocket_origin = http_origin:gsub("^http", "ws")
  return table.concat({
    "default-src 'self'",
    "script-src " .. http_origin .. "/live-preview.nvim/static/",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "font-src 'self' data:",
    "connect-src 'self' " .. websocket_origin,
    "media-src 'self' data: blob:",
    "object-src 'none'",
    "base-uri 'none'",
    "form-action 'none'",
    "frame-src 'none'",
    "frame-ancestors 'none'",
    "worker-src 'self' blob:",
  }, "; ")
end

local function send_http_response(client, status, content_type, body, headers)
  local response = "HTTP/1.1 "
    .. status
    .. "\r\nContent-Type: "
    .. content_type
    .. "\r\nContent-Length: "
    .. #body
    .. "\r\nConnection: close\r\n"

  local response_headers = vim.tbl_extend("force", headers or {}, {
    ["Content-Security-Policy"] = content_security_policy(),
    ["Referrer-Policy"] = "no-referrer",
    ["X-Content-Type-Options"] = "nosniff",
  })
  for name, value in pairs(response_headers) do
    response = response .. name .. ": " .. value .. "\r\n"
  end

  client:write(response .. "\r\n" .. body, function()
    close_after_write(client)
  end)
end

local function safe_route(root, request_path)
  if type(request_path) ~= "string" or request_path:find("%z") or request_path:find("\\", 1, true) then
    return nil
  end

  local path_without_query = request_path:match("^[^?#]*") or ""
  local relative = path_without_query:gsub("^/+", "")
  if relative == "" then
    relative = "index.html"
  end

  local project = require("writing.core.project")
  local real_root = project.realpath_with_missing(root)
  if not real_root then
    return nil
  end

  local candidate = vim.fs.joinpath(real_root, relative)
  local real_candidate = project.realpath_with_missing(candidate)
  if not real_candidate or not project.is_inside(real_root, real_candidate) then
    return nil
  end
  return real_candidate
end

local function ephemeral_port()
  local socket = uv.new_tcp()
  if not socket then
    return nil
  end
  local ok = socket:bind("127.0.0.1", 0)
  if not ok then
    socket:close()
    return nil
  end
  local address = socket:getsockname()
  socket:close()
  return address and address.port or nil
end

local function harden_server()
  if hardened then
    return
  end

  local server = require("livepreview.server")
  local handler = server.handler
  local websocket = server.websocket
  local utils = require("livepreview.utils")
  local original_serve_file = handler.serve_file
  local original_handshake = websocket.handshake
  local original_stop = server.Server.stop

  handler.send_http_response = send_http_response

  function server.Server:routes(path)
    local plugin_prefix = "/live-preview.nvim/"
    if path:sub(1, #plugin_prefix) == plugin_prefix then
      return safe_route(utils.get_plugin_path(), path:sub(#plugin_prefix + 1)) or denied_route
    end
    return safe_route(self.webroot, path) or denied_route
  end

  handler.serve_file = function(client, file_path, if_none_match, accept)
    if file_path == denied_route then
      handler.send_http_response(client, "403 Forbidden", "text/plain", "403 Forbidden")
      return
    end
    original_serve_file(client, file_path, if_none_match, accept)
  end

  websocket.handshake = function(client, request)
    if request_origin(request) ~= expected_origin() then
      reject_websocket(client)
      return nil
    end
    return original_handshake(client, request)
  end

  function server.Server:stop(callback)
    close_all_clients()
    return original_stop(self, function()
      close_all_clients()
      if callback then
        callback()
      end
    end)
  end

  hardened = true
end

function M.setup()
  local options = {
    address = "127.0.0.1",
    browser = "default",
    dynamic_root = true,
    picker = "fzf-lua",
    port = assert(ephemeral_port(), "no se pudo seleccionar un puerto local para el preview Markdown"),
    sync_scroll = true,
  }
  require("livepreview.config").set(options)
  harden_server()
end

return M
