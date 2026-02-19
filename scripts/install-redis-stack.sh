#!/usr/bin/env bash
# Install redis-stack-server (RedisJSON, RediSearch, RedisGraph, etc.)
# via the official Redis apt repo.
# On macOS, skips — redis-stack is available via brew install redis-stack
# but the standard redis formula is sufficient for most use.
# Idempotent — safe to re-run.
set -euo pipefail

if command -v redis-stack-server >/dev/null 2>&1; then
  echo "[redis-stack] already installed"
  exit 0
fi

source "$(dirname "$0")/detect-os.sh"

if [[ "$OS" == "mac" ]]; then
  command -v brew >/dev/null 2>&1 || { echo "[redis-stack] brew not found; skipping"; exit 0; }
  brew install redis-stack
  exit 0
fi

# Linux: add Redis apt repo
echo "[redis-stack] Adding Redis apt repo..."
curl -fsSL https://packages.redis.io/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] \
https://packages.redis.io/deb $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/redis.list >/dev/null

sudo apt-get update -o=Dpkg::Use-Pty=0 >/dev/null
sudo apt-get install -y redis-stack-server

echo "[redis-stack] Installed."
