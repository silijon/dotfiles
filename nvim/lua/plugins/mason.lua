return {
    { -- mason
      "mason-org/mason.nvim",
      opts = {
        log_level = vim.log.levels.INFO
      }
    },
    { -- mason auto installer
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      dependencies = { "mason-org/mason.nvim" },
      -- don’t force it to run on servers unless you want it
      enabled = true,
      config = function()
        local tools = require("config.mason_ensure")
        require("mason-tool-installer").setup({
          ensure_installed = tools.list(),
          auto_update = false,
          run_on_start = true,
        })
      end,
    },
  }

