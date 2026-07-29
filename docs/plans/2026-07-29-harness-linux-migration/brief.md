# Dotfiles Harness Ownership + Native-Linux Provisioning — Brief

> **Revision 2 — 2026-07-29, post-adversarial-review round 1.** Restores requirements that round 1
> found stripped from `design.md` (notably HC10, the nvim precondition), fixes Success Criteria that
> passed vacuously (SC2, SC3, SC6), and records five user decisions. Ground truth: `codebase-facts.md`.
> Mechanisms live in `design.md` §4, which is authoritative where the two disagree.

## Hard Constraints

1. **WSL must keep working — indefinitely, not just during the migration.** Every change is additive
   with respect to the current platform. `PLATFORM=wsl` continues to select `hosts/wsl/`, and `win/` +
   `scripts/win/` are retained as *maintained* first-class paths, not frozen legacy. At no point may
   the machine be left unable to provision.
   *(Revised: round 1 found "throughout" had no end condition while Q7 — whether the other machine
   still uses WSL — is unresolved. User decision: treat WSL as permanent, the reversible choice.)*
2. **Reconcile the fork before anything else.** Local `main` and `origin/main` have diverged (3 local,
   9 remote commits). `git merge`, never `git rebase` — the local commits may exist elsewhere.
   After the merge, re-diff `zsh`, `env`, and `nvim` against the planned overlays before building them:
   four of the nine remote commits touch exactly those files.
3. **Never force-push, hard-reset, `git branch -D`, or delete remote refs.** The 2022 clone's history
   exists in no other location; it is pushed as `archive/2022-pre-rewrite` before its clone is removed,
   **and the removal is gated on a verified `git ls-remote` SHA match that aborts on mismatch** — no
   `|| true`. This is the only unrecoverable operation in the project.
4. **No credentials or transcripts in the repo — including in history.** `.credentials.json`,
   `.claude.json`, `history.jsonl`, `projects/`, `sessions/`, `todos/`, `shell-snapshots/`, `stats/`,
   `debug/` stay untracked. The remote is public. The harness-state `.gitignore` rules land in their own
   verified commit **before** the first harness `git add`; `git add -A` is never used while staging the
   harness. `.gitignore` does not remove anything retroactively and HC3 forbids the force-push that
   would, so this ordering is a one-way door.
5. **No addressable endpoints in any tracked file.** `CC_NTFY_TOPIC` and the Tailscale IP are absent
   from tracked content, with values supplied from gitignored env and a committed `.example`.
   *(Revised: round 1 found the original mitigation insufficient — the topic literal lives at
   `settings.json:3`, inside a file the design commits verbatim, so gitignoring `env.sh` does nothing
   about it. See design §4.4.)*
6. **Machine state is regenerated, not copied.** Any file carrying an absolute `/home/keenan` path
   (`installed_plugins.json`, `known_marketplaces.json`, `plugin-catalog-cache.json`, the plugin
   caches) is gitignored and rebuilt from `packages/claude-plugins.txt` on a new box. This is now
   independently justified: that state is **already 4-of-14 broken** — four records point into
   `~/.claude-accounts/.shared-rrp.*` directories that no longer exist.
7. **Reconciliation is per-package.** No wholesale `stow --adopt` and no wholesale overwrite. Every
   package follows its row in the design's Section 3 table, and live files are backed up to
   `.migration_backups/` before being replaced. That directory is gitignored, hence machine-local and
   never pushed — it may be deleted only after `make verify-fresh` passes **and** explicit
   confirmation, and a one-time off-machine copy is taken before the first package is replaced.
8. **`~/.ssh` private-key permissions are never widened.** **Three** private keys live there
   (`id_ed25519`, `id_rsa`, `enduring-laptop`) — round 1 corrected the count from four. `--adopt` is
   never run against the `ssh` package; the stray `.id_ed25519.pub.swp` is removed, not adopted.
9. **`cc-account-switcher` and `astro_config` remain independent repos.** Declared and installed, not
   vendored. `cc-account-switcher` is pinned to a tag/commit so provisioning is reproducible.
