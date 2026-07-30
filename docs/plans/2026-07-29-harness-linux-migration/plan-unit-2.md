# Unit 2 — `.gitignore` Harness-State Gate + Secret Sweep — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax
> for tracking.

**Goal:** Build and verify the one-way door that keeps credentials, transcripts, and machine state out of
a **public** repo's history — *before* unit 5 stages the harness — and settle the one design question the
brief defers to this unit.

**Architecture:** Three things, in order. First a scripted gate (`assert-gitignore-safe.sh`) that proves
every never-versioned path is ignored, generating its own coverage from a scan of the live harness tree so
an undocumented file fails loudly instead of slipping through. Then the `.gitignore` additions in their
**own commit**, verified by that gate before any harness `git add` exists. Then the empirical answer to
whether Claude Code's settings blocks expand `${VAR}`, because §4.5's two branches are structurally
different and unit 5 cannot start without knowing which applies.

**Tech Stack:** bash, git (`check-ignore`, `ls-files`), jq, GNU stow 2.3.1, Claude Code CLI 2.1.x.

## Global Constraints

- **HC4:** The remote is **public**. `.gitignore` does **not** remove anything retroactively and HC3
  forbids the force-push that would — so the ordering in Task 2 is a genuine one-way door.
- **C6 ordering, mandatory not implied:** (1) commit the `.gitignore` additions **alone**; (2) verify no
  never-versioned path is stageable; (3) only then `git add` the harness. **`git add -A` is never used
  while staging the harness.**
- **D16:** Both irreversible-op gates are **scripted, not typed**. A manually-typed sequence *is* house
  style, which D16 rejects.
- **§4.17:** `assert-gitignore-safe.sh` generates coverage from a scan of the live tree and **fails on
  any entry classified as neither versioned nor ignored** — so the next undocumented file cannot repeat
  the `keybindings.json` / `.last_inuse_sweep` gap.
- **Repo house style is `|| true`.** These gates must not inherit it.
- Depends on Unit 1: `tests/assert.sh`, `tests/run.sh`, `make test`, `scripts/sweep-secrets.sh`.

**Verified pre-state (do not re-derive — from `codebase-facts.md` + `codebase-scan.md`):**
- `.gitignore` is **137 bytes, not empty**: `.worktrees/` and `.migration_backups/` already present.
  Only harness-state rules are new.
- `~/.claude-shared` has exactly 15 entries. `handoffs/` is **empty**. `plugins/.last_inuse_sweep` is a
  one-line ISO timestamp rewritten every session.
- **Both** `settings.json.bak-20260723-103211` and `settings.json.bak2-105016` contain the
  `CC_NTFY_TOPIC` literal `rrp-cc-e2608a317ed1`.
- `settings.json` line 3 carries that literal inside its `env` block. **No `${VAR}` appears anywhere** in
  `settings.json` or `settings.local.json` — there is no in-repo precedent either way.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `scripts/assert-gitignore-safe.sh` | The C6 gate. Asserts every never-versioned path is ignored, and that every live harness entry is *classified*. Exits non-zero on any failure. | Create |
| `packages/harness-manifest.txt` | The single source of truth for the versioned / ignored / never-versioned three-way classification. The gate reads it; unit 5 vendors against it. | Create |
| `tests/assert-gitignore-safe.test.sh` | Proves the gate catches an unignored never-versioned path **and** an unclassified new entry. | Create |
| `.gitignore` | Harness-state exclusions. **Own commit.** | Modify (5 → ~40 lines) |
| `Makefile` | Add `assert-gitignore-safe` target. | Modify |
| `docs/plans/2026-07-29-harness-linux-migration/settings-expansion-finding.md` | Records the `${VAR}` answer and which §4.5 branch applies. A decision record, not scratch notes. | Create |

Splitting the classification into `packages/harness-manifest.txt` rather than hardcoding it in the script
is deliberate: unit 5 needs the same list to decide what to vendor, and two copies would drift — which is
the exact failure mode `cca-lib.sh`'s own comment documents about `SHARED_ITEMS`.

---

## Task 1: The harness manifest and the C6 gate

**Files:**
- Create: `packages/harness-manifest.txt`
- Create: `scripts/assert-gitignore-safe.sh`
- Create: `tests/assert-gitignore-safe.test.sh`
- Modify: `Makefile`

**Interfaces:**
- Consumes: `tests/assert.sh` (Unit 1 Task 1).
- Produces: `scripts/assert-gitignore-safe.sh [--shared-dir <path>] [--repo <path>]`, exit **0** clean /
  **1** on any violation. `packages/harness-manifest.txt` with a `<class> <path>` line format where class
  ∈ `versioned` | `ignored` | `never`. Unit 5 Task "vendor stow/claude" reads the `versioned` lines.

- [ ] **Step 1: Write the manifest**

