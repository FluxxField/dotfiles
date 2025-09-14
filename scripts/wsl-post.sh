#!/usr/bin/env bash
set -euo pipefail

# Clipboard tools
if ! command -v xclip >/dev/null && ! command -v wl-copy >/dev/null; then
  sudo apt install -y xclip
fi

# Git line endings sane defaults for WSL
git config --global core.autocrlf input

# Optional: win32yank for Neovim system clipboard
if ! command -v win32yank.exe >/dev/null; then
  WDIR="/mnt/c/Windows/System32"

  if [[ -x "$WDIR/win32yank.exe" ]]; then
    ln -sf "$WDIR/win32yank.exe" "$HOME/.local/bin/win32yank.exe"
  fi
fi
