# Dotfiles Harness Ownership + Native-Linux Provisioning — Design

## Design Contract
> Structured digest of the design below. Downstream skills read THIS first; the prose design that
> follows is the authoritative source if the two ever disagree.

**Files Touched** — best-effort from the design; codebase-scan resolves exact paths

| Path / component | Repo | Change | Notes |
|---|---|---|---|
| *(git history)* `main` ← `origin/main` | dotfiles | merge | **Task 0.** Local `main` diverged: 3 local-only, 9 remote-only commits. Merge, do not rebase. |
| `packages/apt.txt` | dotfiles | delete | Split into the three files below. |
| `packages/apt-common.txt` | dotfiles | create | Platform-agnostic packages + the 24 installed-but-untracked ones. |
| `packages/apt-linux.txt` | dotfiles | create | Native-Linux-only packages. |
| `packages/apt-wsl.txt` | dotfiles | create | WSL-only packages. |
| `packages/claude-plugins.txt` | dotfiles | create | Declarative marketplace + plugin + scope manifest. |
| `scripts/install-claude-plugins.sh` | dotfiles | create | Replays the manifest via `claude plugin marketplace add` / `claude plugin install`. |
| `scripts/claude-profile-init.sh` | dotfiles | create | Creates an account's symlink skeleton by delegating to `cca`. |
| `scripts/install-gh.sh` | dotfiles | create | Third-party apt repo; removes a "install manually" README row. |
| `scripts/install-docker.sh` | dotfiles | create | Third-party apt repo; removes a "install manually" README row. |
| `scripts/install-cc-switcher.sh` | dotfiles | create | Clones/updates `cc-account-switcher` and runs its `install.sh`. |
| `scripts/detect-os.sh` | dotfiles | modify | Add `PLATFORM` export (`wsl`\|`linux`\|`mac`) alongside existing `OS`/`WSL`. |
| `scripts/install-apt.sh` | dotfiles | modify | Consume the three split package lists per `PLATFORM`. |
| `scripts/verify-fresh.sh` | dotfiles | create | Docker dry-run harness (see Verification). |
| `bootstrap.sh` | dotfiles | modify | Key WSL branches off `PLATFORM`; wire new installer scripts. |
| `stow-all.sh` | dotfiles | modify | Overlay `hosts/` by `PLATFORM`; the `hosts/` tree it already references must actually exist. |
| `Makefile` | dotfiles | modify | Add `verify-fresh`, `install-gh`, `install-docker`, `claude-plugins`, `claude-profile-init`; extend `doctor`. |
| `stow/claude/.claude-shared/**` | dotfiles | create | New package: `skills/`, `hooks/`, `commands/`, `agents/`, `settings.json`, `settings.local.json`, `CLAUDE.md`, `statusline.sh`, `shell-integration.sh`, `accounts.json`, `local-marketplace/`. |
| `stow/claude/.claude-shared/routes.example` | dotfiles | create | `routes` itself is machine-local (absolute project paths) and gitignored; only the example is tracked. |
| `stow/hosts/{@common,wsl,linux,$(hostname)}/` | dotfiles | create | Documented in README today but has never existed. |
| `stow/tmux/.tmux.conf` | dotfiles | create | Adopt the 48-line live config, tracked nowhere today. |
| `stow/bin/.local/bin/ccz` | dotfiles | create | Adopt the untracked live helper. |
| `stow/zsh/.zshrc` | dotfiles | modify | Move `BROWSER=/mnt/c/...` and other WSL branches out to `hosts/wsl/`. |
| `stow/git/.gitconfig` | dotfiles | modify | Line-merge with live (see reconciliation table). |
| `stow/mise/.config/mise/config.toml` | dotfiles | modify | Resolve 7 declared-but-uninstalled tools; fold in remote's `vercel` global. |
| `stow/ssh/.ssh/config` | dotfiles | modify | Correct hardcoded `IdentityFile` (newest live key is `id_rsa`, Nov 2025). |
| `stow/nvim/.config/nvim` | dotfiles | modify | Subtree pull after pushing live divergence upstream. |
| `stow/env/.config/dotfiles/env.sh` | dotfiles | modify | Add templated `CC_NTFY_TOPIC`, Tailscale host; commit an `.example` and gitignore the real file. |
| `.gitignore` | dotfiles | modify | Currently **empty**. Add `.worktrees/`, `.migration_backups/`, and the harness state exclusions. |
| `README.md` | dotfiles | modify | Fix documented-but-absent `stow/hosts/`; document `PLATFORM`, the harness package, `verify-fresh`. |
| `~/github/dotfiles` (stale 2022 clone) | — | archive then remove | Push as `archive/2022-pre-rewrite` FIRST — sole surviving copy of pre-rewrite history. |

