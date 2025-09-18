#!/usr/bin/env bash
# Install global toolchains/packages via mise AFTER zsh/oh-my-zsh are set,
# by running inside a login zsh so ~/.zshrc (mise activation) is evaluated.
set -euo pipefail

# Avoid OMZ nags during noninteractive run
export DISABLE_AUTO_UPDATE=true
export ZSH_DISABLE_COMPFIX=true

# Commands to run inside zsh (one subshell)
zsh -lc '
  set -e
  # Ensure mise is on and active (activation should be in ~/.zshrc already)
  if ! command -v mise >/dev/null 2>&1; then
    echo "[mise-post] mise not on PATH; check install-mise.sh" >&2
    exit 1
  fi

  # Toolchains
  mise use -g -y rust@latest
  mise use -g -y node@lts
  mise use -g -y go@latest

  # NPM globals
  mise use -g -y npm:npm@latest
  mise use -g -y npm:@mermaid-js/mermaid-cli
  mise use -g -y npm:tree-sitter-cli
  mise use -g -y npm:typescript
  mise use -g -y

  # Cargo globals
  mise settings set cargo.binstall true

  mise use -g -y cargo-binstall
  mise use -g -y cargo:ripgrep-all
  mise use -g -y cargo:bottom
  mise use -g -y cargo:zellij
  mise use -g -y cargo:eza
  mise use -g -y cargo:just

  mise reshim || true

  echo "[mise-post] Globals installed and shims refreshed."
'
