# Adversarial Review — Dotfiles Harness Ownership + Native-Linux Provisioning

**Design doc:** `docs/plans/2026-07-29-harness-linux-migration/design.md`
**Brief:** `docs/plans/2026-07-29-harness-linux-migration/brief.md`
**Facts digest:** `docs/plans/2026-07-29-harness-linux-migration/codebase-facts.md`
**Review date:** 2026-07-29 · **Round:** 1
**Verdict:** **BLOCKED** — 10 Critical findings

**Method:** the orchestrator pre-verified ground truth inline into `codebase-facts.md`, then dispatched
three read-only `critic` agents (security / architecture / completeness) with no codebase access. All
three cited design sections and decision IDs; none rubber-stamped, so no Step-2b follow-ups were
needed. Two critic-flagged "unverified" items were resolved by the orchestrator after the critics
returned (see *Resolved during review*).

**Honest limitation:** all three critics and this synthesis are Claude. This is structured
self-review — diversity of framing, not of training.

---

## Headline

The **architecture is sound and survives scrutiny.** No critic attacked the three-layer decomposition,
D2 (keep `cc-account-switcher` separate), D3 (no second subtree), D4 (per-package reconciliation),
D11 (archive before delete), or D12 (`routes` is machine-local). Approach A's *choice* stands.

What does not survive is the **specification**. Ten items are load-bearing and unspecified, and they
cluster into three groups:

1. **Approach A's central mechanism is asserted, not established** (C1) — and its two acceptance
   tests are vacuous as written (C2, C5).
2. **Three of the seven open questions are now resolved *against* the design** (C3 GPG, C4 nvim,
   C10 superpowers) — they are no longer risks to monitor, they are defects to fix.
3. **Two irreversible operations have no verification gate** (C6 credentials into public history,
   C7 archive-then-delete), on a repo whose house style is `|| true`.

Fix cost is mostly low: **8 of the 10 are one-paragraph additions to the design**, not redesigns.
C1 and C10 need a real decision.

---

## Critical Findings (must fix before implementation starts)

`REVISE-DESIGN` = update `design.md`, re-run review. `LOOP-TO-BRIEF` = the requirement exists in
`design.md` but was stripped when `brief.md` was distilled from it — restore it in the brief first.

