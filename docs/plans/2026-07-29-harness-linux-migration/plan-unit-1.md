# Unit 1 — Fork Reconciliation + Git Identity + GPG — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax
> for tracking.

**Goal:** Reconcile the 3-local/9-remote fork of `~/.dotfiles` without losing a commit from either side,
and leave the machine able to make **signed commits non-interactively** — which it currently cannot.

**Architecture:** Sweep the incoming commits for secrets *before* the merge (a merge into a public branch
is as permanent as a `git add`), then `git merge origin/main` (never rebase), then fix the two things the
merge exposes: `stow/git/.gitconfig` declares a signing key that is not in the keyring, and GPG signing
hangs non-interactively because there is no `gpg-agent.conf` and no cached passphrase. Landing the
`.gitconfig` fix in this unit is mandatory — `stow-all.sh` stows *every* package on every run, so the
moment `git` is stowed (unit 3.5) an unfixed config breaks every commit and tag on the machine.

**Tech Stack:** bash, git, GNU stow 2.3.1, gnupg 2.x (rsa3072 key `6C32D9329BDB7DA9`), GitHub CLI `gh`.

## Global Constraints

- **HC2:** `git merge`, **never** `git rebase`. The 3 local commits may exist on another machine.
- **HC3:** Never force-push, hard-reset, `git branch -D`, or delete a remote ref.
- **HC4:** The remote is **public**. Nothing sensitive enters history — and `.gitignore` does not
  retroactively remove anything, so ordering is one-way.
- **HC12:** Commit capability must survive stowing the `git` package.
- **Repo house style is `|| true` everywhere** (`bootstrap.sh`, `audit.sh` drops `-e`, `doctor` always
  exits 0). **D16 explicitly rejects it for gates.** Every verification step below must fail loudly.
- Canonical identity (Q1, decided): `user.email = keenanjj13@gmail.com`, `init.defaultBranch = main`.
- Signing key (Q2, decided): `6C32D9329BDB7DA9` — `rsa3072`, `[SC]`, no expiry, uid
  `Keenan Johns (Github Account) <keenanjj13@gmail.com>`. The declared `665F3EDCE9AB996D` is **absent**
  from the keyring.
- Work in the existing worktree: `~/.dotfiles/.worktrees/feat/harness-linux-migration` on branch
  `feat/harness-linux-migration`.

**Verified pre-state (do not re-derive):** `git rev-list --left-right --count main...origin/main` → `3 9`.
The 9 remote-only commits touch exactly **6 files**: `stow/gnupg/gpg-agent.conf` (new package),
`stow/mise/.config/mise/config.toml`, `stow/nvim/.config/nvim/lazy-lock.json`,
`stow/nvim/.config/nvim/lua/plugins/astrocore.lua`, `stow/zellij/.config/zellij/layouts/web.kdl`,
`stow/zsh/.zshrc`. They do **not** touch `.gitconfig`, `.gitignore`, `Makefile`, `bootstrap.sh`,
`stow-all.sh`, `packages/`, or `scripts/` — so this unit's edits are conflict-free.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `scripts/sweep-secrets.sh` | Reusable secret/PII scanner over a git revision range or a path set. Unit 2 reuses it for the tracked-file sweep. | Create |
| `tests/assert.sh` | Assertion primitives, modelled on `cc-account-switcher/tests/assert.sh`. | Create |
| `tests/run.sh` | Test runner — iterates `tests/*.test.sh`, non-zero on any failure. | Create |
| `tests/sweep-secrets.test.sh` | Proves the scanner detects a planted secret and passes clean input. | Create |
| `Makefile` | Add `test` and `sweep-secrets` targets. | Modify |
| `stow/git/.gitconfig` | Identity + signing key + credential helper line-merge. | Modify (30 lines) |
| `stow/gnupg/.gnupg/gpg-agent.conf` | Relocate the incoming mis-placed `gpg-agent.conf` so stow links it to `~/.gnupg/`, not `~/`. | Move (post-merge) |

`sweep-secrets.sh` is a script rather than inline `git grep` calls because §4.15 requires the same sweep
in unit 1 (revision range) *and* unit 2 (working tree), and D16 requires it be scripted, not typed.

---

## Task 1: Test harness

Nothing in this repo is testable today — there is no `tests/` directory and no `make test`. Every later
task in every unit needs this. Modelled deliberately on `~/github/cc-account-switcher/tests/` so the
idiom is one the user already maintains.

