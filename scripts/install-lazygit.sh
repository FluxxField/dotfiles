#!/usr/bin/env bash
# Install (or update) lazygit from GitHub releases.
# - Linux (x86_64/arm64) and macOS (x86_64/arm64) supported
# - Uses latest tag from jesseduffield/lazygit
# - Installs to /usr/local/bin (requires sudo)
#
# Usage:
#   bash scripts/install-lazygit.sh
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || {
  echo "Missing dependency: $1" >&2
  exit 1
}; }
need curl
need tar

OS="$(uname -s)"
ARCH="$(uname -m)"

# Prefer Homebrew on macOS if available
if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
  echo "[lazygit] Installing via Homebrew..."
  brew install lazygit
  exit 0
fi

# Map OS/arch to release asset suffix
case "$OS" in
Linux)
  case "$ARCH" in
  x86_64 | amd64) ASSET_SUFFIX="Linux_x86_64" ;;
  aarch64 | arm64) ASSET_SUFFIX="Linux_arm64" ;;
  *)
    echo "Unsupported Linux arch: $ARCH" >&2
    exit 2
    ;;
  esac
  ;;
Darwin)
  case "$ARCH" in
  x86_64) ASSET_SUFFIX="Darwin_x86_64" ;;
  arm64) ASSET_SUFFIX="Darwin_arm64" ;;
  *)
    echo "Unsupported macOS arch: $ARCH" >&2
    exit 2
    ;;
  esac
  ;;
*)
  echo "Unsupported OS: $OS" >&2
  exit 2
  ;;
esac

echo "[lazygit] Resolving latest version…"
LAZYGIT_VERSION="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" |
  grep -Po '"tag_name":\s*"v\K[^"]*')"

if [[ -z "${LAZYGIT_VERSION:-}" ]]; then
  echo "Failed to detect latest lazygit version from GitHub API." >&2
  exit 3
fi

URL="https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_${ASSET_SUFFIX}.tar.gz"
echo "[lazygit] Downloading v${LAZYGIT_VERSION} (${ASSET_SUFFIX})…"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

curl -fsSL "$URL" -o "$TMPDIR/lazygit.tgz"
tar -C "$TMPDIR" -xzf "$TMPDIR/lazygit.tgz" lazygit

echo "[lazygit] Installing to /usr/local/bin (sudo)…"
sudo install "$TMPDIR/lazygit" -D -t /usr/local/bin/

echo -n "[lazygit] Installed: "
/usr/local/bin/lazygit --version || true
