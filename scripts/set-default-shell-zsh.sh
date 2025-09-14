#!/usr/bin/env bash
set -euo pipefail

if command -v zsh >/dev/null; then
  CHSH=$(command -v chsh || true)
  SHELLBIN=$(command -v zsh)

  if [[ -n "$CHSH" && "$SHELL" != "$SHELLBIN" ]]; then
    sudo chsh -s "$SHELLBIN" "$USER" || true
  fi
fi
