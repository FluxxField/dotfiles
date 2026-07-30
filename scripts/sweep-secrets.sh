#!/usr/bin/env bash
# Sweep for credentials, tokens, and addressable endpoints.
#
# HC4: the remote is PUBLIC and .gitignore does not remove anything retroactively,
# while HC3 forbids the force-push that would. So this runs BEFORE content lands:
# before Task 0's merge (--range) and before the harness git add (--worktree).
#
# Deliberately NOT in repo house style: no `|| true`, and a hit is a non-zero
# exit. D16 rejects house style for gates.
#
# Usage:
#   scripts/sweep-secrets.sh --worktree                  # tracked + untracked, honours .gitignore
#   scripts/sweep-secrets.sh --range origin/main..HEAD    # every blob introduced in a range
#   scripts/sweep-secrets.sh --worktree --allow 'regex'   # suppress an accepted VALUE (any file)
#   scripts/sweep-secrets.sh --worktree --allow-path P    # exempt one PATH (repeatable)
#
# Prefer --allow-path over --allow. `--allow` is value-scoped and therefore global:
# allowing a value to silence one file also blinds the scanner to that same value
# everywhere else, including a real leak. --allow-path keeps the blind spot to one
# reviewable path.
set -uo pipefail

MODE="" RANGE="" ALLOW=""
ALLOW_PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree) MODE=worktree; shift ;;
    --range) MODE=range; RANGE="${2:-}"; [[ -n "$RANGE" ]] || { echo "usage: --range <git-range>" >&2; exit 2; }; shift 2 ;;
    --allow) ALLOW="${2:-}"; [[ -n "$ALLOW" ]] || { echo "usage: --allow <regex>" >&2; exit 2; }; shift 2 ;;
    --allow-path) [[ -n "${2:-}" ]] || { echo "usage: --allow-path <path>" >&2; exit 2; }; ALLOW_PATHS+=("$2"); shift 2 ;;
    *) echo "usage: $0 [--worktree|--range <range>] [--allow <regex>] [--allow-path <path>]" >&2; exit 2 ;;
  esac
done
[[ -n "$MODE" ]] || { echo "usage: $0 [--worktree|--range <range>] [--allow <regex>] [--allow-path <path>]" >&2; exit 2; }

# Exact-path match, not a substring/prefix test: a prefix test would let
# `--allow-path tests/x` also exempt `tests/x-secrets.md`.
path_allowed() {
  local p="$1" a
  for a in ${ALLOW_PATHS+"${ALLOW_PATHS[@]}"}; do [[ "$p" == "$a" ]] && return 0; done
  return 1
}

PATTERNS=(
  'ghp_[A-Za-z0-9]{16,}'
  'gho_[A-Za-z0-9]{16,}'
  'github_pat_[A-Za-z0-9_]{20,}'
  'sk-ant-[A-Za-z0-9-]{8,}'
  'AKIA[0-9A-Z]{16}'
  'BEGIN [A-Z ]*PRIVATE KEY'
  'rrp-cc-[0-9a-f]{6,}'
  '100\.114\.199\.[0-9]{1,3}'
  'hooks\.slack\.com/services/'
  'ntfy\.sh/[A-Za-z0-9_-]{8,}'
  'xoxb-[A-Za-z0-9-]{10,}'
  '[Aa]uthorization: *[Bb]earer +[A-Za-z0-9._-]{12,}'
)
RE="$(IFS='|'; echo "${PATTERNS[*]}")"

hits=0 skipped=0
# Each input line is "<path>\t<display>" so the filter can be path-scoped.
report() {
  local line path disp
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    path="${line%%$'\t'*}"; disp="${line#*$'\t'}"
    if path_allowed "$path"; then skipped=$(( skipped + 1 )); continue; fi
    if [[ -n "$ALLOW" ]] && printf '%s' "$disp" | grep -qE "$ALLOW"; then skipped=$(( skipped + 1 )); continue; fi
    echo "  !! $disp"
    hits=$(( hits + 1 ))
  done
}

echo "== secret sweep ($MODE${RANGE:+ $RANGE}) =="
if [[ "$MODE" == "worktree" ]]; then
  # --untracked is load-bearing: plain `git grep` is TRACKED-ONLY and would miss a
  # file about to be `git add`ed. --untracked still honours .gitignore.
  # `git grep -n` emits path:line:content — split the path off for path_allowed.
  report < <(git grep --untracked -nIE "$RE" -- . 2>/dev/null \
    | sed $'s#^\\([^:]*\\):#\\1\t\\1:#' || true)
else
  # Per-commit ADDED LINES. A two-dot `git diff A..B` MISSES a secret added and then
  # removed inside the range, yet the merge still carries that blob forever.
  # Merge commits show no diff here, which is correct: their content arrives via the
  # individual commits rev-list already walks.
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    report < <(git show --format= --unified=0 "$sha" 2>/dev/null | awk -v s="${sha:0:9}" '
      /^\+\+\+ b\// { p = substr($0, 7); next }
      /^\+\+\+ \/dev\/null/ { p = ""; next }
      /^\+/ { if (p != "") printf "%s\t%s: %s: %s\n", p, s, p, substr($0, 2) }
    ' | grep -E "$RE" || true)
  done < <(git rev-list "$RANGE" 2>/dev/null || true)
fi

# D16: never silently truncate. If an exemption was used, say so — an exemption the
# reader cannot see is indistinguishable from a scanner that does not work.
[[ $skipped -gt 0 ]] && echo "  (${skipped} match(es) exempted by --allow/--allow-path)"

if [[ $hits -gt 0 ]]; then
  echo "SWEEP FAILED: $hits hit(s). Do not merge or stage this content."
  exit 1
fi
echo "sweep clean"