**Schema Changes** — `None` (no database in scope)

**Endpoints** — `None` (no HTTP surface in scope)

**Domain Types / Contracts**

- `PLATFORM` — new exported contract from `scripts/detect-os.sh`, values `wsl` | `linux` | `mac`.
  Consumed by `bootstrap.sh`, `stow-all.sh`, `install-apt.sh`, and the `hosts/` overlay selection.
  Supersedes implicit "if not WSL, hope for the best" branching. `OS`/`WSL` remain exported for
  backward compatibility.
- `packages/apt-{common,linux,wsl}.txt` — line-delimited apt package names, `#` comments allowed.
- `packages/claude-plugins.txt` — declarative plugin manifest: marketplace source, plugin id, scope.
- Versioned-vs-regenerated boundary for `~/.claude-shared` (enumerated in the design below) — the
  contract that makes the harness portable to a new machine.

**Key Decisions**

- D1: Vendor the harness as a `stow/claude` package (Approach A) — matches existing architecture,
  one repo for a fresh box, and stow tree-folding separates declarations from runtime state for free.
- D2: `cc-account-switcher` stays its own repo, declared and installed, not vendored — it is a
  maintained tool with `bin/lib/share/tests/docs` and its own `install.sh`, under active development.
- D3: `nvim` keeps its existing `git subtree` mechanism; only the 17-file drift is reconciled. No
  second subtree is introduced (C rejected on the evidence of that drift).
- D4: Reconciliation is decided **per package**, not wholesale in either direction — neither side is
  uniformly correct.
- D5: Platform support is additive and reversible — WSL keeps working via `hosts/wsl/` and
  `PLATFORM=wsl`; `win/` and `scripts/win/` are retained and documented as the WSL-era path.
- D6: Machine state with absolute `/home/keenan` paths is gitignored and **regenerated** from a
  declarative manifest, not copied.
- D7: Collapse `~/.claude-accounts/rrp/settings.json` back to a symlink to shared (after merging its
  2 extra `enabledPlugins` entries into shared) — that single file is the entire cause of
  cross-profile plugin divergence.
- D8: Relocate `local-marketplace/` to the profile-independent `~/.claude-shared/local-marketplace/`
  and repoint `known_marketplaces.json` — fixes the dangling-under-`kjweb` bug at its root.
- D9: Verification is a Docker dry-run (`make verify-fresh`), deliberately scoped to exclude fonts,
  GUI, and dev-service daemons.
- D10: Remove `asdf` in favour of `mise` — two version managers on one `PATH` is a latent ordering bug.
- D11: Archive the 2022 clone as a remote branch before deleting it; never force-push, never delete
  remote refs.
- D12: `routes` is treated as machine-local, not shared harness config — tracked as `routes.example`
  with the live file gitignored, because its entries are absolute project paths. Same pattern as
  `env.sh`.

**Open Questions / Risks**

- **Q1 (blocking a `git` package decision):** which email is canonical — live `keenanjj13@gmail.com`
  or repo `keenanjj13@protonmail.com`? And should `defaultBranch` move `master` → `main`?
- **Q2 (breaks committing if wrong):** GPG signing key `665F3EDCE9AB996D` is declared with
  `commit.gpgsign=true`. Must be confirmed present in the keyring on the new box or every commit
  fails. The remote's `gpg-agent.conf` commit is relevant here.