**Files:**
- Create: `tests/assert.sh`
- Create: `tests/run.sh`
- Modify: `Makefile` (add `test` target, extend `.PHONY`)

**Interfaces:**
- Produces: `assert_eq <got> <want> [msg]`, `assert_file <path>`, `assert_dir <path>`,
  `assert_link <path> <expected-link-text>`, `assert_real_dir <path>` (exists, is a directory, is **not**
  a symlink — needed by SC11), `assert_ok <cmd...>`, `assert_fail <cmd...>`,
  `assert_contains <haystack> <needle> [msg]`. All print `FAIL: …` and `exit 1`.
- Consumes: nothing.

- [ ] **Step 1: Write the assertion library**

```bash
cat > tests/assert.sh <<'EOF'
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
EOF
```

- [ ] **Step 2: Write the runner**

```bash
cat > tests/run.sh <<'EOF'
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
EOF
chmod +x tests/run.sh
```

- [ ] **Step 3: Prove the harness itself can fail (guard against a vacuous runner)**

`make doctor` and `audit.sh` both "passed" for months while reporting failures. Do not let the test
runner join them.

```bash
cat > tests/zz-harness-selfcheck.test.sh <<'EOF'
#!/usr/bin/env bash
# Proves assert_* actually fail. Run each in a subshell so the exit 1 is caught.
set -u
source "$(dirname "$0")/assert.sh"
( assert_eq a b "should fail" ) && { echo "FAIL: assert_eq did not fail"; exit 1; }
( assert_file /nonexistent-xyz ) && { echo "FAIL: assert_file did not fail"; exit 1; }
( assert_real_dir /etc/os-release ) && { echo "FAIL: assert_real_dir accepted a file"; exit 1; }
assert_eq a a "positive case"
assert_real_dir /etc
echo "harness selfcheck ok"
EOF
```

- [ ] **Step 4: Add the `test` target**

In `Makefile`, add `test` to the `.PHONY` list on line 6-9, and add the target:

```make
test:
	bash tests/run.sh
```

- [ ] **Step 5: Run the tests — they must pass, and the selfcheck must prove failures are detected**

Run: `make test`
Expected: `== zz-harness-selfcheck.test.sh ==` then `harness selfcheck ok` then `PASS`, exit 0.

Then confirm the runner is not vacuous:

Run: `printf '#!/usr/bin/env bash\nexit 1\n' > tests/zz-tmp-fail.test.sh && bash tests/run.sh; echo "rc=$?"; rm tests/zz-tmp-fail.test.sh`
Expected: `FAILED: …zz-tmp-fail.test.sh` and **`rc=1`**. If `rc=0`, the runner is broken — stop and fix it.

- [ ] **Step 6: Commit**

```bash
git add tests/assert.sh tests/run.sh tests/zz-harness-selfcheck.test.sh Makefile
git commit -m "test: add assertion harness and make test target

Modelled on cc-account-switcher/tests/. Includes a selfcheck that proves
assert_* actually fail — make doctor and audit.sh both reported failures
while exiting 0 for months, and the test runner must not repeat that."
```

---

## Task 2: Secret/PII scanner

§4.15: *"The 9 incoming remote commits are swept before Task 0 merges them. A `git merge` into a public
branch is exactly as history-permanent as the `git add` that C6 guards, and it happens in unit 1 —
before unit 2's `.gitignore` gate exists."* D16 requires this be scripted, not typed.

**Files:**
- Create: `scripts/sweep-secrets.sh`
- Create: `tests/sweep-secrets.test.sh`
- Modify: `Makefile` (add `sweep-secrets` target)

**Interfaces:**
- Consumes: `tests/assert.sh` from Task 1.
- Produces: `scripts/sweep-secrets.sh [--range <git-range> | --worktree] [--allow <regex>]`. Exits **0**
  when clean, **1** on any hit, **2** on usage error. Unit 2 Task 4 reuses it with `--worktree`.

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/sweep-secrets.test.sh <<'EOF'
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/assert.sh"
SWEEP="$ROOT/scripts/sweep-secrets.sh"

sbx="$(mktemp -d "${TMPDIR:-/tmp}/sweep-sbx.XXXXXX")"
trap 'rm -rf "$sbx"' EXIT
cd "$sbx"
git init -q . && git config user.email t@t && git config user.name t && git config commit.gpgsign false

# 1. Clean tree passes.
echo "nothing to see here" > ok.txt
git add -A && git commit -qm "clean"
assert_ok bash "$SWEEP" --worktree

