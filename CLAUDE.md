# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles configuration repository containing:
- **Neovim configuration** (`nvim/`) - Lua-based setup with lazy.nvim plugin manager
- **Alacritty terminal configuration** (`alacritty.toml`)
- **Zsh/Oh-My-Zsh configuration** (`.zshrc`, `kali.zsh-theme`)
- **VS Code settings** (`vscode/`)
- **Setup automation** (`setup.sh`)

## Architecture and Structure

### Neovim Configuration (`nvim/`)
- **Entry point**: `nvim/init.lua` - Contains base vim settings, keymaps, and lazy.nvim setup
- **Plugin system**: Uses lazy.nvim for plugin management with conditional loading
- **Plugin modules**: Individual plugins in `nvim/lua/plugins/` directory
- **Two-tier setup**: Minimal setup vs full IDE setup controlled by `NVIM_FULL_IDE_SETUP=1` environment variable
- **Key plugins**: Telescope (fuzzy finder), Harpoon (file navigation), LSP config, formatters, linters

### Setup System
- **Primary installer**: `setup.sh` - Comprehensive system setup script that:
  - Installs system packages (curl, git, zsh, tmux, fd-find, ripgrep, fzf, zoxide, ranger)
  - Builds Neovim from source if not installed
  - Sets up Oh-My-Zsh with custom theme
  - Creates symlinks for all config files
  - Configures tmux with TPM (Tmux Plugin Manager)

## Common Commands

### System Setup
```bash
# Full system setup (requires root)
sudo ./setup.sh
```

### Neovim
```bash
# Launch with full IDE features
NVIM_FULL_IDE_SETUP=1 nvim

# Launch with minimal setup (default)
nvim
```

### Configuration Management
- Neovim config is symlinked to `~/.config/nvim`
- Zsh config is symlinked to `~/.zshrc`
- Git config is symlinked to `~/.gitconfig`
- Tmux config is symlinked to `~/.tmux.conf`

## Key Features

### Neovim Features
- **Leader key**: Space
- **File navigation**: Oil.nvim for filesystem editing, Harpoon for quick file switching
- **Search**: Telescope with fzf integration
- **Terminal integration**: Built-in terminal with tmux navigation
- **Color scheme**: Carbonfox (nightfox.nvim)
- **Status line**: mini.statusline with git, diagnostics, and LSP info
- **todo.txt sync**: `lua/config/todo_sync.lua` syncs `~/todo.txt` with Dropbox via curl on save (OAuth PKCE, `git merge-file` for conflicts). Commands: `:TodoSyncLogin`, `:TodoSyncPull`, `:TodoSyncPush`, `:TodoSyncStatus`

### Shell Environment
- **Zsh plugins**: vi-mode, sudo, git, python, node, zoxide via Oh-My-Zsh
- **Additional plugins**: zsh-autosuggestions, zsh-syntax-highlighting via znap
- **Theme**: Custom "kali" theme
- **Tools**: fd, ripgrep, fzf, zoxide for enhanced file operations

## File Modifications

When modifying configuration files:
- Neovim plugins are in separate files under `nvim/lua/plugins/`
- Main nvim config is in `nvim/init.lua`
- Shell customizations go in `.zshrc`
- Terminal settings in `alacritty.toml`