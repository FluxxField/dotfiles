#!/usr/bin/env bash
set -euo pipefail

# Usage: nvim-manager.sh {install|switch|current} {stable|nightly}

CMD="${1:-help}"
CHANNEL="${2:-stable}"
PREFIX="$HOME/.local/nvim"
BINLINK="$HOME/.local/bin/nvim"

detect_os() { [[ "$(uname -s)" == "Darwin" ]] && echo mac || echo linux; }
arch_asset() {
  case "$(uname -m)" in
  x86_64) echo "linux64" ;;
  aarch64 | arm64) echo "linux-arm64" ;;
  *) echo "unsupported" ;;
  esac
}
ensure_dirs() { mkdir -p "$PREFIX" "$HOME/.local/bin"; }

install_linux() {
  local channel="$1" asset url tmpdir src dest
  asset="$(arch_asset)"
  [[ "$asset" == unsupported ]] && {
    echo "Unsupported arch: $(uname -m)"
    exit 1
  }

  if [[ "$channel" == stable ]]; then
    url="https://github.com/neovim/neovim/releases/latest/download/nvim-${asset}.tar.gz"
  else
    url="https://github.com/neovim/neovim/releases/download/nightly/nvim-${asset}.tar.gz"
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  curl -fL "$url" -o "$tmpdir/nvim.tgz"
  tar -xzf "$tmpdir/nvim.tgz" -C "$tmpdir"
  src="$tmpdir/nvim-${asset}"
  dest="$PREFIX/$channel"
  rm -rf "$dest"
  mkdir -p "$PREFIX"
  mv "$src" "$dest"
  echo "Installed Neovim $channel to $dest"
}

install_mac() {
  local channel="$1"

  if ! command -v brew >/dev/null; then
    echo "Homebrew required on macOS"
    exit 1
  fi

  if [[ "$channel" == stable ]]; then
    brew install neovim || brew upgrade neovim || true
  else
    brew install --HEAD neovim || brew upgrade --fetch-HEAD neovim || true
  fi

  echo "Installed Neovim $channel via Homebrew"
}

switch_linux() {
  local channel="$1" target
  target="$PREFIX/$channel/bin/nvim"
  [[ -x "$target" ]] || {
    echo "Neovim $channel not installed. Run: $0 install $channel"
    exit 1
  }
  ln -sf "$target" "$BINLINK"
  echo "Switched nvim symlink to $channel ($BINLINK -> $target)"
}

current_linux() {
  if [[ -L "$BINLINK" ]]; then
    readlink "$BINLINK"
  else
    echo "nvim not linked via $BINLINK"
  fi
}

main() {
  local os="$(detect_os)"
  ensure_dirs
  case "$CMD" in
  install)
    if [[ "$os" == mac ]]; then install_mac "$CHANNEL"; else install_linux "$CHANNEL"; fi
    ;;
  switch)
    if [[ "$os" == mac ]]; then echo "On macOS, Homebrew manages the binary; reorder PATH to prefer HEAD if needed."; else switch_linux "$CHANNEL"; fi
    ;;
  current)
    if [[ "$os" == mac ]]; then nvim --version | head -n1; else current_linux; fi
    ;;
  help | *)
    echo "Usage: $0 {install|switch|current} {stable|nightly}"
    ;;
  esac
}
main "$@"