The three-way split from design Section 2 + §4.17, made machine-readable. Paths are relative to
`~/.claude-shared`.

```bash
cat > packages/harness-manifest.txt <<'EOF'
# Claude Code harness classification — the single source of truth.
#
# Three classes, and EVERY entry in ~/.claude-shared must match exactly one.
# An unclassified entry is a bug: it is how keybindings.json stayed dangling and
# how .last_inuse_sweep and workflow-navigator.bak went unnoticed (§4.17).
#
#   versioned — tracked in stow/claude/.claude-shared/, stow-symlinked into place
#   ignored   — real machine state, regenerable or local; gitignored
#   never     — must NEVER be committed under any circumstance (HC4)
#
# Format: <class> <path-relative-to-~/.claude-shared>
# Trailing / marks a directory.

# ── versioned ───────────────────────────────────────────────────────────────
versioned  skills/
versioned  hooks/
versioned  commands/
versioned  agents/
versioned  settings.json
versioned  settings.local.json
versioned  CLAUDE.md
versioned  statusline.sh
versioned  shell-integration.sh
versioned  accounts.json
versioned  keybindings.json
versioned  local-marketplace/
versioned  routes.example

# ── ignored (regenerable or machine-local) ──────────────────────────────────
# plugins/ as a whole: NOTHING under it is versioned, and §4.1 requires it stay a
# real directory pre-created by stow-all.sh rather than a repo-backed symlink. So
# the whole subtree is ignored. The individual entries below are kept for
# documentation — they all pass under the blanket rule, and listing them means the
# gate's live-tree scan can classify each one it finds.
ignored    plugins/
ignored    plugins/cache/
ignored    plugins/data/
ignored    plugins/marketplaces/
ignored    plugins/installed_plugins.json
ignored    plugins/known_marketplaces.json
ignored    plugins/plugin-catalog-cache.json
ignored    plugins/blocklist.json
ignored    plugins/.last_inuse_sweep
ignored    plugins/workflow-navigator
ignored    plugins/workflow-navigator.bak-20260724/
ignored    handoffs/
ignored    routes
ignored    settings.json.bak-20260723-103211
ignored    settings.json.bak2-105016

# ── never versioned (HC4) ───────────────────────────────────────────────────
# These live in the per-account dirs, not ~/.claude-shared, but the gate asserts
# them ignored anyway so a stray copy can never be staged.
never      .credentials.json
never      .claude.json
never      history.jsonl
never      projects/
never      sessions/
never      todos/
never      shell-snapshots/
never      stats/
never      debug/
EOF
```

> `plugins/workflow-navigator` is classed `ignored` rather than `never` because D8 deletes it outright —
> it is the dangling symlink through `~/.claude`. Classifying it keeps the gate from failing on an entry
> that legitimately exists right now.

- [ ] **Step 2: Write the failing test**

```bash
cat > tests/assert-gitignore-safe.test.sh <<'EOF'
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/assert.sh"
GATE="$ROOT/scripts/assert-gitignore-safe.sh"
assert_file "$GATE"

sbx="$(mktemp -d "${TMPDIR:-/tmp}/gate-sbx.XXXXXX")"
trap 'rm -rf "$sbx"' EXIT

# A fake repo that vendors a fake harness, plus a fake ~/.claude-shared.
repo="$sbx/repo"; shared="$sbx/shared"
mkdir -p "$repo" "$shared"
cd "$repo"
git init -q . && git config user.email t@t && git config user.name t && git config commit.gpgsign false
cp "$ROOT/packages/harness-manifest.txt" ./harness-manifest.txt
mkdir -p packages && cp ./harness-manifest.txt packages/harness-manifest.txt

# Build a ~/.claude-shared containing one entry of each class.
mkdir -p "$shared/skills" "$shared/plugins/cache" "$shared/handoffs"
echo x > "$shared/settings.json"
echo x > "$shared/plugins/installed_plugins.json"
echo x > "$shared/.credentials.json"

# 1. With NO .gitignore, the never/ignored entries are stageable -> gate must FAIL.
assert_fail bash "$GATE" --repo "$repo" --shared-dir "$shared"

# 2. With correct rules, the gate must PASS.
cat > .gitignore <<'GI'
stow/claude/.claude-shared/plugins/
stow/claude/.claude-shared/plugins/cache/
stow/claude/.claude-shared/plugins/data/
stow/claude/.claude-shared/plugins/marketplaces/
stow/claude/.claude-shared/plugins/installed_plugins.json
stow/claude/.claude-shared/plugins/known_marketplaces.json
stow/claude/.claude-shared/plugins/plugin-catalog-cache.json
stow/claude/.claude-shared/plugins/blocklist.json
stow/claude/.claude-shared/plugins/.last_inuse_sweep
stow/claude/.claude-shared/plugins/workflow-navigator
stow/claude/.claude-shared/plugins/workflow-navigator.bak-20260724/
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
git add .gitignore && git commit -qm "gitignore"
assert_ok bash "$GATE" --repo "$repo" --shared-dir "$shared"

# 3. §4.17: an UNCLASSIFIED live entry must fail, even though it is not in any list.
echo x > "$shared/brand-new-thing.json"
assert_fail bash "$GATE" --repo "$repo" --shared-dir "$shared"
rm "$shared/brand-new-thing.json"
assert_ok bash "$GATE" --repo "$repo" --shared-dir "$shared"

# 4. Removing one ignore rule must fail — the gate checks every entry, not a sample.
#    Use handoffs/, NOT a plugins/* entry: those are all covered by the blanket
#    plugins/ rule, so dropping one of them correctly changes nothing.
cp .gitignore .gi.bak
grep -v 'handoffs/' .gi.bak > .gitignore
git add .gitignore && git commit -qm "drop one rule"
assert_fail bash "$GATE" --repo "$repo" --shared-dir "$shared"
cp .gi.bak .gitignore && git add .gitignore && git commit -qm "restore"
assert_ok bash "$GATE" --repo "$repo" --shared-dir "$shared"

# 5. An ALREADY-TRACKED never path must fail even though the ignore rule exists.
#    A rule added after a `git add` does not untrack anything — this is the case
#    check-ignore alone cannot see, and the reason the gate has a second loop.
mkdir -p stow/claude/.claude-shared
echo "secret" > stow/claude/.claude-shared/.credentials.json
git add -f stow/claude/.claude-shared/.credentials.json
assert_fail bash "$GATE" --repo "$repo" --shared-dir "$shared"
git rm -q --cached stow/claude/.claude-shared/.credentials.json
assert_ok bash "$GATE" --repo "$repo" --shared-dir "$shared"
echo "assert-gitignore-safe ok"
EOF
```

