#!/usr/bin/env bash
set -euo pipefail

OS="linux"
WSL="0"

if [[ "$(uname -s)" == "Darwin" ]]; then
  OS="mac"
fi

if grep -qi microsoft /proc/version 2>/dev/null; then
  WSL="1"
fi

export OS WSL
