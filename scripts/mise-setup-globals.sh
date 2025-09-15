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
# Rust (toolchain managed by mise; replaces rustup step)
"${MISE_BIN}" use -g -y rust@latest

# Node + Go (global)
"${MISE_BIN}" use -g -y node@lts
"${MISE_BIN}" use -g -y go@latest

# ------------------------------
# Global packages via mise backends
# ------------------------------
# npm globals (requires node above)
"${MISE_BIN}" use -g -y npm:npm@latest
"${MISE_BIN}" use -g -y npm:@mermaid-js/mermaid-cli@latest
"${MISE_BIN}" use -g -y npm:tree-sitter-cli@latest

# cargo-installed CLIs (requires rust above)
"${MISE_BIN}" use -g -y cargo:zellij
"${MISE_BIN}" use -g -y cargo:exa
"${MISE_BIN}" use -g -y cargo:ripgrep_all
"${MISE_BIN}" use -g -y cargo:bottom
"${MISE_BIN}" use -g -y cargo:just

# Regenerate shims
"${MISE_BIN}" reshim || true

echo "Global mise setup complete:"
command -v node >/dev/null && node -v || echo "node not found"
command -v npm >/dev/null && npm -v || echo "npm not found"
command -v go >/dev/null && go version || echo "go not found"
command -v rga >/dev/null && rga --version || echo "ripgrep-all (rga) not found"