10. **Uncommitted `~/.config/nvim` work must be preserved before any subtree operation.** *(NEW —
    round 1 found this stripped from the brief.)* The live clone has real uncommitted changes
    (`lazy-lock.json`, `lua/community.lua`, `lua/consts/language_packs.lua`, and
    `lua/plugins/{astrocore,astrolsp,autocmds,blink,init}.lua`). They must be committed — or explicitly
    reviewed and discarded — and pushed to `astro_config`, with a verified-clean working tree, **before**
    `nvim-subtree.sh pull` or `push` runs. A pull first would destroy them. This is the HC3-equivalent
    protection for the one place recoverability rules had not been applied.
11. **The stow contract for the `claude` package is explicit, not incidental.** *(NEW — round 1.)*
    Directories that must stay real (`~/.claude-shared/` and its `plugins/{cache,data,marketplaces}/`,
    `handoffs/`) are pre-created, and the package is stowed `--no-folding`. Otherwise, on a fresh box —
    or on this one after HC7 moves live `~/.claude-shared` aside — stow folds the whole tree into one
    symlink and runtime state is written inside the repo working tree.
12. **Commit capability must survive stowing the `git` package.** *(NEW — round 1.)* The declared
    signing key `665F3EDCE9AB996D` is **absent** from the keyring; `stow-all.sh` stows every package on
    every run, so landing the repo `.gitconfig` unchanged breaks every commit and tag on the machine,
    including this project's own.

## Non-Goals

- Migrating the OS itself, or provisioning the physical Linux machine.
- Migrating `~/.aws` / `~/.azure` *contents* out of `/mnt/c` — the dangling-symlink risk is
  documented as Q5, but the data move is separate work.
- Fonts, GUI, and dev-service daemon verification — explicitly outside the Docker harness.
- Refactoring `cc-account-switcher` itself, or any harness skill/hook behaviour. The harness is
  *versioned* here, not redesigned. **Three carve-outs**, each a prerequisite for cross-profile
  correctness rather than a redesign: (a) the `local-marketplace` relocation, (b) collapsing
  `rrp/settings.json` back to a symlink, and (c) de-duplicating `superpowers` as part of (b).
  *(Revised: round 1 found carve-out (c) was needed because a naive (b) would enable both superpowers
  sources on both profiles — a duplicate-skill regression on `kjweb`, which today has none.)*
- macOS support beyond keeping the existing `mac` branches intact; it is not tested.
- ~~Resolving the duplicate `superpowers` install (Q4)~~ — **no longer a non-goal.** User decision:
  de-duplicate during the D7 merge. Safe because both records reference the identical upstream commit
  `a98c5dfc9de0df5318f4980d91d24780a566ee60`; the 6.1.1-vs-4.2.0 labels are a marketplace-manifest
  artefact, not two versions of the code.

## Decisions Recorded

