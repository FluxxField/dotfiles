#!/usr/bin/env bash
set -euo pipefail

# Ensure mise exists
MISE_BIN="$(command -v mise || true)"
if [[ -z "${MISE_BIN}" && -x "$HOME/.local/bin/mise" ]]; then
  MISE_BIN="$HOME/.local/bin/mise"
fi
if [[ -z "${MISE_BIN}" ]]; then
  echo "mise not found; run scripts/install-mise.sh first." >&2
  exit 1
fi

# ------------------------------
# Core toolchains with mise
# ------------------------------
"${MISE_BIN}" use -g rust@latest
"${MISE_BIN}" use -g node@lts
"${MISE_BIN}" use -g go@latest

# ------------------------------
# Global packages via mise backends
# ------------------------------
"${MISE_BIN}" use -g npm:npm
"${MISE_BIN}" use -g npm:@mermaid-js/mermaid-cli
"${MISE_BIN}" use -g npm:tree-sitter-cli

"${MISE_BIN}" use -g cargo:zellij
"${MISE_BIN}" use -g cargo:exa
"${MISE_BIN}" use -g cargo:ripgrep_all
"${MISE_BIN}" use -g cargo:bottom
"${MISE_BIN}" use -g cargo:just

# Regenerate shims
"${MISE_BIN}" reshim || true

echo "Global mise setup complete:"
command -v node >/dev/null && node -v || echo "node not found"
command -v npm >/dev/null && npm -v || echo "npm not found"
command -v go >/dev/null && go version || echo "go not found"
command -v rga >/dev/null && rga --version || echo "ripgrep-all (rga) not found"
