#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/assert.sh"
CFG="$ROOT/stow/git/.gitconfig"
assert_file "$CFG"
get() { git config --file "$CFG" --get "$1" 2>/dev/null || echo "<unset>"; }

# Q1: canonical identity.
assert_eq "$(get user.email)" "keenanjj13@gmail.com" "user.email is the gmail identity"
assert_eq "$(get init.defaultBranch)" "main" "defaultBranch is main"
# Q2: the signing key must be the one that exists in the keyring.
assert_eq "$(get user.signingkey)" "6C32D9329BDB7DA9" "signingkey points at the present key"
assert_eq "$(get commit.gpgsign)" "true" "commit signing stays enabled"
assert_eq "$(get tag.gpgSign)" "true" "tag signing stays enabled"
# The absent key must not survive anywhere in the file.
assert_fail grep -q "665F3EDCE9AB996D" "$CFG"
# Adopted from live: the gh credential helper (repo version had none).
assert_contains "$(cat "$CFG")" "gh auth git-credential" "adopts the gh credential helper"
# user.email MUST match the signing key's uid or GitHub shows "Unverified".
if command -v gpg >/dev/null 2>&1 && gpg --list-keys 6C32D9329BDB7DA9 >/dev/null 2>&1; then
  uids="$(gpg --list-keys --with-colons 6C32D9329BDB7DA9 | awk -F: '/^uid/{print $10}')"
  assert_contains "$uids" "$(get user.email)" "signing key uid contains user.email"
fi
echo "gitconfig ok"