# 2. A planted ntfy topic is caught in the worktree while still UNTRACKED —
#    the gate must catch content before it is added, which requires --untracked.
echo 'CC_NTFY_TOPIC=rrp-cc-e2608a317ed1' > leak.txt
assert_fail bash "$SWEEP" --worktree

# 2b. ...but a gitignored file is NOT scanned. Correctly-ignored machine state
#     (credentials, transcripts) must be skipped, not read and echoed to the log.
echo 'secret.log' > .gitignore
echo 'rrp-cc-deadbeef99' > secret.log
rm leak.txt
assert_ok bash "$SWEEP" --worktree
rm secret.log .gitignore
echo 'CC_NTFY_TOPIC=rrp-cc-e2608a317ed1' > leak.txt

# 3. ...and caught in a revision range once committed.
git add -A && git commit -qm "leak"
assert_fail bash "$SWEEP" --range "HEAD~1..HEAD"

# 3b. The case a two-dot endpoint diff would MISS: added, then removed, inside the
#     range. The blob is still in history forever, so the gate must still fail.
base="$(git rev-parse HEAD)"
echo 'ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' > transient.txt
git add -A && git commit -qm "add secret"
git rm -q transient.txt && git commit -qm "remove secret"
echo 'unrelated' >> ok.txt && git add -A && git commit -qm "unrelated"
assert_fail bash "$SWEEP" --range "$base..HEAD"

# 4. --allow suppresses a specific value that IS a pattern hit. Use a real
#    pattern match — an email would not work here, because emails are
#    deliberately not in PATTERNS (I18 accepts accounts.json's own-domain
#    address explicitly, so it is not something to scan for).
rm -f leak.txt && echo 'topic: rrp-cc-abc123' > acct.txt
git add -A && git commit -qm "value to be allow-listed"
assert_fail bash "$SWEEP" --worktree
assert_ok   bash "$SWEEP" --worktree --allow 'rrp-cc-abc123'
rm acct.txt

# 5. Each individual pattern class is detected — not just the first one.
for bad in 'ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
           'sk-ant-api03-xxxxxxxx' \
           '100.114.199.90' \
           '-----BEGIN OPENSSH PRIVATE KEY-----' \
           'https://hooks.slack.com/services/T0/B0/xxxx'; do
  rm -f acct.txt; printf '%s\n' "$bad" > probe.txt
  assert_fail bash "$SWEEP" --worktree
done
echo "sweep-secrets ok"
EOF
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `bash tests/sweep-secrets.test.sh`
Expected: FAIL — `scripts/sweep-secrets.sh` does not exist yet, so `assert_ok bash …` reports
`FAIL: expected success`.

- [ ] **Step 3: Write the scanner**

