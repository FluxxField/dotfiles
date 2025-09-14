#!/usr/bin/env bash
set -euo pipefail

if ! command -v cargo >/dev/null; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y
  source "$HOME/.cargo/env"
fi

# optional: install cargo-binstall for faster crate installs
if ! command -v cargo-binstall >/dev/null; then
  cargo install cargo-binstall || true
fi

if [[ -f packages/cargo.txt ]]; then
  while read -r crate; do
    [[ -z "$crate" || "$crate" =~ ^# ]] && continue
    (command -v cargo-binstall >/dev/null && cargo binstall -y "$crate") || cargo install "$crate" || true
  done <packages/cargo.txt
fi
