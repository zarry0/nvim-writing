local M = {}

local uv = vim.uv or vim.loop

local function normalize(path)
  local normalized = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  return normalized == "/" and normalized or normalized:gsub("/$", "")
end

local function is_absolute(path)
  return path:sub(1, 1) == "/" or path:match("^%a:[/\\]") ~= nil
end

local function has_parent_segment(path)
  for segment in path:gmatch("[^/\\]+") do
    if segment == ".." then
      return true
    end
  end
  return false
end

function M.is_inside(root, path)
  root = normalize(root)
  path = normalize(path)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

function M.realpath_with_missing(path)
  local cursor = normalize(path)
  local missing = {}

  while cursor and cursor ~= "" do
    if uv.fs_lstat(cursor) then
      local resolved = uv.fs_realpath(cursor)
      if not resolved then
        return nil
      end
      for _, segment in ipairs(missing) do
        resolved = vim.fs.joinpath(resolved, segment)
      end
      return normalize(resolved)
    end

    local parent = vim.fs.dirname(cursor)
    if not parent or parent == cursor then
      return nil
    end
    table.insert(missing, 1, vim.fs.basename(cursor))
    cursor = parent
  end
end

function M.is_real_inside(root, path)
  local real_root = M.realpath_with_missing(root)
  local real_path = M.realpath_with_missing(path)
  return real_root ~= nil and real_path ~= nil and M.is_inside(real_root, real_path)
end

local function resolve_inside(root, relative, label)
  if type(relative) ~= "string" or relative == "" then
    return nil, label .. " debe ser una ruta relativa no vacía"
  end
  if is_absolute(relative) or has_parent_segment(relative) then
    return nil, label .. " debe permanecer dentro del proyecto"
  end

  local resolved = normalize(vim.fs.joinpath(root, relative))
  if not M.is_inside(root, resolved) then
    return nil, label .. " escapa de la raíz del proyecto"
  end
  if not M.is_real_inside(root, resolved) then
    return nil, label .. " escapa de la raíz mediante un symlink"
  end
  return resolved
end

local function find_up(marker, start)
  local match = vim.fs.find(marker, { path = start, upward = true, limit = 1 })[1]
  return match and normalize(vim.fs.dirname(match)) or nil
end

local function read_manifest(path)
  local stat = uv.fs_stat(path)
  if not stat then
    return {}, nil
  end
  if stat.type ~= "file" then
    return nil, ".writing.json no es un archivo regular"
  end
  if stat.size > 65536 then
    return nil, ".writing.json supera 64 KiB"
  end

  local file, open_error = io.open(path, "r")
  if not file then
    return nil, "No se pudo leer .writing.json: " .. tostring(open_error)
  end
  local contents = file:read("*a")
  file:close()

  local ok, manifest = pcall(vim.json.decode, contents)
  if not ok or type(manifest) ~= "table" then
    return nil, ".writing.json no contiene JSON válido"
  end
  if manifest.schemaVersion ~= 1 then
    return nil, "schemaVersion debe ser 1"
  end
  return manifest, nil
end

local function start_directory(path)
  if not path or path == "" then
    return normalize(uv.cwd())
  end
  local stat = uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return normalize(path)
  end
  return normalize(vim.fn.fnamemodify(path, ":h"))
end

function M.resolve_path(path)
  path = path and path ~= "" and normalize(path) or nil
  local start = start_directory(path)
  local root_source = "file-dir"
  local root = find_up(".writing.json", start)

  if root then
    root_source = "writing-json"
  else
    root = find_up("typst.toml", start)
    if root then
      root_source = "typst-toml"
    else
      root = find_up(".git", start)
      if root then
        root_source = "git"
      else
        root = start
        root_source = path and "file-dir" or "cwd"
      end
    end
  end

  local manifest_path = vim.fs.joinpath(root, ".writing.json")
  local manifest, manifest_error = read_manifest(manifest_path)
  local errors = {}
  if manifest_error then
    errors[#errors + 1] = manifest_error
    manifest = {}
  end

  local main = path
  if manifest.main then
    local err
    main, err = resolve_inside(root, manifest.main, "main")
    if err then
      errors[#errors + 1] = err
    end
  elseif root_source == "typst-toml" and uv.fs_stat(vim.fs.joinpath(root, "main.typ")) then
    local err
    main, err = resolve_inside(root, "main.typ", "main")
    if err then
      errors[#errors + 1] = err
    end
  end
  if main and not M.is_real_inside(root, main) then
    errors[#errors + 1] = "main escapa de la raíz mediante un symlink"
  end

  local build_dir, build_error = resolve_inside(root, manifest.buildDir or "build", "buildDir")
  if build_error then
    errors[#errors + 1] = build_error
  end

  local bibliography
  if manifest.bibliography then
    local err
    bibliography, err = resolve_inside(root, manifest.bibliography, "bibliography")
    if err then
      errors[#errors + 1] = err
    end
  else
    local candidate = vim.fs.joinpath(root, "references.bib")
    if uv.fs_stat(candidate) then
      if M.is_real_inside(root, candidate) then
        bibliography = candidate
      else
        errors[#errors + 1] = "references.bib escapa de la raíz mediante un symlink"
      end
    end
  end

  local reference_doc
  if manifest.referenceDoc then
    local err
    reference_doc, err = resolve_inside(root, manifest.referenceDoc, "referenceDoc")
    if err then
      errors[#errors + 1] = err
    end
  else
    local candidate = vim.fs.joinpath(root, "reference.docx")
    if uv.fs_stat(candidate) then
      if M.is_real_inside(root, candidate) then
        reference_doc = candidate
      else
        errors[#errors + 1] = "reference.docx escapa de la raíz mediante un symlink"
      end
    end
  end

  return {
    root = root,
    root_source = root_source,
    manifest_path = uv.fs_stat(manifest_path) and manifest_path or nil,
    manifest = manifest,
    current_file = path,
    main = main,
    build_dir = build_dir,
    bibliography = bibliography,
    reference_doc = reference_doc,
    errors = errors,
  }
end

function M.resolve(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or (bufnr or 0)
  local path = vim.api.nvim_buf_get_name(bufnr)
  return M.resolve_path(path ~= "" and path or nil)
end

function M.require_valid(bufnr)
  local context = M.resolve(bufnr)
  if #context.errors > 0 then
    return nil, table.concat(context.errors, "; ")
  end
  if not context.main then
    return nil, "El buffer no tiene un archivo principal"
  end
  if not context.build_dir then
    return nil, "No se pudo resolver buildDir"
  end
  return context
end

function M.git_root(bufnr)
  local context = M.resolve(bufnr)
  return find_up(".git", context.root) or context.root
end

function M.display(context)
  local lines = {
    "Raíz: " .. context.root,
    "Detectada por: " .. context.root_source,
    "Manifest: " .. (context.manifest_path or "ninguno"),
    "Main: " .. (context.main or "ninguno"),
    "Build: " .. (context.build_dir or "inválido"),
    "Bibliografía: " .. (context.bibliography or "ninguna"),
  }
  if #context.errors > 0 then
    lines[#lines + 1] = "Errores: " .. table.concat(context.errors, "; ")
  end
  return lines
end

return M
