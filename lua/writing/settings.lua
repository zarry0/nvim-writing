return {
  required_neovim = "0.12.4",
  default_language = "es",
  primary_ltex_language = "es-ES",
  theme = "writing-monochrome",
  theme_variant = "dark",
  zen_width = 92,
  preview_auto_start = false,
  word_count_debounce_ms = 450,
  word_count_timeout_ms = 2500,
  word_count_max_source_bytes = 2 * 1024 * 1024,
  treesitter_parsers = { "markdown", "markdown_inline", "typst", "latex", "bibtex" },
}
