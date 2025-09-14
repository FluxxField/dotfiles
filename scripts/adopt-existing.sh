#!/usr/bin/env bash
# Adopt existing dotfiles on a legacy machine into this repo safely.
# - Auto-installs GNU Stow if missing (apt on Linux, Homebrew on macOS)
# - Backs up conflicts
# - Uses Stow --adopt to move them into package folders
# - Then (re)stows to create symlinks
#
# Usage:
#   scripts/adopt-existing.sh             # adopt ALL packages under stow/ (excludes hosts)
#   scripts/adopt-existing.sh zsh nvim    # adopt specific packages
#   scripts/adopt-existing.sh --dry-run   # show what would change
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

DRYRUN=0
PKGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run | -n)
    DRYRUN=1
    shift
    ;;
  *)
    PKGS+=("$1")
    shift
    ;;
  esac
done

ensure_stow() {
  if command -v stow >/dev/null 2>&1; then
    :
  else
    # Try to install stow
    case "$(uname -s)" in
    Linux)
      if command -v apt >/dev/null 2>&1; then
        echo "Installing GNU Stow via apt..."
        sudo apt update && sudo apt install -y stow
      else
        echo "apt not available; please install GNU Stow manually." >&2
        exit 1
      fi
      ;;
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        echo "Installing GNU Stow via Homebrew..."
        brew install stow
      else
        echo "Homebrew not found; please install Homebrew, then 'brew install stow'." >&2
        exit 1
      fi
      ;;
    *)
      echo "Unsupported OS for auto-install; please install GNU Stow manually." >&2
      exit 1
      ;;
    esac
  fi

  # Require --adopt support
  if ! stow --help 2>/dev/null | grep -q -- "--adopt"; then
    echo "Your stow does not support --adopt. Please upgrade to stow >= 2.3." >&2
    exit 1
  fi
}

list_packages() {
  find stow -maxdepth 1 -mindepth 1 -type d -not -name hosts -printf "%f\n" | sort
}

backup_conflicts_for_pkg() {
  local pkg="$1" backup_root="$2"
  (
    cd "stow/$pkg"
    while IFS= read -r rel; do
      [[ -z "$rel" ]] && continue
      local target="$HOME/$rel"
      local dst="$backup_root/$rel"
      if [[ -e "$target" && ! -L "$target" ]]; then
        mkdir -p "$(dirname "$dst")"
        cp -a "$target" "$dst"
      fi
    done < <(find . -type f -o -type l | sed 's#^\./##')
  )
}

adopt_pkg() {
  local pkg="$1"
  if ((DRYRUN)); then
    echo "---- DRY RUN: $pkg ----"
    stow -n -v 2 -d stow -t "$HOME" "$pkg" || true
    return 0
  fi

  local ts backup_root
  ts="$(date +%Y%m%d-%H%M%S)"
  backup_root="$ROOT_DIR/.migration_backups/$ts/$pkg"
  mkdir -p "$backup_root"

  echo "Backing up conflicts for '$pkg' to $backup_root ..."
  backup_conflicts_for_pkg "$pkg" "$backup_root"

  echo "Adopting existing files into stow package '$pkg' ..."
  stow --adopt -v 1 -d stow -t "$HOME" "$pkg"

  echo "Restowing '$pkg' to ensure symlinks ..."
  stow -R -v 1 -d stow -t "$HOME" "$pkg"

  echo "✅ Adopted '$pkg'. Backup at: $backup_root"
}

main() {
  ensure_stow
  if [[ ${#PKGS[@]} -eq 0 ]]; then
    mapfile -t PKGS < <(list_packages)
  fi
  for p in "${PKGS[@]}"; do
    adopt_pkg "$p"
  done
  if ((!DRYRUN)); then
    echo
    echo "Next steps:"
    echo "  git add -A && git commit -m \"adopt: import existing dotfiles\""
    echo "  ./stow-all.sh   # or stow specific packages"
  fi
}
main "$@"
