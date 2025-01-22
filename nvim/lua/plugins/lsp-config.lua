return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end

  },
  -- ensures that the mentioned LSP servers are automatically installed on your system
  -- without having to manually install them via Mason
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        -- other LSP names', including `rust_analyzer` or `pyright` may be found here: https://github.com/williamboman/mason-lspconfig.nvim?tab=readme-ov-file#available-lsp-servers
        ensure_installed = { "lua_ls"}
      })
    end
  }, {
    -- this hooks-up nvim to the installed LSP servers by sending them requests like: file-opened, file-updated, etc.
    "neovim/nvim-lspconfig",
    config = function()
      -- repeat this for every LSP
      local lspconfig = require("lspconfig")
      lspconfig.lua_ls.setup({})
      -- do `:h vim.lsp.buf` to see all options for key-binding
      -- `n` stands for Normal mode
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {})
      vim.keymap.set({'n', 'v'}, '<leader>ca', vim.lsp.buf.code_action, {})
    end
  }
}
