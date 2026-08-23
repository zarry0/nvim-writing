return {
  {
    "brianhuster/live-preview.nvim",
    cmd = "LivePreview",
    ft = { "markdown" },
    dependencies = { "ibhagwan/fzf-lua" },
    config = function()
      require("writing.core.live_preview").setup()
    end,
  },
}