> **This gate was prototyped and all six cases verified before the plan was written.** The first draft
> stripped the trailing slash before calling `check-ignore`, which made every directory rule
> (`projects/`, `handoffs/`, `plugins/`) falsely report as unignored — case 2 failed with 3 violations
> when it should have passed. The version above is the corrected one. Expected results: cases 1, 3, 3b,
> 4, 5 → `rc=1`; cases 2, 6 → `rc=0`.

- [ ] **Step 3: Run it to verify it fails**

Run: `bash tests/assert-gitignore-safe.test.sh`
Expected: `FAIL: expected file: …/scripts/assert-gitignore-safe.sh`.

- [ ] **Step 4: Write the gate**

```bash
cat > scripts/assert-gitignore-safe.sh <<'GATEEOF'
#!/usr/bin/env bash
# The C6 gate. Run BEFORE any harness `git add`, and again before every commit
# that touches the harness package.
#
# Asserts two things:
#   1. Every `ignored` and `never` path in packages/harness-manifest.txt is
#      actually ignored by git under stow/claude/.claude-shared/.
#   2. Every entry that exists in the live ~/.claude-shared is CLASSIFIED by the
#      manifest. An unclassified entry fails the run (§4.17) — that is how
#      keybindings.json, .last_inuse_sweep and workflow-navigator.bak slipped
#      through review.
#
# Deliberately not in repo house style: no `|| true`, non-zero exit on any
# violation. HC4 makes this one-way — .gitignore does not remove anything
# retroactively and HC3 forbids the force-push that would. D16.
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
echo "   repo:      $REPO"
echo "   shared:    $SHARED"

# ── 1. Every ignored/never path must be ignored by git ──────────────────────
while read -r class path; do
  [[ -z "${class:-}" || "$class" == \#* ]] && continue
  case "$class" in ignored|never) ;; *) continue ;; esac
  # Keep the manifest's trailing slash — do NOT strip it. Verified behaviour of
  # `git check-ignore` against a `foo/` rule:
  #     foo          -> NO match   (git cannot tell a non-existent path is a dir)
  #     foo/         -> match
  #     foo/.probe   -> match
  # and against a plain `foo` rule, `foo` matches. So passing the path exactly as
  # the manifest writes it is correct for both classes; stripping the slash makes
  # every directory rule falsely report as unignored.
  target="$PKG_PREFIX/$path"
  if ! git -C "$REPO" check-ignore -q "$target"; then
    note "NOT ignored: $target  (class=$class)"
  fi
done < "$MANIFEST"

# ── 2. Nothing in the never/ignored set may be currently TRACKED ────────────
# check-ignore says nothing about a file already in the index — a rule added
# after a `git add` does not untrack it. This catches that case. Here the trailing
# slash IS stripped — ls-files matches index entries, not gitignore patterns.
while read -r class path; do
  [[ -z "${class:-}" || "$class" == \#* ]] && continue
  case "$class" in ignored|never) ;; *) continue ;; esac
  target="$PKG_PREFIX/${path%/}"
  if [[ -n "$(git -C "$REPO" ls-files -- "$target" 2>/dev/null)" ]]; then
    note "TRACKED but must not be: $target  (class=$class)"
  fi
done < "$MANIFEST"

# ── 3. Every live ~/.claude-shared entry must be classified (§4.17) ─────────
if [[ -d "$SHARED" ]]; then
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if ! awk '$1 !~ /^#/ && NF >= 2 {print $2}' "$MANIFEST" \
         | sed 's#/$##' | grep -qx "$entry"; then
      note "UNCLASSIFIED live entry: $entry  — add it to $MANIFEST as versioned|ignored|never"
    fi
  done < <(find "$SHARED" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)

  # plugins/ is the other directory with unclassified-entry history.
  if [[ -d "$SHARED/plugins" ]]; then
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      if ! awk '$1 !~ /^#/ && NF >= 2 {print $2}' "$MANIFEST" \
           | sed 's#/$##' | grep -qx "plugins/$entry"; then
        note "UNCLASSIFIED live entry: plugins/$entry  — add it to $MANIFEST"
      fi
    done < <(find "$SHARED/plugins" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort)
  fi
fi

if [[ $violations -gt 0 ]]; then
  echo "GATE FAILED: $violations violation(s). Do NOT git add the harness."
  exit 1
fi
echo "gate clean — safe to stage the harness"
GATEEOF
chmod +x scripts/assert-gitignore-safe.sh
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/assert-gitignore-safe.test.sh`
Expected: `assert-gitignore-safe ok`, exit 0.

