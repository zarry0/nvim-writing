local opt = vim.opt

opt.autochdir = false
opt.autoread = true
opt.backup = false
opt.breakindent = true
opt.breakindentopt = { "shift:2", "min:20" }
opt.completeopt = { "menu", "menuone", "noselect" }
opt.confirm = true
opt.cursorline = true
opt.encoding = "utf-8"
opt.expandtab = true
opt.exrc = false
opt.hidden = true
opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"
opt.ignorecase = true
opt.inccommand = "split"
opt.incsearch = true
opt.laststatus = 3
opt.linebreak = true
opt.list = false
opt.mouse = "a"
opt.modeline = true
opt.modelines = 5
opt.number = true
opt.relativenumber = true
opt.scrolloff = 8
opt.showmode = false
opt.showtabline = 2
opt.sidescrolloff = 8
opt.signcolumn = "yes:1"
opt.smartcase = true
opt.smartindent = true
opt.spellsuggest = "best,9"
opt.splitbelow = true
opt.splitright = true
opt.swapfile = true
opt.tabstop = 2
opt.termguicolors = true
opt.textwidth = 0
opt.shiftwidth = 2
opt.softtabstop = 2
opt.undofile = true
opt.updatetime = 250
opt.wrap = true
opt.writebackup = true

opt.listchars = {
  nbsp = "␣",
  tab = "› ",
  trail = "·",
}

local undo_dir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undo_dir, "p")
opt.undodir = undo_dir

opt.sessionoptions = {
  "buffers",
  "curdir",
  "folds",
  "globals",
  "help",
  "tabpages",
  "winsize",
}
