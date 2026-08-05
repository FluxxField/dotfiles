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
4. **No credentials, transcripts, or machine state in the repo — including in history.** The full
   never-versioned set, which `scripts/assert-gitignore-safe.sh` asserts via `git check-ignore` per
   entry: `.credentials.json`, `.claude.json`, `history.jsonl`, `projects/`, `sessions/`, `todos/`,
   `shell-snapshots/`, `stats/`, `debug/`, `plugins/{cache,data,marketplaces}/`,
   `installed_plugins.json`, `known_marketplaces.json`, `plugin-catalog-cache.json`, `blocklist.json`,
   `handoffs/`, **`settings.json.bak*`**, **`routes`**, `.last_inuse_sweep`, and
   `plugins/workflow-navigator.bak-20260724/`. **`dotfiles` is public; `claude-harness` is private
   (§4.22) — the rule binds in both histories, and privacy is not a substitute for the exclusions,
   because a private repo can still be shared, forked, or made public later.** The harness-state
   `.gitignore` rules land in their own verified commit **before** the first harness `git add`;
   `git add -A` is never used while staging the harness. `.gitignore` does not remove anything
   retroactively and HC3 forbids the force-push that would, so this ordering is a one-way door.
   *(Revised round 5, after the user's visibility decision: the harness moves to a private repo as a
   submodule at `stow/claude/`. Verified first that this cost nothing retroactively — zero tracked files
   and zero commits under `stow/claude`, because unit 5 had never run. The exclusions above were
   committed to `claude-harness` in its own first commit, before any content, preserving this same
   ordering in a repo whose history was still empty.)*
   *(Revised: round 3 found this list was a strict subset of the design's, and the omission was not
   harmless — **both `settings.json.bak*` files were verified to contain the `CC_NTFY_TOPIC` literal
   `rrp-cc-<REDACTED>`** that HC5 exists to keep out of tracked content, plus 20 and 6 hardcoded
   `/home/keenan` paths. `.last_inuse_sweep` and the `workflow-navigator.bak` directory were classified
   as neither versioned nor ignored — the same gap that let `keybindings.json` through. The assertion
   script generates its coverage from a scan of the live tree and fails on any entry classified as
   neither, so the next undocumented file cannot repeat this.)*
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
   confirmation, and a one-time off-machine copy is taken before the first package is replaced, to an
   existing private encrypted target (explicitly not another public remote or an unencrypted share).
   **The rollback path for a failed or partial reconciliation is the existing
   `scripts/merge-from-backup.sh`** — round 2 found HC7 said when the backups may be deleted but never
   how they are used to recover, while a script for exactly that purpose already sits unreferenced in
   the repo.
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
- **Project-scoped plugin enablement.** *(NEW — round 2.)* `packages/claude-plugins.txt` declares
  **user-scope installs only**. Project-scoped records key on a `projectPath` outside this repo
  (`roof-report-pro-web`) that will not exist on a fresh box, so modelling them in a provisioning
  manifest is out of scope — they are re-enabled per project by whoever works in it.
- **Restoring dangling-symlink detection to `cca doctor`.** It checks link text, never whether the
  target resolves — which is why `keybindings.json` went unnoticed. Fixing that belongs to
  `cc-account-switcher`; here the gap is covered by an explicit assertion instead (SC12).
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
  the scope, and adding one is the user's call). **If it is absent, upload it before enabling signing** —
  otherwise commits sign locally but show "Unverified" on GitHub. This fallback is the decision, not a
  question to re-open at implementation time.
- **Superpowers:** keep `superpowers@claude-plugins-official`, drop `superpowers@superpowers-marketplace`.
- **WSL horizon:** permanent (Q7 unresolved; the reversible choice).
- **Delivery:** five sequenced units — see below.
- **`cc-account-switcher` is published PRIVATE** *(NEW — round 4, after codebase-scan found it had no
  remote and no tags at all, which blocked HC9/I11/SC10)*: `github.com/FluxxField/cc-account-switcher`,
  default branch `main`, **pin target tag `v0.1.0` = `0e66044`**. Swept before publishing: no
  credentials or tokens in any of the 27 commits, but two business emails plus client names
  (`roofco`, `roof-report-pro`) across 9 files — hence private, which is also the reversible direction.
  **Consequence:** a private remote cannot be cloned anonymously, so `verify-fresh` must supply the
  switcher from the host (a `git bundle` of the pinned tag, or a read-only bind-mount) via a
  `CCA_SOURCE` parameter. **No token may enter the build context or an image layer** — the same rule
  §4.17 applies to the GPG key.
