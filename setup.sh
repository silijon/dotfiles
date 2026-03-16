#!/usr/bin/env bash

set -euo pipefail

log() {
  echo -e "\033[1;32m==> $1\033[0m"
}


# --- Architecture Check (Early Exit) ---
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        THIS_ARCH="x86_64"
        ;;
    aarch64|arm64)
        THIS_ARCH="arm64"
        ;;
    *)
        log "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

  
# --- Configuration ---
USERNAME=$(whoami)
USER_HOME="$HOME"
DOTFILES="https://github.com/silijon/dot-config.git"
# NVIM_INSTALL_DIR="$HOME/.local/bin/nvim"
NVIM_INSTALL_DIR="/opt"
NVIM_DIST_DIR="$NVIM_INSTALL_DIR/nvim-linux-$THIS_ARCH"
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$THIS_ARCH.tar.gz"
log "Running as $USERNAME on $ARCH. Home: $USER_HOME"

# Setup Sudo prefix if not root
SUDO_CMD=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO_CMD="sudo"
fi


# --- System Dependencies ---
log "Updating apt and installing base dependencies..."
$SUDO_CMD apt update
# We need 'ca-certificates' early to talk to GitHub securely
$SUDO_CMD apt install -y ca-certificates git curl sudo locales build-essential
$SUDO_CMD sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
$SUDO_CMD locale-gen


# --- User Packages ---
REQUIRED_PKGS=(
  zsh
  tmux
  fd-find
  ripgrep
  fzf
  zoxide
  ranger
  direnv
)

for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        log "Installing $pkg..."
        $SUDO_CMD apt install -y "$pkg"
    fi
done


# -- Symlinks for User Packages
ln -sfT "$USER_HOME/dotfiles/.zshrc" "$USER_HOME/.zshrc"
ln -sfT "$USER_HOME/dotfiles/.gitconfig" "$USER_HOME/.gitconfig"
ln -sfT "$USER_HOME/dotfiles/.tmux.conf" "$USER_HOME/.tmux.conf"
ln -sfT "$USER_HOME/dotfiles/.rgignore" "$USER_HOME/.rgignore"


# --- Clone dotfiles ---
if [ ! -d "$USER_HOME/dotfiles" ]; then
    log "Cloning dotfiles..."
    git clone "$DOTFILES" "$USER_HOME/dotfiles"
fi


# --- Install Oh My Zsh (Unattended) ---
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh..."
    export ZSH="$USER_HOME/.oh-my-zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    # mkdir -p "$USER_HOME/.oh-my-zsh/themes"
    ln -sfT "$USER_HOME/dotfiles/kali.zsh-theme" "$USER_HOME/.oh-my-zsh/themes/kali.zsh-theme"
fi


# --- Tmux Packages ---
if [ ! -d "$USER_HOME/.tmux/plugins/tpm" ]; then
  log "Installing tmux plugin manager (TPM)..."
  git clone https://github.com/tmux-plugins/tpm "$USER_HOME/.tmux/plugins/tpm"

  log "Installing tmux plugins..."
  if tmux has-session 2>/dev/null || $SUDO_CMD tmux start-server 2>/dev/null; then
      tmux new-session -d -s temp_session && \
      tmux send-keys -t temp_session 'run-shell ~/.tmux/plugins/tpm/scripts/install_plugins.sh' C-m && \
      sleep 2 && tmux kill-session -t temp_session
  else
    log "Unable to initialize tmux server. Skipping tmux plugin install."
  fi
else
  log "TPM already installed. Skipping."
fi


# Install Neovim Binary (Native Arch) ---
if [ ! -d "$NVIM_DIST_DIR" ]; then
    log "Installing Neovim ($THIS_ARCH) to $NVIM_INSTALL_DIR..."
    $SUDO_CMD mkdir -p "$NVIM_INSTALL_DIR"

    TEMP_DIR=$(mktemp -d)
    curl -LO --output-dir "$TEMP_DIR" "$NVIM_URL"
    
    $SUDO_CMD tar -C $NVIM_INSTALL_DIR -xzf "$TEMP_DIR/$(basename "$NVIM_URL")"
    $SUDO_CMD ln -sf "$NVIM_DIST_DIR/bin/nvim" /usr/local/bin/nvim

    rm -rf "$TEMP_DIR"

    mkdir -p "$USER_HOME/.config"

    if command -v update-alternatives >/dev/null; then
        $SUDO_CMD update-alternatives --install /usr/bin/vim vim /usr/local/bin/nvim 60
        $SUDO_CMD update-alternatives --set vim /usr/local/bin/nvim
    fi
else
    log "Neovim already exists at $NVIM_DIST_DIR."
fi

ln -sfT "$USER_HOME/dotfiles/nvim" "$USER_HOME/.config/nvim"

# --- Final message ---
log "Setup complete. Switching to home directory and sourcing shell..."
cd "$USER_HOME"
$SUDO_CMD chsh -s $(which zsh) "$USERNAME"

log "You may need to log out and back in for shell changes to take effect."