| # | Finding | Critics | Cost to Fix | Cost to Skip | Path |
|---|---------|---------|-------------|--------------|------|
| **C1** | **`stow`'s tree-folding does the opposite of what Approach A claims on a fresh box.** The justification for A (§2 + "Approaches considered" A) is that folding links each entry *individually*, so versioned content is linked while `plugins/cache/`, `handoffs/`, `.bak` files stay untouched real state — "stow solves it for free". Folding only descends when the target directory **already exists as a real directory**. On a fresh box `~/.claude-shared` does not exist, so `stow` creates **one symlink for the whole tree** → every subsequent runtime write (`plugins/cache/`, `installed_plugins.json`, `handoffs/`) lands **inside the dotfiles git working tree**. This machine converges to the fresh case too, because HC7 moves live `~/.claude-shared` to `.migration_backups/` before restowing. `stow-all.sh` passes no `--no-folding`. | Arch (Crit), Comp (Imp/Crit) | Low — one design paragraph: either `mkdir -p` the real dirs that must exist before stowing `claude`, or pin `--no-folding` for that package, and have `verify-fresh` assert it on a container with no pre-existing `~/.claude-shared` | The gitignored-state boundary — "the whole problem", per the design's own words — silently inverts on the machine this project exists to provision. Runtime state pollutes the repo | `REVISE-DESIGN` |
| **C2** | **`make doctor` can never fail, so SC2 and `verify-fresh` are unfalsifiable.** Every check is `command -v … \|\| echo "MISSING: …"`; nothing propagates an exit code; the final `doctor done (no output = all present)` prints unconditionally. Observed live: `MISSING: eza` **and** `doctor done (no output = all present)` in the same run, `$?`=0. Combined with `bootstrap.sh`'s pervasive `\|\| true`, a container run can install almost nothing and still report clean. Files-Touched row 27 only says "extend `doctor`" (add checks) — it never addresses exit semantics. | Arch (Crit), Comp (Crit) | Low — make `doctor` exit non-zero on any `MISSING`, or have `verify-fresh` `grep -q MISSING` and fail the run. Pick one in the design | D9's "repeatable regression test" and SC2 both pass vacuously. The single mechanism meant to catch WSL assumptions, missing apt repos, `chsh`, and stow conflicts catches nothing | `REVISE-DESIGN` |
| **C3** | **Q2 is resolved unfavourably: the declared GPG signing key does not exist.** `stow/git/.gitconfig` sets `signingkey = 665F3EDCE9AB996D` with `commit.gpgsign=true` **and** `tag.gpgSign=true`. The only secret key in the keyring is `6C32D9329BDB7DA9` (rsa3072, gmail uid). `stow-all.sh` stows **every** `stow/*` package on every run, so the moment `git` is stowed, every `git commit` and `git tag` on this machine fails — including the migration's own commits. The design still phrases this as a risk to "confirm". | Sec (Imp), Arch (Crit), Comp (Crit) | Low, but needs a **decision** (see Decisions Required) — then one design line and a task ordered before anything else commits | Self-inflicted mid-migration deadlock; the likely field fix is silently disabling signing, dropping commit authenticity repo-wide with no record | `REVISE-DESIGN` |
| **C4** | **Q6 is resolved unfavourably: `~/.config/nvim` has uncommitted work, and the brief dropped the warning.** `git status --short` shows ≥8 modified files (`lazy-lock.json`, `lua/community.lua`, `lua/consts/language_packs.lua`, `lua/plugins/{astrocore,astrolsp,autocmds,blink,init}.lua`). The design's `nvim` row says "commit and push the 17 diverged files, then `nvim-subtree.sh pull`" — conflating committed branch divergence with an uncommitted working tree. Design Q6 explicitly warns "a pull could otherwise overwrite it"; **`brief.md` carries no equivalent** — HC3 protects the 2022 clone's history but nothing protects this. | Arch (Imp), Comp (Crit) | Low — restore a Hard Constraint parallel to HC3, plus an explicit commit-and-verify sub-step before any subtree op | Unrecoverable loss of real nvim config work. The one class of damage the brief's recoverability rules exist to prevent, in the one place they were not applied | `LOOP-TO-BRIEF` |
| **C5** | **Neither `env.sh` nor `routes` will exist on a fresh clone, so `stow` links nothing and R2's mitigation never materializes.** D12 + §2 move both to gitignored-real + committed-`.example`. `stow` only links what is physically in the package dir, and **no copy-from-`.example` step exists** in `bootstrap.sh`, `stow-all.sh`, or the `Makefile`. So on a new box (and inside `verify-fresh`) there is no `env.sh` — meaning `CC_NTFY_TOPIC` and the Tailscale host, which R2 says are "templated into" it, are simply absent, and the startup hook that has never run still never runs. | Arch (Crit), Comp (stripping: DANGEROUS) | Low — one `install-env.sh` (or `bootstrap.sh` step) that copies `*.example` → real file only when absent, ordered **before** `stow-all.sh` | Fresh-box provisioning — the entire point of the project — is broken for two packages, and `verify-fresh` will not notice because of C2 | `REVISE-DESIGN` |
| **C6** | **No gate forces the harness-state `.gitignore` rules to land and be verified *before* the first `git add` of the harness.** The `.gitignore` Files-Touched row states no ordering relative to the `stow/claude/**` create row. The never-versioned list is large (`.credentials.json`, `.claude.json`, `history.jsonl`, `projects/`, `sessions/`, `todos/`, `shell-snapshots/`, `stats/`, `debug/`) and the remote is **public**. One mistimed `git add -A` is permanent — `.gitignore` does not retroactively remove anything from history, and HC3 forbids the force-push that would. | Sec (Crit) | Low — commit the `.gitignore` additions as their own commit; `git status`-verify no never-versioned path is stageable; only then `git add` the package | Live Anthropic credentials and full session transcripts in public git history, unremovable without violating HC3 | `REVISE-DESIGN` |
| **C7** | **Archive-then-delete of the 2022 clone has no verification step between push and `rm`.** §3 says push `archive/2022-pre-rewrite` "first … *then* remove the clone" — no assertion that the push landed. `~/github/dotfiles` (HEAD `e4a76dc`, root `327614fb`) is the sole surviving copy of that lineage. The repo's house style is `\|\| true` everywhere, `doctor` always exits 0, and `audit.sh` deliberately drops `-e`. | Sec (Crit) | Trivial — `git ls-remote origin archive/2022-pre-rewrite` must return the expected SHA (or `merge-base --is-ancestor` after a fetch), and the removal must abort — **not** `\|\| true` — on mismatch | Permanent, unrecoverable loss of history that exists nowhere else. The one truly irreversible step in the plan currently has the repo's weakest error handling | `REVISE-DESIGN` |
| **C8** | **`CC_NTFY_TOPIC` stays committed in cleartext, because the file it lives in is versioned wholesale.** §2 says the topic is "templated into `stow/env/.config/dotfiles/env.sh`" — but the literal is at `~/.claude-shared/settings.json:3`, and `settings.json` is in §2's **Versioned** list, committed as-is. The design never states a mechanism to remove or interpolate it out of the JSON. Directly violates **HC5** ("no addressable endpoints committed") and defeats R2. | Sec (Crit) | Low — either strip the literal and inject at runtime from `env.sh`, or confirm the settings `env` block supports `${VAR}` interpolation and use it. State which | Anyone reading the public repo can push notifications to the user's phone, indefinitely and unremovably | `REVISE-DESIGN` |
| **C9** | **SC6 ("no absolute `/home/keenan` path in any tracked file") has no mechanism and is currently false for the files the design versions.** Verified counts: `settings.json` **6** (incl. `Read(//home/keenan/**)`, `Edit(//home/keenan/.claude/**)`, and `/home/keenan/github` in `additionalDirectories`), **4 of 16 hooks** (`continuous-learning.sh`, `session-stats.sh`, `wip-snapshot.sh`, `context-pressure.sh`), **3 skills**, **1** `local-marketplace` file. D6 gitignores only machine-state JSON and never addresses paths *inside* versioned content. Note the direction: the **brief hardened** this beyond the design (the design scoped portability to the state files) — but the underlying need is real, since those hooks and permission rules genuinely break under a different `$HOME`. `shell-integration.sh` already shows the right pattern (`"${CCA_HOME:-$HOME}"`). | Sec (Imp+Min), Arch (Crit), Comp (Crit) | Medium — a substitution/templating mechanism for versioned harness files, plus a decision on whether SC6 stays absolute or is scoped precisely | SC6 fails on first audit; worse, the harness is not actually portable — which is the project's premise | `REVISE-DESIGN` (+ tighten SC6 wording in the brief) |
| **C10** | **D7 propagates the Q4 duplicate rather than restoring sharing, and the brief's Q4 non-goal forbids exactly that.** `rrp` enables `superpowers@superpowers-marketplace`; shared/`kjweb` enables `superpowers@claude-plugins-official`. Collapsing `rrp/settings.json` into shared (D7, mandated by SC5) therefore leaves **both** superpowers sources enabled for **both** profiles — creating the duplicate-skill-source condition on `kjweb`, which today has none. The brief lists resolving Q4 as a **Non-Goal** ("flagged for a decision, not fixed here") and lists "any harness skill/hook behaviour" change as a non-goal with only the `local-marketplace` relocation carved out. So SC5 can pass while contradicting two non-goals. | Comp (Crit) | Low, but needs a **decision** — de-duplicate during the D7 merge, or carve out a second explicit non-goal exception and accept the propagation | A silent skill-source regression on `kjweb`, introduced by the change meant to fix cross-profile parity | `REVISE-DESIGN` |

