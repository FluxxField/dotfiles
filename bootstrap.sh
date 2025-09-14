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

bash scripts/install-cargo.sh
bash scripts/install-mise.sh

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