```bash
cat > scripts/sweep-secrets.sh <<'SWEEPEOF'
#!/usr/bin/env bash
# Sweep for credentials, tokens, and addressable endpoints.
#
# HC4: the remote is PUBLIC and .gitignore does not remove anything retroactively,
# while HC3 forbids the force-push that would. So this runs BEFORE content lands:
# before Task 0's merge (--range) and before the harness git add (--worktree).
#
# Deliberately NOT written in repo house style: no `|| true`, and a hit is a
# non-zero exit. D16 rejects house style for gates.
#
# Usage:
#   scripts/sweep-secrets.sh --worktree                 # tracked files at HEAD + staged + unstaged
#   scripts/sweep-secrets.sh --range origin/main..HEAD   # every blob introduced in a range
#   scripts/sweep-secrets.sh --worktree --allow 'regex'  # suppress an explicitly accepted value
set -uo pipefail

MODE="" RANGE="" ALLOW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --worktree) MODE=worktree; shift ;;
    --range) MODE=range; RANGE="${2:-}"; [[ -n "$RANGE" ]] || { echo "usage: --range <git-range>" >&2; exit 2; }; shift 2 ;;
    --allow) ALLOW="${2:-}"; [[ -n "$ALLOW" ]] || { echo "usage: --allow <regex>" >&2; exit 2; }; shift 2 ;;
    *) echo "usage: $0 [--worktree|--range <range>] [--allow <regex>]" >&2; exit 2 ;;
  esac
done
[[ -n "$MODE" ]] || { echo "usage: $0 [--worktree|--range <range>] [--allow <regex>]" >&2; exit 2; }

# Pattern classes. Keep each on its own line with a comment — this list is the
# security contract and is meant to be reviewed, not skimmed.
PATTERNS=(
  'ghp_[A-Za-z0-9]{16,}'                    # GitHub personal access token
  'gho_[A-Za-z0-9]{16,}'                    # GitHub OAuth token
  'github_pat_[A-Za-z0-9_]{20,}'            # GitHub fine-grained PAT
  'sk-ant-[A-Za-z0-9-]{8,}'                 # Anthropic API key
  'AKIA[0-9A-Z]{16}'                        # AWS access key id
  'BEGIN [A-Z ]*PRIVATE KEY'                # any PEM/OpenSSH private key
  'rrp-cc-[0-9a-f]{6,}'                     # CC_NTFY_TOPIC (HC5)
  '100\.114\.199\.[0-9]{1,3}'               # Tailscale host (HC5, R2)
  'hooks\.slack\.com/services/'             # Slack webhook
  'ntfy\.sh/[A-Za-z0-9_-]{8,}'              # ntfy topic URL
  'xoxb-[A-Za-z0-9-]{10,}'                  # Slack bot token
  '[Aa]uthorization: *[Bb]earer +[A-Za-z0-9._-]{12,}'  # hardcoded bearer
)
RE="$(IFS='|'; echo "${PATTERNS[*]}")"

hits=0
report() { # <label> <payload-on-stdin>
  local label="$1" line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ -n "$ALLOW" ]] && printf '%s' "$line" | grep -qE "$ALLOW"; then continue; fi
    echo "  !! $line"
    hits=$(( hits + 1 ))
  done
}

echo "== secret sweep ($MODE${RANGE:+ $RANGE}) =="
if [[ "$MODE" == "worktree" ]]; then
  # --untracked is load-bearing, not incidental. Verified semantics:
  #   * plain `git grep` searches TRACKED files only — it would miss a file that is
  #     about to be `git add`ed, which is precisely what this gate exists to catch.
  #   * `git grep --untracked` finds untracked files AND still honours .gitignore,
  #     so correctly-ignored machine state (credentials, transcripts) is skipped
  #     rather than being read and echoed into the log.
  # -I skips binary files.
  report worktree < <(git grep --untracked -nIE "$RE" -- . 2>/dev/null || true)
else
  # Per-commit ADDED LINES — not a two-dot diff of the endpoints, and not a
  # whole-tree grep per commit. Verified rationale for each rejected alternative:
  #   * `git diff -U0 A..B` compares endpoints, so it MISSES a secret that was
  #     added and then removed inside the range — yet the merge still carries that
  #     blob in history forever, which is exactly the case HC4 guards.
  #   * `git grep <sha>` greps each commit's entire tree, so any pre-existing value
  #     in the base is re-reported once per commit and fails the gate spuriously.
  # Iterating commits and grepping only added lines catches every introduced blob
  # while staying quiet about content that was already there.
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    # Two greps: '^\+' narrows to added lines, then "$RE" narrows to matches.
    # Prefix each hit with the commit so a failure is actionable.
    report "$sha" < <(git show --format= --unified=0 "$sha" 2>/dev/null \
      | grep -E '^\+' \
      | grep -E "$RE" \
      | sed "s#^#${sha:0:9}: #" || true)
  done < <(git rev-list "$RANGE" 2>/dev/null || true)
fi

if [[ $hits -gt 0 ]]; then
  echo "SWEEP FAILED: $hits hit(s). Do not merge or stage this content."
  exit 1
fi
echo "sweep clean"
SWEEPEOF
chmod +x scripts/sweep-secrets.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/sweep-secrets.test.sh`
Expected: `sweep-secrets ok`, exit 0. If case 5 fails for one specific pattern, that pattern's regex is
wrong — fix the regex, not the test.

> **This script was prototyped and all 14 scenarios verified before the plan was written**, including
> every pattern class individually. Three bugs were found and corrected in the version above, so do not
> "simplify" them back:
> 1. Plain `git grep` searches **tracked files only** — it missed the untracked leak in case 2, which is
>    the exact content this gate exists to catch. `--untracked` is required, and it still honours
>    `.gitignore` (case 2b).
> 2. A two-dot `git diff A..B` in range mode **misses a secret added then removed inside the range**
>    (case 3b) — yet the merge carries that blob in history forever.
> 3. `grep '^\+'` alone passes *every* added line; the `"$RE"` filter must be piped after it.

- [ ] **Step 5: Add the Makefile target**

Add `sweep-secrets` to `.PHONY`, then:

