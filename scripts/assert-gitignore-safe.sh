#!/usr/bin/env bash
# The C6 gate. Run BEFORE any harness `git add`, and again before every commit
# that touches the harness package.
#
# Asserts three things:
#   1. Every `ignored` and `never` path in packages/harness-manifest.txt is
#      actually ignored by git under stow/claude/.claude-shared/.
#   2. None of them is already TRACKED — a rule added after a `git add` does not
#      untrack anything, and check-ignore cannot see that case.
#   3. Every entry that exists in the live ~/.claude-shared is CLASSIFIED by the
#      manifest. An unclassified entry fails the run (§4.17) — that is how
#      keybindings.json, .last_inuse_sweep and workflow-navigator.bak slipped
#      through review.
#
# Deliberately not in repo house style: no `|| true`, non-zero exit on any
# violation. HC4 makes this one-way — .gitignore does not remove anything
# retroactively and HC3 forbids the force-push that would. D16.
#
# Usage:
#   scripts/assert-gitignore-safe.sh
#   scripts/assert-gitignore-safe.sh --repo <path> --shared-dir <path>
set -uo pipefail

REPO="" SHARED=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --shared-dir) SHARED="${2:-}"; shift 2 ;;
    *) echo "usage: $0 [--repo <path>] [--shared-dir <path>]" >&2; exit 2 ;;
  esac
done
REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
SHARED="${SHARED:-$HOME/.claude-shared}"
MANIFEST="$REPO/packages/harness-manifest.txt"
PKG_PREFIX="stow/claude/.claude-shared"

[[ -f "$MANIFEST" ]] || { echo "missing manifest: $MANIFEST" >&2; exit 2; }

violations=0
note() { echo "  !! $*"; violations=$(( violations + 1 )); }

echo "== assert-gitignore-safe =="
echo "   repo:   $REPO"
echo "   shared: $SHARED"

# ── 1. Every ignored/never path must be ignored by git ──────────────────────
while read -r class path; do
  [[ -z "${class:-}" || "$class" == \#* ]] && continue
  case "$class" in ignored|never) ;; *) continue ;; esac
  # Keep the manifest's trailing slash — do NOT strip it. Verified behaviour of
  # `git check-ignore` against a `foo/` rule:
  #     foo        -> NO match  (git cannot tell a non-existent path is a dir)
  #     foo/       -> match
  #     foo/.probe -> match
  # and against a plain `foo` rule, `foo` matches. Passing the path exactly as
  # the manifest writes it is correct for both; stripping the slash makes every
  # directory rule falsely report as unignored.
  target="$PKG_PREFIX/$path"
  if ! git -C "$REPO" check-ignore -q "$target"; then
    note "NOT ignored: $target  (class=$class)"
  fi
done < "$MANIFEST"

# ── 2. None of them may be currently TRACKED ────────────────────────────────
# Here the trailing slash IS stripped — ls-files matches index entries, not
# gitignore patterns.
while read -r class path; do
  [[ -z "${class:-}" || "$class" == \#* ]] && continue
  case "$class" in ignored|never) ;; *) continue ;; esac
  target="$PKG_PREFIX/${path%/}"
  if [[ -n "$(git -C "$REPO" ls-files -- "$target" 2>/dev/null)" ]]; then
    note "TRACKED but must not be: $target  (class=$class)"
  fi
done < "$MANIFEST"

# ── 3. Every live ~/.claude-shared entry must be classified (§4.17) ─────────
classified() { awk '$1 !~ /^#/ && NF >= 2 {print $2}' "$MANIFEST" | sed 's#/$##' | grep -qx "$1"; }
if [[ -d "$SHARED" ]]; then
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    classified "$entry" \
      || note "UNCLASSIFIED live entry: $entry  — add it to packages/harness-manifest.txt as versioned|ignored|never"
  done < <(find "$SHARED" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)

  # plugins/ is the other directory with unclassified-entry history.
  if [[ -d "$SHARED/plugins" ]]; then
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      classified "plugins/$entry" \
        || note "UNCLASSIFIED live entry: plugins/$entry  — add it to packages/harness-manifest.txt"
    done < <(find "$SHARED/plugins" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)
  fi
fi

if [[ $violations -gt 0 ]]; then
  echo "GATE FAILED: $violations violation(s). Do NOT git add the harness."
  exit 1
fi
echo "gate clean — safe to stage the harness"
