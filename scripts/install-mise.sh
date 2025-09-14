#!/usr/bin/env bash
set -euo pipefail

# Install mise (universal runtime manager) the official way.
# This adds 'eval "$(mise activate zsh)"' to your ~/.zshrc automatically.
if command -v mise >/dev/null; then
  echo "mise already installed"
  exit 0
fi

# Official installer (zsh-focused; safe to rerun)
# Ref: https://mise.jdx.dev/installing-mise.html
curl -fsSL https://mise.run/zsh | sh
