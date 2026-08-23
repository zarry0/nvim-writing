return {
  {
    "chomosuke/typst-preview.nvim",
    version = "1.*",
    ft = "typst",
    opts = function()
      local project = require("writing.core.project")
      return {
        dependencies_bin = { tinymist = "tinymist" },
        follow_cursor = true,
        partial_rendering = true,
        get_main_file = function(path)
          return project.resolve_path(path).main or path
        end,
        get_root = function(path)
          return project.resolve_path(path).root or vim.fs.dirname(path)
        end,
      }
    end,
  },
}