```make
sweep-secrets:
	bash scripts/sweep-secrets.sh --worktree
```

- [ ] **Step 6: Run the full suite**

Run: `make test`
Expected: both test files PASS, exit 0.

- [ ] **Step 7: Commit**

```bash
git add scripts/sweep-secrets.sh tests/sweep-secrets.test.sh Makefile
git commit -m "feat(scripts): add sweep-secrets.sh with tests

Scripts the HC4 gate rather than trusting a typed grep (D16). Used in
unit 1 with --range to sweep the 9 incoming commits before the merge,
and in unit 2 with --worktree before the harness git add."
```

---

## Task 3: Sweep the 9 incoming commits, then merge the fork

The merge itself. §4.15 orders the sweep first; §4.17 supplies the conflict guidance.

**Files:** none created or modified — this task produces a merge commit.

**Interfaces:**
- Consumes: `scripts/sweep-secrets.sh` from Task 2.
- Produces: a merged `feat/harness-linux-migration` containing all 12 commits, and the new
  `stow/gnupg/` package in the tree.

- [ ] **Step 1: Fetch and confirm the pre-merge state matches the plan**

```bash
git fetch origin
git rev-list --left-right --count main...origin/main
```

Expected: exactly `3	9`. **If the counts differ, stop** — another machine has pushed since planning and
the sweep scope below is no longer the right set.

- [ ] **Step 2: Sweep the incoming commits — before merging them**

```bash
bash scripts/sweep-secrets.sh --range "main..origin/main"
```

Expected: `sweep clean`, exit 0.

**If it reports a hit, stop and do not merge.** HC4 makes this one-way: the remote is public,
`.gitignore` does not remove anything retroactively, and HC3 forbids the force-push that would.

- [ ] **Step 3: Record the expected ancestry set for SC1 before the merge changes anything**

```bash
git rev-list main..origin/main  > /tmp/unit1-remote-only.txt   # expect 9 lines
git rev-list origin/main..main  > /tmp/unit1-local-only.txt    # expect 3 lines
wc -l /tmp/unit1-remote-only.txt /tmp/unit1-local-only.txt
```

Expected: `9` and `3`.

- [ ] **Step 4: Merge — `merge`, never `rebase` (HC2)**

```bash
git merge origin/main
```

Expected: either a clean merge commit, or textual conflicts confined to
`stow/zsh/.zshrc`, `stow/mise/.config/mise/config.toml`, `stow/nvim/**`, or
`stow/zellij/.config/zellij/layouts/web.kdl`.

**Conflict resolution rule (§4.17, verbatim):** *"if the merge produces textual conflicts in
`zsh`/`env`/`nvim`, keep **both** sides' content pending unit 3.5's re-diff rather than dropping
either — SC1's ancestry check protects commits, not content."* So resolve by **union**, not by choosing
a side. Do not attempt to reconcile the content here; that is unit 3.5's job and §4.9 requires an
explicit re-diff for exactly these files.

- [ ] **Step 5: Verify SC1 mechanically — every commit from both sides is an ancestor**

Brief SC1 requires `git merge-base --is-ancestor`, not "`git log` looks right".

```bash
fail=0
while read -r c; do
  git merge-base --is-ancestor "$c" HEAD || { echo "LOST: $c"; fail=1; }
done < /tmp/unit1-remote-only.txt
while read -r c; do
  git merge-base --is-ancestor "$c" HEAD || { echo "LOST: $c"; fail=1; }
done < /tmp/unit1-local-only.txt
echo "ancestry check fail=$fail"
```

Expected: `ancestry check fail=0` with no `LOST:` lines. **A non-zero result means a commit was dropped
— stop and investigate; do not proceed.**

- [ ] **Step 6: Confirm the 9th stow package arrived (§4.19)**

```bash
ls stow/
ls -la stow/gnupg/
```

Expected: 9 package directories including `gnupg`, and `stow/gnupg/gpg-agent.conf` present **at the
package root** — the mis-placement Task 5 fixes.

- [ ] **Step 7: Sweep the merged worktree, then push**

```bash
bash scripts/sweep-secrets.sh --worktree
git push origin feat/harness-linux-migration
```

Expected: `sweep clean`, then a successful push. No force flag, ever (HC3).

---

## Task 4: Repoint the signing key and canonical identity

`stow/git/.gitconfig` declares `signingkey = 665F3EDCE9AB996D`, which is **not in the keyring**, with
`commit.gpgsign = true` and `tag.gpgSign = true`. `stow-all.sh` stows every package on every run, so
this must be correct *before* unit 3.5 stows `git` (HC12) — otherwise every commit and tag on the
machine fails, including this project's own.