- [ ] **Step 6: Add the Makefile target**

Add `assert-gitignore-safe` to `.PHONY`, then:

```make
assert-gitignore-safe:
	bash scripts/assert-gitignore-safe.sh
```

- [ ] **Step 7: Confirm the gate currently FAILS against this repo — that is the point**

Run: `make assert-gitignore-safe`
Expected: **exit 1**, with `NOT ignored:` lines for every ignored/never path, because Task 2 has not
added the rules yet. Also expect `UNCLASSIFIED live entry:` lines only if the live tree has gained an
entry since planning — if so, classify it in the manifest before continuing rather than suppressing it.

- [ ] **Step 8: Commit — gate and manifest only, no `.gitignore` change yet**

Keeping these separate is what makes Task 2's commit verifiable in isolation (C6 step 1).

```bash
git add packages/harness-manifest.txt scripts/assert-gitignore-safe.sh \
        tests/assert-gitignore-safe.test.sh Makefile
git commit -m "feat(scripts): add assert-gitignore-safe gate + harness manifest

Scripts the C6 gate instead of trusting a typed sequence (D16), and
generates its coverage from a scan of the live tree so an unclassified
entry fails loudly — the gap that let keybindings.json stay dangling and
.last_inuse_sweep / workflow-navigator.bak go unnoticed (§4.17).
The manifest is the single source of truth unit 5 vendors against."
```

---

## Task 2: The `.gitignore` additions — their own verified commit

**C6, verbatim:** *"1. Commit the harness-state `.gitignore` additions **alone**. 2. Verify… 3. Only then
`git add` the harness package."*

**Files:**
- Modify: `.gitignore` (5 lines → ~40)

**Interfaces:**
- Consumes: `scripts/assert-gitignore-safe.sh` (Task 1).
- Produces: a `.gitignore` under which the gate passes. Unit 5 will not stage anything until it does.

- [ ] **Step 1: Append the harness-state rules**

Do **not** rewrite the file — `.worktrees/` and `.migration_backups/` are already there and correct.
Append:

```gitignore

# ── Claude Code harness state ───────────────────────────────────────────────
# Classification lives in packages/harness-manifest.txt; scripts/assert-gitignore-safe.sh
# asserts these rules match it. The remote is PUBLIC and .gitignore does not
# remove anything retroactively, so these rules land BEFORE the harness is
# staged (C6/HC4) — this ordering is a one-way door.

# Regenerable plugin state — rebuilt from packages/claude-plugins.txt (D6/HC6).
# Already 4-of-14 broken today: four records point into ~/.claude-accounts/.shared-rrp.*
# directories that no longer exist.
#
# The whole plugins/ subtree is ignored: nothing under it is versioned, and §4.1
# requires it stay a REAL directory created by stow-all.sh, not a repo-backed
# symlink. The specific rules that follow are redundant under this one and kept
# only as documentation of what lives there.
stow/claude/.claude-shared/plugins/
stow/claude/.claude-shared/plugins/cache/
stow/claude/.claude-shared/plugins/data/
stow/claude/.claude-shared/plugins/marketplaces/
stow/claude/.claude-shared/plugins/installed_plugins.json
stow/claude/.claude-shared/plugins/known_marketplaces.json
stow/claude/.claude-shared/plugins/plugin-catalog-cache.json
stow/claude/.claude-shared/plugins/blocklist.json
stow/claude/.claude-shared/plugins/.last_inuse_sweep
stow/claude/.claude-shared/plugins/workflow-navigator
stow/claude/.claude-shared/plugins/workflow-navigator.bak-20260724/

# Machine-local runtime state.
stow/claude/.claude-shared/handoffs/
# routes maps absolute project paths to accounts — machine-local by nature (D12).
# routes.example is tracked; the real file is not.
stow/claude/.claude-shared/routes
# Both .bak files contain the CC_NTFY_TOPIC literal HC5 exists to keep out.
stow/claude/.claude-shared/settings.json.bak*

# Never versioned under any circumstance (HC4).
stow/claude/.claude-shared/.credentials.json
stow/claude/.claude-shared/.claude.json
stow/claude/.claude-shared/history.jsonl
stow/claude/.claude-shared/projects/
stow/claude/.claude-shared/sessions/
stow/claude/.claude-shared/todos/
stow/claude/.claude-shared/shell-snapshots/
stow/claude/.claude-shared/stats/
stow/claude/.claude-shared/debug/

# Machine-local env / settings materialized from .example by install-env.sh (§4.3).
stow/env/.config/dotfiles/env.sh
```

> The final line untracks a **currently tracked** file. §4.3 requires `git rm --cached` for it — that is
> unit 3.5's `env` task, not this one. The ignore rule is harmless until then (git ignores rules for
> tracked files), and landing it here keeps all the exclusions in one reviewable commit.

- [ ] **Step 2: Run the gate — it must now pass**

Run: `make assert-gitignore-safe`
Expected: `gate clean — safe to stage the harness`, exit 0.

If any `NOT ignored:` line remains, the rule's path does not match the manifest entry — fix the
`.gitignore` line, not the manifest.

- [ ] **Step 3: Verify nothing sensitive is stageable right now**

Belt and braces alongside the gate — C6 step 2 asks for `git status --porcelain` **plus** per-entry
`check-ignore`.

```bash
git status --porcelain
git check-ignore -v stow/claude/.claude-shared/.credentials.json \
                    stow/claude/.claude-shared/plugins/installed_plugins.json \
                    stow/claude/.claude-shared/settings.json.bak-20260723-103211 \
                    stow/claude/.claude-shared/routes
```

Expected: `git status` shows only `.gitignore` as modified. Every `check-ignore -v` path prints the
matching rule (which proves the *rule* matched, not merely that the file is absent).

- [ ] **Step 4: Confirm the versioned paths are NOT ignored — an over-broad rule is also a bug**

A rule like `stow/claude/**` would pass every check above while making the harness unstageable.

```bash
for p in settings.json settings.local.json CLAUDE.md statusline.sh shell-integration.sh \
         accounts.json keybindings.json routes.example \
         skills/pr-watch/SKILL.md hooks/notify.sh commands/promote.md agents/critic.md \
         local-marketplace/.claude-plugin/marketplace.json; do
  if git check-ignore -q "stow/claude/.claude-shared/$p"; then echo "OVER-BROAD: $p is ignored"; fi
done
echo "over-broad check done"
```

Expected: `over-broad check done` with **no** `OVER-BROAD:` lines.

- [ ] **Step 5: Commit — `.gitignore` alone (C6 step 1)**

Note the explicit file path. **Not `git add -A`** — C6 forbids it while the harness is in play, and
building the habit here matters more than in unit 5 where it is load-bearing.

```bash
git add .gitignore
git commit -m "chore(gitignore): harness-state exclusions, ahead of any harness git add

C6 requires these land ALONE and verified before the harness is staged:
the remote is public, .gitignore does not remove anything retroactively,
and HC3 forbids the force-push that would. Verified by
scripts/assert-gitignore-safe.sh (gate clean) plus an over-broad check
confirming the versioned paths are still stageable.

Note .gitignore was NOT empty — .worktrees/ and .migration_backups/ were
already present; only the harness rules are new."
```

- [ ] **Step 6: Push**

```bash
make test && git push origin feat/harness-linux-migration
```

Expected: all tests PASS, push succeeds.

---

## Task 3: Sweep every file this project newly tracks or modifies

**§4.15** widened R3's scope: the sweep is not only the 47 harness files but *"`stow/tmux/.tmux.conf`
(adopted verbatim), `stow/bin/.local/bin/ccz`, `stow/ssh/.ssh/config`, the mise config, `.zshrc`, and
everything under `packages/` and `scripts/`."*

**Files:**
- Create: `tests/no-endpoints-tracked.test.sh`

**Interfaces:**
- Consumes: `scripts/sweep-secrets.sh` (Unit 1 Task 2); `tests/assert.sh`.
- Produces: a regression test that keeps HC5 true as unit 3.5 and unit 5 add files, rather than being a
  one-time check.

