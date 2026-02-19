#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt >/dev/null; then
  exit 0
fi

sudo apt update

# Strip comments and blank lines before passing to apt
grep -v '^\s*#' packages/apt.txt | grep -v '^\s*$' | xargs sudo apt install -y

# Ubuntu aliases
if command -v batcat >/dev/null && ! command -v bat >/dev/null; then
  sudo update-alternatives --install /usr/bin/bat bat /usr/bin/batcat 10
fi

if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
  sudo ln -sf $(command -v fdfind) /usr/local/bin/fd
fi
