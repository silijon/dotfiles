--[[
=====================================================================
==================== JOHN W DENNIS NVIM CONFIG ======================
=====================================================================
========                                        _            ========
========                                      /   )          ========
========                                     @| ?\           ========
========       ._-_.    _____________________@| ?\\          ========
========      +|\G/|+  | ____________________@| ?\\\         ========
========      +|\./|+  || O  o o o  =|=  |  =@| ?\\\\        ========
========      +|\./|+  || O  o o o   |  =|=  | -- ====       ========
========       `|H|"   ||______________________||\ \\\       ========
========        |a|    |________________________| \ \\\      ========
========        |H|    ||MM88MM<<                            ========
========                                                     ========
=====================================================================
=====================================================================
--]]

-- Environmental Settings
vim.g.have_nerd_font = true
vim.g.full_ide_setup = vim.env.NVIM_FULL_IDE_SETUP == "1"

-- Set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable netrw for nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set tab defaults - vim-sleuth will adjust these as needed
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.g.pyindent_open_paren = vim.bo.shiftwidth --unfuck python indentation

-- Colors
vim.opt.termguicolors = true

-- Make line numbers default
vim.opt.number = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = "a"

-- Don"t show the mode, since it"s already in status line
vim.opt.showmode = false

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help "clipboard"`
vim.opt.clipboard = "unnamedplus"

-- Enable break indent
vim.opt.breakindent = true

-- Save undo history
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = "yes"

-- Decrease update time
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace in the editor.
--  See `:help "list"`
--  and `:help "listchars"`
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live, as you type!
vim.opt.inccommand = "split"

-- Show which line your cursor is on
-- vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- Disable folds, they're annoying
vim.opt.foldenable = false

-- Set highlight on search
vim.opt.hlsearch = true

-- Turn on spellcheck
vim.opt.spelllang = "en_us"
vim.opt.spell = true

-- Handle non-four-space tabstops per-file
local ft_settings = {
  lua = { ts = 2, sw = 2, et = true },
  bash = { ts = 2, sw = 2, et = true },
  zsh = { ts = 2, sw = 2, et = true },
  markdown = { ts = 2, sw = 2, et = true },
}

vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local s = ft_settings[args.match]
    if not s then return end

    vim.opt_local.tabstop = s.ts
    vim.opt_local.shiftwidth = s.sw
    vim.opt_local.expandtab = s.et
  end,
})

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
vim.keymap.set("n", "<leader>n", "<cmd>bnext<CR>", { desc = "Goto Next Buffer" })
vim.keymap.set("n", "<leader>p", "<cmd>bprev<CR>", { desc = "Goto Previous Buffer" })
vim.keymap.set("n", "<leader>b", "<C-^>", { desc = "Goto Previous Buffer" })

-- Clear search highlighting on <Esc> but still allow Esc for other things
vim.keymap.set("n", "<Esc>", function()
  if vim.v.hlsearch == 1 then
    vim.cmd('nohlsearch')
  end
  -- Fire a custom event that other plugins can listen to
  ---@diagnostic disable-next-line: param-type-mismatch
  vim.api.nvim_exec_autocmds("User", { pattern = "EscapePressed" })
end, { desc = "Clear search highlighting" })

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open Diagnostic [Q]uickfix List" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This (Esc-Esc) won"t work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<C-q>", "<C-\\><C-n>", { desc = "Exit Terminal Mode" })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move Focus to the Left Window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move Focus to the Right Window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move Focus to the Lower Window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move Focus to the Upper Window" })
vim.keymap.set("n", "<Tab>", "<C-w><C-w>", { desc = "Move Focus Between Splits" })

