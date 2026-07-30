#!/usr/bin/env bash
# Runs every tests/*.test.sh. Exits non-zero if any fails.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
fail=0
shopt -s nullglob
for t in "$HERE"/*.test.sh; do
  echo "== $(basename "$t") =="
  if bash "$t"; then echo "PASS"; else echo "FAILED: $t"; fail=1; fi
done
exit $fail