- **Q3:** `zellij` needs a file-level diff (live vs repo vs remote's newer web layout) — not yet run.
- **Q4:** Two `superpowers` installs are enabled simultaneously under `rrp` —
  `official@6.1.1` (user scope) and `superpowers-marketplace@4.2.0` (project-scoped to
  `roof-report-pro-web`). A duplicate skill source to resolve, not state to faithfully preserve.
- **Q5:** `~/.aws` and `~/.azure` are symlinks into `/mnt/c/Users/Keenan/` and **will dangle** on
  native Linux. Their contents must be migrated, not just relinked.
- **Q6:** `~/.config/nvim`'s committed-vs-uncommitted state was not confirmed (a `git status` probe
  was denied), so the 17-file divergence may include uncommitted work. Verify before any subtree pull
  — a pull could otherwise overwrite it.
- **Q7:** The 9 unpulled remote commits were authored from another machine; whether that machine is
  still in use affects whether this repo must stay WSL-compatible indefinitely.
- **R1:** `~/.ssh/` holds four private keys. The `ssh` package must never widen their permissions;
  `stow-all.sh` already fixes `config` to 600.
- **R2:** `CC_NTFY_TOPIC` (`rrp-cc-e2608a317ed1`) and the Tailscale IP `100.114.199.90` in `ccz` are
  addressable endpoints on a repo with a public remote. Templated to gitignored env, per user approval.

---

## Design (authoritative — verbatim from brainstorming)

### Findings — ground truth of the current state

**The repo is aspirational, not descriptive.** Nothing is actually stowed on this machine.
`~/.zshrc`, `~/.gitconfig`, `~/.config/nvim`, `~/.config/mise`, `~/.config/zellij`, `~/.tmux.conf`
are all real files that diverge from their `stow/` counterparts; `~/.config/dotfiles/env.sh` and
`~/.local/bin/nvimx` were never created, so the startup hook and `nvimx` channel switcher have never
run. Live `.zshrc` is a stock oh-my-zsh template with **zero** references to `.dotfiles`. Live
`.gitconfig` uses gmail + `defaultBranch=master` + no signing; the repo version uses protonmail +
GPG signing + `nvim`.

**The CC harness is 100% unversioned** — 60 files across
`~/.claude-shared/{skills(17),hooks(16),commands(10),agents(4)}`, `statusline.sh`,
`shell-integration.sh`, `accounts.json`, `routes`, plus the `workflow-navigator` plugin. None of it
is in any repo.

**A live harness bug worth fixing regardless of this project:**
`~/.claude-shared/plugins/workflow-navigator` resolves *through* `~/.claude` — the active-profile
symlink — to `local-marketplace/`, which exists only under `rrp`. Switch to `kjweb` and that symlink
dangles. Consistently, `kjweb`'s settings lack `superpowers` and `workflow-navigator` in
`enabledPlugins`; the two `settings.json` files differ **only** by those three lines, so `rrp`'s
8.3k real file is otherwise a redundant copy of the shared one.

Other drift: `apt.txt` is missing 24 genuinely-installed packages (`docker-ce`, `gh`, `jq`,
`tailscale`, `syncthing`, `stripe`, `redis-stack-server`, `awscli`, `mosh`, `tesseract-ocr`,
`openjdk-11-jdk`…); `mise` declares 7 tools that aren't installed; the README documents a
`stow/hosts/` overlay tree that **doesn't exist** even though `stow-all.sh` references it; `~/.aws`
and `~/.azure` are symlinks into `/mnt/c/Users/Keenan/` that will dangle the moment you leave WSL;
`nvim` is a subtree of `FluxxField/astro_config` whose live clone has diverged in 17 files (each side
has files the other lacks); `ccz` is a hand-written helper sitting untracked in `~/.local/bin`; and
`asdf` and `mise` are both installed.

### Requirements settled during brainstorming

1. **CC scope:** repo owns the full harness — settings.json split, the profile-switcher mechanism,
   hooks, skills/plugins manifest, and the `~/.claude` symlink wiring — with credentials,
   `.claude.json` history, and transcripts gitignored.
2. **OS target:** both platforms, explicitly branched. Keep WSL support working while adding a
   native-Linux path, with the platform difference made explicit rather than implicit. Migrate
   incrementally and reversibly; the existing `win/` dir survives as a documented legacy path.
