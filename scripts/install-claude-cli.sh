#!/usr/bin/env bash
# Install (or update) the Claude Code CLI via Anthropic's native installer.
#
# Closes design.md §4.17: install-claude-plugins.sh and claude-profile-init.sh both
# shell out to `claude`, and verify-fresh §4.12 steps 3-4 run them inside a
# from-scratch container — but nothing provisioned the CLI itself. This is that
# provisioning step.
#
# Installs to ~/.local/bin/claude -> ~/.local/share/claude/versions/<version>.
# No sudo, nothing outside $HOME. stow/zsh/.zshrc:3 already puts ~/.local/bin
# first on PATH, so the binary is reachable once the zsh package is stowed.
#
# Supply-chain posture (SC16): the installer *script* is fetched over TLS only —
# the same transport as bootstrap.sh's starship step. Unlike starship, though, the
# *binary* is SHA256-verified: install.sh downloads a per-platform manifest,
# extracts the expected checksum, and aborts on mismatch. So the residual risk is
# the script fetch, not the payload. Pin CLAUDE_CLI_VERSION to a concrete version
# for a reproducible run (verify-fresh does; see D9/I11).
#
# Usage:
#   bash scripts/install-claude-cli.sh                    # track the stable channel
#   CLAUDE_CLI_VERSION=2.1.220 bash scripts/install-claude-cli.sh   # pin exactly
#
# Idempotent — safe to re-run. Re-running with an unchanged pin is a no-op.
set -euo pipefail

# stable | latest | X.Y.Z  — passed straight through to install.sh's TARGET arg.
CLAUDE_CLI_VERSION="${CLAUDE_CLI_VERSION:-stable}"
CLAUDE_CLI_INSTALLER_URL="${CLAUDE_CLI_INSTALLER_URL:-https://claude.ai/install.sh}"

need() { command -v "$1" >/dev/null 2>&1 || {
  echo "[claude-cli] Missing dependency: $1" >&2
  exit 1
}; }
need curl

# Resolve the real binary, NOT `command -v claude` — shell-integration.sh:20 defines
# a `claude()` shell function (the cca profile wrapper) that shadows the binary in
# interactive shells. Checking the path avoids ever mistaking the wrapper for an install.
CLAUDE_BIN="$HOME/.local/bin/claude"

installed_version() {
  [[ -x "$CLAUDE_BIN" ]] || return 1
  # `claude --version` prints e.g. "2.1.220 (Claude Code)"
  "$CLAUDE_BIN" --version 2>/dev/null | awk '{print $1}' | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+' || return 1
}

current="$(installed_version || true)"

if [[ -n "$current" ]]; then
  # Exact pin already satisfied → nothing to do.
  if [[ "$CLAUDE_CLI_VERSION" == "$current" ]]; then
    echo "[claude-cli] already installed at pinned version: $current"
    exit 0
  fi
  # Channel install (stable/latest): let the installer decide, it is a cheap no-op
  # when already current, and this is how the CLI is meant to be updated.
  echo "[claude-cli] present: $current — reconciling against '$CLAUDE_CLI_VERSION'"
else
  echo "[claude-cli] not installed — installing '$CLAUDE_CLI_VERSION'"
fi

# install.sh refuses to run under `sudo` when SUDO_USER is set: it installs into
# $HOME, which under sudo resolves to root's home, leaving the binary unreachable
# from the real user's shell. Plain root (containers, CI) is unaffected. Fail loudly
# rather than silently installing into the wrong home.
if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  echo "[claude-cli] Refusing to install under sudo — it would land in root's home." >&2
  echo "[claude-cli] Re-run as the target user without sudo." >&2
  exit 1
fi

curl -fsSL "$CLAUDE_CLI_INSTALLER_URL" | bash -s -- "$CLAUDE_CLI_VERSION"

# Verify rather than trust: bootstrap.sh's house style is `|| true`, but a silent
# failure here makes verify-fresh steps 3-4 fail later for a misattributed reason.
new="$(installed_version || true)"
if [[ -z "$new" ]]; then
  echo "[claude-cli] FAILED — no working binary at $CLAUDE_BIN after install." >&2
  exit 1
fi

echo "[claude-cli] Installed: $new  ($CLAUDE_BIN)"

# ~/.local/bin is on PATH via stow/zsh/.zshrc:3, but `make doctor` runs under a
# non-login bash (Makefile:1) that never sources .zshrc. Warn so a green install
# followed by a red doctor check is self-explanatory.
case ":${PATH}:" in
*":$HOME/.local/bin:"*) ;;
*) echo "[claude-cli] NOTE: $HOME/.local/bin is not on PATH in this shell; 'claude' resolves only after the zsh package is stowed and a new shell starts." ;;
esac
