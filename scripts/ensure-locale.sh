#!/usr/bin/env bash
# Ensure en_US.UTF-8 locale exists and is the default (Ubuntu/WSL friendly).
set -euo pipefail

if [[ ! -f /etc/os-release ]]; then exit 0; fi
. /etc/os-release
[[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *debian* ]] && exit 0

# Make sure locales package exists
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -o=Dpkg::Use-Pty=0 || true
  sudo apt-get install -y locales || true
fi

# Add (or un-comment) the locale in /etc/locale.gen
if ! grep -E -q '^[[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8' /etc/locale.gen; then
  if grep -E -q '^[[:space:]]*#?[[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8' /etc/locale.gen; then
    sudo sed -i -E 's/^#?[[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  else
    echo 'en_US.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null
  fi
fi

# Generate and set defaults
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Export for current shell (won’t persist across sessions—env.sh handles that)
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
