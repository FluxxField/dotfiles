#!/usr/bin/env bash
set -euo pipefail

if command -v brew >/dev/null; then
  exit 0
fi

NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "eval '$(/opt/homebrew/bin/brew shellenv)'" >>"$HOME/.zprofile"
fi
