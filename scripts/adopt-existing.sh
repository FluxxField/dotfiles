#!/usr/bin/env bash
# Adopt existing dotfiles on a legacy machine into this repo safely.
# - Backs up any real files that would be replaced
# - Uses GNU Stow --adopt to move them into the package directories
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

require_stow() {
  if ! command -v stow >/dev/null; then
    echo "GNU Stow is required." >&2
    exit 1
  fi

  if ! stow --help 2>/dev/null | grep -q -- "--adopt"; then
    echo "Your stow does not support --adopt. Please update (>=2.3+ recommended)." >&2
    exit 1
  fi
}

list_packages() {
  find stow -maxdepth 1 -mindepth 1 -type d -not -name hosts -printf "%f\n" | sort
}

backup_conflicts_for_pkg() {
  local pkg="$1" backup_root="$2"
  # For every file tracked in this package, if a real file exists at $HOME,
  # copy it to backup preserving structure.
  (
    cd "stow/$pkg"
    # include files and symlinks; directories are created as needed
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
  require_stow
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