- **Canonical git identity:** `keenanjj13@gmail.com`; `init.defaultBranch = main`.
- **GPG:** repoint `signingkey` to `6C32D9329BDB7DA9` (present, `[SC]`, no expiry, uid
  `Keenan Johns (Github Account) <keenanjj13@gmail.com>`), keeping signing enabled. Open task, not an
  assumption: confirm that public key is registered on GitHub —
  `gh auth refresh -h github.com -s admin:gpg_key && gh api user/gpg_keys` (the session's token lacks
  the scope, and adding one is the user's call).
- **Superpowers:** keep `superpowers@claude-plugins-official`, drop `superpowers@superpowers-marketplace`.
- **WSL horizon:** permanent (Q7 unresolved; the reversible choice).
- **Delivery:** four sequenced units — see below.

## Delivery Sequence

Landed as four sequenced units rather than one change, because unit 1 unblocks every later commit,
unit 2 must precede any harness `git add`, and unit 5 depends on 2 and 4:

1. Fork reconciliation + git identity + GPG fix.
2. `.gitignore` harness-state rules + secret/PII sweep of all 47 versioned files.
3. Package lists + tool-ownership policy + `audit.sh`.
4. `PLATFORM` + `hosts/` + `verify-fresh`, with a `doctor` that can fail.
5. Harness vendoring.

## Success Criteria

1. `git log` shows local and remote history reconciled, with no commits lost from either side.
2. `make verify-fresh` passes: `bootstrap.sh` + `stow-all.sh` complete non-interactively in a clean
   `ubuntu:24.04` container as a non-root sudo user, **`make doctor` exits non-zero on any missing tool
   and exits 0 here**, and every stow symlink resolves to a real file.
   *(Revised: round 1 found `doctor` can never fail — every check is `command -v … || echo` with no
   exit propagation, and it unconditionally prints "doctor done (no output = all present)". Observed
   live emitting `MISSING: eza` and "all present" together with `$?`=0. Fixing `doctor`'s exit
   semantics is now part of the criterion, not assumed. Note also that `bootstrap.sh` is pervasively
   `|| true`, so "bootstrap completed" is not evidence — verify-fresh's assertions are.)*
3. `make audit` reports **all four** of its classes clean: no apt-declared-but-uninstalled, no
   untracked-but-installed apt packages, no mise-declared-but-uninstalled, and no
   mise-installed-but-undeclared tools. No tool is provisioned by direct `cargo install`.
   *(Revised: round 1 found the original wording covered 2 of 4 classes, and that the omitted two are
   where the real drift is — `bottom` is declared in both `apt.txt` and mise and absent from PATH;
   `zellij` and `exa` are cargo-direct and invisible to both audits.)*
4. On this machine, every package in the design's Section 3 table is genuinely stowed — `~/.zshrc`,
   `~/.gitconfig`, `~/.tmux.conf`, `~/.ssh/config`, `~/.config/{nvim,mise,zellij,dotfiles}`,
   `~/.local/bin/{nvimx,ccz}` all resolve into `~/.dotfiles`, with pre-existing content preserved in
   `.migration_backups/`. `~/.ssh/config`'s `IdentityFile` resolves to the intended key (the template
   hardcodes `id_ed25519` from Jan 2022; the newest key is `id_rsa`, Nov 2025).
   *(Revised: `~/.ssh/config` was absent from the list even though its row is the one that says the
   template needs "correcting, not just installing".)*
5. Switching profiles with `cca` leaves the same plugins enabled under both `rrp` and `kjweb`:
   `rrp/settings.json` is a symlink to shared, `workflow-navigator@local` resolves under both, and
   exactly **one** `superpowers` source is enabled on each.
6. A fresh `~/.claude-shared` can be reconstructed from the repo plus
   `scripts/install-claude-plugins.sh` and `scripts/claude-profile-init.sh`, with no absolute
   `/home/keenan` path in any tracked file **under `stow/claude/**` or `stow/env/**`**, and the harness
   functions under a different `$HOME`.
   *(Revised: round 1 found this unachievable as written — the criterion demanded it of "any tracked
   file" while the design's only mechanism (D6) gitignores machine-state JSON and never touches paths
   inside versioned content: 6 occurrences in `settings.json`, 4 of 16 hooks, 3 skills, 1
   `local-marketplace` file. Scope is now stated precisely AND a real mechanism exists — design §4.5.)*
7. `README.md` describes only things that exist — in particular `stow/hosts/` is real, no table row
   says "install manually on a new machine", and the `docker` group's root-equivalent access is
   documented as an accepted trade-off.
8. `~/github/dotfiles` is gone locally, and its history is reachable from
   `origin/archive/2022-pre-rewrite` — verified by `ls-remote` SHA match **before** the local clone was
   removed.
9. **NEW.** A test commit and a test tag succeed after the `git` package is stowed. *(Round 1: nothing
   would otherwise have caught HC12's failure until the next commit — potentially the migration's own.)*
10. **NEW.** `scripts/install-cc-switcher.sh` installs the pinned `cc-account-switcher` during
    `verify-fresh`, and `cca doctor` reports no unknown items. *(Round 1: HC9 asserted the switcher is
    "declared and installed" but nothing verified installation happened or was ordered correctly —
    `bootstrap.sh` has no such step today.)*
11. **NEW.** `~/.claude-shared` is a real directory (not a symlink) after `stow-all.sh` on a container
    with no pre-existing `~/.claude-shared`, each versioned entry beneath it is a symlink into the repo,
    and `git status --porcelain` is clean after a harness run — i.e. runtime state did not land in the
    working tree. *(Round 1, HC11.)*
