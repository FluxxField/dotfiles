#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

HOSTNAME=$(hostname)

# 1) base packages (exclude hosts/*)
for pkg in $(find stow -maxdepth 1 -mindepth 1 -type d -not -name hosts -printf "%f\n" | sort); do
  stow -d stow -t "$HOME" "$pkg"
done

# 2) common host overlay
if [[ -d "stow/hosts/@common" ]]; then
  stow -d stow -t "$HOME" hosts/@common
fi

# 3) machine‑specific overlay
if [[ -d "stow/hosts/$HOSTNAME" ]]; then
  stow -d stow -t "$HOME" "hosts/$HOSTNAME"
fi

# 4) WSL overlay (optional heuristic)
if grep -qi microsoft /proc/version 2>/dev/null && [[ -d "stow/hosts/wsl" ]]; then
  stow -d stow -t "$HOME" hosts/wsl
fi

echo "Stowed packages for $HOSTNAME"
