#!/usr/bin/env bash
# Manage your Neovim config as a git subtree inside this dotfiles repo.
# Stores upstream details in repo-local git config:
#   subtree.nvim.remote = <remote name, default: nvim-origin>
#   subtree.nvim.url    = git@github.com:USER/REPO.git
#   subtree.nvim.branch = main
#
# Commands:
#   init <repo-url> [branch]   # one-time: add remote & subtree at stow/nvim/.config/nvim
#   pull [--auto]              # fetch & subtree pull; --auto = no-op if not configured/dirty
#   push                       # subtree push back to upstream
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PREFIX="stow/nvim/.config/nvim"
REMOTE_NAME="$(git config --get subtree.nvim.remote || echo "nvim-origin")"
REMOTE_URL="$(git config --get subtree.nvim.url || echo "")"
BRANCH="$(git config --get subtree.nvim.branch || echo "main")"

require_clean_tree() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree not clean. Commit or stash changes first." >&2
    exit 1
  fi
}

require_subtree_cmd() {
  if ! command -v git subtree >/dev/null 2>&1; then
    echo "git subtree not available. Install git-subtree (Ubuntu: apt install git-subtree)." >&2
    exit 1
  fi
}

cmd="${1:-help}"
shift || true

case "$cmd" in
init)
  require_subtree_cmd
  url="${1:-}"
  branch="${2:-main}"
  [[ -n "$url" ]] || {
    echo "Usage: $0 init <repo-url> [branch]"
    exit 1
  }
  require_clean_tree

  # Save config
  git config subtree.nvim.remote "$REMOTE_NAME"
  git config subtree.nvim.url "$url"
  git config subtree.nvim.branch "$branch"

  # Add/replace remote
  if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
    git remote set-url "$REMOTE_NAME" "$url"
  else
    git remote add "$REMOTE_NAME" "$url"
  fi
  git fetch "$REMOTE_NAME"

  # Add subtree (once)
  if [[ -d "$PREFIX/.git" || -d "$PREFIX" && -n "$(ls -A "$PREFIX" 2>/dev/null)" ]]; then
    echo "Directory $PREFIX is not empty—won't overwrite. If this is intentional, use 'pull' instead." >&2
    exit 1
  fi
  git subtree add --prefix "$PREFIX" "$REMOTE_NAME" "$branch" --squash -m "chore(nvim): subtree add ($branch)"
  echo "✅ Subtree added for Neovim config at $PREFIX"
  ;;
pull)
  AUTO=0
  [[ "${1:-}" == "--auto" ]] && AUTO=1
  if [[ -z "$REMOTE_URL" ]]; then
    if ((AUTO)); then exit 0; fi
    echo "Neovim subtree not configured. Run: scripts/nvim-subtree.sh init <repo-url> [branch]" >&2
    exit 1
  fi
  require_subtree_cmd
  if ((!AUTO)); then require_clean_tree; fi

  # Ensure remote exists & up to date
  if ! git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
    git remote add "$REMOTE_NAME" "$REMOTE_URL"
  else
    git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
  fi
  git fetch "$REMOTE_NAME"

  # Pull latest into subtree
  git subtree pull --prefix "$PREFIX" "$REMOTE_NAME" "$BRANCH" --squash -m "chore(nvim): subtree update ($(date -u +%F))"
  echo "✅ Subtree pulled from $REMOTE_NAME/$BRANCH into $PREFIX"
  ;;

push)
  if [[ -z "$REMOTE_URL" ]]; then
    echo "Neovim subtree not configured. Run init first." >&2
    exit 1
  fi
  require_subtree_cmd
  require_clean_tree
  git subtree push --prefix "$PREFIX" "$REMOTE_NAME" "$BRANCH"
  echo "✅ Subtree pushed to $REMOTE_NAME/$BRANCH"
  ;;

help | *)
  cat <<EOF
Usage:
  $0 init <repo-url> [branch]    # one-time setup
  $0 pull [--auto]               # update subtree (auto mode skips if not configured/dirty)
  $0 push                        # publish changes back upstream

Config in this repo:
  subtree.nvim.remote = $REMOTE_NAME
  subtree.nvim.url    = ${REMOTE_URL:-<unset>}
  subtree.nvim.branch = $BRANCH
Prefix: $PREFIX
EOF
  ;;
esac
