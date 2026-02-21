return {
  { -- Fuzzy Finder (files, lsp, etc)
    "nvim-telescope/telescope.nvim",
    event = "VimEnter",
    dependencies = {
      "nvim-lua/plenary.nvim",

      -- Overrides native vim select
      "nvim-telescope/telescope-ui-select.nvim",

      -- Fuzzy find
      { -- If encountering errors, see telescope-fzf-native README for install instructions
        "nvim-telescope/telescope-fzf-native.nvim",

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = "make",

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable "make" == 1
        end,
      },

      -- File browser
      "nvim-telescope/telescope-file-browser.nvim",

      -- Zoxide for slick dir changes
      "jvgrootveld/telescope-zoxide",

      -- Nav the undo tree
      "debugloop/telescope-undo.nvim",

      -- Pretty icons -- requires Nerd Font
      { "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      local telescope = require("telescope")

      -- Make file picking more readable
      vim.api.nvim_create_autocmd("FileType", {
          pattern = "TelescopeResults",
          callback = function(ctx)
              vim.api.nvim_buf_call(ctx.buf, function()
                  vim.fn.matchadd("TelescopeParent", "\t\t.*$")
                  vim.api.nvim_set_hl(0, "TelescopeParent", { link = "Comment" })
              end)
          end,
      })

      telescope.setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you"re looking for is in `:help telescope.setup()`
        pickers = {
          find_files = {
            find_command = {
              "rg",
              "--smart-case",
              "--hidden",
              "--files",
              "--no-ignore-vcs",
              "--glob",
              "!**/.git/*",
              "--glob",
              "!**/.cache/*",
              "--glob",
              "!**/node_modules/*",
              "--glob",
              "!**/.venv/*",
              "--glob",
              "!**/__pycache__/*",
              "--glob",
              "!**/.next/*",
              "--glob",
              "!**/.ruff_cache/*",
            },
          },
          live_grep = {
            additional_args = {
              "--smart-case",
              "--hidden",
              "--no-ignore-vcs",
            },
            glob_pattern = {
              "!**/.git/*",
              "!**/node_modules/*",
              "!**/.venv/*",
              "!**/__pycache__/*",
              "!**/.next/*",
              "!**/.ruff_cache/*",
            },
          },
          buffers = {
            sort_mru = true,
            sort_lastused = true
          }
        },
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown(),
          },
          file_browser = {
            hijack_netrw = true,
            hidden = true,
            -- path = "%:p:h", -- open in current file dir (default is pwd)
            mappings = {
              ["n"] = {
                ["H"] = telescope.extensions.file_browser.actions.toggle_hidden,
                ["h"] = telescope.extensions.file_browser.actions.goto_parent_dir,
                ["l"] = require("telescope.actions").select_default,
              },
            },
          },
          zoxide = {
            mappings = {
              default = {
                -- Fix bug in Harpoon: https://github.com/rmagatti/auto-session/issues/433
                before_action = function()
                  -- might not be necessary, but save current harpoon data when we're about to restore a session
                  require("harpoon"):sync()
                end,
                after_action = function(selection)
                  -- this is the only way i found to force harpoon to reread data from the disk rather
                  -- than using what's in memory
                  local harpoon = require("harpoon")
                  harpoon.data = require("harpoon.data").Data:new(harpoon.config)
                  print("Updated to (" .. selection.z_score .. ") " .. selection.path)
                end
              },
            },
          },
          undo = {
            mappings = {
              i = {
                ["<cr>"] = require("telescope-undo.actions").restore,
              },
              n = {
                ["<cr>"] = require("telescope-undo.actions").restore,
                ["y"] = require("telescope-undo.actions").yank_additions,
                ["Y"] = require("telescope-undo.actions").yank_deletions,
              },
            },
          },
        },
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
          path_display = function(_, path)
            local tail = vim.fs.basename(path)
            local parent = vim.fs.dirname(path)
            if parent == "." then return tail end
            return string.format("%s\t\t%s", tail, parent)
          end,
        }
      }

      -- Enable telescope extensions, if they are installed
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
      pcall(telescope.load_extension, "file_browser")
      pcall(telescope.load_extension, "zoxide")
      pcall(telescope.load_extension, "undo")

      -- See `:help telescope.builtin`
      local builtin = require "telescope.builtin"

      vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
      vim.keymap.set("n", "<leader>sk", builtin.keymaps, { desc = "[S]earch [K]eymaps" })
      vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })
      vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
      vim.keymap.set("n", "<leader>sb", builtin.buffers, { desc = "[S]earch Open [B]uffers" })
      vim.keymap.set("n", "<leader>st", builtin.builtin, { desc = "[S]earch Select [T]elescope" })
      vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch Current [W]ord" })
      vim.keymap.set("n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
      vim.keymap.set("n", "<leader>sr", builtin.resume, { desc = "[S]earch [R]esume" })
      vim.keymap.set("n", "<leader>s.", builtin.oldfiles, { desc = "[S]earch Recent Files ('.' for repeat)" })
      vim.keymap.set("n", "<leader>su", telescope.extensions.undo.undo, { desc = "Search [U]ndo history" })
      vim.keymap.set("n", "<leader>sz", telescope.extensions.zoxide.list, { desc = "Search Zoxide to Change Directory" })

      -- Special addtl setting for most common use case
      vim.keymap.set("n", "<leader><leader>", builtin.find_files, { desc = "[S]earch [F]iles" })

      -- Override default spell suggestions to use telescope
      vim.keymap.set('n', "z=", builtin.spell_suggest, { desc = 'Spell Suggest' })

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set("n", "<leader>/", function()
        -- You can pass additional configuration to telescope to change theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = "[/] Fuzzily Search in Current Buffer" })

      -- Also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set("n", "<leader>s/", function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = "Live Grep in Open Files",
        }
      end, { desc = "[S]earch [/] in Open Files" })

      -- Shortcut for searching your neovim configuration files
      vim.keymap.set("n", "<leader>sn", function()
        builtin.find_files { cwd = vim.fn.stdpath "config" }
      end, { desc = "[S]earch [N]eovim Files" })

      -- Git search shortcuts
      vim.keymap.set("n", "<leader>ss", builtin.git_status, { desc = "[S]earch git [S]tatus" })
      vim.keymap.set("n", "<leader>sc", builtin.git_commits, { desc = "[S]earch git [C]ommits" })

      -- Open file browser in cwd
      vim.keymap.set("n", "<leader>e", function()
        require("telescope").extensions.file_browser.file_browser()
      end, { desc = "Open file [e]xplorer in current working directory" })

      -- Open file browser in current file dir
      vim.keymap.set("n", "<leader>E", function()
        require("telescope").extensions.file_browser.file_browser({
          path = "%:p:h",
          select_buffer = true,
        })
      end, { desc = "Open file [E]xplorer in current file directory" })

      -- Add line numbers to the previewer
      vim.cmd "autocmd User TelescopePreviewerLoaded setlocal number"
    end,
  },
}