- [ ] **Step 1: Sweep the current tracked tree**

```bash
bash scripts/sweep-secrets.sh --worktree
```

Expected: `sweep clean`. This is the baseline — the harness is not vendored yet, so a hit here would mean
something already in the repo.

- [ ] **Step 2: Sweep the not-yet-tracked files this project will adopt**

These are the real risk: content that is clean in the repo today because it is not in the repo yet.

```bash
for f in ~/.tmux.conf ~/.local/bin/ccz ~/.claude-shared/settings.json \
         ~/.claude-shared/settings.local.json ~/.claude-shared/CLAUDE.md \
         ~/.claude-shared/accounts.json ~/.claude-shared/statusline.sh \
         ~/.claude-shared/shell-integration.sh; do
  printf '%-45s ' "$(basename "$f")"
  if grep -qE 'rrp-cc-[0-9a-f]{6,}|100\.114\.199\.|ghp_|gho_|sk-ant-|BEGIN [A-Z ]*PRIVATE KEY' "$f" 2>/dev/null; then
    echo "HIT"
  else echo "clean"; fi
done
```

Expected: `settings.json` → **HIT** (the `CC_NTFY_TOPIC` at line 3 — this is the known R2/C8 case Task 4
resolves), `ccz` → **HIT** (the Tailscale IP, comment-only). Everything else `clean`.

**Record the result.** Any HIT beyond those two is a new finding and must be resolved before unit 5
vendors that file.

- [ ] **Step 3: Sweep the harness directory trees (47 files) for anything the design has not surfaced**

R3 treated the 4-hooks/3-skills `/home/keenan` discovery as a canary for exactly this.

```bash
bash -c '
RE="rrp-cc-[0-9a-f]{6,}|100\.114\.199\.|ghp_|gho_|github_pat_|sk-ant-|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|hooks\.slack\.com/services/|xoxb-"
grep -rnIE "$RE" ~/.claude-shared/hooks ~/.claude-shared/skills \
    ~/.claude-shared/commands ~/.claude-shared/agents \
    ~/.claude-accounts/rrp/local-marketplace 2>/dev/null || echo "no endpoint/credential hits in the 47 files"
'
```

Expected: `no endpoint/credential hits in the 47 files`. Any hit is a new HC5 item — add it to the design
before proceeding.

- [ ] **Step 4: Write the regression test**

A one-time sweep does not stay true. This keeps HC5/SC6 honest as later units add tracked files.

```bash
cat > tests/no-endpoints-tracked.test.sh <<'EOF'
#!/usr/bin/env bash
# HC5: no addressable endpoint may appear in any TRACKED file.
# SC6: no absolute /home/keenan path under stow/claude/** or stow/env/**.
# This is a regression test, not a one-time sweep — unit 3.5 and unit 5 both add
# tracked files, and R3 showed the design under-counted what needed checking.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/assert.sh"
cd "$ROOT"

# HC5 — endpoints, over everything tracked.
hits="$(git grep -nIE 'rrp-cc-[0-9a-f]{6,}|100\.114\.199\.' -- . || true)"
assert_eq "$hits" "" "HC5: no CC_NTFY_TOPIC or Tailscale host in tracked files"

# SC6 — absolute home paths, scoped exactly as the brief scopes it.
scoped="$(git ls-files -- 'stow/claude/*' 'stow/env/*' || true)"
if [ -n "$scoped" ]; then
  # shellcheck disable=SC2086
  paths="$(git grep -lI '/home/keenan' -- 'stow/claude/*' 'stow/env/*' || true)"
  assert_eq "$paths" "" "SC6: no /home/keenan under stow/claude/** or stow/env/**"
fi
echo "no-endpoints-tracked ok"
EOF
```

- [ ] **Step 5: Run it — it must pass now and keep passing**

Run: `bash tests/no-endpoints-tracked.test.sh`
Expected: `no-endpoints-tracked ok`. It passes trivially today (the harness is not vendored); its value
is that unit 5 cannot land a violation without turning it red.

- [ ] **Step 6: Commit**

```bash
git add tests/no-endpoints-tracked.test.sh
git commit -m "test: regression-guard HC5 endpoints and SC6 absolute paths

Passes trivially today because the harness is not vendored yet — the
point is that unit 5 cannot land a violation without turning it red.
R3 found the round-1 sweep covered only the two already-known values."
```

---

## Task 4: Settle the `${VAR}` expansion question and record it

The brief: *"**To be decided and RECORDED in unit 2, not improvised:** whether the Claude Code settings
`env`/permission blocks expand `${VAR}`."* §4.5's two branches are structurally different — one keeps
`settings.json` stow-symlinked, the other moves it to gitignored-real + a tracked `.example`
materialized **before** stow. Unit 5 cannot start without the answer.

