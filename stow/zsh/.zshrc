export ZDOTDIR="$HOME"
export EDITOR="nvim"
export PATH="$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':omz:update' mode auto

ENABLE_CORRECTION="true"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH"/oh-my-zsh.sh

# Load dotfiles env overrides (create/edit ~/.config/dotfiles/env.sh)
if [ -f "$HOME/.config/dotfiles/env.sh" ]; then
  . "$HOME/.config/dotfiles/env.sh"
fi

# mise activation
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# fzf keybindings
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
fi

# Aliases
alias n="nvim"
alias vim="nvim"
alias v="nvim"
alias fd="fdfind"
alias ls="eza"
alias la="eza -a"
alias ll="eza -l"

bindkey '^I' complete-word         # tab | complete
bindkey '^[[Z' autosuggest-execute # shift + tab | autosuggest
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(buffer-empty bracketed-paste accept-line push-line-or-edit)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC=true

export LC_ALL="en_US.UTF-8"
export EDITOR="nvim"
export PATH="$PATH:/opt/nvim/"

# SSH
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# GPG
export GPG_TTY=$(tty)
gpgconf --launch gpg-agent

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# WSL tweaks
if grep -qi microsoft /proc/version 2>/dev/null; then
  export BROWSER="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
fi

# Run startup checks/upgrades (cached) + fastfetch on interactive TTYs
if [ -t 1 ] && [ -x "$HOME/.dotfiles/scripts/startup.sh" ]; then
  "$HOME/.dotfiles/scripts/startup.sh" --auto || true
fi

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