- **The Claude Code CLI gets an installer, not a Non-Goal** *(NEW — round 4, closing §4.17)*:
  `scripts/install-claude-cli.sh`, already written and verified on the branch. Version-pinnable via
  `CLAUDE_CLI_VERSION` (`stable|latest|X.Y.Z`), so `verify-fresh` can pin for D9/I11 reproducibility.
  §4.12 steps 3–4 therefore stay unconditional. Wiring into `bootstrap.sh` / `doctor` / README is
  **deferred to unit 4 under HC2** — `origin/main` has 9 unpulled commits and editing those three files
  pre-merge manufactures avoidable conflicts; a new file has no conflict surface.
- **To be decided and RECORDED in unit 2, not improvised:** whether the Claude Code settings
  `env`/permission blocks expand `${VAR}`. If yes, `settings.json` is committed with placeholders and
  stays stow-symlinked. If no, it becomes gitignored-real + a tracked `settings.json.example`,
  materialized by `install-env.sh` **before** `stow-all.sh`. It is never rewritten in place after
  stowing — that would edit the tracked repo file and break SC11.

## Delivery Sequence

Landed as five sequenced units rather than one change, because unit 1 unblocks every later commit,
unit 2 must precede any harness `git add`, and unit 5 depends on 2 and 4:

1. Fork reconciliation + git identity + GPG fix. The 9 incoming remote commits are swept for
   secrets/endpoints **before** the merge — a `git merge` into a public branch is as history-permanent
   as a `git add`, and it happens before unit 2's gate exists.
2. `.gitignore` harness-state rules + secret/PII sweep. Scope is every file newly tracked or modified
   anywhere in this work — not only the 47 harness files, but also `stow/tmux/.tmux.conf` (adopted
   verbatim), `ccz`, `stow/ssh/.ssh/config`, the mise config, `.zshrc`, `packages/**`, `scripts/**`.
