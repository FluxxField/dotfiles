#!/usr/bin/env bash
# Manage Neovim binaries (stable/nightly) on Linux/macOS.
# Linux: installs tarballs to ~/.local/nvim/{stable,nightly} and symlinks ~/.local/bin/nvim
# macOS: uses Homebrew to install/use stable or --HEAD for nightly.
#
# Usage:
#   nvim-manager.sh use {stable|nightly}       # ensure installed; switch only if needed (idempotent)
#   nvim-manager.sh current                    # show active/current
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
ensure_dirs() { mkdir -p "$HOME_BIN" "$INSTALL_ROOT"; }

# --- helpers (Linux) ---------------------------------------------------------
download_extract_linux() {
  local url="$1" dest="$2"
  need curl
  need tar
  ensure_dirs

  local TMP=""
  TMP="$(mktemp -d)"
  trap '[[ -n "${TMP:-}" ]] && rm -rf -- "$_TMP"' RETURN

  echo "[nvim] Downloading: $url"
  curl -fsSL "$url" -o "$TMP/nvim.tgz"

  echo "[nvim] Extracting to: $dest"
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -xzf "$TMP/nvim.tgz" -C "$_TMP"

  local extracted=""
  extracted="$(find "$TMP" -maxdepth 1 -type d -name 'nvim-*' -print -quit)"

  [[ -z "${extracted:-}" ]] && {
    echo "Archive missing nvim dir." >&2
    exit 2
  }

  shopt -s dotglob nullglob
  mv "$extracted"/* "$dest"/
  shopt -u dotglob nullglob
}

install_linux() {
  local channel="$1" url=""
  case "$channel" in
  stable)
    if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
      url="$LINUX_STABLE_URL_X64"
    else url="$LINUX_STABLE_URL_ARM64_FALLBACK"; fi
    ;;
  nightly)
    if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
      url="$LINUX_NIGHTLY_URL_X64"
    else url="$LINUX_NIGHTLY_URL_ARM64"; fi
    ;;
  *)
    echo "Unknown channel: $channel (use stable|nightly)"
    exit 2
    ;;
  esac

  # graceful fallback if arm64 stable not published
  if ! curl -fsI "$url" >/dev/null 2>&1; then
    if [[ "$ARCH" != "x86_64" && "$channel" == "stable" ]]; then
      url="$LINUX_STABLE_URL_X64"
      echo "[nvim] ARM64 stable tar not found; falling back to x64."
    else
      echo "[nvim] Unable to fetch: $url" >&2
      exit 3
    fi
  fi

  download_extract_linux "$url" "$INSTALL_ROOT/$channel"
}

is_installed_linux() { [[ -x "$INSTALL_ROOT/$1/bin/nvim" ]]; }

get_current_channel_linux() {
  if [[ -L "$HOME_BIN/nvim" ]]; then
    local tgt
    tgt="$(readlink -f "$HOME_BIN/nvim")"

    [[ "$tgt" == "$INSTALL_ROOT/stable/bin/nvim" ]] && {
      echo stable
      return
    }

    [[ "$tgt" == "$INSTALL_ROOT/nightly/bin/nvim" ]] && {
      echo nightly
      return
    }
  fi

  echo ""
}

activate_linux() {
  local channel="$1"

  ln -sf "$INSTALL_ROOT/$channel/bin/nvim" "$HOME_BIN/nvim"
  echo "[nvim] Active channel → $channel"
  "$HOME_BIN/nvim" --version | head -n1 || true
}

use_linux() {
  local channel="$1"

  ensure_dirs

  if ! is_installed_linux "$channel"; then
    echo "[nvim] '$channel' not installed; installing…"
    install_linux "$channel"
  fi

  local cur=""
  cur="$(get_current_channel_linux)"

  if [[ "$cur" == "$channel" ]]; then
    echo "[nvim] '$channel' already active; nothing to do."
  else
    activate_linux "$channel"
  fi
}

current_linux() {
  local cur=""
  cur="$(get_current_channel_linux)"

  if [[ -n "$cur" ]]; then
    echo "[nvim] Current channel: $cur  (symlink at $HOME_BIN/nvim)"
  elif command -v nvim >/dev/null 2>&1; then
    echo "[nvim] Using nvim from PATH: $(command -v nvim)"
  else
    echo "[nvim] nvim not found"
  fi

  command -v nvim >/dev/null 2>&1 && nvim --version | head -n1 || true
}

# --- helpers (macOS) ---------------------------------------------------------
use_macos() {
  need brew
  case "$1" in
  nightly) brew install --HEAD neovim || true ;;
  stable | *) brew install neovim || true ;;
  esac
  echo "[nvim] macOS uses Homebrew precedence to switch stable/nightly."
  current_macos
}

current_macos() {
  command -v nvim >/dev/null 2>&1 && nvim --version | head -n1 || echo "[nvim] not found"
  echo "[nvim] PATH: $(command -v nvim || echo 'not in PATH')"
}

usage() {
  cat <<EOF
Usage:
  $0 use {stable|nightly}      # ensure installed; switch only if needed
  $0 current
EOF
}

main() {
  case "$CMD" in
  use)
    [[ -z "${CHAN:-}" ]] && {
      usage
      exit 1
    }

    if [[ "$OS" == "Linux" ]]; then
      use_linux "$CHAN"
    else
      use_macos "$CHAN"
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
