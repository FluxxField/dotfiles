#!/usr/bin/env bash
# Install oh-my-zsh + essential plugins (zsh-autosuggestions, zsh-syntax-highlighting).
set -euo pipefail

# Ensure zsh present
if ! command -v zsh >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -o=Dpkg::Use-Pty=0 || true
    sudo apt-get install -y zsh
  elif command -v brew >/dev/null 2>&1; then
    brew install zsh
  fi
fi

# Install oh-my-zsh (no auto-run, keep existing .zshrc)
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/plugins"

# Plugins via OMZ/custom
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Ensure .zshrc loads OMZ and enables plugins
ZRC="$HOME/.zshrc"
touch "$ZRC"

# Add OMZ bootstrap if missing
if ! grep -q 'oh-my-zsh.sh' "$ZRC"; then
  {
    echo ''
    echo '# --- oh-my-zsh ---'
    echo 'export ZSH="$HOME/.oh-my-zsh"'
    echo 'ZSH_THEME="robbyrussell"'
    echo 'plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)'
    echo 'if [ -s "$ZSH/oh-my-zsh.sh" ]; then'
    echo '  source "$ZSH/oh-my-zsh.sh"'
    echo 'fi'
  } >>"$ZRC"
fi

# If a plugins=(...) line exists, ensure our two plugins are present
if grep -qE '^[[:space:]]*plugins=\(' "$ZRC"; then
  for p in zsh-autosuggestions zsh-syntax-highlighting; do
    grep -q "$p" "$ZRC" || sed -i -E "s/^(plugins=\(.*)\)$/\1 $p)/" "$ZRC"
  done
fi