**Files:**
- Modify: `stow/git/.gitconfig` (30 lines)
- Create: `tests/gitconfig.test.sh`

**Interfaces:**
- Consumes: `tests/assert.sh` from Task 1.
- Produces: a `.gitconfig` whose `user.email` matches the signing key's uid — which is what makes GitHub
  show "Verified".

- [ ] **Step 1: Confirm the keyring state still matches the decision**

```bash
gpg --list-secret-keys --keyid-format LONG
gpg --list-secret-keys --with-colons 6C32D9329BDB7DA9 | grep '^sec'
```

Expected: `6C32D9329BDB7DA9` present, `rsa3072`, capability field containing `sSC`/`scESC`, **empty
expiry field**. `665F3EDCE9AB996D` absent. If `6C32D9329BDB7DA9` is missing, stop — the whole decision
rests on it.

- [ ] **Step 2: Write the failing test**

```bash
cat > tests/gitconfig.test.sh <<'EOF'
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
EOF
```

- [ ] **Step 3: Run it to verify it fails**

Run: `bash tests/gitconfig.test.sh`
Expected: `FAIL: user.email is the gmail identity: got [keenanjj13@protonmail.com] want
[keenanjj13@gmail.com]`.

- [ ] **Step 4: Apply the line-merge**

Edit `stow/git/.gitconfig`. Change the `[user]` block:

```gitconfig
[user]
	name = Keenan Johns
	email = keenanjj13@gmail.com
	signingkey = 6C32D9329BDB7DA9
```

Then append the credential helper adopted from live `~/.gitconfig` (the repo version has none; live has
it for both hosts). Note the leading empty value — it clears any inherited helper before setting ours,
which is how the live config is written:

```gitconfig
[credential "https://github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential

[credential "https://gist.github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential
```

Leave every other block as-is: `gpg.program`, `core.{editor,excludesfile,autocrlf}`, `pull.rebase`,
`init.defaultBranch = main`, `merge.tool`, `diff.tool`. There is a stray trailing-whitespace line after
`autocrlf = input` — leave it; touching it adds diff noise for no gain.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/gitconfig.test.sh`
Expected: `gitconfig ok`, exit 0.

- [ ] **Step 6: Confirm the GPG public key is registered on GitHub**

This is an **open task, not an assumption** (brief, Decisions Recorded). The planning session's token
lacked the scope.

```bash
gh auth refresh -h github.com -s admin:gpg_key
gh api user/gpg_keys --jq '.[].key_id'
```

Expected: a list containing `6C32D9329BDB7DA9`.

**If it is absent, upload it before continuing** — otherwise commits sign locally but show "Unverified":

```bash
gpg --armor --export 6C32D9329BDB7DA9 > /tmp/gpg-pub.asc
gh gpg-key add /tmp/gpg-pub.asc
gh api user/gpg_keys --jq '.[].key_id'   # re-verify
rm /tmp/gpg-pub.asc
```

- [ ] **Step 7: Commit**

```bash
git add stow/git/.gitconfig tests/gitconfig.test.sh
git commit -m "fix(git): repoint signingkey to the key that exists; canonical identity

