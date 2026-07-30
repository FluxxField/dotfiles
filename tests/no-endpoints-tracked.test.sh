#!/usr/bin/env bash
# HC5: no addressable endpoint may appear in any TRACKED file.
# SC6: no absolute /home/keenan path under stow/claude/** or stow/env/**.
# This is a regression test, not a one-time sweep — unit 3.5 and unit 5 both add
# tracked files, and R3 showed the design under-counted what needed checking.
#
# Round 5 made this test load-bearing rather than theoretical: the real
# CC_NTFY_TOPIC and Tailscale IP were found quoted in eight tracked planning
# documents, already pushed to the public remote (design.md 4.20).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/assert.sh"
cd "$ROOT"

# The two fixture-bearing paths, exempted BY PATH and kept in sync with the
# Makefile's SWEEP_EXEMPT. They hold real-SHAPED but fake tokens on purpose:
# they are what proves detection works. Exempting by path (not by value) keeps
# the blind spot to two reviewable files.
EXEMPT=(':!tests/sweep-secrets.test.sh'
        ':!docs/plans/2026-07-29-harness-linux-migration/plan-unit-1.md')

# HC5 — endpoints, over everything tracked.
hits="$(git grep -nIE 'rrp-cc-[0-9a-f]{6,}|100\.114\.199\.' -- . "${EXEMPT[@]}" || true)"
assert_eq "$hits" "" "HC5: no CC_NTFY_TOPIC or Tailscale host in tracked files"

# Guard the guard: the exemption must not have silenced the whole check. If the
# fixture files stop matching, the pathspec is stale and this test has quietly
# become vacuous.
canary="$(git grep -lIE 'rrp-cc-[0-9a-f]{6,}|100\.114\.199\.' -- tests/sweep-secrets.test.sh || true)"
assert_eq "$canary" "tests/sweep-secrets.test.sh" \
  "fixture canary: the endpoint regex must still match the fixture file"

# SC6 — absolute home paths, scoped exactly as the brief scopes it.
scoped="$(git ls-files -- 'stow/claude/*' 'stow/env/*' || true)"
if [ -n "$scoped" ]; then
  paths="$(git grep -lI '/home/keenan' -- 'stow/claude/*' 'stow/env/*' || true)"
  assert_eq "$paths" "" "SC6: no /home/keenan under stow/claude/** or stow/env/**"
fi
echo "no-endpoints-tracked ok"
