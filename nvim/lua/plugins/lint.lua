return {
  {
    "mfussenegger/nvim-lint",
    dependencies = {
      "mason-org/mason.nvim",
    },
    event = "VeryLazy",
    init = function()
      require("config.mason_ensure").add({
        "markdownlint", -- Markdown linting
        "ruff", -- Python linting
      })
    end,
    opts = {
      ignore_errors = false
    },
    config = function()
      local function get_python_path()
        local venv = os.getenv("VIRTUAL_ENV")
        if venv then
          return venv .. "/bin/python"
        end

        ---@diagnostic disable: need-check-nil
        local handle = io.popen("command -v python")
        local result = handle:read("*a"):gsub("%s+$", "")
        handle:close()
        ---@diagnostic enable: need-check-nil

        return result
      end

      local lint = require("lint")

      --------------------------------------------------------------------
      -- 1. Configure linters per filetype
      --------------------------------------------------------------------
      lint.linters_by_ft = {
        markdown = { "markdownlint", },
        python   = { "ruff", "pylint", },
      }

      --------------------------------------------------------------------
      -- 2. Derive one unique set of *all* linter names
      --------------------------------------------------------------------
      local linter_set = {}      --  lookup  linter_set[name] → true
      for _, linters in pairs(lint.linters_by_ft) do
        for _, name in ipairs(linters) do
          linter_set[name] = true
        end
      end
      -- If you ever need the list as an array:
      -- local linter_list = vim.tbl_keys(linter_set)

      --------------------------------------------------------------------
      -- 3. Toggle: show linters (run) ⇄ hide them (reset only those active)
      --------------------------------------------------------------------
      local visible = false   -- start with diagnostics not shown
      local active = nil

      local function toggle_linter_diagnostics(names, opts)

        visible = not visible
        if visible then
          -- Re-run the linters for the current buffer
          active = names
          vim.b.linting = true
          vim.cmd("redrawstatus")
          lint.try_lint(active, opts)
          return
        end

        ------------------------------------------------------------------
        -- Hide phase:
        -- * enumerate all current namespaces (`vim.diagnostic.get_namespaces`)
        -- * if its *name* is one of our linters *and* the buffer actually
        --   has diagnostics in that namespace, reset it for this buffer
        ------------------------------------------------------------------
        active = nil
        vim.b.linting = false
        vim.cmd("redrawstatus")

        -- 0 ⇒ current buffer
        local bufnr = 0
        local nsinfo = vim.diagnostic.get_namespaces()  -- {ns_id → {name=…}}
        for ns_id, info in pairs(nsinfo) do
          if linter_set[info.name] then
            if #vim.diagnostic.get(bufnr, { namespace = ns_id }) > 0 then
              vim.diagnostic.hide(ns_id, bufnr)
            end
          end
        end
      end

      -- Run after save, insert leave, etc.
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
        callback = function()
          if visible then
            lint.try_lint(active)
          end
        end
      })

      -- Set python linters to work in virtualenv
      -- This has the addtl effect of keeping the linter quiet UNTIL one or the 
      -- other (or both) are available in the current env (global or venv)
      local python_path = get_python_path()
      lint.linters.pylint.cmd = python_path
      lint.linters.pylint.args = { "-m", "pylint", "-f", "json", "--from-stdin", function() return vim.api.nvim_buf_get_name(0) end, }
      lint.linters.ruff.cmd = get_python_path()
      lint.linters.ruff.args = { "-m", "ruff", "check", "--output-format=json", "--stdin-filename", function() return vim.api.nvim_buf_get_name(0) end, }

      -- Disable annoying overly pedantic rules
      -- MD013: Line length too long
      -- MD024: Duplicate headings
      lint.linters.markdownlint.args = { "--stdin", "--disable", "MD013", "MD024", "--", }

      vim.keymap.set("n", "<leader>fl", toggle_linter_diagnostics, { desc = "[L]int Current Buffer" })
    end
  }
}