**There is no in-repo precedent** — verified: no `${` appears anywhere in `settings.json` or
`settings.local.json`. So this must be tested empirically.

**Files:**
- Create: `docs/plans/2026-07-29-harness-linux-migration/settings-expansion-finding.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the decision record that unit 5 reads to know which §4.5 branch applies.

- [ ] **Step 1: Test expansion in the `env` block, in a throwaway config dir**

Never test this against the live profile. `CLAUDE_CONFIG_DIR` isolates it.

```bash
sbx="$(mktemp -d /tmp/cc-expand.XXXXXX)"
cat > "$sbx/settings.json" <<'EOF'
{
  "env": {
    "CC_EXPANSION_PROBE": "${HOME}/probe-marker"
  }
}
EOF
CLAUDE_CONFIG_DIR="$sbx" ~/.local/bin/claude -p 'Print the exact value of the CC_EXPANSION_PROBE environment variable and nothing else.' 2>&1 | tail -3
```

Expected: either the literal `${HOME}/probe-marker` (**no expansion**) or `/home/keenan/probe-marker`
(**expansion works**). Record the exact output verbatim.

- [ ] **Step 2: Test expansion in a permission glob**

The `env` block and the permission matcher are different code paths — §4.5 needs both, and it is entirely
possible one expands and the other does not.

```bash
cat > "$sbx/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Read(${HOME}/**)"],
    "deny": []
  }
}
EOF
CLAUDE_CONFIG_DIR="$sbx" ~/.local/bin/claude -p 'Read the file /etc/hostname and print its first line.' 2>&1 | tail -5
```

Expected: if the read succeeds without a permission prompt, the glob expanded. If it is denied or prompts,
it did not. Record the exact behaviour.

- [ ] **Step 3: Test `additionalDirectories`, the third distinct consumer**

```bash
cat > "$sbx/settings.json" <<'EOF'
{
  "permissions": {
    "additionalDirectories": ["${HOME}/github"]
  }
}
EOF
CLAUDE_CONFIG_DIR="$sbx" ~/.local/bin/claude -p 'List your additional working directories, exactly as configured.' 2>&1 | tail -5
rm -rf "$sbx"
```

Record the result.

- [ ] **Step 4: Write the decision record**

Fill in the three observed results and select the branch. Both branch texts below are complete — copy the
one that applies into the "Decision" line; do not paraphrase.

```bash
cat > docs/plans/2026-07-29-harness-linux-migration/settings-expansion-finding.md <<'EOF'
# Finding — does Claude Code expand `${VAR}` in settings.json?

**Date:** <fill in>
**Claude Code version:** <output of `~/.local/bin/claude --version`>
**Why this exists:** brief.md requires this "decided and RECORDED in unit 2, not improvised".
design.md §4.5 has two structurally different branches and unit 5 cannot start without knowing which.
There is no in-repo precedent — no `${` appears anywhere in settings.json or settings.local.json.

## Method

Tested against a throwaway `CLAUDE_CONFIG_DIR`, never the live profile. Three distinct consumers,
because they are different code paths and may disagree.

## Results

| Consumer | Probe | Observed output | Expands? |
|---|---|---|---|
| `env` block | `"CC_EXPANSION_PROBE": "${HOME}/probe-marker"` | <verbatim> | yes / no |
| permission glob | `"allow": ["Read(${HOME}/**)"]` | <verbatim> | yes / no |
| `additionalDirectories` | `["${HOME}/github"]` | <verbatim> | yes / no |

## Decision

<Copy exactly ONE of the following.>

**Branch A — expansion works (all three consumers).** `settings.json` is committed with `${HOME}` /
`${CC_NTFY_TOPIC}` placeholders and stays a versioned, stow-symlinked file. Nothing is rewritten at any
point. `CC_NTFY_TOPIC` comes from the environment via `env.sh` (§4.4 mechanism 1). SC6's six
`/home/keenan` occurrences are fixed by templating in place.

**Branch B — expansion does not work (any consumer).** `settings.json` gets exactly the `env.sh`/`routes`
treatment: the real file becomes gitignored, a tracked `settings.json.example` carries `$HOME`-relative
placeholders, and `install-env.sh` materializes the real file (substituting the actual `$HOME`)
**before** `stow-all.sh` runs. `settings.json` moves from the Versioned list to the
gitignored-materialized list for §4.1's assertions, and `packages/harness-manifest.txt` must be updated
to reclassify it from `versioned` to `ignored` with `settings.json.example` added as `versioned`.
`CC_NTFY_TOPIC` is removed from the committed file entirely and the notifying hook reads
`$CC_NTFY_TOPIC` from the environment (§4.4 mechanism 2).

**Mixed result (e.g. `env` expands but globs do not):** Branch B applies — it is the safe superset. Record
which consumers differed, because it affects nothing else here but is worth knowing.