3. **Reconciliation:** per-package decision. Repo wins for the curated packages that were designed
   but never installed; live wins for `nvim` (reconciled through the subtree); genuinely-diverged
   files like `.gitconfig` get an explicit line-level merge. The only option that doesn't silently
   throw away one side.
4. **Verification:** Docker dry-run harness — a make target that runs `bootstrap.sh` in a clean
   Ubuntu container and asserts the doctor checks pass. Catches the WSL assumptions, missing apt
   repos (`gh`/`docker`), and stow conflicts now rather than on migration day, and gives a
   repeatable regression test to re-run after every future change.

### Approaches considered

**A. Vendor the harness as stow packages** (recommended, chosen). A new `stow/claude/` package
mirroring `~/.claude-shared/{skills,hooks,commands,agents,settings.json,statusline.sh,shell-integration.sh,accounts.json,routes}`
(`routes` was later scoped down to a tracked `routes.example` only — see Section 2 and D12).
The harness becomes symlinks exactly like `zsh` and `git` — one repo, one `stow-all.sh`, and a fresh
box comes up with the harness live in a single step. The reason this fits better than it first
appears: stow's tree-folding symlinks each entry *individually* when the parent already exists, so
the versioned content gets linked while `handoffs/`, `plugins/cache/`, `plugin-catalog-cache.json`,
and the `.bak` files stay untouched real state. That split is the whole problem, and stow solves it
for free rather than needing an ignore mechanism.

**B. A separate `cc-harness` repo that dotfiles clones.** Cleaner conceptual boundary, independently
versionable, and shareable without dragging shell config along. But it's a second repo to keep in
sync, bootstrap gains a clone-and-link step, and "which repo owns this?" becomes a question to
answer every time a hook is touched.

**C. Vendor via `git subtree`,** the way `nvim` is done today. Theoretically the best of both. In
practice the counter-evidence is already in this repo: the nvim subtree has silently drifted 17 files
from its live clone, with unique files on both sides. Adding a second subtree adds a second thing to
drift.

**Chosen: A**, with one deliberate exception: **`cc-account-switcher` stays its own repo.** It has
`bin/`, `lib/`, `share/`, `tests/`, `docs/`, and its own `install.sh` — that's a maintained tool, not
configuration, and it's under active development (there's a live worktree on it). Dotfiles should
*declare and invoke* its installer, not vendor its source. Same call for `nvim`: leave the subtree
mechanism alone, just reconcile the drift once.

### Section 1 — Architecture

Three layers, each with one job:

**Layer 1: `packages/` declares what gets installed.** `apt.txt` splits into `apt-common.txt`
(works anywhere) plus `apt-linux.txt` / `apt-wsl.txt` for platform-only packages, and gains the 24
untracked-but-installed packages. The four tools needing third-party apt repos (`gh`, `docker-ce`,
plus existing `stripe`/`redis-stack`) get real installer scripts so "install manually on a new
machine" disappears from the README. `asdf` gets removed in favor of `mise` — two version managers on
one PATH is a latent ordering bug, not a feature.

**Layer 2: `stow/` declares what gets linked**, gaining `stow/claude/` (the harness) and
`stow/hosts/` (which the README already documents and `stow-all.sh` already calls, but which has
never existed). Platform-conditional config moves out of inline `if` blocks in `.zshrc` into
`stow/hosts/wsl/` and `stow/hosts/linux/` overlays, so `BROWSER=/mnt/c/.../chrome.exe` lives in the
WSL overlay rather than being a branch in a shared file.

**Layer 3: `scripts/` declares how**, with `detect-os.sh` extended from `OS`/`WSL` to also export a
`PLATFORM` (`wsl` | `linux` | `mac`) that overlays and installers key off explicitly — replacing
today's implicit "if not WSL, hope for the best."

The reversibility requirement is satisfied by Layer 2/3 being additive: WSL keeps working the whole
time because `hosts/wsl/` still exists and `PLATFORM=wsl` still selects it. Nothing gets deleted from
the Windows path; `win/` and `scripts/win/` stay, documented as the WSL-era path.

### Plugin sharing across profiles — verified state