3. Package lists + tool-ownership policy + `audit.sh` (five classes).
3.5. Per-package `stow/` reconciliation — `nvim` (HC10's commit-and-verify gate **first**), `zsh`,
   `env`, `bin`, `ssh`, `tmux` — entered via the post-merge re-diff of `zsh`/`env`/`nvim` against the
   planned overlays. *(Round 2 found these packages, including the highest-risk one, unassigned to any
   unit.)*
4. `PLATFORM` + `hosts/` + `verify-fresh`, with a `doctor` that can fail and the `make unlink`/`restow`
   bugs fixed.
5. Harness vendoring, internally checkpointed: vendor + template → `local-marketplace` relocation +
   plugin replay → `rrp/settings.json` collapse + superpowers de-dup → `keybindings.json` → final
   SC5/SC6/SC11 verification. It is the only unit that writes into live `~/.claude-shared` /
   `~/.claude-accounts` state, so it gets the same staging rigor as the irreversible operations.

## Success Criteria

1. Local and remote history are reconciled with no commits lost from either side — verified
   mechanically: each of the 3 local-only and 9 remote-only commits (or its content) is an ancestor of
   the merged `main`, checked via `git merge-base --is-ancestor`.
   *(Revised: round 2 noted "`git log` shows … reconciled" named no checker, unlike SC8's `ls-remote`
   SHA match.)*
2. `make verify-fresh` passes: `bootstrap.sh` + `stow-all.sh` complete non-interactively in a clean
   `ubuntu:24.04` container as a non-root sudo user, **`make doctor` exits non-zero on any missing tool
   and exits 0 here**, and every stow symlink resolves to a real file.
   *(Revised: round 1 found `doctor` can never fail — every check is `command -v … || echo` with no
   exit propagation, and it unconditionally prints "doctor done (no output = all present)". Observed
   live emitting `MISSING: eza` and "all present" together with `$?`=0. Fixing `doctor`'s exit
   semantics is now part of the criterion, not assumed. Note also that `bootstrap.sh` is pervasively
   `|| true`, so "bootstrap completed" is not evidence — verify-fresh's assertions are.)*
3. `make audit` reports **all five** of its classes clean: no apt-declared-but-uninstalled, no
   untracked-but-installed apt packages, no mise-declared-but-uninstalled, no
   mise-installed-but-undeclared tools, and **no binary in `~/.cargo/bin` unattributable to a
   mise-managed install**.
   *(Revised twice: round 1 found the original wording covered 2 of 4 classes, and that the omitted two
   are where the real drift is — `bottom` is declared in both `apt.txt` and mise and absent from PATH.
   Round 2 found that even four classes structurally cannot see a tool declared in neither list, so
   "no direct cargo install" was an unenforceable claim; the fifth class makes it an invariant rather
   than a one-time cleanup.)*
4. On this machine, every package in the design's Section 3 table is genuinely stowed — `~/.zshrc`,
   `~/.gitconfig`, `~/.tmux.conf`, `~/.ssh/config`, `~/.config/{nvim,mise,zellij,dotfiles}`,
   `~/.local/bin/{nvimx,ccz}` all resolve into `~/.dotfiles`, with pre-existing content preserved in
   `.migration_backups/`. `~/.ssh/config`'s `IdentityFile` resolves to the intended key (the template
   hardcodes `id_ed25519` from Jan 2022; the newest key is `id_rsa`, Nov 2025).
   *(Revised: `~/.ssh/config` was absent from the list even though its row is the one that says the
   template needs "correcting, not just installing".)*
5. Switching profiles with `cca` leaves the same plugins enabled under both `rrp` and `kjweb` —
   verified by diffing the two profiles' effective `enabledPlugins` blocks and asserting they are
   identical: `rrp/settings.json` resolves to shared, `workflow-navigator@local` resolves under both,
   and exactly **one** `superpowers` source is enabled on each.
   *(Revised: round 3 noted SC5 was the only criterion naming no checker.)*
6. A fresh `~/.claude-shared` can be reconstructed from the repo plus
   `scripts/install-claude-plugins.sh` and `scripts/claude-profile-init.sh`, with no absolute
   `/home/keenan` path in any tracked file **under `stow/claude/**` or `stow/env/**`**, and the harness
   functions under a different `$HOME` — verified in a container whose **username and UID differ from
   the live machine's**, so this cannot pass by accident.
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
10. **NEW.** `scripts/install-cc-switcher.sh` installs `cc-account-switcher` **pinned to `v0.1.0`
    (`0e66044`)** during `verify-fresh`, and `cca doctor` reports no unknown items. Because the remote
    is **private**, the container is fed the pinned source from the host via `CCA_SOURCE` (bundle or
    read-only bind-mount) and **no credential appears in the build context or any image layer**; a real
    fresh box uses the remote URL default. *(Round 1: HC9 asserted the switcher is "declared and
    installed" but nothing verified installation happened or was ordered correctly — `bootstrap.sh` has
    no such step today. Round 4: the repo had no remote at all, so this criterion was unsatisfiable as
    written.)*
11. **NEW.** `~/.claude-shared` is a real directory (not a symlink) after `stow-all.sh` on a container
    with no pre-existing `~/.claude-shared`, each versioned entry beneath it is a symlink into the repo,
    and `git status --porcelain` is clean after a harness run — i.e. runtime state did not land in the
    working tree. *(Round 1, HC11.)*
12. **NEW (round 2).** `verify-fresh` exercises the reproducibility path itself, not just stowing:
    it runs `claude-profile-init.sh` for at least one synthetic profile, then
    `install-claude-plugins.sh`, and asserts the regenerated `installed_plugins.json` /
    `known_marketplaces.json` are self-consistent, contain no unresolvable `installPath`, and carry no
    non-portable home path. It also asserts `~/.claude-shared/keybindings.json` resolves to a real
    file. *(Round 2 found the design called the plugin replay "the piece that makes a fresh box
    reproducible" while no criterion exercised it — SC2/SC11 tested stowing and `doctor` only. And
    `cca doctor` cannot cover `keybindings.json`: it checks a shared symlink's link text, never whether
    the target resolves, which is exactly why that dangling link went unnoticed.)*
13. **NEW (round 2).** `stow-all.sh` is idempotent: running it a second time on an
    already-provisioned box produces no error and no change. Additionally `make restow` succeeds and is
    equivalent to `unlink` then `link`, and `make unlink` honours the same `hosts` exclusion and
    per-package flags as `stow-all.sh`. *(The review-then-`restow` workflow assumes repeat runs are
    routine, and `make restow` is currently outright broken — `restow:` is a tab-indented recipe running
    `unlink link` as a shell command — while `make unlink` bypasses `stow-all.sh` entirely and lacks its
    `hosts` exclusion. Round 3 noted SC13 tested `stow-all.sh` but not the two broken targets.)*
14. **NEW (round 3).** `env.sh` and `routes` — and `settings.json` if the no-expansion branch applies —
    exist as real files after `verify-fresh`, and `install-env.sh` never clobbers an existing local file
    (running it twice with a locally-edited `env.sh` leaves the edit intact). *(Round 3: the
    materialization mechanism was the one Critical from round 1 with no dedicated criterion.)*
15. **NEW (round 3).** Changed hook/skill/command content is detected on the **execution path**, not on
    `make restow`: after simulating a `git pull` that edits a vendored hook's contents with no stow
    operation, the session-start check surfaces the diff rather than executing silently.
    *(Round 3 Critical: because the package is stowed `--no-folding`, each hook is an individual symlink
    into the repo, so a content-only pull goes live with no restow — the round-2 `restow` gate guarded a
    step that vector never takes.)*
16. **NEW (round 3).** `install-gh.sh` and `install-docker.sh` pin GPG key fingerprints and use
    `signed-by` keyring files — no `apt-key add`. If starship's `curl | bash` is left unhardened, that is
    recorded here as an accepted residual risk rather than an oversight.
    *(Round 4 refinement: `install-claude-cli.sh` is also `curl | bash`, but it is **not** the same risk
    class and must not be lumped in — Anthropic's `install.sh` fetches a per-platform manifest, extracts
    a SHA256, and aborts on mismatch, so the payload is verified and only the script fetch is TLS-only.
    Starship verifies nothing. The accepted residual risk is starship alone.)*
17. **NEW (round 4).** The Claude Code CLI is provisioned by `scripts/install-claude-cli.sh` and
    `make doctor` checks for it — so `verify-fresh` steps 3–4 (`claude-profile-init.sh` and the plugin
    replay) run against a CLI the repo installed, not one that happened to be present. `verify-fresh`
    pins `CLAUDE_CLI_VERSION` to a concrete version. Note the asymmetry that cannot be fixed here:
    `claude plugin install` has **no** version-pin flag, so the manifest replay always resolves
    marketplace-latest. *(Round 3 found the CLI was never provisioned anywhere while steps 3–4 depend on
    it; round 4 chose the installer over the Non-Goal.)*
18. **NEW (round 5) — HC5 applies to the planning artifacts, not only to the shipped config.**
    `make sweep-secrets` passes over the **whole worktree including `docs/`**, with fixture-bearing paths
    exempted **by path** (an explicit `SWEEP_EXEMPT` list in the `Makefile`), never by value, and the run
    always discloses how many matches it exempted.
    *(Round 5 Critical: the first real run returned 36 hits. The real `CC_NTFY_TOPIC` and the real
    Tailscale IP were quoted verbatim in eight tracked planning documents — already pushed to the public
    remote at `614e0c2`. HC5 forbids exactly this, and §4.6 designs an elaborate scheme to keep the same
    topic out of `settings.json`; three rounds of adversarial review checked the designed artifact
    against HC5 and never pointed HC5 at the design. The literals are now redacted, but HC3 forbids the
    force-push that would scrub history, so **rotating `CC_NTFY_TOPIC` is the only real mitigation and is
    the user's call** — see §4.20.)*
19. **NEW (round 5) — the harness is private and consumed as a submodule.** `stow/claude/` is a git
    submodule pointing at `FluxxField/claude-harness` (private); `FluxxField/dotfiles` stays public for
    the nine shell/editor packages. `make verify-fresh` provisions the submodule **without a token in
    the build context** — via a host-supplied git bundle or read-only bind-mount, the same mechanism
    `CCA_SOURCE` uses for `cc-account-switcher` (§4.18). Both private dependencies share one mechanism.
    *(Round 5, user decision. Justified by §4.20: a secret scanner catches credentials, not judgment,
    and 16 of the 47 harness files reference internal project names. Verified empirically that this
    needs **no** change to `stow-all.sh` — stow does not link a submodule's `.git` into `$HOME`, nor a
    package root's `.gitignore`/`README.md`, per the built-in list in `Stow.pm`'s `__DATA__`. The cost
    is one `git submodule update --init` in `bootstrap.sh`, not a second stow source.)*
