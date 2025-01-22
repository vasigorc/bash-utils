
return {"nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
  config = function()
      local configs = require("nvim-treesitter.configs")
    configs.setup({
      ensure_installed = { "c", "lua", "vim", "vimdoc", "javascript", "html", "awk", "cpp", "gitignore", "gitcommit", "git_config", "hocon", "java", "json", "kotlin", "llvm", "markdown", "nix", "proto", "python", "ruby", "rust", "scala", "sql", "terraform", "toml", "typescript", "xml", "yaml", "zig"},
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },  
    })
  end
}