**Shared and working:** the `plugins/` directory itself is in the switcher's `SHARED_ITEMS`
(`lib/cca-lib.sh:18`), so both profiles symlink to `~/.claude-shared/plugins` — marketplace
checkouts, the version cache, and `installed_plugins.json` are genuinely common. Install under `rrp`
and the bits are on disk for `kjweb`.

**Shared in intent, broken in practice — enablement.** `settings.json` is *also* in `SHARED_ITEMS`,
but `rrp`'s is a real file rather than a symlink, so `rrp` has silently broken out of sharing. That
one file is the entire reason `kjweb` is missing `superpowers@superpowers-marketplace` and
`workflow-navigator@local`. Collapsing `rrp/settings.json` back to a symlink (after merging those two
entries into shared) fixes cross-profile enablement wholesale.

**Not shared at all — the `local` marketplace.** `known_marketplaces.json` locates it at
`/home/keenan/.claude/local-marketplace`, which resolves *through the active-profile symlink*, and
that directory exists only under `rrp`. Under `kjweb` it dangles — which is the root cause of both
this and the `plugins/workflow-navigator` symlink flagged above (the `workflow-navigator.bak-20260724`
sibling suggests it has already been hand-patched around once). Shared content living at a
per-profile path.

Two further observations from reading the state: **two superpowers installs are enabled
simultaneously** under `rrp` — `official@6.1.1` (user scope) and `superpowers-marketplace@4.2.0`
(project-scoped to `roof-report-pro-web`) — which is a duplicate skill source, not a config to
faithfully preserve. Separately, every `installPath`/`installLocation` in that shared state has
`/home/keenan` hardcoded, so those files are **not portable to the new box** even with the same
username layout.

`claude plugin marketplace add` and `claude plugin install` both exist as non-interactive CLI
commands, so a declarative replay is feasible.

### Section 2 — The `stow/claude` package

Ownership splits on one line: **declarations are versioned, machine state is regenerated.**

*Versioned* (`stow/claude/.claude-shared/`): `skills/`, `hooks/`, `commands/`, `agents/`,
`settings.json`, `settings.local.json`, `CLAUDE.md`, `statusline.sh`, `shell-integration.sh`,
`accounts.json`, and `local-marketplace/` — relocated to `~/.claude-shared/local-marketplace/`, a
profile-independent path, with `known_marketplaces.json` pointing there instead of through
`~/.claude`. That relocation is what makes `workflow-navigator` work under both profiles and lets the
dangling symlink and its `.bak` be dropped.

*Gitignored as regenerable or machine-local state*: `plugins/{cache,data,marketplaces}/`,
`installed_plugins.json`, `known_marketplaces.json`, `plugin-catalog-cache.json`, `blocklist.json`,
`handoffs/`, the `settings.json.bak*` files, and **`routes`**. All of it carries absolute
`/home/keenan` paths — `routes` maps a project directory to an account
(`/home/keenan/github/roof-report-pro` → `rrp`), so it is machine-local by nature. It ships as a
committed `routes.example` with the real file gitignored, the same treatment as `env.sh`.

*Replacing it*: `packages/claude-plugins.txt` declares marketplace + plugin + scope, and
`scripts/install-claude-plugins.sh` replays it with `claude plugin marketplace add` /
`claude plugin install`. That's the piece that makes a fresh box reproducible — the cache is
re-derived rather than copying an unportable one.

*Never versioned*: `.credentials.json`, `.claude.json`, `history.jsonl`, `projects/`, `sessions/`,
`todos/`, `shell-snapshots/`, `stats/`, `debug/`. The per-account dirs stay entirely untracked; the
repo owns `~/.claude-shared` plus a `scripts/claude-profile-init.sh` that creates an account's
symlink skeleton by delegating to `cca` — so provisioning a profile on the new box is one command,
and the switcher stays its own repo.

**Endpoint handling (user-approved):** `CC_NTFY_TOPIC` in `settings.json` is `rrp-cc-e2608a317ed1`,
and `ccz` has the Tailscale IP `100.114.199.90` hardcoded. Neither is a credential, but both are
addressable endpoints — anyone with the topic can push notifications to the phone. Both are templated
into `stow/env/.config/dotfiles/env.sh` (gitignored, with a committed `.example`) rather than
committed, since the remote is public.

### Section 3 — Migration mechanics

