#!/usr/bin/env bash
# Install Stripe CLI via the official Stripe apt repo.
# On macOS, delegates to Homebrew.
# Idempotent — safe to re-run.
set -euo pipefail

if command -v stripe >/dev/null 2>&1; then
  echo "[stripe] already installed: $(stripe --version)"
  exit 0
fi

source "$(dirname "$0")/detect-os.sh"

if [[ "$OS" == "mac" ]]; then
  command -v brew >/dev/null 2>&1 || { echo "[stripe] brew not found; skipping"; exit 0; }
  brew install stripe/stripe-cli/stripe
  exit 0
fi

# Linux: add Stripe's apt repo and install
echo "[stripe] Adding Stripe apt repo..."
curl -fsSL https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/stripe-cli-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/stripe-cli-archive-keyring.gpg] \
https://packages.stripe.dev/stripe-cli-debian-local stable/" \
  | sudo tee /etc/apt/sources.list.d/stripe.list >/dev/null

sudo apt-get update -o=Dpkg::Use-Pty=0 >/dev/null
sudo apt-get install -y stripe

echo "[stripe] Installed: $(stripe --version)"
