return {
  {
    "stevearc/conform.nvim",
    dependencies = {
      "mason-org/mason.nvim",
    },
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>ff",
        function()
          require("conform").format { async = true, lsp_format = "fallback" }
        end,
        mode = "",
        desc = "[F]ormat Current Buffer",
      },
    },
    init = function()
      require("config.mason_ensure").add({
        "stylua", -- Used to format lua code
        "black", -- Used to format python code
        "isort", -- Used to format python imports
        "jq", -- Json formatting
        "markdownlint", -- Markdown linting
        "mdformat", -- Markdown formatting
        "prettier", -- JS/TS formatting
        "ruff", -- Python formatting
      })
    end,
    opts = {
      notify_on_error = false,
      format_on_save = false,
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_fix", "ruff_format", "ruff_organize_imports", "isort", "black", },
        markdown = { "mdformat" },
        json = { "jq" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        --
        -- You can use "stop_after_first" to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
}