---

## Important Findings (address before PR)

| # | Finding | Critics | Cost to Fix | Cost to Skip | Decision |
|---|---------|---------|-------------|--------------|----------|
| I1 | **`scripts/audit.sh` is absent from the Files-Touched table**, yet SC3 depends on it and row 1 **deletes** `packages/apt.txt`. `audit.sh` reads a single `APT_LIST="$DOTFILES_ROOT/packages/apt.txt"`; after the split it errors or reports every installed package as untracked. | Arch | Low | SC3 breaks the moment row 1 lands | Add the row: union the three lists filtered by `$PLATFORM` |
| I2 | **SC3 covers 2 of `audit.sh`'s 4 report classes** (it omits apt-declared-but-not-installed and mise-installed-but-not-declared) — and the omitted two are exactly where the real drift is: `bottom` is declared in `apt.txt` **and** absent from PATH. | Comp | Low | "audit clean" means less than it sounds | Require all four classes clean |
| I3 | **The mise resolution is binary but reality is three-way.** `bottom` declared in both `apt.txt` and mise; `zellij` declared in mise but installed at `~/.cargo/bin/zellij`; `eza` declared in mise and checked by `doctor` while only the predecessor `exa` exists (also cargo); `just` declared and absent. "Install it or delete it" has no answer for cargo-direct installs, and mise shims vs `~/.cargo/bin` is the same PATH-precedence bug class D10 fixes one layer up. | Arch, Comp | Medium | `audit`/`doctor` keep disagreeing; the drift D10 removes reappears | Add a tool-ownership policy (which manager owns which category) + clean up orphaned cargo binaries |
| I4 | **`stow-all.sh` needs net-new logic, not a swap, and risks two WSL detectors.** It currently keys overlays off `hostname` + its **own** inline `grep -qi microsoft /proc/version` (independent of `detect-os.sh`'s identical grep), applies the hostname overlay unconditionally, and has **no `linux` branch at all**. Files-Touched row 26 ("Overlay `hosts/` by `PLATFORM`") undersells this and doesn't commit to removing the inline grep. | Arch, Comp | Medium | Two independently-maintained WSL detectors — precisely the implicit branching D5/Layer 3 exists to kill | Have `stow-all.sh` source `detect-os.sh` and branch only on `$PLATFORM` |
| I5 | **D8 must repoint two files, not one, and neither is hand-editable.** *(orchestrator-verified after critic return)* `known_marketplaces.json` holds the `local` source path; `installed_plugins.json:85,93` holds `installPath: /home/keenan/.claude/plugins/cache/local/workflow-navigator/1.0.0`. **Both** route through `~/.claude`, and **both** are in D6's gitignored/regenerated set — so D8 has to be effected by the `install-claude-plugins.sh` replay, not by editing a file. The design also never says to remove the old `~/.claude-accounts/rrp/local-marketplace/`. | Arch (+orch) | Low | A stale duplicate marketplace, and D8 half-applied | State that D8 is realized by the replay; add explicit removal of the old dir |
| I6 | **`keybindings.json` falls in the gap the design was built to close.** It is in cca's `SHARED_ITEMS`, `~/.claude-accounts/rrp/keybindings.json` points at it, and `~/.claude-shared/keybindings.json` **does not exist** — an already-dangling shared symlink. It appears in neither §2's Versioned nor Gitignored list. `cca-lib.sh`'s own comment warns that entries in neither list are invisible to `init`/`ensure_shell`/`doctor` — this reproduces that exact bug class inside the new package. | Arch, Sec, Comp | Trivial | The "repo owns the full harness" claim (Requirement 1) is false, and the failure stays silent | Classify it explicitly — versioned (even as a default) or documented out-of-scope |
| I7 | **New third-party apt-repo installers have no stated trust requirements.** `install-gh.sh` / `install-docker.sh` add repos and GPG keys; the design says nothing about pinned fingerprints or `signed-by` keyring files vs deprecated `apt-key add`. The retained `curl -fsSL https://starship.rs/install.sh \| bash` in `bootstrap.sh` sets the wrong precedent. | Sec | Low | Unpinned third-party keys on every fresh provision | Require pinned fingerprints + `signed-by`; note starship as inherited, unaddressed |
| I8 | **`install-docker.sh` grants root-equivalent access via the `docker` group** (bind-mount the host fs as root) and the design never names the trade-off — while SC7 demands the README "describe only things that exist". | Sec | Trivial | An undocumented privilege-escalation surface added by a provisioning script | Document explicitly as an accepted trade-off |
| I9 | **`.migration_backups/` is the only safety net for up to 9 package migrations, and it is gitignored — machine-local, never pushed, with no retention policy or integrity check.** | Sec | Low | HC7's rollback path is one `rm -rf` from gone | State when it may be deleted (after `verify-fresh` + explicit confirmation) and consider a one-time off-machine copy |
| I10 | **Vendoring `hooks/` turns `git pull` into "accept new auto-executing code."** Hooks run automatically on session events. A second machine is actively pushing to this repo (9 remote-only commits) and Q7 is unresolved; the one integrity mechanism that would help — commit signing — is confirmed non-functional (C3). | Sec | Low | Auto-run code changes arrive with no review gate | Note the requirement to review hook diffs before `restow`, at least until Q7 and C3 are resolved |
| I11 | **`install-cc-switcher.sh` clones an actively-developed repo unpinned**, so `verify-fresh` — framed by D9 as "a repeatable regression test" — is not reproducible, and the trust boundary moves with upstream `main`. Nothing in the brief verifies the switcher is installed at all. | Sec, Comp | Low | Non-reproducible verification; upstream changes silently alter provisioning | Pin to a tag/commit, bumped deliberately; add an SC that the switcher installs |
| I12 | **HC1's "WSL must keep working throughout" has no end condition, and Q7 has no owner.** The 9 remote-only commits are recent WSL-era work (`gpg-agent.conf`, zsh ssh-agent, `win32yank`, `WINUSR`) from another machine — suggesting WSL support may need to be indefinite rather than migration-scoped. | Comp | Trivial (needs a user answer) | HC1 is unfalsifiable; `win/` retention is unjustified either way | Resolve Q7, then state HC1's duration precisely |
| I13 | **`~/.ssh/config` is missing from SC4's list, and the `IdentityFile` correction is unverified by anything.** §3's `ssh` row says the repo template hardcodes `id_ed25519` while the newest key is `id_rsa` (Nov 2025) — "template needs correcting, not just installing". HC8 only forbids widening permissions. | Comp | Trivial | The one package whose row says "correcting" has no criterion that would notice | Add `~/.ssh/config` to SC4 + assert `IdentityFile` resolves to the intended key |
| I14 | **The hostname-keyed overlay `stow/hosts/$(hostname)/` is keyed to the *current* WSL box**, but the project's purpose is provisioning a *new* machine. If the target hostname differs, that overlay silently never applies; SC7 only checks that `stow/hosts/` "is real". | Comp | Low | A whole overlay layer quietly inert on the machine it was built for | State whether the target shares this hostname; if not, define what `@common`+`linux` must cover |
| I15 | **Post-Task-0, nothing re-diffs the merged content against the overlay design.** Four of the nine remote commits (`zsh` ssh-agent, `gpg-agent.conf`, nvim `win32yank`, `env` WINUSER→WINUSR) touch exactly the files Layer 2/3 then rewrites. The design notes they "land right in scope" but adds no reconciliation step, so the same WSL coupling gets merged in and then moved — or dropped. | Arch | Low | Merged WSL-era logic silently dropped or duplicated; conflicts resolved twice | Add an explicit post-merge re-diff of `zsh`/`env`/`nvim` against the planned overlays |
| I16 | **Q1 and Q3 have no resolution owner in the brief.** Q1 (canonical email; `defaultBranch` `master`→`main`) is called "a decision at implement time" with no decider named; Q3 (`zellij` needs a file-level diff, not yet run) has no owner, yet SC4 requires `~/.config/zellij` to resolve into the repo. | Comp | Trivial | An implementer silently picks the user's git identity; the zellij merge is improvised | Name owners; resolve Q1 before the `git` package lands (it gates C3 too) |
| I17 | **Sizing: five independent problem classes land as one undifferentiated unit** — (a) fork + 2022 archive, (b) per-package reconciliation incl. the commit-blocking GPG gap, (c) apt/mise/cargo consolidation, (d) `PLATFORM`+`hosts/`+`verify-fresh`, (e) 60-file harness vendoring with cross-profile settings/plugin work. With C1–C10 outstanding, one-shot landing risks a stuck mid-migration state. | Arch | Low (planning only) | A half-migrated machine with broken commits and no working verification | Stage as 4 landable units — see Recommended Sequencing |
| I18 | **`accounts.json` carries a personal email** (`keenan@kjweb.dev`) and is in the Versioned list; §2's endpoint review covered only `CC_NTFY_TOPIC` and the Tailscale IP. Low sensitivity (own domain; commit authorship already exposes an email), but it was never consciously accepted. | Sec | Trivial | Unreviewed PII in a public repo | Accept explicitly or template it |
| I19 | **The design's secret sweep covered exactly the two values it already knew about.** The orchestrator's independent grep then found `/home/keenan` in 4 hooks, 3 skills, and `settings.json` — none of which the design surfaced. That is a canary: **47 versioned files** (16 hooks + 17 skills + 10 commands + 4 agents) have not had a full secret/PII pass before being committed to a public remote. | Sec | Low | Unknown unknowns land in permanent public history | Run a dedicated sweep (tokens, webhook URLs, other IPs/hostnames) over all 47 files before the first commit |

---

## Minor Findings (noted, no gate)

| # | Finding | Critics |
|---|---------|---------|
| M1 | Files-Touched claims `.gitignore` is "Currently **empty**". It is 137 bytes and already contains `.worktrees/` and `.migration_backups/` — 2 of the 3 planned additions. Only the harness-state rules are new. | orch, Comp |
| M2 | R1 says "four private keys"; there are **three** (`id_ed25519`, `id_rsa`, `enduring-laptop`). The guardrail is unaffected. | Arch, Sec, Comp |
| M3 | A stray `~/.ssh/.id_ed25519.pub.swp` (0644, 12k, Jan 2022) sits in the directory being brought under stow for the first time. Housekeeping — and a reason no per-package `--adopt` should ever run on `ssh`. | Sec |
| M4 | D10 is partially stale: `asdf` is already **off** PATH (`command -v asdf` → not found); only the leftover `~/.asdf` directory remains. The PATH-ordering bug it cites is not currently live. | orch, Comp |
| M5 | The design says the remote "has only `main`". `git ls-remote --heads origin` now shows **two** heads — `main` and `feat/harness-linux-migration`. Does not affect D11 (still purely additive). | orch, Comp |
| M6 | The mise gap is **8** declared-but-uninstalled tools, not 7. | orch |
| M7 | `PLATFORM` is added as a third variable beside `OS`/`WSL` "for backward compatibility" without designating them derived aliases or enumerating the `bootstrap.sh` WSL-keyed call sites (`pwsh.exe` fonts, `wsl-post.sh`) that should convert. Low functional risk — one script computes all three — but it undercuts the "explicit over implicit" rationale. | Arch |
| M8 | `detect-os.sh` carries `set -euo pipefail` and is `source`d by `bootstrap.sh`, leaking those options into the caller. Pre-existing; worth not making worse as `PLATFORM` is added. | orch |
| M9 | Absolute `/home/keenan` paths in versioned files are also a (low) information-disclosure item — username + directory layout, permanent in public history. Primarily the portability issue C9. | Sec |

---

## Resolved during review (no action)

- **Two root commits in `~/.dotfiles` are benign.** The completeness critic flagged `136f68a`/`d3bb970`
  as possible evidence of a graft or shallow clone threatening Task 0 / SC1. Verified: `d3bb970`
  (2025-09-13, LICENSE only) is the real root; `136f68a` is
  `Squashed 'stow/nvim/.config/nvim/' content from commit 00b1f34` — the ordinary
  `git subtree add --squash` root. No `.git/shallow`, no `.git/info/grafts`, no replace refs.
  Task 0's plain `git merge origin/main` is unaffected.
- **Symlink-attack surface: not exploitable.** The `~/.claude` → `~/.claude-accounts/<profile>` →
  `~/.claude-shared/*` chain is entirely single-user-owned; no privilege boundary is crossed. D8 is a
  correctness fix, not a security fix. (Security critic reached this conclusion explicitly rather
  than manufacturing a finding.)
- **No web-app surface.** All three critics were asked about SQL injection, XSS, IDOR, rate limiting,
  DB indexes, DTOs, and handler sizing, and all three explicitly recorded them as inapplicable
  (`Schema Changes: None`, `Endpoints: None`) rather than padding. Noted so a later reader does not
  read their absence as an oversight.

---

## Strengths (what the design got right)

- **Approach A's *choice* is well-argued and survived all three critics.** Nobody proposed B or C.
  The C-rejection reasoning (the nvim subtree has already drifted 17 files, so don't add a second
  subtree) is evidence-based rather than aesthetic.
- **D4 (per-package reconciliation) is the standout call.** Every critic implicitly relied on it;
  neither wholesale `--adopt` nor wholesale overwrite would have surfaced the `.gitconfig` line-merge
  or the `ssh` template correction.
- **D11 + HC3 (archive before delete, never force-push) correctly identified the single irreversible
  operation** and got the ordering right. C7 is a missing assertion, not a wrong plan.
- **The brainstorming ground-truth pass was unusually thorough and largely accurate.** The 3/9 fork
  divergence, the 24 untracked-but-installed packages, the `rrp/settings.json`-breaks-sharing
  diagnosis, the `local-marketplace`-resolves-through-`~/.claude` root cause, and the
  documented-but-absent `stow/hosts/` all verified exactly as described.
- **D8's root-cause analysis is correct and non-obvious** — it correctly distinguished the two
  marketplaces that land in shared anyway (because `plugins` *is* a per-profile symlink) from `local`,
  the only one that actually breaks under `kjweb`.
- **Q1–Q7 and R1–R2 exist at all.** Three of them (Q1, Q2, Q6) turned out to be real defects rather
  than hypotheticals — the design flagged them before anyone looked. That is the risk register doing
  its job; C3 and C4 are about *closing* them, not about having missed them.
- **`routes` was correctly scoped down** from the initial Approach-A file list to a tracked
  `.example` only (D12) — the design caught its own over-reach mid-flight.

---

## Decisions Required (user)

These gate the design revision; nobody but the user can answer them.

1. **Q1 — canonical git identity.** `keenanjj13@gmail.com` (live, and the uid on the key that
   actually exists) or `keenanjj13@protonmail.com` (repo)? And `init.defaultBranch`: keep `master`
   (live) or move to `main` (repo)? — gates the `git` package and interacts with C3.
2. **C3 / Q2 — GPG direction.** Repoint `signingkey` to `6C32D9329BDB7DA9` (present, gmail uid) /
   import or regenerate `665F3EDCE9AB996D` / set `commit.gpgsign=false`.
3. **C10 / Q4 — superpowers duplication.** De-duplicate as part of D7, or carve out an explicit
   non-goal exception and accept both sources on both profiles?
4. **I12 / Q7 + I14 — WSL horizon and target hostname.** Is WSL support permanent (another machine
   still uses it) or only for the migration? Will the native-Linux box share this hostname?
5. **I17 — staging.** One PR, or four sequenced units?

## Recommended Sequencing (I17)

1. **Fork reconciliation + git identity + GPG** (Task 0, C3, I16, I15) — unblocks every later commit.
2. **`.gitignore` + secret/PII sweep** (C6, C8, I19, I18) — must precede any harness `git add`.
3. **Packages + tool ownership** (apt split, `audit.sh`, mise/cargo policy — I1, I2, I3).
4. **`PLATFORM` + `hosts/` + `verify-fresh` with a `doctor` that can fail** (C1, C2, C5, I4, M7).
5. **Harness vendoring** (C9, C10, I5, I6, I10, I11) — last, because it depends on 2 and 4.

---

---
---

# Round 2 — 2026-07-29

Fresh critics on design revision 2 / brief revision 2, given **no knowledge of round 1**, so an
inadequate fix would be re-found rather than assumed closed.

**Result: none of the 10 round-1 Criticals were re-raised by any critic.** Security explicitly recorded
C6, C7, and C8's mechanisms as sound; architecture recorded C2's `doctor` fix, C6's gate, and the
`apt.txt`/`audit.sh` closure as complete; completeness recorded HC10, and the SC2/SC3/SC6 rewrites, as
genuinely falsifiable. The revision held.

**One new Critical, found independently by two critics:**

| # | Finding | Critics | Path |
|---|---------|---------|------|
| **R2-C1** | **`verify-fresh`'s script inventory was never specified.** §4.2 fixed *whether* `doctor` can fail without ever saying *what `verify-fresh` runs*. Its only description (Section 3) predates units 4–5 and names none of the new installers — so SC5, SC9, SC10, SC11 rested on an implied mechanism. Worse, `install-claude-plugins.sh` and `claude-profile-init.sh` — which the design itself calls "the piece that makes a fresh box reproducible" — were exercised by nothing. Same vacuous-acceptance-test class as round-1 C2. | Arch, Comp | `REVISE-DESIGN` → closed by §4.12 |

**Round-2 Importants** (all folded into §4.13–§4.15 and the brief): sweep scope limited to
`stow/claude/**` when `tmux`/`ccz`/`ssh`/`mise`/`zsh` are also newly tracked; the 9 incoming commits
merged into a public branch without a sweep, in unit 1 *before* unit 2's gate exists; both irreversible
gates specified as prose rather than scripts; I10's hook gate stated as policy with nothing enforcing it;
installer ordering unstated; the tool-ownership rule not resolving its own `bottom` example; `audit.sh`'s
four classes structurally unable to see a cargo-direct install; the plugin manifest schema unable to
express project-scoped records; per-package reconciliation (including HC10's nvim precondition — the
highest-risk item) unassigned to any unit; unit 5 undivided; `keybindings.json` missing from the
Files-Touched enumeration; `.migration_backups/` restore path unnamed while
`scripts/merge-from-backup.sh` sat unreferenced in the repo; SC1 naming no checker.

**Resolved by the orchestrator after round 2** (three critic "unverified" flags, all checked directly):

- **`make restow` is broken and `make unlink` bypasses `stow-all.sh`.** `cat -A` confirms `restow:` is
  followed by a tab-indented recipe `unlink link`, so it runs `/usr/bin/unlink` against a file named
  `link` and fails. `make unlink` has its own `find stow … | xargs stow -D` loop that skips
  `stow-all.sh` *and* lacks its `-not -name hosts` filter, so it attempts `stow -D hosts`. Both
  pre-existing; both load-bearing for the review-then-restow workflow. → §4.14.
- **`cca doctor` cannot detect a dangling shared symlink**, and its unknown-item scan
  (`cca::untracked_items`) covers only the per-account directory, never `~/.claude-shared`. Two
  consequences: D8 is achievable with **no** `cc-account-switcher` change (the Non-Goal boundary holds),
  and SC10 is **not** sufficient cover for `keybindings.json` — `cmd_doctor` compares link *text* only,
  which is exactly why that dangling link went unnoticed. Hence the separate assertion in SC12.
- **`stow/ssh/.ssh/config` carries no network topology** — a `Host *` default block and a commented-out
  `myserver.example.com` example. Only the `IdentityFile` line needs correcting. No finding.

---

# Round 3 — 2026-07-29

Fresh critics on design revision 3 / brief revision 3. **Result: 4 Criticals — and the 3-loop cap is
reached.**

The character of the findings changed, which is the important signal: **three of the four are defects in
the revision text itself, not in the underlying design** — two are contradictions introduced by the
round-2/3 edits, one is a brief-side enumeration that drifted from the design's. Only R3-C1 is a genuine
new insight into the design.

| # | Finding | Critics | Status |
|---|---------|---------|--------|
| **R3-C1** | **The hook-diff gate guards a step the threat never takes.** §4.15 wired the review gate to `make restow`. But the `claude` package is stowed `--no-folding`, so **each hook is an individual symlink into the repo working tree** — a `git pull` that changes only a vendored hook's *contents* needs no stow, no restow, no link. The existing symlink already resolves to the new bytes, and the code auto-executes on the next session. The mitigation was unreachable for the exact vector I10/D18 name (a second machine actively pushing to this repo). | Sec | Closed by **§4.16** — gate moved to a session-start hash check on the execution path, plus SC15 which tests it by simulating a content-only pull with no stow operation |
| **R3-C2** | **The `settings.json` no-expansion fallback contradicted the clean-tree guarantee.** §4.5 said `claude-profile-init.sh` would rewrite the paths "at install time" — but `settings.json` is stow-symlinked, so an in-place post-stow edit edits the **tracked repo file** and breaks §4.12's `git status --porcelain`-clean assertion, while swapping the symlink for a real copy breaks the "every versioned entry is a symlink" assertion. Neither branch was reconciled. Self-inflicted by the round-2 wording. | Arch | Closed by rewritten **§4.5** — both branches fully specified; the no-expansion branch gets the `env.sh`/`routes` treatment (gitignored-real, materialized from `.example` *before* stow). Never rewritten in place |
| **R3-C3** | **§4.12 and §4.15 gave contradictory installer orders** with no tie-breaker between two subsections of the same authoritative section. §4.15 put `stow-all.sh` last; §4.12 puts it at step 2. Following §4.15 literally would run `claude-profile-init.sh` against a `~/.claude-shared` that does not exist yet — reproducing the dangling-shared-symlink defect (I6) the design exists to fix. Self-inflicted by the round-2 wording. | Arch | Closed — **§4.12 is now sole canonical order**; §4.15's bullet corrected and the error recorded |
| **R3-C4** | **The brief's never-versioned list was a strict subset of the design's**, dropping `handoffs/`, `settings.json.bak*`, and `routes`. Not harmless: the orchestrator verified that **both** `settings.json.bak*` files contain the `CC_NTFY_TOPIC` literal `rrp-cc-e2608a317ed1` — the exact value HC5 exists to keep out of tracked content — plus 20 and 6 hardcoded `/home/keenan` paths. An implementation reading only the brief would under-scope `assert-gitignore-safe.sh`. | Comp | Closed by rewritten **HC4** (full list) — and `assert-gitignore-safe.sh` now generates coverage from a live-tree scan and fails on any entry classified as neither versioned nor ignored, so this class cannot recur |

**Round-3 Importants** (folded into §4.17 and the brief): the **`claude` CLI itself is never
provisioned** anywhere, yet §4.12 steps 3–4 run it in a from-scratch container; `.last_inuse_sweep` and
`plugins/workflow-navigator.bak-20260724/` were classified as neither versioned nor ignored (the same gap
as `keybindings.json`); GPG signing inside the ephemeral container needed a specified mechanism that does
**not** put the real secret key in an image layer; `verify-fresh` reads as landing whole in unit 4 while
§4.12 steps 3–4 depend on unit-5 deliverables; `install-apt.sh`'s cwd dependency; Task 0 in-merge
conflict guidance; the `.ssh` swap-file removal stated without an assertion; SC5 naming no checker;
and the brief's stray "four sequenced units" contradicting its own five-item list.

**Two items deliberately left for `codebase-scan`** rather than assumed: whether the container's non-root
user has passwordless `sudo` (required non-interactively by `install-apt.sh`, both new apt-repo
installers, and `set-default-shell-zsh.sh`), and whether `cca` supports non-interactive profile creation
in a TTY-less container. Either being false blocks units 4–5, and both are cheap to check with the
codebase in hand.

---

## Gate — HALTED AT THE 3-LOOP CAP

Round 1: 10 Critical. Round 2: 1 Critical (none of round 1's re-raised). Round 3: 4 Critical, of which 3
were defects in the revision text and 1 was a genuine new design insight.

All four round-3 Criticals have been addressed in design revision 4 / brief revision 4 (§4.5 rewritten,
§4.12 made canonical, §4.16 added, HC4 corrected, SC14–SC16 added). **But the skill's loop exit condition
is a fresh critic run producing zero Criticals — not the orchestrator's judgement that the edits were
sufficient — and the documented maximum of 3 loops is now reached.**

Per the skill, this requires explicit human adjudication. The user chooses:
**(a)** authorize a round-4 verification pass (exceeds the documented cap), **(b)** accept the current
state and proceed to `codebase-scan`, or **(c)** revise further / abandon.

**Orchestrator's read, for what it is worth:** the trend supports (b). Round 1 attacked the design and
found ten real defects. Round 3 found none in the design — three were contradictions the revisions
themselves introduced, all now removed, and the fourth (R3-C1, the hook gate) was a genuinely good catch
that is now fixed with a testable criterion. Continued rounds are increasingly reviewing the review
prose rather than the plan. The two open `sudo`/`cca` questions are better answered by `codebase-scan`,
which reads the actual code, than by another document-only critic pass.
