#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/assert.sh"
GATE="$ROOT/scripts/assert-gitignore-safe.sh"
assert_file "$GATE"

sbx="$(mktemp -d "${TMPDIR:-/tmp}/gate-sbx.XXXXXX")"
trap 'rm -rf "$sbx"' EXIT
repo="$sbx/repo"; shared="$sbx/shared"
mkdir -p "$repo/packages" "$shared"
cd "$repo"
git init -q . && git config user.email t@t && git config user.name t && git config commit.gpgsign false
cp "$ROOT/packages/harness-manifest.txt" packages/harness-manifest.txt

mkdir -p "$shared/skills" "$shared/hooks" "$shared/commands" "$shared/agents" \
         "$shared/plugins/cache" "$shared/plugins/data" "$shared/plugins/marketplaces" "$shared/handoffs"
for f in settings.json settings.local.json CLAUDE.md statusline.sh shell-integration.sh accounts.json routes; do
  echo x > "$shared/$f"
done
for f in installed_plugins.json known_marketplaces.json plugin-catalog-cache.json blocklist.json .last_inuse_sweep; do
  echo x > "$shared/plugins/$f"
done

# 1. No .gitignore -> gate must FAIL.
assert_fail bash "$GATE" --repo "$repo" --shared-dir "$shared"

# 2. Correct rules -> gate must PASS.
cat > .gitignore <<'GI'
stow/claude/.claude-shared/plugins/
stow/claude/.claude-shared/handoffs/
stow/claude/.claude-shared/routes
stow/claude/.claude-shared/settings.json.bak*
stow/claude/.claude-shared/.credentials.json
stow/claude/.claude-shared/.claude.json
stow/claude/.claude-shared/history.jsonl
stow/claude/.claude-shared/projects/
stow/claude/.claude-shared/sessions/
stow/claude/.claude-shared/todos/
stow/claude/.claude-shared/shell-snapshots/
stow/claude/.claude-shared/stats/
stow/claude/.claude-shared/debug/
GI
git add -A && git commit -qm "gitignore"
assert_ok bash "$GATE" --repo "$repo" --shared-dir "$shared"

# 3. An UNCLASSIFIED live entry must fail (§4.17).
echo x > "$shared/brand-new-thing.json"
assert_fail bash "$GATE" --repo "$repo" --shared-dir "$shared"
rm "$shared/brand-new-thing.json"
assert_ok bash "$GATE" --repo "$repo" --shared-dir "$shared"

# 3b. ...including one nested under plugins/.
echo x > "$shared/plugins/some-new-cache.json"
assert_fail bash "$GATE" --repo "$repo" --shared-dir "$shared"
rm "$shared/plugins/some-new-cache.json"

# 4. Dropping one rule must fail. Use handoffs/, not a plugins/* entry — those
#    are covered by the blanket plugins/ rule so dropping one changes nothing.
cp .gitignore .gi.bak
grep -v 'handoffs/' .gi.bak > .gitignore
git add .gitignore && git commit -qm "drop one rule"
assert_fail bash "$GATE" --repo "$repo" --shared-dir "$shared"
cp .gi.bak .gitignore && rm .gi.bak && git add -A && git commit -qm "restore"
assert_ok bash "$GATE" --repo "$repo" --shared-dir "$shared"

# 5. An ALREADY-TRACKED never path must fail even though the ignore rule exists.
mkdir -p stow/claude/.claude-shared
echo "secret" > stow/claude/.claude-shared/.credentials.json
git add -f stow/claude/.claude-shared/.credentials.json
assert_fail bash "$GATE" --repo "$repo" --shared-dir "$shared"
git rm -q --cached stow/claude/.claude-shared/.credentials.json
assert_ok bash "$GATE" --repo "$repo" --shared-dir "$shared"
echo "assert-gitignore-safe ok"
