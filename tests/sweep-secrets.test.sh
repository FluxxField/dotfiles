#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/assert.sh"
SWEEP="$ROOT/scripts/sweep-secrets.sh"
assert_file "$SWEEP"

sbx="$(mktemp -d "${TMPDIR:-/tmp}/sweep-sbx.XXXXXX")"
trap 'rm -rf "$sbx"' EXIT
cd "$sbx"
git init -q . && git config user.email t@t && git config user.name t && git config commit.gpgsign false

# 1. Clean tree passes.
echo "nothing to see here" > ok.txt
git add -A && git commit -qm "clean"
assert_ok bash "$SWEEP" --worktree

# 2. Caught while still UNTRACKED — the gate must see content before it is added.
echo 'CC_NTFY_TOPIC=rrp-cc-000000fake01' > leak.txt
assert_fail bash "$SWEEP" --worktree

# 2b. A gitignored file is NOT scanned — correctly-ignored machine state is skipped.
echo 'secret.log' > .gitignore
echo 'rrp-cc-deadbeef99' > secret.log
rm leak.txt
assert_ok bash "$SWEEP" --worktree
rm secret.log .gitignore
echo 'CC_NTFY_TOPIC=rrp-cc-000000fake01' > leak.txt

# 3. Caught in a revision range once committed.
git add -A && git commit -qm "leak"
assert_fail bash "$SWEEP" --range "HEAD~1..HEAD"

# 3b. The case a two-dot endpoint diff would MISS: added then removed in-range.
base="$(git rev-parse HEAD)"
git rm -q leak.txt && git commit -qm "rm leak"
echo 'ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' > transient.txt
git add -A && git commit -qm "add secret"
git rm -q transient.txt && git commit -qm "remove secret"
echo 'unrelated' >> ok.txt && git add -A && git commit -qm "unrelated"
assert_fail bash "$SWEEP" --range "$base..HEAD"

# 4. --allow suppresses a specific value that IS a pattern hit.
echo 'topic: rrp-cc-abc123' > acct.txt
assert_fail bash "$SWEEP" --worktree
assert_ok   bash "$SWEEP" --worktree --allow 'rrp-cc-abc123'
rm acct.txt

# 5. Every pattern class is detected individually, not just the first.
for bad in 'ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
           'sk-ant-api03-xxxxxxxx' \
           '100.114.199.99' \
           '-----BEGIN OPENSSH PRIVATE KEY-----' \
           'https://hooks.slack.com/services/T0/B0/xxxx' \
           'AKIAABCDEFGHIJKLMNOP' \
           'xoxb-1234567890-abcdef'; do
  printf '%s\n' "$bad" > probe.txt
  assert_fail bash "$SWEEP" --worktree
done
echo "sweep-secrets ok"

# --- Case 15: --allow-path exempts ONE path, and only that path ---------------
# The regression this guards: using value-scoped --allow to silence the fixture
# file would also blind the scanner to that value in a real file.
t="$(mktemp -d)"; git -C "$t" init -q; git -C "$t" config user.email t@t; git -C "$t" config user.name t
mkdir -p "$t/tests"
printf 'tok ghp_AAAAAAAAAAAAAAAAAAAA\n' > "$t/tests/fixture.test.sh"
printf 'tok ghp_AAAAAAAAAAAAAAAAAAAA\n' > "$t/real.md"
git -C "$t" add -A >/dev/null; git -C "$t" commit -qm x

out="$(cd "$t" && bash "$SWEEP" --worktree --allow-path tests/fixture.test.sh 2>&1)"; rc=$?
assert_eq "$rc" "1" "case15: real.md must still fail while the fixture is exempt"
assert_contains "$out" "real.md" "case15: the unexempted path must be reported"
case "$out" in *tests/fixture.test.sh:*) echo "FAIL: case15: exempted path was reported"; exit 1;; esac
assert_contains "$out" "exempted by" "case15: exemption must be disclosed, not silent"

# Exact match, not prefix: a sibling sharing the prefix must NOT be exempted.
printf 'tok ghp_AAAAAAAAAAAAAAAAAAAA\n' > "$t/tests/fixture.test.sh.bak"
git -C "$t" add -A >/dev/null
out="$(cd "$t" && bash "$SWEEP" --worktree --allow-path tests/fixture.test.sh 2>&1)"
assert_contains "$out" "fixture.test.sh.bak" "case15: prefix-sharing sibling must not be exempted"
echo "case15 ok"
