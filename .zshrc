###############################################################################
# env setup 
###############################################################################
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

###############################################################################
# zsh/omz setup 
###############################################################################
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="kali"

plugins=(
    vi-mode
    sudo
    systemd
    git
    docker
    docker-compose
    dotnet
    node
    npm
    nvm
    virtualenv
    python
    pip
    zoxide
    #voice-inject
)

# Source OMZ
source $ZSH/oh-my-zsh.sh

# Download Znap, if it's not there yet.
[[ -r ~/.config/zsh/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git ~/.config/zsh/znap
source ~/.config/zsh/znap/znap.zsh  # Start Znap

# Znap plugins
znap source zsh-users/zsh-autosuggestions
znap source zsh-users/zsh-syntax-highlighting

# Fix autosuggestion colors 
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#777777'

# fzf key bindings + completion (cross-distro)
_fzf_sources=(
  /usr/share/fzf/shell/key-bindings.zsh
  /usr/share/fzf/shell/completion.zsh
  /usr/share/doc/fzf/examples/key-bindings.zsh
  /usr/share/doc/fzf/examples/completion.zsh
)

for f in "${_fzf_sources[@]}"; do
  [[ -r "$f" ]] && source "$f"
done
unset _fzf_sources

# Bind personal override keys after all the zsh mods
bindkey '^t' autosuggest-accept

###############################################################################
# user environment 
###############################################################################

# Change cursor style on vi modes
function __set_beam_cursor {
  echo -ne '\e[6 q'
}

function __set_block_cursor {
  echo -ne '\e[2 q'
}

function zle-keymap-select {
  case $KEYMAP in
    vicmd) __set_block_cursor;;
    viins|main) __set_beam_cursor;;
  esac
}

precmd_functions+=(__set_beam_cursor)

zle -N zle-keymap-select

# Ensure ls colors work with non-standard terms
# if [[ -z "$LS_COLORS" ]]; then
#   eval "$(TERM=xterm-256color dircolors -b)"
# fi

# aliases
export PATH="$HOME/.local/bin:$PATH"
export EDITOR='nvim'

alias open='xdg-open'
alias vim='nvim'
alias todo="nvim $HOME/Dropbox/Documents/todo.txt"
alias myip='curl http://icanhazip.com'
alias l='ls -hal --color'
alias ll='ls -hal --color |less'
alias fd='fdfind --hidden --no-ignore' # show hidden and don't respect .gitignore (who comes up with these defaults?)
alias fzf='fzf --ansi'
alias lg='lazygit'
alias gd='git diff --name-only --relative --diff-filter=d |xargs bat --diff'
# alias ranger='source ranger' # drops you into currently selected dir when exiting ranger
alias ranger='ranger --cmd="set show_hidden true"'
alias ipython='ipython --no-autoindent' # autoindent messes with cut/paste and nvim send-to-term

# functions
genpwd() {
  local length=${1:-20}
  LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()_+=-' < /dev/urandom | head -c "$length"
  echo
}


###############################################################################
# specific packages 
###############################################################################

# ghostty
export GHOSTTY_SHELL_INTEGRATION_NO_CURSOR=1

# dotnet
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"

# go
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

# rust
export PATH="$HOME/.cargo/bin:$PATH"

# vcpkg
export VCPKG_ROOT="$HOME/.local/share/vcpkg/"
export PATH="$VCPKG_ROOT:$PATH"

# pyenv
export PATH="$HOME/.pyenv/bin:$PATH"
if command -v pyenv >/dev/null; then
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init - zsh)"
fi

# nvm
if command -v nvm >/dev/null; then
    export NVM_DIR="$HOME/.config/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

# miniforge (for conda and mamba)
export PATH="$HOME/miniforge3/bin:$PATH"

# conda
if command -v conda >/dev/null; then
    export CONDA_CHANGEPS1=false # disable default env name in prompt
    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$(\"$HOME/miniforge3/bin/conda\" 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
            . "$HOME/miniforge3/etc/profile.d/conda.sh"
        else
            export PATH="$HOME/miniforge3/bin:$PATH"
        fi
    fi
    unset __conda_setup
    # <<< conda initialize <<<
fi

# mamba
if command -v mamba >/dev/null; then
    export MAMBA_CHANGEPS1=false
    # >>> mamba initialize >>>
    # !! Contents within this block are managed by 'mamba shell init' !!
    export MAMBA_EXE="$HOME/miniforge3/bin/mamba";
    export MAMBA_ROOT_PREFIX="$HOME/miniforge3";
    __mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__mamba_setup"
    else
        alias mamba="$MAMBA_EXE"  # Fallback on help from mamba activate
    fi
    unset __mamba_setup
    # <<< mamba initialize <<<
fi
