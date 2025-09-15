#!/usr/bin/env bash
# Interactively merge files adopted from $HOME with the versions in your repo.
# It compares the latest .migration_backups/<timestamp>/<pkg>/ tree against stow/<pkg>/,
# and opens a 2-way diff for each changed file so you can reconcile.
#
# Usage:
#   scripts/merge-from-backup.sh                # scan all packages with a latest backup
#   scripts/merge-from-backup.sh zsh git        # limit to specific packages
#   MERGE_TOOL=meld scripts/merge-from-backup.sh  # choose tool: nvimdiff (default) or meld/code
#
# Notes:
# - Run this AFTER `make adopt` (or scripts/adopt-existing.sh ...).
# - Backups live under ./.migration_backups/<timestamp>/<pkg>/...
# - For each differing file, we launch your mergetool:
#     * nvimdiff:      nvim -d <repo> <backup>
#     * meld:          meld <repo> <backup>
#     * code (VSCode): code --diff <repo> <backup>
# - When you finish editing, stage with `git add <file>`; the script can do it automatically.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

MERGE_TOOL="${MERGE_TOOL:-nvimdiff}" # nvimdiff|meld|code
PKGS=("$@")

# Pick latest backup timestamp dir
latest_backup_root() {
  local latest
  latest="$(ls -1d ".migration_backups"/* 2>/dev/null | sort | tail -n1 || true)"
  [[ -n "$latest" ]] && echo "$latest" || return 1
}

launch_diff() {
  local repo_file="$1" backup_file="$2"
  case "$MERGE_TOOL" in
  nvimdiff | nvim | vimdiff)
    nvim -d "$repo_file" "$backup_file"
    ;;
  meld)
    meld "$repo_file" "$backup_file"
    ;;
  code | vscode)
    code --diff "$repo_file" "$backup_file"
    ;;
  *)
    echo "Unknown MERGE_TOOL='$MERGE_TOOL' (supported: nvimdiff|meld|code)" >&2
    exit 1
    ;;
  esac
}

need() { command -v "$1" >/dev/null 2>&1; }

different() {
  git diff --no-index --quiet -- "$1" "$2" >/dev/null 2>&1 || return 0
  return 1
}

main() {
  local latest tsdir
  latest="$(latest_backup_root)" || {
    echo "No backups found in .migration_backups/"
    exit 1
  }
  echo "Using latest backup: $latest"

  if [[ ${#PKGS[@]} -eq 0 ]]; then
    # infer pkgs present in backup
    mapfile -t PKGS < <(ls -1 "$latest" 2>/dev/null | sort)
  fi

  # Ensure mergetool exists
  case "$MERGE_TOOL" in
  nvimdiff | nvim | vimdiff) need nvim || {
    echo "nvim not found"
    exit 1
  } ;;
  meld) need meld || {
    echo "meld not found"
    exit 1
  } ;;
  code | vscode) need code || {
    echo "VS Code 'code' CLI not found"
    exit 1
  } ;;
  esac

  local any=0
  for pkg in "${PKGS[@]}"; do
    tsdir="$latest/$pkg"
    [[ -d "$tsdir" ]] || {
      echo "No backup dir for pkg '$pkg' in $latest"
      continue
    }
    echo "Scanning package: $pkg"

    # Compare every backed-up file against current repo file
    (
      cd "$tsdir"
      while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        local repo_file="$ROOT_DIR/stow/$pkg/$rel"
        local backup_file="$tsdir/$rel"

        # If no corresponding repo file, just copy it in (adoption might have skipped)
        if [[ ! -e "$repo_file" ]]; then
          mkdir -p "$(dirname "$repo_file")"
          cp -a "$backup_file" "$repo_file"
          echo "Added (from backup): stow/$pkg/$rel"
          git add "stow/$pkg/$rel" || true
          continue
        fi

        # If both exist and differ, open a diff to reconcile
        if different "$repo_file" "$backup_file"; then
          any=1
          echo
          echo "Diff: stow/$pkg/$rel  <->  backup"
          echo "Repo:   $repo_file"
          echo "Backup: $backup_file"
          launch_diff "$repo_file" "$backup_file"
          # After you quit the mergetool, stage if file exists
          if [[ -f "$repo_file" ]]; then
            git add "$repo_file" || true
          fi
        fi
      done < <(find . -type f -o -type l | sed 's#^\./##')
    )
  done

  echo
  if [[ "$any" -eq 1 ]]; then
    echo "Review changes with 'git status' and commit when happy:"
    echo "  git commit -m \"merge: reconcile adopted configs\""
  else
    echo "No differences to merge. You're good to go."
  fi
}
main "$@"
