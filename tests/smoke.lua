local function assert_equal(actual, expected, message)
  assert(actual == expected, string.format("%s: esperado %s, recibido %s", message, expected, actual))
end

assert_equal(vim.env.NVIM_APPNAME, "nvim-writing", "perfil aislado")
assert(vim.version.ge(vim.version(), { 0, 12, 4 }), "Neovim debe ser >= 0.12.4")

for _, command in ipairs({
  "WriteNew",
  "WriteRoot",
  "WritePreview",
  "WriteBuild",
  "WriteExport",
  "WriteLanguage",
  "WriteCitation",
  "WriteFocus",
  "WriteHealth",
}) do
  assert_equal(vim.fn.exists(":" .. command), 2, "comando " .. command)
end

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

local markdown_destination = vim.fn.tempname() .. "-nvim-writing-markdown"
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