Two findings reorder the plan:

**`~/.dotfiles` has diverged from its own remote.** Not stale — *forked*. Three local commits (the
2026-02-19 work: audit script, dev-services stack, cross-platform fixes) were never pushed, and
**nine remote commits were never pulled**:

```
a48b128 feat(zsh): added ssh agent to startup      226010f refactor(env): removed WINUSER
b2e95f8 feat: added gpg-agent.conf                 ec0fa88 feat(env): added WINUSR path
14b692a feat(nvim): added win32yank for clipboard  080cbe0 chore(nvim): updated plugins
432a8fa feat(zellij): updated web layout           3aaaa72 feat(mise): added vercel to global
3af1e20 Merge branch 'main' ...
```

So another machine has been pushing to this repo. Reconciling that fork has to be **task zero** —
every reconciliation decision below is meaningless if made against the wrong base. Notably four of
those nine commits (`ssh-agent`, `gpg-agent.conf`, `win32yank`, `WINUSR`) are exactly the WSL-era
coupling the platform-overlay work needs to sort, so they land right in scope.

**The 2022 clone holds history that exists nowhere else.** `e4a76dc` isn't an ancestor of current
`main` — the object doesn't even exist in `~/.dotfiles`, the two repos have *different root commits*,
and `git ls-remote` shows the remote has only `main`. That repo was rewritten at some point, and
`~/github/dotfiles` is the sole surviving copy of the pre-rewrite lineage. Given the recoverability
rules it is not deleted: push it as an `archive/2022-pre-rewrite` branch first (purely additive, no
force-push), *then* remove the clone.

**Task 0: reconcile the fork.** `git merge origin/main` on a branch, resolve conflicts, push. Merge
not rebase — the local commits may already exist elsewhere and rebasing rewrites shared history.

**Per-package reconciliation**, given each side's actual state:

| Package | Winner | Mechanism |
|---|---|---|
| `zsh` | **repo** | Live is a stock oh-my-zsh template with no `.dotfiles` reference — nothing to salvage beyond the completion `matcher-list`, which the repo already has. Back live up, stow the curated version. |
| `git` | **line-merge** | Repo base (protonmail, GPG signing, `nvim`, `excludesfile`) + adopt live's `gh auth git-credential` helper. Two live values need a decision at implement time: which email, and `defaultBranch` `master`→`main`. Signing key `665F3EDCE9AB996D` must be verified present in the keyring or commits start failing. |
| `nvim` | **live**, via subtree | Commit and push the 17 diverged files to `astro_config`, then `nvim-subtree.sh pull`. Confirm both unique files (`neorg.lua` live, `ts_error_translator.lua` repo) survive — this is a merge, not a takeover. |
| `mise` | **line-merge** | Repo declares 7 tools that aren't installed. Each gets installed or deleted from `config.toml` — declared-but-absent is the drift that made `audit` noisy. Remote's `vercel` global folds in here. |
| `zellij` | **diff at implement time** | Both sides real; remote has a newer web layout. Needs a file-level diff not yet run. |
| `env`, `bin` | **repo** | Never installed live, so pure install — plus adopt `ccz` into `stow/bin`. |
| `ssh` | **repo** | Live has *no* `config` at all, only keys. But the repo template hardcodes `IdentityFile ~/.ssh/id_ed25519` while the newest key is `id_rsa` (Nov 2025) — template needs correcting, not just installing. |
| `tmux` | **live** → new package | 48-line live config (prefix `C-Space`, pane-path splits) tracked nowhere. Adopt it. |
| `claude` | **live** → new package | Per Section 2. |

**Verification harness.** `make verify-fresh` builds a clean `ubuntu:24.04` container, runs
`bootstrap.sh` + `stow-all.sh` with `PLATFORM=linux`, then asserts `make doctor` is clean and every
stow target resolves to a real file. It runs *non-interactively as a non-root user with sudo*, which
is what catches the failures that matter: the WSL branches, the four third-party apt repos, `chsh` on
a box with no login session, and stow conflicts against a pristine `$HOME`. Scoped deliberately
narrow — no fonts, no GUI, no dev-service daemons; those are VM concerns and re-testing them in a
container mostly proves Docker works.