-- <leader>x in visual mode will run whatever you’ve selected as Lua
vim.keymap.set("v", "<leader>x", function()
  -- yank visual selection to register z
  vim.cmd('normal! "zy')
  local lines = tostring(vim.fn.getreg('z'))

  -- compile
  local fn, err = loadstring(lines)
  if not fn then
    return vim.notify("Lua compile error: " .. err, vim.log.levels.ERROR)
  end

  -- run
  local ok, result = pcall(fn)
  if not ok then
    vim.notify("Lua runtime error: " .. result, vim.log.levels.ERROR)
  else
    vim.notify("Output: " .. tostring(result),  vim.log.levels.INFO)
  end
end, { desc = "Execute visual selection as Lua" })

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
---@diagnostic disable-next-line: param-type-mismatch
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
---@diagnostic disable-next-line: undefined-field
if not vim.loop.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath }
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    { -- colorscheme
      "EdenEast/nightfox.nvim",
      lazy = false,
      priority = 1000,
      config = function()
        require("nightfox").setup({
          palettes = {
            carbonfox = {
              sel0 = "#3e4a5b" -- brighten visual selection
            },
          },
          options = {
            transparent = true,
            styles = {
              comments = "italic",
              types = "italic",
            }
          }
        })
        vim.cmd.colorscheme "carbonfox"
      end
    },

    { -- Edit filesystem as buffer
      'stevearc/oil.nvim',
      dependencies = { "nvim-tree/nvim-web-devicons" },
      lazy = false,
      config = function()
        require("oil").setup({
          default_file_explorer = false,
          skip_confirm_for_simple_edits = true,
          columns = { "icon", "permissions", "size", "mtime", },
          float = {
            max_height = 0.7,
            max_width = 0.7,
            preview_split = "auto",
          },
          view_options = { show_hidden = true, }
        })

        vim.keymap.set("n", "-", require("oil").open_float, { desc = "Open Oil in current working directory" })
      end,
    },

    "tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically

    { "numToStr/Comment.nvim",    opts = {} }, -- Quick commenting/uncommenting


    { -- Useful plugin to show you pending keybinds.
      "folke/which-key.nvim",
      event = "VeryLazy", -- Sets the loading event to "VeryLazy"
      opts = {
        -- delay between pressing a key and opening which-key (milliseconds)
        -- this setting is independent of vim.opt.timeoutlen
        delay = 0,
        icons = {
          -- set icon mappings to true if you have a Nerd Font
          mappings = vim.g.have_nerd_font,
          -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
          -- default which-key.nvim defined Nerd Font icons, otherwise define a string table
          keys = vim.g.have_nerd_font and {} or {
            Up = "<Up> ",
            Down = "<Down> ",
            Left = "<Left> ",
            Right = "<Right> ",
            C = "<C-…> ",
            M = "<M-…> ",
            D = "<D-…> ",
            S = "<S-…> ",
            CR = "<CR> ",
            Esc = "<Esc> ",
            ScrollWheelDown = "<ScrollWheelDown> ",
            ScrollWheelUp = "<ScrollWheelUp> ",
            NL = "<NL> ",
            BS = "<BS> ",
            Space = "<Space> ",
            Tab = "<Tab> ",
            F1 = "<F1>",
            F2 = "<F2>",
            F3 = "<F3>",
            F4 = "<F4>",
            F5 = "<F5>",
            F6 = "<F6>",
            F7 = "<F7>",
            F8 = "<F8>",
            F9 = "<F9>",
            F10 = "<F10>",
            F11 = "<F11>",
            F12 = "<F12>",
          },
        },
        -- Document existing key chains
        spec = {
          { "<leader>c", group = "[C]ode",     mode = { "n", "x" } },
          { "<leader>f", group = "[F]ormat" },
          { "<leader>d", group = "[D]ebug" },
          { "<leader>s", group = "[S]earch" },
          { "<leader>h", group = "[H]arpoon" },
        },
      },
    },

    { -- Highlight todo, notes, etc in comments
      "folke/todo-comments.nvim",
      event = "VimEnter",
      dependencies = { "nvim-lua/plenary.nvim" },
      opts = { signs = false },
    },

    { -- Collection of various small independent plugins/modules
      "echasnovski/mini.nvim",
      config = function()

        -- Better Around/Inside textobjects
        --
        -- Examples:
        --  - va)  - [V]isually select [A]round [)]paren
        --  - yinq - [Y]ank [I]nside [N]ext ["]quote
        --  - ci"  - [C]hange [I]nside ["]quote
        require("mini.ai").setup { n_lines = 500 }

        -- Add/delete/replace surroundings (brackets, quotes, etc.)
        --
        -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
        -- - sd"   - [S]urround [D]elete ["]quotes
        -- - sr)"  - [S]urround [R]eplace [)] ["]
        vim.keymap.set({ "n", "v" }, "s", "<Nop>", { noremap = true }) -- Avoid conflicts
        require("mini.surround").setup({
          custom_surroundings = {
            ["+"] = { -- bold in markdown
              input = { '%*%*().-()%*%*' },
              output = { left = '**', right = '**' },
            },
            ["-"] = { -- strikethrough in markdown
              input = { '%~%~().-()%~%~' },
              output = { left = '~~', right = '~~' },
            },
          },
        })

      end,
    },

    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        ---@diagnostic disable-next-line: redundant-value
        require("lualine").setup {
          options = {
            theme = "nightfly",
          },
          sections = {
            lualine_b = {
              "branch",
              "diff",
              {
                "linter",
                padding = { left = 1, right = 1 },
                fmt = function() return vim.b.linting and "󰒱" or "󰅙" end,
              },
              "diagnostics",
            },
            lualine_x = {
              {
                "macro",
                icon = "󰑋",
                color = { fg = "#ff0000", gui = "bold" },
                cond = function()
                  return vim.fn.reg_recording() ~= ""
                end,
                padding = { left = 1, right = 1 },
                fmt = function()
                  local key = vim.fn.reg_recording()
                  if key == "" then
                    return ""
                  else
                    return "@" .. key
                  end
                end,
              },
              "encoding",
              {
                "fileformat",
                padding = { left = 1, right = 1 },
              },
              "filetype",
            },
          }
        }
      end
    },

    {
      "nvim-treesitter/nvim-treesitter",
      lazy = false,
      build = ":TSUpdate",
      config = function()
        local filetypes = {
          "bash", "zsh", "diff", "query", "regex", "csv",
          "vim", "lua", "c", "python", "java",
          "html", "css", "javascript", "jsx", "typescript", "tsx",
          "vimdoc", "luadoc", "json", "yaml", "toml",
          "markdown", "markdown_inline",
        }

        -- Optional: keep this if you like auto-install; it's async.
        -- It will race on fresh installs, so treesitter.start() MUST be pcall'd.
        require("nvim-treesitter").install(filetypes)

        vim.api.nvim_create_autocmd("FileType", {
          pattern = filetypes,
          callback = function(args)
            pcall(vim.treesitter.start, args.buf)
          end,
        })

        -- Filetype associations
        vim.filetype.add({ extension = { jams = "json" } })
        vim.filetype.add({
          filename = {
            ["docker-compose.yml"] = "yaml.docker-compose",
            ["docker-compose.yaml"] = "yaml.docker-compose",
            ["compose.yml"] = "yaml.docker-compose",
            ["compose.yaml"] = "yaml.docker-compose",
          },
        })

        -- Make docker-compose TS use yaml parser/queries (optional but nice)
        vim.treesitter.language.register("yaml", { "yaml.docker-compose" })

        -- Highlight tweaks
        vim.api.nvim_set_hl(0, "@markup.strikethrough", { strikethrough = true, fg = "#888888" })
        vim.api.nvim_set_hl(0, "@markup.strong", { bold = true })
        vim.api.nvim_set_hl(0, "@markup.emphasis", { italic = true })
        vim.api.nvim_set_hl(0, "@markup.raw.inline", { fg = "#ffa500", bg = "#2b2b2b" })
      end,
    },

    -- Show colors when color codes are detected
    "norcalli/nvim-colorizer.lua",

    { -- Integrates window navigation with tmux
      "christoomey/vim-tmux-navigator",
      lazy = false,
      config = function()
        vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { desc = "Tmux Window Left" })
        vim.keymap.set("n", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { desc = "Tmux Window Right" })
        vim.keymap.set("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { desc = "Tmux Window Down" })
        vim.keymap.set("n", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { desc = "Tmux Window Up" })
      end,
    },

    -- Makes debugging nvim configs easier by running lua in a full screen
    -- "rafcamlet/nvim-luapad",

    -- Minimal Setup
    { import = "plugins/telescope" },
    { import = "plugins/harpoon" },
    { import = "plugins/noice" },

    -- Full Setup
    { import = "plugins/mason", cond = vim.g.full_ide_setup },
    { import = "plugins/lspconfig", cond = vim.g.full_ide_setup },
    { import = "plugins/todo", cond = vim.g.full_ide_setup },
    { import = "plugins/autocmp", cond = vim.g.full_ide_setup },
    { import = "plugins/format", cond = vim.g.full_ide_setup },
    { import = "plugins/lint", cond = vim.g.full_ide_setup },
    { import = "plugins/term", cond = vim.g.full_ide_setup },
    { import = "plugins/git", cond = vim.g.full_ide_setup },
    { import = "plugins/debugger", cond = vim.g.full_ide_setup },
    -- { import = "plugins/copilot", cond = vim.g.full_ide_setup },

  },
  ---@diagnostic disable-next-line: missing-fields
  {
    ui = {
      -- If you are using a Nerd Font: set icons to an empty table which will use the
      -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
      icons = vim.g.have_nerd_font and {} or {
        cmd = "⌘",
        config = "🛠",
        event = "📅",
        ft = "📂",
        init = "⚙",
        keys = "🗝",
        plugin = "🔌",
        runtime = "💻",
        require = "🌙",
        source = "📄",
        start = "🚀",
        task = "📌",
        lazy = "💤 ",
      },
    },
  })