signingkey was 665F3EDCE9AB996D, which is absent from the keyring, with
commit.gpgsign and tag.gpgSign both true — so stowing this package would
have failed every commit and tag on the machine (HC12). Repointed to
6C32D9329BDB7DA9 (rsa3072, [SC], no expiry) whose uid is the gmail
address, so user.email matches the signing key and GitHub reports
Verified. Adopts live's gh credential helper. Q1/Q2."
```

---

## Task 5: Make non-interactive signing actually work

**§4.19.** Task 4 pointed at a key that exists; it did not make signing *work*. Verified: `echo test |
gpg --local-user 6C32D9329BDB7DA9 --clearsign --batch` **times out**. `gpg-agent` runs socket-activated
under systemd, the key is passphrase-protected with nothing cached, and there is **no
`~/.gnupg/gpg-agent.conf`** — so no `pinentry-program` and no cache TTL. With `commit.gpgsign = true`
now landing, every non-interactive commit **hangs** rather than failing cleanly. SC9 depends on this.

The incoming `b2e95f8` carries the fix — but at the wrong path, so merging it changed nothing.

**Files:**
- Move: `stow/gnupg/gpg-agent.conf` → `stow/gnupg/.gnupg/gpg-agent.conf`
- Create: `tests/stow-layout.test.sh`

**Interfaces:**
- Consumes: `tests/assert.sh` from Task 1; the merged `stow/gnupg/` from Task 3.
- Produces: a `gnupg` package that stows to `~/.gnupg/gpg-agent.conf`. Unit 3 adds `pinentry-curses`
  and `gnupg` to `apt-common.txt`; unit 3.5 adds `gnupg` to the never-`--adopt` list; unit 4 extends
  `chmod 700` to `~/.gnupg`.

- [ ] **Step 1: Reproduce the failure, so the fix is verified against a known-bad baseline**

```bash
echo test | timeout 15 gpg --local-user 6C32D9329BDB7DA9 --clearsign --batch --yes -o /dev/null; echo "rc=$?"
```

Expected: a timeout — `rc=124`, or `gpg: signing failed: Timeout`. **This failing baseline is the point
of the task.** If it unexpectedly succeeds, the passphrase is cached in the current agent session; clear
it with `gpgconf --reload gpg-agent` and retry so you are testing the cold path a script or hook sees.

- [ ] **Step 2: Write the failing test**

Every stow package must mirror `$HOME`. A file at a package *root* links to `~/<file>` — which is how
`gpg-agent.conf` ended up destined for `~/gpg-agent.conf`. This test generalises the rule so no future
package repeats it.

```bash
cat > tests/stow-layout.test.sh <<'EOF'
#!/usr/bin/env bash
# Every stow package mirrors $HOME. A dotfile sitting at a package root would be
# linked to ~/<name> instead of its real location — how stow/gnupg/gpg-agent.conf
# was destined for ~/gpg-agent.conf rather than ~/.gnupg/gpg-agent.conf (§4.19).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/assert.sh"

# gnupg specifically: the config must be under .gnupg/.
assert_file "$ROOT/stow/gnupg/.gnupg/gpg-agent.conf"
assert_fail test -e "$ROOT/stow/gnupg/gpg-agent.conf"

