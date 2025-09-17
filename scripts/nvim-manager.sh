#!/usr/bin/env bash
# Manage Neovim binaries (stable/nightly) on Linux/macOS.
# Linux: installs tarballs to ~/.local/nvim/{stable,nightly} and symlinks ~/.local/bin/nvim
# macOS: uses Homebrew for install/switch hints.
#
# Usage:
#   nvim-manager.sh {install|switch|current} {stable|nightly}
#   nvim-manager.sh current
set -Eeuo pipefail

CMD="${1:-}"
CHAN="${2:-}"

OS="$(uname -s)"
ARCH="$(uname -m)"
HOME_BIN="$HOME/.local/bin"
INSTALL_ROOT="$HOME/.local/nvim"
LINUX_STABLE_URL_X64="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz"
LINUX_STABLE_URL_ARM64_FALLBACK="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-arm64.tar.gz"
LINUX_NIGHTLY_URL_X64="https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz"
LINUX_NIGHTLY_URL_ARM64="https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-arm64.tar.gz"

need() { command -v "$1" >/dev/null 2>&1 || {
  echo "Missing dependency: $1" >&2
  exit 1
}; }

ensure_dirs() {
  mkdir -p "$HOME_BIN" "$INSTALL_ROOT"
}

download_extract_linux() {
  local url="$1" dest="$2"
  need curl
  need tar
  ensure_dirs

  local TMP=""
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  echo "[nvim] Downloading: $url"
  curl -fsSL "$url" -o "$TMP/nvim.tgz"

  echo "[nvim] Extracting to: $dest"
  rm -rf "$dest"
  mkdir -p "$dest"

  tar -xzf "$TMP/nvim.tgz" -C "$TMP"
  # archive extracts as "nvim-linux*/" -> move its contents into $dest
  local extracted
  extracted="$(find "$TMP" -maxdepth 1 -type d -name 'nvim-*' -print -quit)"
  if [[ -z "${extracted:-}" ]]; then
    echo "Could not locate extracted nvim directory in archive." >&2
    exit 2
  fi
  # Move the contents, preserving structure
  shopt -s dotglob nullglob
  mv "$extracted"/* "$dest"/
  shopt -u dotglob nullglob
}

install_linux() {
  local channel="$1"
  local url=""
  local dest="$INSTALL_ROOT/$channel"

  case "$channel" in
  stable)
    if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
      url="$LINUX_STABLE_URL_X64"
    else
      # Try ARM64 first; some releases may still only ship x64
      url="$LINUX_STABLE_URL_ARM64_FALLBACK"
    fi
    ;;
  nightly)
    if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
      url="$LINUX_NIGHTLY_URL_X64"
    else
      url="$LINUX_NIGHTLY_URL_ARM64"
    fi
    ;;
  *)
    echo "Unknown channel: $channel (use stable|nightly)"
    exit 2
    ;;
  esac

  # Try primary URL, with a graceful fallback from arm64→x64 if needed
  if ! curl -fsI "$url" >/dev/null 2>&1; then
    if [[ "$ARCH" != "x86_64" && "$channel" == "stable" ]]; then
      # Fallback: some stable releases may not publish arm64 tar; try x64
      url="$LINUX_STABLE_URL_X64"
      echo "[nvim] ARM64 tar not found for stable; falling back to x64 tar (will still run on most systems via qemu/glibc if configured)."
    else
      echo "[nvim] Unable to fetch: $url" >&2
      exit 3
    fi
  fi

  download_extract_linux "$url" "$dest"
}

switch_linux() {
  local channel="$1"
  local target="$INSTALL_ROOT/$channel/bin/nvim"
  ensure_dirs
  if [[ ! -x "$target" ]]; then
    echo "[nvim] $channel is not installed yet. Run: $0 install $channel" >&2
    exit 4
  fi
  ln -sf "$target" "$HOME_BIN/nvim"
  echo "[nvim] Switched ~/.local/bin/nvim -> $channel"
  "$HOME_BIN/nvim" --version | head -n1 || true
}

current_linux() {
  if [[ -L "$HOME_BIN/nvim" ]]; then
    local tgt
    tgt="$(readlink -f "$HOME_BIN/nvim")"
    echo "[nvim] Symlink: $HOME_BIN/nvim -> $tgt"
  elif command -v nvim >/dev/null 2>&1; then
    echo "[nvim] Using nvim from PATH: $(command -v nvim)"
  else
    echo "[nvim] nvim not found"
  fi
  command -v nvim >/dev/null 2>&1 && nvim --version | head -n1 || true
}

install_macos() {
  need brew
  if [[ "$CHAN" == "nightly" ]]; then
    brew install --HEAD neovim || true
  else
    brew install neovim || true
  fi
}

current_macos() {
  command -v nvim >/dev/null 2>&1 && nvim --version | head -n1 || echo "[nvim] not found"
  echo "[nvim] PATH: $(command -v nvim || echo 'not in PATH')"
  echo "[nvim] To switch nightly <-> stable on macOS, use Homebrew and ensure the desired one is first in PATH."
}

usage() {
  cat <<EOF
Usage: $0 {install|switch|current} {stable|nightly}

Examples:
  $0 install stable
  $0 install nightly
  $0 switch stable
  $0 current
EOF
}

main() {
  case "$CMD" in
  install)
    [[ -z "${CHAN:-}" ]] && {
      usage
      exit 1
    }
    if [[ "$OS" == "Linux" ]]; then
      install_linux "$CHAN"
      switch_linux "$CHAN"
    elif [[ "$OS" == "Darwin" ]]; then
      install_macos
    else
      echo "Unsupported OS: $OS"
      exit 2
    fi
    ;;
  switch)
    [[ -z "${CHAN:-}" ]] && {
      usage
      exit 1
    }
    if [[ "$OS" == "Linux" ]]; then
      switch_linux "$CHAN"
    else
      echo "[nvim] Switch is path-based on macOS; ensure the desired brew build is first in PATH."
      current_macos
    fi
    ;;
  current)
    if [[ "$OS" == "Linux" ]]; then
      current_linux
    else
      current_macos
    fi
    ;;
  *)
    usage
    exit 1
    ;;
  esac
}
main
