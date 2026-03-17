return {
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
    },
  },

  { -- Git commands in vim
    "tpope/vim-fugitive",
    config = function()
      local function toggle_git()
        local git_buffers = vim.tbl_filter(function(buf)
          return vim.bo[buf].filetype == "fugitive"
        end, vim.api.nvim_list_bufs())

        if #git_buffers > 0 then
          for _, buf in ipairs(git_buffers) do
            local windows = vim.fn.win_findbuf(buf)
            for _, win in ipairs(windows) do
              vim.api.nvim_win_close(win, false)
            end
          end
        else
          vim.cmd("Git")
        end
      end

      vim.keymap.set("n", "<leader>gs", toggle_git, { desc = "Git [S]tatus Toggle" })
      vim.keymap.set("n", "<leader>gd", "<cmd>Gvdiffsplit<CR>", { desc = "Git [D]iff Split" })
    end,
  },
}