# General rule: no package may contain a top-level *file* that is not a dotfile
# destined for $HOME. Every real payload belongs under a dot-directory or is a
# dotfile itself. Flag anything else as a probable mis-layout.
bad=""
for pkg in "$ROOT"/stow/*/; do
  [ -d "$pkg" ] || continue
  case "$(basename "$pkg")" in hosts) continue ;; esac
  while IFS= read -r f; do
    case "$(basename "$f")" in
      .*) ;;                       # ~/.zshrc, ~/.gitconfig, ~/.tmux.conf — correct
      *) bad="$bad $f" ;;          # non-dotfile at package root — suspicious
    esac
  done < <(find "$pkg" -maxdepth 1 -type f)
done
assert_eq "$bad" "" "no non-dotfile at any stow package root"
echo "stow-layout ok"
EOF
```

- [ ] **Step 3: Run it to verify it fails**

Run: `bash tests/stow-layout.test.sh`
Expected: `FAIL: expected file: …/stow/gnupg/.gnupg/gpg-agent.conf`.

- [ ] **Step 4: Relocate the file with `git mv` so the move is recorded as a move**

```bash
mkdir -p stow/gnupg/.gnupg
git mv stow/gnupg/gpg-agent.conf stow/gnupg/.gnupg/gpg-agent.conf
cat stow/gnupg/.gnupg/gpg-agent.conf
```

Expected contents, unchanged from `b2e95f8`:

```
default-cache-ttl 86400
max-cache-ttl 31536000
pinentry-program /usr/bin/pinentry-curses
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/stow-layout.test.sh`
Expected: `stow-layout ok`, exit 0.

- [ ] **Step 6: Prove the config actually fixes signing**

Do **not** stow the package yet — `stow-all.sh` still lacks unit 4's `--no-folding` handling and
unit 3.5 owns package reconciliation. Verify by installing the config directly, which is what stowing
will later produce:

```bash
cp stow/gnupg/.gnupg/gpg-agent.conf ~/.gnupg/gpg-agent.conf
chmod 600 ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent && gpgconf --launch gpg-agent
export GPG_TTY=$(tty)
echo test | gpg --local-user 6C32D9329BDB7DA9 --clearsign --yes -o /dev/null && echo "SIGNING OK"
```

Expected: a pinentry passphrase prompt appears (this step is interactive **by design** — it is the one
place a human must type the passphrase), then `SIGNING OK`.

Then confirm the cache makes the *non-interactive* path work, which is the actual goal:

```bash
echo test | timeout 15 gpg --local-user 6C32D9329BDB7DA9 --clearsign --batch --yes -o /dev/null && echo "NON-INTERACTIVE SIGNING OK"
```

Expected: `NON-INTERACTIVE SIGNING OK` — no timeout. `default-cache-ttl 86400` is what makes this hold
for 24h after one unlock.

- [ ] **Step 7: Prove a signed commit and a signed tag both succeed (SC9, on the host)**

§4.17 scopes the container's SC9 to a disposable key; the *real* key is verified once here.

```bash
git commit --allow-empty -S -m "probe: signed commit works"
git log --show-signature -1 | head -5
git tag -s probe-signing -m "probe: signed tag works"
git tag -v probe-signing 2>&1 | head -5
```

Expected: `gpg: Good signature from "Keenan Johns (Github Account) <keenanjj13@gmail.com>"` for both.

Clean up the probes — the empty commit and local tag are not wanted on the branch:

```bash
git tag -d probe-signing
git reset --soft HEAD~1
```

> `git reset --soft` only moves the branch pointer and keeps every file; it is not the `--hard` that
> HC3 forbids.

- [ ] **Step 8: Commit**

```bash
git add stow/gnupg/.gnupg/gpg-agent.conf tests/stow-layout.test.sh
git commit -m "fix(gnupg): move gpg-agent.conf under .gnupg/ so stow links it correctly

Incoming b2e95f8 put gpg-agent.conf at the package root, so stow would
have linked it to ~/gpg-agent.conf and gpg-agent would never have read
it. Without it, signing HANGS non-interactively: the key is
passphrase-protected, nothing is cached, and there is no
pinentry-program — verified by a timing-out gpg --clearsign --batch.
With commit.gpgsign now true (Task 4) that would hang every scripted
commit. Adds a general stow-layout test so no package repeats this. §4.19"
```

- [ ] **Step 9: Push and close the unit**

```bash
make test
bash scripts/sweep-secrets.sh --worktree
git push origin feat/harness-linux-migration
```

Expected: all tests PASS, `sweep clean`, push succeeds.

---

## Unit 1 Exit Criteria

| Criterion | Check |
|---|---|
| SC1 — no commit lost | `git merge-base --is-ancestor` over all 12 recorded commits, `fail=0` (Task 3 Step 5) |
| HC2 — merge not rebase | `git log --merges -1` shows the merge commit; no rebase performed |
| HC4 — nothing sensitive merged | `sweep-secrets.sh --range main..origin/main` clean **before** the merge |
| HC12 — commit capability survives | signed commit **and** signed tag succeed (Task 5 Step 7) |
| Q1/Q2 recorded in the tree | `make test` passes `gitconfig.test.sh` |
| §4.19 — non-interactive signing | `gpg --clearsign --batch` succeeds without timeout (Task 5 Step 6) |
| 9th package surfaced | `stow/gnupg/.gnupg/gpg-agent.conf` exists; `stow/gnupg/gpg-agent.conf` does not |

**Deliberately NOT in this unit** — do not let a subagent drift into these:
- Stowing anything. `stow-all.sh` lacks unit 4's `--no-folding` and `PLATFORM` work; unit 3.5 owns
  package reconciliation.
- Reconciling `zsh` / `mise` / `nvim` / `zellij` content from the merge. §4.9 requires an explicit
  post-merge re-diff, which is unit 3.5's entry condition. Conflicts here are resolved by **union**.
- Adding `pinentry-curses`, `gnupg`, or `lsb-release` to the package lists — unit 3 owns `packages/`.
- Touching `.gitignore` — unit 2 owns it, and C6 requires it land in its own verified commit.

## Handoff to Unit 2

Unit 2 (`.gitignore` harness-state gate + secret sweep + the `settings.json` `${VAR}` decision) depends
on Task 1's harness and Task 2's `sweep-secrets.sh`, and on nothing else from this unit. It is
merge-independent, so it can be planned and executed as soon as Unit 1 lands.

Units 3, 3.5, 4, and 5 **cannot be planned accurately until this unit's merge lands** — §4.9 requires an
explicit post-merge re-diff of `zsh`/`env`/`nvim` against the planned overlays, and the merge changes
`mise/config.toml`, `.zshrc`, `zellij/web.kdl`, and `nvim/**`, which are precisely the files those units
rewrite. Plan them against the merged tree, not against this one.
