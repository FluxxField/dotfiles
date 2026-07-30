#!/usr/bin/env bash
# Assertion primitives for dotfiles tests. Source this; do not execute.
# Modelled on cc-account-switcher/tests/assert.sh so both repos read the same.
assert_eq() { if [ "$1" != "$2" ]; then echo "FAIL: ${3:-assert_eq}: got [$1] want [$2]"; exit 1; fi; }
assert_file() { if [ ! -f "$1" ]; then echo "FAIL: expected file: $1"; exit 1; fi; }
assert_dir() { if [ ! -d "$1" ]; then echo "FAIL: expected dir: $1"; exit 1; fi; }
# SC11 needs "real directory, NOT a symlink" — a plain -d passes for a symlink-to-dir.
assert_real_dir() {
  if [ -L "$1" ]; then echo "FAIL: expected real dir but found symlink: $1"; exit 1; fi
  if [ ! -d "$1" ]; then echo "FAIL: expected dir: $1"; exit 1; fi
}
assert_link() {
  if [ ! -L "$1" ]; then echo "FAIL: expected symlink: $1"; exit 1; fi
  local got; got="$(readlink "$1")"
  if [ "$got" != "$2" ]; then echo "FAIL: link $1 -> [$got] want [$2]"; exit 1; fi
}
assert_contains() {
  case "$1" in *"$2"*) ;; *) echo "FAIL: ${3:-assert_contains}: [$1] does not contain [$2]"; exit 1;; esac
}
assert_ok() { if ! "$@"; then echo "FAIL: expected success: $*"; exit 1; fi; }
assert_fail() { if "$@"; then echo "FAIL: expected failure: $*"; exit 1; fi; }
