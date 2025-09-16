#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

source scripts/detect-os.sh

# 0) Core deps
if ! command -v stow >/dev/null; then
  if [[ "$OS" == "mac" ]]; then
    bash scripts/install-brew.sh
    brew install stow
  fi

  if [[ "$OS" == "linux" ]]; then
    sudo apt update && sudo apt install -y stow
  fi
fi

# 1) Package managers & shells
if [[ "$OS" == "linux" ]]; then
  bash scripts/install-apt.sh
fi

# 1.1) Fonts (shared manifest) — Linux fonts + (if WSL) Windows fonts via PowerShell
# Toggle with DOTFILES_INSTALL_FONTS=0 to skip
INSTALL_FONTS="${DOTFILES_INSTALL_FONTS:-1}"
if [[ "$INSTALL_FONTS" == "1" ]]; then
  if [[ "$OS" == "linux" ]]; then
    echo "[bootstrap] Installing Linux fonts from fonts/manifest.json ..."
    bash scripts/install-fonts-linux.sh || true
    if [[ "$WSL" == "1" ]]; then
      echo "[bootstrap] Installing Windows fonts from fonts/manifest.json (WSL) ..."
      if command -v pwsh.exe >/dev/null 2>&1; then
        pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$PWD/scripts/win/install-fonts.ps1")" || true
      elif command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$PWD/scripts/win/install-fonts.ps1")" || true
      else
        echo "[bootstrap] Skipping Windows fonts: no pwsh.exe/powershell.exe found."
      fi
    fi
  fi
fi

bash scripts/nvim-manager.sh install stable || true
bash scripts/nvim-manager.sh switch stable || true

bash scripts/install-mise.sh
bash scripts/mise-setup-globals.sh

# 3) Neovim config via git subtree (pull latest if configured)
bash scripts/nvim-subtree.sh pull --auto || true

# 2) Default shell to zsh (if installed)
bash scripts/set-default-shell-zsh.sh || true

# 3) WSL niceties
if [[ "$WSL" == "1" ]]; then
  bash scripts/wsl-post.sh || true
fi

# 4) Optional: install Starship prompt if present in package list
if ! command -v starship >/dev/null; then
  curl -fsSL https://starship.rs/install.sh | bash -s -- -y
fi

echo "Bootstrap complete. Run ./stow-all.sh to link configs."
