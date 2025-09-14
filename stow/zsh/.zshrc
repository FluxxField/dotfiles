export ZDOTDIR="$HOME"
export EDITOR="nvim"
export PATH="$HOME/.local/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

zstyle ':omz:update' mode auto

plugins=(
  git
)

source "$ZSH"/oh-my-zsh.sh

# Load dotfiles env overrides (create/edit ~/.config/dotfiles/env.sh)
if [ -f "$HOME/.config/dotfiles/env.sh" ]; then
  . "$HOME/.config/dotfiles/env.sh"
fi

# fzf keybindings
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
fi

# Aliases
alias n="nvim"
alias vim="vim"
alias ll='ls -alF'
alias lg='git lg'

# WSL tweaks
if grep -qi microsoft /proc/version 2>/dev/null; then
  export BROWSER="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
fi

# Run startup checks/upgrades (cached) + fastfetch on interactive TTYs
if [ -t 1 ] && [ -x "$HOME/.dotfiles/scripts/startup.sh" ]; then
  "$HOME/.dotfiles/scripts/startup.sh" --auto || true
fi

eval "$(starship init zsh)"