## Consequences for unit 5

- Which §4.5 branch: <A or B>
- `packages/harness-manifest.txt` change required: <none / reclassify settings.json>
- `install-env.sh` must materialize `settings.json`: <no / yes>

**Not permitted under either branch:** rewriting a stowed `settings.json` in place. It is a symlink into
the repo, so a post-stow edit would modify the tracked file and break SC11's `git status --porcelain`
assertion, while replacing the symlink with a real copy would break the "every versioned entry is a
symlink" assertion. Materialize-before-stow is the only branch that satisfies both (§4.5).
EOF
```

- [ ] **Step 5: If Branch B applies, reclassify in the manifest now**

Doing it here rather than in unit 5 keeps the gate and the manifest in agreement.

```bash
# Only if Branch B:
#   - change `versioned  settings.json` to `ignored    settings.json`
#   - add    `versioned  settings.json.example`
#   - add    stow/claude/.claude-shared/settings.json to .gitignore
# Then re-run the gate, which must still pass:
make assert-gitignore-safe
```

Expected (Branch B): `gate clean`. Expected (Branch A): no change needed.

- [ ] **Step 6: Commit**

```bash
git add docs/plans/2026-07-29-harness-linux-migration/settings-expansion-finding.md
# plus packages/harness-manifest.txt and .gitignore if Branch B applied
git commit -m "docs(plans): record the settings.json \${VAR} expansion finding

The brief requires this decided and recorded in unit 2, not improvised at
implementation time. There was no in-repo precedent to reason from — no
\${} appears anywhere in settings.json or settings.local.json — so it was
tested empirically against a throwaway CLAUDE_CONFIG_DIR across all three
consumers (env block, permission glob, additionalDirectories), which are
separate code paths. §4.5 branch selected."
```

---

## Unit 2 Exit Criteria

| Criterion | Check |
|---|---|
| C6 step 1 — rules land alone | `git show --stat` on the `.gitignore` commit lists **only** `.gitignore` |
| C6 step 2 — verified | `make assert-gitignore-safe` exits 0 |
| C6 — gate is scripted, not typed | `scripts/assert-gitignore-safe.sh` exists and is tested (D16) |
| §4.17 — unclassified entries fail | `tests/assert-gitignore-safe.test.sh` case 3 passes |
| No over-broad rule | Task 2 Step 4 prints no `OVER-BROAD:` lines |
| HC4/HC5 — nothing sensitive tracked | `sweep-secrets.sh --worktree` clean; `no-endpoints-tracked.test.sh` passes |
| §4.5 branch decided **and recorded** | `settings-expansion-finding.md` exists with a branch selected |
| Manifest and `.gitignore` agree | gate passes after any Branch-B reclassification |

**Deliberately NOT in this unit:**
- Staging any harness file. C6 step 3 is unit 5. The gate exists *so that* unit 5 can.
- `git rm --cached stow/env/.config/dotfiles/env.sh` — §4.3, unit 3.5's `env` task. The ignore rule is
  inert until then.
- Creating `env.sh.example` / `routes.example` or `install-env.sh` — unit 3.5.
- Removing the `settings.json.bak*` files. They are ignored now, which is what HC4 requires; deleting
  live files is unit 5's staged work.

## Handoff

Units 3, 3.5, 4, and 5 must be planned **against the merged tree**, not against the pre-merge one.
§4.9 requires an explicit post-merge re-diff of `zsh`/`env`/`nvim` against the planned `hosts/wsl/`
overlay and the `env.sh` template before those packages are built, and Unit 1's merge changes
`stow/mise/.config/mise/config.toml`, `stow/zsh/.zshrc`, `stow/zellij/.config/zellij/layouts/web.kdl`,
and `stow/nvim/**` — exactly the files those units rewrite. §4.19 adds a 9th package (`gnupg`) that needs
a reconciliation row, an `apt-common.txt` entry (`pinentry-curses`, `gnupg`), a never-`--adopt` entry, and
`chmod 700 ~/.gnupg` in `stow-all.sh`.

Known inputs already gathered for those units, so they need no re-scanning:
`codebase-scan.md` Part 2 findings **B** (`PLATFORM` must be an overridable input — `/proc/version` reads
`microsoft` inside containers on this host), **C** (`DOCKER_CONFIG` workaround), **D** (bootstrap creates
real files at stow-owned paths), **E** (`install-mise-globals.sh` contradicts the tool-ownership policy),
**F** (`audit.sh` needs `doctor`'s exit-semantics fix), **G**/**H** (the cargo/mise cleanup is ~12
binaries, `bottom` is installed as `btm`), **I** (`adopt-existing.sh` violates HC8/HC4/HC7), and
**J** (`lsb_release` / `gnupg` missing from `apt.txt`).
