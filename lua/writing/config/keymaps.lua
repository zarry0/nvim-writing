local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Limpiar búsqueda" })
map("n", "gl", vim.diagnostic.open_float, { desc = "Mostrar diagnóstico" })

map("n", "<leader>h", "<cmd>split<CR>", { desc = "Split horizontal" })
map("n", "<leader>v", "<cmd>vsplit<CR>", { desc = "Split vertical" })

map("n", "<C-h>", "<C-w>h", { desc = "Foco a la izquierda" })
map("n", "<C-j>", "<C-w>j", { desc = "Foco abajo" })
map("n", "<C-k>", "<C-w>k", { desc = "Foco arriba" })
map("n", "<C-l>", "<C-w>l", { desc = "Foco a la derecha" })

map("n", "<BS>H", "<C-w>H", { desc = "Mover ventana a la izquierda" })
map("n", "<BS>J", "<C-w>J", { desc = "Mover ventana abajo" })
map("n", "<BS>K", "<C-w>K", { desc = "Mover ventana arriba" })
map("n", "<BS>L", "<C-w>L", { desc = "Mover ventana a la derecha" })

map("n", "<leader>u", function()
  vim.api.nvim_cmd({ cmd = "packadd", args = { "nvim.undotree" } }, {})
  vim.api.nvim_cmd({ cmd = "Undotree" }, {})
end, { desc = "Abrir undo tree nativo" })

-- Tabby solamente dibuja estas tabpages nativas; no hay bufferline.
map("n", "<C-t>t", "<cmd>tabnew<CR>", { desc = "Nueva tabpage" })
map("n", "<C-t>c", "<cmd>tabclose<CR>", { desc = "Cerrar tabpage" })
map("n", "<C-t>n", "<cmd>tabnext<CR>", { desc = "Siguiente tabpage" })
map("n", "<C-t>p", "<cmd>tabprevious<CR>", { desc = "Tabpage anterior" })

map("n", "<leader>yp", function()
  local path = vim.fn.expand("%:~")
  vim.fn.setreg("+", path)
  vim.notify("Ruta copiada: " .. path)
end, { desc = "Copiar ruta del archivo" })

local function wrapped_motion(key)
  return function()
    return vim.v.count == 0 and "g" .. key or key
  end
end

map({ "n", "x" }, "j", wrapped_motion("j"), {
  expr = true,
  silent = true,
  desc = "Bajar renglón visual; con conteo, línea lógica",
})
map({ "n", "x" }, "k", wrapped_motion("k"), {
  expr = true,
  silent = true,
  desc = "Subir renglón visual; con conteo, línea lógica",
})
