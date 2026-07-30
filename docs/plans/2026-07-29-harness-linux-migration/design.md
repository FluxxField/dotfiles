# Dotfiles Harness Ownership + Native-Linux Provisioning — Design

> **Revision 2 — 2026-07-29, post-adversarial-review round 1.**
> Amended to close 10 Critical findings and 19 Important findings from
> `adversarial-review.md`, plus five user decisions. **Precedence, highest first:**
> (1) **Section 4 — Review Revisions** (added in this revision), (2) this Design Contract,
> (3) the verbatim brainstorming prose in Sections 1–3. Where Section 4 contradicts the earlier prose,
> Section 4 wins — the prose is retained as the historical record of how the design was reached.
> Ground truth for every factual claim: `codebase-facts.md`.

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
| `scripts/install-cc-switcher.sh` | dotfiles | create | Clones/updates `cc-account-switcher` and runs its `install.sh`. **Remote now exists** (§4.18): `git@github.com:FluxxField/cc-account-switcher.git`, **private**, pinned to tag `v0.1.0` = `0e66044`. |
| `scripts/install-claude-cli.sh` | dotfiles | create | **DONE, already on the branch.** Provisions the Claude Code CLI via Anthropic's native installer — closes §4.17's gap. Version-pinnable via `CLAUDE_CLI_VERSION`. |
| `scripts/detect-os.sh` | dotfiles | modify | Add `PLATFORM` export (`wsl`\|`linux`\|`mac`) alongside existing `OS`/`WSL`. |
| `scripts/install-apt.sh` | dotfiles | modify | Consume the three split package lists per `PLATFORM`. |
| `scripts/verify-fresh.sh` | dotfiles | create | Docker dry-run harness (see Verification). |
| `bootstrap.sh` | dotfiles | modify | Key WSL branches off `PLATFORM`; wire new installer scripts. |
| `stow-all.sh` | dotfiles | modify | Overlay `hosts/` by `PLATFORM`; the `hosts/` tree it already references must actually exist. |
| `Makefile` | dotfiles | modify | Add `verify-fresh`, `install-gh`, `install-docker`, `claude-plugins`, `claude-profile-init`; extend `doctor`. |
| `stow/claude/.claude-shared/**` | dotfiles | create | New package: `skills/`, `hooks/`, `commands/`, `agents/`, `settings.json`, `settings.local.json`, `CLAUDE.md`, `statusline.sh`, `shell-integration.sh`, `accounts.json`, **`keybindings.json`** (§4.10 I6 — currently a dangling shared symlink, invisible to `cca doctor`), `local-marketplace/`. |
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
| `.gitignore` | dotfiles | modify | **Not empty** (137 B; already has `.worktrees/`, `.migration_backups/`). Add ONLY the harness-state exclusions — and land them in their **own commit, verified, before any harness `git add`** (§4 C6). |
| `README.md` | dotfiles | modify | Fix documented-but-absent `stow/hosts/`; document `PLATFORM`, the harness package, `verify-fresh`, and the `docker` group trade-off (§4 I8). |
| `~/github/dotfiles` (stale 2022 clone) | — | archive then remove | Push as `archive/2022-pre-rewrite` FIRST — sole surviving copy of pre-rewrite history. Removal **gated on a verified `ls-remote` SHA match** (§4 C7). |
| `scripts/audit.sh` | dotfiles | modify | **Was missing from this table.** Reads a single `APT_LIST="$DOTFILES_ROOT/packages/apt.txt"`; must union the three split lists filtered by `$PLATFORM` or it breaks the moment `apt.txt` is deleted (§4 I1). |
| `scripts/install-env.sh` | dotfiles | create | Copies `*.example` → real file **only when absent**, for `env.sh` and `routes`. Ordered before `stow-all.sh`. Without it a fresh clone has no file for stow to link (§4 C5). |
| `scripts/claude-path-template.sh` | dotfiles | create | Parameterizes absolute `/home/keenan` paths in versioned **shell / hook / skill** files to `$HOME`/`${CCA_HOME:-$HOME}` form, and reverses them at install time. `settings.json`'s permission globs + `additionalDirectories` are handled by `claude-profile-init.sh` in the no-expansion branch only (§4.15). Required for SC6. |
| `scripts/assert-gitignore-safe.sh` | dotfiles | create | Loops the never-versioned path list with `git check-ignore -q`, fails loudly. Scripts the C6 gate instead of trusting a typed sequence (§4.15). |
| `Makefile` (`unlink`, `restow`) | dotfiles | fix | **Pre-existing bugs.** `restow:` is a tab-indented recipe running `unlink link` as a shell command, so it fails; `unlink` has its own stow loop that bypasses `stow-all.sh` and lacks the `-not -name hosts` filter (§4.14). |

**Schema Changes** — `None` (no database in scope)

**Endpoints** — `None` (no HTTP surface in scope)

**Domain Types / Contracts**

- `PLATFORM` — new exported contract from `scripts/detect-os.sh`, values `wsl` | `linux` | `mac`.
  Consumed by `bootstrap.sh`, `stow-all.sh`, `install-apt.sh`, `audit.sh` (§4.10 I1 — it must union the
  three split lists per `$PLATFORM`), and the `hosts/` overlay selection.
  Supersedes implicit "if not WSL, hope for the best" branching. `OS`/`WSL` remain exported for
  backward compatibility.
- `packages/apt-{common,linux,wsl}.txt` — line-delimited apt package names, `#` comments allowed.
- `packages/claude-plugins.txt` — declarative plugin manifest: marketplace source, plugin id, scope.
- Versioned-vs-regenerated boundary for `~/.claude-shared` (enumerated in the design below) — the
  contract that makes the harness portable to a new machine.

**Key Decisions**

- D1: Vendor the harness as a `stow/claude` package (Approach A) — matches existing architecture and
  gives one repo for a fresh box. **Amended (§4 C1): tree-folding does NOT separate declarations from
  runtime state "for free."** Folding only descends into a target directory that already exists as a
  real directory; on a fresh box `~/.claude-shared` does not exist, so stow would link the whole tree
  as a single symlink and every later runtime write would land inside the repo. The separation must be
  made explicit — see D13.
- D13: **`stow` invocation for the `claude` package is explicit, not incidental.** `stow-all.sh`
  pre-creates the real directories that must stay real (`~/.claude-shared/`, `plugins/`,
  `plugins/{cache,data,marketplaces}/`, `handoffs/`) with `mkdir -p` before stowing, and passes
  `--no-folding` for the `claude` package. `verify-fresh` asserts this on a container with **no**
  pre-existing `~/.claude-shared`, and asserts that no path inside the repo working tree was written
  by a post-stow harness run.
- D14: **`make doctor` must be able to fail.** It currently emits `MISSING: …` lines but always exits
  0 and unconditionally prints `doctor done (no output = all present)` — verified live emitting
  `MISSING: eza` and "all present" together with `$?`=0. `doctor` gains a failure counter and exits
  non-zero when any check misses; the unconditional success line is removed. Without this, SC2 and
  D9's "repeatable regression test" pass vacuously.
- D15: **Absolute-path portability is a build step, not a gitignore rule.** D6 covers only machine-state
  JSON; it does not touch the 6 `/home/keenan` occurrences in `settings.json`, 4 of 16 hooks, 3 skills,
  and 1 `local-marketplace` file — all of which the design versions. `scripts/claude-path-template.sh`
  parameterizes them to `$HOME` / `${CCA_HOME:-$HOME}` (the pattern `shell-integration.sh` already
  uses). SC6 is scoped to tracked files under `stow/claude/**` plus `stow/env/**`.
- D16: **Irreversible steps get hard gates, against repo house style.** `bootstrap.sh` is pervasively
  `|| true`, `doctor` always exits 0, `audit.sh` deliberately drops `-e`. The two irreversible
  operations must not inherit that: (a) the harness-state `.gitignore` rules land in their own commit
  and are verified (no never-versioned path stageable) **before** the first harness `git add`;
  (b) the 2022 clone is removed only after `git ls-remote origin archive/2022-pre-rewrite` returns the
  expected SHA. Both abort on mismatch — no `|| true`.
- D17: **Landed as five sequenced units** (user decision), not one change: (1) fork reconciliation +
  git identity + GPG, (2) `.gitignore` + secret/PII sweep, (3) packages + tool-ownership policy +
  `audit.sh`, (3.5) per-package `stow/` reconciliation — `nvim` (HC10's precondition first), `zsh`,
  `env`, `bin`, `ssh`, `tmux` — entered via §4.9's post-merge re-diff, (4) `PLATFORM` + `hosts/` +
  `verify-fresh` with a failing `doctor`, then (5) harness vendoring, itself internally checkpointed
  (§4.15). Rationale: unit 1 unblocks every later commit, unit 2 must precede any harness `git add`,
  and unit 5 depends on 2 and 4. Avoids a stuck half-migrated machine.
- D18: **WSL support is treated as permanent** (user decision, Q7 unresolved). `win/`, `scripts/win/`,
  and `hosts/wsl/` stay first-class and maintained; HC1 has no end date. Corollary: because another
  machine actively pushes to this repo and hooks auto-execute once vendored, hook diffs are reviewed
  before any `restow` picks them up (§4 I10).
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
  extra `enabledPlugins` entries into shared) — that single file is the entire cause of cross-profile
  plugin divergence. **Amended (§4 C10, user decision): de-duplicate `superpowers` during the merge
  rather than propagating it.** A naive collapse would enable BOTH `superpowers@claude-plugins-official`
  and `superpowers@superpowers-marketplace` on BOTH profiles — introducing a duplicate skill source on
  `kjweb`, which today has none. Keep `superpowers@claude-plugins-official` (user scope, cache under
  `~/.claude` so it resolves for both profiles); drop `superpowers@superpowers-marketplace`. Safe
  because both record the identical upstream commit `a98c5dfc9de0df5318f4980d91d24780a566ee60` — the
  6.1.1-vs-4.2.0 label difference is a marketplace-manifest artefact, not a code difference. So
  `workflow-navigator@local` is the only entry actually merged into shared.
- D8: Relocate `local-marketplace/` to the profile-independent `~/.claude-shared/local-marketplace/`
  and repoint the marketplace registration — fixes the dangling-under-`kjweb` bug at its root.
  **Amended (§4 I5): D8 is realized by the `install-claude-plugins.sh` replay, not by editing a file.**
  The `~/.claude`-routed path is cached in **two** places — `known_marketplaces.json` (the `local`
  source + installLocation) and `installed_plugins.json:85,93` (`installPath:
  /home/keenan/.claude/plugins/cache/local/workflow-navigator/1.0.0`) — and both are in D6's
  gitignored/regenerated set, so hand-editing one is neither sufficient nor durable. The old
  `~/.claude-accounts/rrp/local-marketplace/` is removed after the content moves, so no stale duplicate
  remains for a later `claude plugin marketplace add` to target.
- D9: Verification is a Docker dry-run (`make verify-fresh`), deliberately scoped to exclude fonts,
  GUI, and dev-service daemons.
- D10: Remove `asdf` in favour of `mise` — two version managers on one `PATH` is a latent ordering bug.
- D11: Archive the 2022 clone as a remote branch before deleting it; never force-push, never delete
  remote refs.
- D12: `routes` is treated as machine-local, not shared harness config — tracked as `routes.example`
  with the live file gitignored, because its entries are absolute project paths. Same pattern as
  `env.sh`.

**Open Questions / Risks**

- **Q1 — RESOLVED (user decision).** Canonical identity is **`keenanjj13@gmail.com`**, and
  `init.defaultBranch = main`. Rationale: gmail is what live `.gitconfig` already uses AND it is the
  uid on the only GPG key that exists, so `user.email` matches the signing key (what makes GitHub show
  "Verified"); `main` because `origin`'s default branch is `main` and every repo in play uses
  `main`/`dev`, so `master` would be actively wrong on new repos.
- **Q2 — RESOLVED (defect confirmed; direction decided).** `665F3EDCE9AB996D` is **absent** from the
  keyring. The only secret key is `6C32D9329BDB7DA9` — `rsa3072`, capability `scESC` (sign + certify),
  **no expiry**, ultimate trust, uid `Keenan Johns (Github Account) <keenanjj13@gmail.com>`.
  **Decision: repoint `signingkey` to `6C32D9329BDB7DA9` and keep `commit.gpgsign`/`tag.gpgSign` true.**
  Because `stow-all.sh` stows every package on every run, this must land in unit 1 — otherwise the
  moment `git` is stowed, every commit and tag on the machine (including this project's own) fails.
  **One verification the session could not perform:** whether that public key is registered on GitHub
  (`gh api user/gpg_keys` → 404, token lacks the `admin:gpg_key` scope). Adding a token scope is the
  user's call, so it is a task, not an assumption: `gh auth refresh -h github.com -s admin:gpg_key &&
  gh api user/gpg_keys`. If absent, upload it before enabling signing — otherwise commits sign locally
  but show "Unverified" on GitHub.
- **Q3 — OPEN, owner assigned.** `zellij` needs a file-level diff (live vs repo vs remote's newer web
  layout). Not yet run. Resolved during unit 3, before the `zellij` package is stowed; SC4 covers the
  outcome.
- **Q4 — RESOLVED, and the original framing undercounted.** There are **three** `superpowers` records,
  not two, and **two are user-scope**: `claude-plugins-official` user/6.1.1 (path exists),
  `superpowers-marketplace` project/4.2.0 (path exists), and `superpowers-marketplace` user/6.1.1
  whose `installPath` (`~/.claude-accounts/.shared-rrp.33991/…`) **no longer exists**. Both marketplace
  entries record the same upstream commit as the official one, so de-duplication is lossless.
  Resolution is folded into D7 — no longer deferred.
- **Q5 — OPEN, out of scope (unchanged).** `~/.aws` and `~/.azure` are symlinks into
  `/mnt/c/Users/Keenan/` and **will dangle** on native Linux. Contents must be migrated, not relinked.
  Confirmed still true; the data move remains separate work.
- **Q6 — RESOLVED (defect confirmed).** `~/.config/nvim` **has uncommitted work**: `lazy-lock.json`,
  `lua/community.lua`, `lua/consts/language_packs.lua`, and
  `lua/plugins/{astrocore,astrolsp,autocmds,blink,init}.lua` are all modified against HEAD `0bf7e19`.
  So the 17-file divergence is not purely committed drift. **A subtree pull before committing these
  would destroy real work.** Hard precondition added: commit (or explicitly review and discard) the
  live working tree, push to `astro_config`, and verify clean **before** any `nvim-subtree.sh` operation.
  Mirrored into the brief as a Hard Constraint (it was stripped in round 1).
- **Q7 — OPEN; treated as permanent (user decision).** Whether the other machine is still in use is
  unconfirmed, so WSL support is designed as indefinite — the reversible choice. See D18.
- **R1 — CORRECTED.** `~/.ssh/` holds **three** private keys (`id_ed25519`, `id_rsa`,
  `enduring-laptop`), not four, plus a stray `.id_ed25519.pub.swp` (0644, Jan 2022) that should be
  removed while the directory is being touched. The guardrail is unchanged: never widen key
  permissions, and never run `--adopt` against the `ssh` package. `stow-all.sh` already chmods
  `config` to 600 and `~/.ssh` to 700.
- **R2 — AMENDED; the original mitigation was incomplete.** `CC_NTFY_TOPIC` (`rrp-cc-<REDACTED>`)
  and the Tailscale IP `<TAILSCALE-IP-REDACTED>` are addressable endpoints on a public remote. The round-1
  plan — "template both into gitignored `env.sh`" — does not actually work for the topic, because the
  literal lives at `~/.claude-shared/settings.json:3` and `settings.json` is in the **Versioned** list,
  committed verbatim. See §4 C8 for the corrected mechanism. The Tailscale IP in `ccz` is
  comment-only, so templating it is straightforward.
- **R3 — NEW.** The round-1 secret review covered only the two values already known. An independent
  grep then found `/home/keenan` in 4 hooks, 3 skills, and `settings.json` — items the design had not
  surfaced. Treated as a canary: **all 47 versioned files** (16 hooks + 17 skills + 10 commands +
  4 agents) get a dedicated secret/PII sweep (tokens, webhook URLs, other IPs/hostnames) before the
  first commit, in unit 2.
- **R4 — NEW.** `installed_plugins.json` is **already 4-of-14 broken**: four records point into
  `~/.claude-accounts/.shared-rrp.{33991,59780}` directories that do not exist, `workflow-navigator@local`
  has a duplicate record, and `vercel@claude-plugins-official` + one `frontend-design` record cache
  under `~/.claude-accounts/rrp` despite being enabled in shared — a second instance of the
  per-profile-path-for-shared-content bug D8 diagnoses. This strengthens D6 considerably: the state is
  not merely unportable, it is already partly invalid, so regenerating from
  `packages/claude-plugins.txt` is the only sound path.

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

**Endpoint handling (user-approved):** `CC_NTFY_TOPIC` in `settings.json` is `rrp-cc-<REDACTED>`,
and `ccz` has the Tailscale IP `<TAILSCALE-IP-REDACTED>` hardcoded. Neither is a credential, but both are
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

---

## Section 4 — Review Revisions (authoritative)

> Added in revision 2 to close `adversarial-review.md` round 1. **This section takes precedence over
> Sections 1–3 and over the Design Contract wherever they disagree.** Each item names the finding it
> closes.

### 4.1 The stow contract for `claude` must be explicit (C1)

Approach A's justification was that tree-folding links each entry individually, so machine state stays
untouched "for free". That is only true when the target directory already exists as a real directory —
which is the *incidental* current state of this machine, not a property of stow. On a fresh box, and on
this box after HC7 moves live `~/.claude-shared` into `.migration_backups/`, folding produces a single
whole-tree symlink and every subsequent runtime write lands inside the dotfiles working tree.

`stow-all.sh` therefore, for the `claude` package only:
1. `mkdir -p` the directories that must remain real: `~/.claude-shared/`, `~/.claude-shared/plugins/`,
   `~/.claude-shared/plugins/{cache,data,marketplaces}/`, `~/.claude-shared/handoffs/`.
2. Stows with `--no-folding` so each versioned entry is linked individually and no parent is ever
   collapsed.

`verify-fresh` asserts both: run in a container with no pre-existing `~/.claude-shared`, then confirm
(a) `~/.claude-shared` is a real directory, not a symlink, (b) each versioned entry under it is a
symlink into the repo, and (c) `git status --porcelain` in the repo is clean after a harness run —
i.e. runtime state did not land in the working tree.

### 4.2 `doctor` gains real exit semantics (C2)

Current body is 12 × `@command -v X >/dev/null || echo "MISSING: X"` followed by an unconditional
`@echo "doctor done (no output = all present)"`. It cannot fail; live it printed `MISSING: eza` and
"all present" in the same run with `$?`=0. Rewrite: accumulate misses, drop the unconditional success
line, exit 1 if any miss. `verify-fresh` additionally greps the captured output for `MISSING:` as a
belt-and-braces check, and fails the container run itself. Related: `bootstrap.sh`'s pervasive
`|| true` means "bootstrap completed" is not evidence — `verify-fresh`'s assertions, not bootstrap's
exit code, are the acceptance signal.

### 4.3 `.example` files are materialized before stowing (C5)

`env.sh` and `routes` become gitignored-real + committed-`.example`. `stow` links only what physically
exists in the package directory, so on a fresh clone there is nothing to link — meaning R2's whole
mitigation (the topic and Tailscale host "templated into `env.sh`") silently never materializes, and
the startup hook that has never run still never runs. New `scripts/install-env.sh` copies each
`*.example` to its real path **only when the real file is absent** (never clobbering local edits), and
`bootstrap.sh` runs it before `stow-all.sh`. `verify-fresh` asserts both real files exist post-run.
Note `stow/env/.config/dotfiles/env.sh` is **currently tracked**, so the transition includes
`git rm --cached` — and, because history is public and HC3 forbids force-pushing, the committed
history of that file must be reviewed for anything sensitive before it is untracked (there is nothing
sensitive in it today; the check is for the future).

### 4.4 `CC_NTFY_TOPIC` cannot be templated by gitignoring another file (C8)

The topic literal lives at `~/.claude-shared/settings.json:3`, inside the `env` block of a file the
design commits verbatim. Gitignoring `env.sh` does nothing about it. Mechanism, in preference order:
1. **Preferred** — confirm whether Claude Code's settings `env` block expands `${CC_NTFY_TOPIC}`. If it
   does, commit the placeholder and let the value come from the environment via `env.sh`.
2. **Fallback** — remove the key from the committed `settings.json` entirely and have the notifying
   hook read `$CC_NTFY_TOPIC` from the environment (`env.sh` already exports into every shell), so the
   endpoint never appears in tracked content.

Which of the two applies is determined during unit 2 and recorded; it is not left to implementation
improvisation. HC5 is not satisfied until the literal is absent from every tracked file.

### 4.5 Absolute-path portability needs a mechanism (C9)

Verified violations inside files the design versions: `settings.json` **6** (`Read(//home/keenan/**)`,
`Read(//home/keenan/github/**)`, `Read(//home/keenan/.claude/**)`, `Edit(//home/keenan/github/**)`,
`Edit(//home/keenan/.claude/**)`, and `/home/keenan/github` in `additionalDirectories`); **4 of 16
hooks** (`continuous-learning.sh`, `session-stats.sh`, `wip-snapshot.sh`, `context-pressure.sh`);
**3 skills**; **1** `local-marketplace` file. These genuinely break under a different `$HOME`, so this
is a portability defect, not only an SC6 wording problem.

`scripts/claude-path-template.sh` parameterizes them following the pattern `shell-integration.sh`
already demonstrates (`"${CCA_HOME:-$HOME}/.claude-accounts"`): shell, hook, and skill files use
`$HOME` / `${CCA_HOME:-$HOME}` directly. SC6 is scoped to tracked files under `stow/claude/**` and
`stow/env/**`.

`settings.json`'s permission globs and `additionalDirectories` are the hard case, and the resolution
depends on §4.4's undetermined expansion question. **Both branches are now fully specified — neither
may rewrite a stowed file in place:**

- **If the settings `env`/permission blocks expand `${VAR}`:** commit `settings.json` with placeholders.
  It stays a versioned, stow-symlinked file. Nothing is rewritten at any point.
- **If they do not:** `settings.json` gets **exactly the `env.sh`/`routes` treatment** — the real file
  becomes gitignored, a `settings.json.example` carrying `$HOME`-relative placeholders is tracked, and
  `install-env.sh` materializes the real file (substituting the actual `$HOME`) **before** `stow-all.sh`
  runs. `settings.json` then moves from the Versioned list to the gitignored-materialized list for the
  purposes of §4.1's assertions.

An earlier draft said the no-expansion branch had `claude-profile-init.sh` rewrite the paths "at install
time." That is withdrawn: `settings.json` is stow-symlinked into the repo, so an in-place post-stow edit
would edit the **tracked repo file** and break §4.12's `git status --porcelain`-clean assertion, while
replacing the symlink with a real copy would break the "every versioned entry is a symlink" assertion.
Materialize-before-stow is the only branch that satisfies both.

### 4.6 Hard gates on the two irreversible operations (C6, C7)

**C6 — credentials into public history.** Ordering is now mandatory, not implied:
1. Commit the harness-state `.gitignore` additions **alone**.
2. Verify: no path in the never-versioned set (`.credentials.json`, `.claude.json`, `history.jsonl`,
   `projects/`, `sessions/`, `todos/`, `shell-snapshots/`, `stats/`, `debug/`, `plugins/{cache,data,marketplaces}/`,
   `installed_plugins.json`, `known_marketplaces.json`, `plugin-catalog-cache.json`, `blocklist.json`,
   `handoffs/`, `settings.json.bak*`, `routes`) appears as stageable — `git status --porcelain` plus an
   explicit `git check-ignore` assertion per entry.
3. Only then `git add` the harness package. Never `git add -A` while staging it.

`.gitignore` does not retroactively remove anything, and HC3 forbids the force-push that would — so
this is a one-way door.

**C7 — the 2022 archive.** Between push and removal, assert
`git ls-remote origin refs/heads/archive/2022-pre-rewrite` returns the expected SHA (equivalently,
fetch and `git merge-base --is-ancestor`). Abort on any mismatch. Explicitly **no `|| true`** on this
step — it is the only genuinely unrecoverable operation in the project, and it currently sits in a
repo whose scripts swallow failures by convention.

### 4.7 `PLATFORM` replaces WSL sniffing rather than joining it (I4, M7)

`stow-all.sh` today keys overlays off `hostname` plus **its own** inline
`grep -qi microsoft /proc/version` — a second, independent copy of the detection already in
`detect-os.sh` — applies the hostname overlay unconditionally, and has **no `linux` branch at all**.
So "overlay `hosts/` by `PLATFORM`" is net-new logic, not a substitution. `stow-all.sh` sources
`detect-os.sh` and branches solely on `$PLATFORM`, with the inline grep deleted so exactly one
WSL-detection implementation exists. `bootstrap.sh`'s remaining `WSL`-keyed branches (the `pwsh.exe`
font install, `wsl-post.sh`) convert to `$PLATFORM` as well; `OS`/`WSL` remain exported but are
documented as derived low-level facts, with `PLATFORM` the only thing overlay selection consults.
Caveat: `detect-os.sh` carries `set -euo pipefail` and is `source`d, leaking those options into
callers — adding `PLATFORM` must not make that worse.

### 4.8 Tool ownership is a policy, not a per-entry judgement call (I3, I2)

The round-1 mise plan ("install it or delete it") assumes a two-way apt/mise world. Verified reality is
three-way: `bottom` is declared in **both** `apt.txt` and mise and is absent from PATH; `zellij` is
declared in mise but installed at `~/.cargo/bin/zellij`; `eza` is declared in mise **and** checked by
`doctor` while only the predecessor `exa` exists (also cargo-direct); `just` is declared and absent.
That is the same PATH-precedence bug class D10 removes one layer up.

Policy: **mise owns language runtimes and language-ecosystem CLI tools** (`cargo:*`, `npm:*`, go, node,
rust); **apt owns system packages only**; **no direct `cargo install`** — existing cargo-direct
binaries (`exa`, `zellij`) are removed and re-provisioned through the owning manager, and `eza`
replaces `exa` so `doctor`'s check is meaningful. `bottom` is removed from whichever list does not own
it. `audit.sh` is extended to all four of its report classes and SC3 requires all four clean.

### 4.9 Post-merge reconciliation against the overlay design (I15)

Four of the nine remote-only commits — `a48b128` zsh ssh-agent, `b2e95f8` `gpg-agent.conf`, `14b692a`
nvim `win32yank`, `226010f`/`ec0fa88` env WINUSER→WINUSR — touch exactly the files Layer 2/3 then
rewrites. After Task 0, explicitly re-diff `zsh`, `env`, and `nvim` against the planned `hosts/wsl/`
overlay and the `env.sh` template before building them, so merged WSL-era logic is neither silently
dropped nor duplicated into both a shared file and an overlay. `b2e95f8` (`gpg-agent.conf`) is also
directly relevant to Q2 and is reviewed as part of unit 1.

### 4.10 Remaining Important items folded in

- **I1** `scripts/audit.sh` added to Files-Touched — must union the three split lists per `$PLATFORM`
  or it breaks when `apt.txt` is deleted.
- **I6** `keybindings.json` is classified explicitly. It is in cca's `SHARED_ITEMS`,
  `~/.claude-accounts/rrp/keybindings.json` points at it, and `~/.claude-shared/keybindings.json`
  **does not exist** — an already-dangling shared symlink. It joins the versioned list (as a default
  file if there is no content to preserve), because leaving it unclassified reproduces exactly the
  blind-spot bug `cca-lib.sh`'s own comment documents.
- **I7** `install-gh.sh` / `install-docker.sh` pin GPG key fingerprints to known-good values and use
  `signed-by` keyring files — never deprecated `apt-key add`. The retained
  `curl -fsSL https://starship.rs/install.sh | bash` in `bootstrap.sh` is noted as an inherited,
  unaddressed risk rather than silently accepted.
- **I8** README documents that `install-docker.sh` grants root-equivalent access via the `docker`
  group (bind-mount the host filesystem as root) as an accepted trade-off — SC7 requires the README
  describe what actually happens.
- **I9** `.migration_backups/` is the sole rollback path for up to 9 package migrations and is
  gitignored, hence machine-local and never pushed. It may be deleted only after `verify-fresh` passes
  **and** explicit user confirmation; a one-time off-machine copy is taken before the first package is
  replaced.
- **I10** Vendored `hooks/` auto-execute on session events, a second machine actively pushes to this
  repo, and Q7 is unresolved — so `git pull` becomes "accept new auto-executing code". Hook diffs are
  reviewed before any `restow` picks them up. (Commit signing, the mechanism that would help here, is
  only restored by Q2's fix.)
- **I11** `install-cc-switcher.sh` pins `cc-account-switcher` to a tag/commit, bumped deliberately, so
  `verify-fresh` is reproducible per D9 and upstream `main` cannot silently change provisioning. An SC
  verifies the switcher actually installs.
- **I13** `~/.ssh/config` joins SC4's enumerated list, and `IdentityFile` is asserted to resolve to the
  intended key — the repo template hardcodes `id_ed25519` (Jan 2022) while the newest key is `id_rsa`
  (Nov 2025). Note live `~/.ssh/config` does not exist at all, so this is a pure install, and
  `~/.gitignore_global` likewise does not exist live while `stow/git/.gitignore_global` does.
- **I14** The hostname-keyed overlay `stow/hosts/$(hostname)/` is keyed to the current WSL box. Whether
  the native-Linux target shares this hostname is unresolved; until it is, `@common` + `linux` must
  carry everything functionally required, and a hostname overlay is treated as convenience only.
- **I18** `accounts.json` carries `keenan@kjweb.dev` and is versioned. Low sensitivity (own domain;
  commit authorship already exposes an email) — accepted explicitly rather than by omission.

### 4.12 `verify-fresh`'s script inventory is specified, not implied (round-2 Critical)

Round 2 found — independently from two directions — that §4.2 fixed *whether* `doctor` can fail without
ever specifying *what `verify-fresh` actually runs*. The only description of its contents (Section 3)
predates units 4–5 and names none of the new installers, so SC5, SC9, SC10, and SC11 depended on an
implied mechanism. That is the same vacuous-acceptance-test defect §4.2 was written to close.

`verify-fresh` runs, in this order, in a clean `ubuntu:24.04` container as a **non-root sudo user whose
username and UID differ from the live machine's** (required — otherwise SC6's "functions under a
different `$HOME`" passes by accident):

1. `bootstrap.sh` — which must itself now invoke, in order: `install-apt.sh` (per-`PLATFORM` lists) →
   `install-gh.sh` → `install-docker.sh` → **`install-claude-cli.sh`** (§4.18; must precede the
   switcher, whose `install.sh` and `cca` wrapper both assume a `claude` binary) →
   `install-cc-switcher.sh` (pinned to `v0.1.0`; `CCA_SOURCE` = bundle in-container, remote on a real
   box — §4.18) → `install-env.sh` (materialize `*.example`) → the existing mise/nvim/starship steps.
2. `stow-all.sh` — including the `mkdir -p` + `--no-folding` handling for the `claude` package (§4.1).
3. `claude-profile-init.sh` for at least one synthetic profile — must precede the replay, because
   `claude plugin install` writes into the *active* `~/.claude` profile path, so a profile must exist
   first.
4. `install-claude-plugins.sh` — the manifest replay.
5. `stow-all.sh` **a second time**, asserting no error and no diff — proving idempotency, which I10's
   review-then-`restow` workflow assumes is routine.
6. `make doctor` — asserted to exit 0 **and** to emit no `MISSING:` line.
7. `make audit` — all five classes clean (§4.8).
8. Assertions: `~/.claude-shared` is a real directory, not a symlink; every versioned entry beneath it
   is a symlink into the repo; `git status --porcelain` in the repo is clean; `env.sh` and `routes`
   exist as real files; `~/.ssh/config` resolves with the intended `IdentityFile`; no tracked file under
   `stow/claude/**` or `stow/env/**` contains `/home/keenan`; the regenerated
   `installed_plugins.json` / `known_marketplaces.json` contain no path referencing the build user's
   home in a non-portable form and no unresolvable `installPath`; a test commit **and** a test tag
   succeed (SC9); `cca doctor` reports no unknown items and no missing/wrong shared symlink; and
   `~/.claude-shared/keybindings.json` resolves to a real file.

The `keybindings.json` assertion is called out separately because `cca doctor` **cannot** catch it:
`cmd_doctor` checks only that each `SHARED_ITEMS` entry is a symlink whose *link text* matches
`../../.claude-shared/$item` — never that the target resolves. `rrp/keybindings.json` is a
correctly-pointed link to a nonexistent file and passes `cca doctor` silently today. That is precisely
why the bug survived, and it means SC10 is not sufficient cover for I6.

**Docker availability is not a bootstrap-ordering problem for `verify-fresh`**: it runs a container
*from the host*, and `docker-ce` is already installed there. `install-docker.sh` exists so a *future*
fresh box can reach the same state; `verify-fresh` exercises it inside the container without depending
on it.

### 4.13 Plugin manifest scope is bounded to user scope (round-2 Important)

`packages/claude-plugins.txt` ("marketplace source, plugin id, scope") cannot express what the live
state actually contains: multiple scopes per plugin, **project-scoped** installs keyed to a
`projectPath` outside this repo (`roof-report-pro-web`), git-SHA version strings (`hookify` →
`"unknown"` and `0b420de37255`), and duplicate records. Rather than grow the schema to model project
paths that will not exist on a fresh box:

**The manifest declares user-scope installs only.** Project-scoped plugin enablement is explicitly out
of scope — it belongs to the project directory, not to machine provisioning, and a fresh box has no
such directory to key on. `install-claude-plugins.sh` replays user-scope entries; project-scoped
plugins are re-enabled per project by whoever works in it. This is added to the brief's Non-Goals.
Consequence for the round-1 de-duplication (D7): dropping `superpowers@superpowers-marketplace` removes
both its user-scope record (whose `installPath` is already gone) and its project-scope record from the
declared set, which is the intended outcome.

### 4.14 `make restow` and `make unlink` are broken today and must be fixed (round-2 Important)

Two pre-existing Makefile bugs, both load-bearing for this design:

- **`restow:` is followed by a tab-indented recipe line `unlink link`**, so `make restow` runs the shell
  command `/usr/bin/unlink link` and fails — it does not run the `unlink` and `link` targets. I10's
  entire "review hook diffs before any `restow`" workflow assumes `restow` works.
- **`make unlink` bypasses `stow-all.sh`** with its own `find stow … | xargs stow -D {}` loop. So (a)
  the per-package `--no-folding` handling added in §4.1 is not mirrored on unlink, leaving link and
  unlink asymmetric for the `claude` package, and (b) unlike `stow-all.sh`'s forward loop it has **no
  `-not -name hosts` filter**, so it attempts `stow -D hosts` — never stowed as a package, since the
  overlays are stowed as `hosts/@common`, `hosts/$HOSTNAME`, `hosts/wsl`.

Fix: make `restow` a real `unlink link` prerequisite chain, and give unlink a single shared codepath
with link (an `unstow-all.sh`, or a mode flag on `stow-all.sh`) so package-specific flags and the
`hosts` exclusion cannot drift between the two directions. `Makefile` is already in Files-Touched; this
adds `unlink`/`restow` to its scope.

### 4.15 Remaining round-2 Important items folded in

- **Secret sweep covers everything newly tracked or modified, not only `stow/claude/**`.** R3 scoped it
  to the 47 harness files; it also applies to `stow/tmux/.tmux.conf` (adopted verbatim),
  `stow/bin/.local/bin/ccz`, `stow/ssh/.ssh/config`, `stow/mise/.config/mise/config.toml`,
  `stow/zsh/.zshrc`, and everything under `packages/` and `scripts/`. *(`stow/ssh/.ssh/config` has since
  been checked directly: a `Host *` default block and a commented-out `myserver.example.com` example —
  no real hostnames, ports, or `ProxyJump`. Only the `IdentityFile` line needs correcting.)*
- **The 9 incoming remote commits are swept before Task 0 merges them.** A `git merge` into a public
  branch is exactly as history-permanent as the `git add` that C6 guards, and it happens in unit 1 —
  *before* unit 2's `.gitignore` gate exists. Sweep them for secrets/tokens/IPs/hostnames first.
- **Both irreversible-op gates are scripted, not typed.** `scripts/assert-gitignore-safe.sh` loops the
  never-versioned list with `git check-ignore -q` and fails loudly; the archive `ls-remote` SHA match is
  likewise a script step. D16 explicitly rejects house style — a manually-typed sequence *is* house
  style.
- **A hook-diff gate is a mechanism, not a policy** — see §4.16, which supersedes this bullet's
  original `restow`-based proposal.
- **Installer ordering:** within `bootstrap.sh`, `install-cc-switcher.sh` runs before the harness steps.
  The full canonical order — including where `stow-all.sh` sits relative to `claude-profile-init.sh` and
  `install-claude-plugins.sh` — is **§4.12 steps 1–8 and only §4.12**. (An earlier draft of this bullet
  listed `stow-all.sh` last, which was wrong: `claude-profile-init.sh` creates per-profile symlinks
  pointing at `../../.claude-shared/*`, so the claude package must already be stowed or those links
  dangle on creation — the exact defect I6 documents.)
- **Tool-ownership rule resolves its own example.** §4.8's mechanism-based phrasing did not settle
  `bottom`. The disambiguating rule: **any tool with a maintained apt package is apt-owned regardless of
  whether a cargo/npm package also exists; mise is reserved for language runtimes and for tools apt does
  not package.** So `bottom` → apt (removed from mise), `eza` → apt if packaged on the target release
  else mise, `zellij`/`just` → mise. Cargo-direct binaries are removed either way.
- **`audit.sh` gains a fifth class:** binaries in `~/.cargo/bin` not attributable to a mise-managed
  install. Without it, "no direct cargo install" (SC3) is a one-time cleanup rather than an enforced
  invariant — the four existing classes structurally cannot see a tool that appears in neither list.
- **Path-reversal ownership disambiguated.** `claude-path-template.sh` is the general
  parameterizer/reverser for shell, hook, and skill files. `claude-profile-init.sh` additionally
  rewrites `settings.json`'s permission globs and `additionalDirectories` at profile-creation time **in
  the no-expansion branch only**. Files-Touched row for `claude-path-template.sh` is corrected
  accordingly.
- **`keybindings.json` is added to the Files-Touched enumeration** for
  `stow/claude/.claude-shared/**`, not only to §4.10 — the Design Contract is what downstream skills
  read first.
- **`.migration_backups/` restore path is named:** `scripts/merge-from-backup.sh` already exists in the
  repo for this purpose and is the documented rollback for a failed per-package reconciliation. The
  off-machine copy destination must be an existing private encrypted target — explicitly not another
  public remote or an unencrypted share.
- **`audit.sh` joins the `PLATFORM` consumer list** in Domain Types (it must union the three split
  lists per `$PLATFORM`).
- **D17 lists five units, not four** — a wording miscount, corrected in both documents.
- **SC1 gets a mechanical check:** each of the 3 local-only and 9 remote-only commits (or its content)
  is verified an ancestor of the merged `main` via `git merge-base --is-ancestor`, rather than "`git log`
  shows … reconciled".
- **Unit 5 is internally checkpointed** rather than one undivided step: vendor + template → D8
  relocation + replay → D7 collapse + superpowers de-dup → `keybindings.json` → final SC5/SC6/SC11
  verification. It is the only unit that writes into live `~/.claude-shared` / `~/.claude-accounts`
  state, so it gets the same staging rigor as the irreversible operations.
- **Per-package reconciliation is assigned to units.** Round 1 mapped only `git`→unit 1 and
  `zellij`→unit 3, leaving `nvim`, `zsh`, `env`, `bin`, `ssh`, `tmux` — including HC10's nvim
  precondition, the highest-risk item — unscheduled. They land in a new **unit 3.5 (per-package stow
  reconciliation)**, with HC10's commit-and-verify gate ordered first within it and §4.9's post-merge
  re-diff of `zsh`/`env`/`nvim` as its entry condition.

### 4.16 The hook gate must sit on the execution path, not on `make restow` (round-3 Critical)

Round 3 found that §4.15's original mitigation does not cover the vector I10 names. Because the `claude`
package is stowed `--no-folding`, **each hook is an individual symlink into the repo working tree**. So a
`git pull` that only changes a vendored hook's *contents* needs no `stow`, no `restow`, and no `link` —
the existing symlink already resolves to the new bytes, and the changed code auto-executes on the next
Claude Code session. A `restow` precondition guards a step that a content-only change never takes. The
mitigation was, in effect, unreachable.

The gate therefore moves onto the path that actually precedes execution:

1. A manifest of reviewed content — a hash over `stow/claude/.claude-shared/{hooks,skills,commands}/**`
   plus the commit SHA it was reviewed at — is stored outside the stowed tree (machine-local,
   gitignored).
2. A **session-start check** (a Claude Code `SessionStart` hook, and/or a check in
   `shell-integration.sh`, which is sourced by every new shell) recomputes that hash and, on mismatch,
   surfaces the diff and refuses to proceed silently — it does not matter whether `stow`, `restow`, or
   nothing at all was run in between.
3. `make restow` keeps a diff prompt as a convenience, but it is no longer the enforcement point.

Constraint on the implementation: the check must be cheap (a hash over ~47 small files) and must fail
**closed** in the sense of warning loudly, not fail open silently — the failure mode this whole item
exists to prevent. Note the bootstrapping subtlety: the checker itself lives in the versioned tree it
checks, so its own integrity rests on the same `git pull`. That is acceptable — the goal is to stop
*unnoticed* change, not to defend against an attacker who already controls the repo — but it should be
stated rather than implied.

An alternative the design explicitly does **not** adopt: routing pulls through a staging clone that is
diffed before merging into the checkout stow reads from. It is stronger, but it changes the daily git
workflow for every package, not just `claude`, and HC1/D18 already commit to living with a second
machine pushing to this repo.

### 4.17 Round-3 Important items

- **The `claude` CLI itself is never provisioned. — RESOLVED, see §4.18.** User decision: add the
  installer. `scripts/install-claude-cli.sh` is written and on the branch; the `doctor` check and the
  `bootstrap.sh` wiring are scheduled (deferred by HC2 — see §4.18). The Non-Goal branch is withdrawn,
  so §4.12 steps 3–4 stay unconditional and SC12 is genuinely exercised.
- **Two live `plugins/` entries are unclassified:** `.last_inuse_sweep` and
  `plugins/workflow-navigator.bak-20260724/` appear in neither the Versioned list, the
  gitignored-as-regenerable list, nor C6's never-versioned enumeration — the same unclassified-entry gap
  as `keybindings.json`. Both are machine-local runtime debris: add them to the gitignored set, and drop
  the `.bak` directory outright (D8 makes it obsolete). Better: generate
  `assert-gitignore-safe.sh`'s coverage from a scan of the live tree and **fail on any entry classified
  as neither versioned nor ignored**, so the next undocumented file cannot repeat this.
- **GPG signing inside the `verify-fresh` container needs a specified mechanism.** SC9 asserts a test
  commit and tag succeed while `commit.gpgsign`/`tag.gpgSign` are true. Do **not** copy the real secret
  key into a build context or image layer. Use a disposable container-local test key generated at run
  time and scope SC9 to "signing mechanics work end-to-end"; the real key's usability is verified once on
  the host in unit 1, not per container run.
- **The stray `~/.ssh/.id_ed25519.pub.swp` removal gets an assertion,** not just prose: unit 3.5 removes
  it and `verify-fresh`/the reconciliation script asserts `[[ ! -e ~/.ssh/.id_ed25519.pub.swp ]]`. Low
  severity — it shadows a *public* key — but it is the one ssh item stated without a check.
- **`verify-fresh` is scaffolded in unit 4 and completed in unit 5.** §4.12's steps 3–4 depend on
  unit-5 deliverables, so "unit 4 delivers verify-fresh" must not be read as delivering the full §4.12
  script. Unit 4 lands stow mechanics + `doctor` + package lists; unit 5 adds profile-init and the replay.
- **`install-apt.sh`'s cwd dependency** (`packages/apt.txt` relative, working only because
  `bootstrap.sh` `cd`s first) is fixed to `$DOTFILES_ROOT`-relative addressing while the file is being
  modified anyway for the `PLATFORM` split — matching `audit.sh`'s existing pattern.
- **Task 0 merge-conflict guidance:** if the merge produces textual conflicts in `zsh`/`env`/`nvim`,
  keep **both** sides' content pending unit 3.5's re-diff rather than dropping either — SC1's
  ancestry check protects commits, not content.
- **Starship's `curl | bash`** is reconsidered rather than merely noted: once `install-gh.sh` /
  `install-docker.sh` establish the pinned-fingerprint pattern, extending it to starship (checksum-pinned
  release, or provision via mise/apt) is cheap. If it is still left as-is, that is recorded as an accepted
  risk in the brief, not only in the design.
- **Unverified — for `codebase-scan` to resolve, not assumed here: BOTH RESOLVED**, see
  `codebase-scan.md` Part 1 and §4.18 below. (a) The container has **no `sudo` binary at all** (the
  `ubuntu` user is in group `sudo`, but the package is absent and `/etc/sudoers.d` does not exist) — so
  the Dockerfile provides it, and separately must create a user whose **UID differs from 1000**, because
  the stock `ubuntu` user shares `keenan`'s UID and would make SC6 pass by accident. (b) `cca` is fully
  non-interactive, but **`cca init` is the wrong entry point** — there is no `cca create`/`add`
  subcommand, `cmd_init` hardcodes the `kjweb`/`rrp` slugs, refuses once `~/.claude-shared` exists
  (which §4.12 step 2 creates), and under `--force` `rm -rf`s `~/.claude` and writes
  `accounts.json` **through its stow symlink into the tracked repo file**, breaking SC11. The correct
  primitive is the library function `cca::ensure_shell <slug>`, which honours `CCA_HOME`.
  Neither blocks unit 4/5.

### 4.18 Round-4 resolutions (user decisions, 2026-07-29)

Both items `codebase-scan.md` escalated are decided. This subsection is authoritative over §4.17's
original framing.

- **`cc-account-switcher` now has a remote — published private.** The scan found it had *no* remote and
  *no* tags, which blocked `install-cc-switcher.sh`, I11's pin, and SC10. It is now
  `github.com/FluxxField/cc-account-switcher`, **visibility private**, default branch renamed
  `master` → `main` (per Q1's `init.defaultBranch = main`; the design calls `master` "actively wrong on
  new repos"), with `feat/shared-and-routing` also pushed so no local-only work remains. **I11's pin
  target is tag `v0.1.0` = commit `0e66044`.** History was swept first: **no credentials, tokens, or
  keys anywhere in 27 commits** — but it does carry `keenan@kjweb.dev`, `keenan@roofreportpro.com`,
  `/home/keenan/…` paths and client names (`roofco`, `roof-report-pro`) across 9 files, which is why
  private was chosen over public. Private is also the reversible direction.
  - **Consequence for `verify-fresh` (new, must be planned):** a private remote **cannot be cloned
    anonymously**, so §4.12 step 1's `install-cc-switcher.sh` will fail inside the container. Do **not**
    inject a token into the build context — that is the same mistake §4.17 rejects for the GPG key.
    Instead `verify-fresh` feeds the switcher in from the host: a `git bundle` created from the pinned
    tag, or a read-only bind-mount of the clone, with `install-cc-switcher.sh` taking the source as a
    parameter (`CCA_SOURCE`, defaulting to the remote URL) so a real fresh box uses the remote and the
    container uses the bundle. SC10 is then satisfied without a credential ever entering an image layer.
- **The Claude Code CLI gets an installer.** `scripts/install-claude-cli.sh` is written, executable, and
  on the branch. It follows the repo's non-apt installer shape (`install-lazygit.sh`): `need curl`,
  early-exit idempotency, loud verification instead of `|| true`. Verified working: pinned-and-present
  is a no-op exit 0; an install that fails to produce a binary exits 1.
  - It resolves `$HOME/.local/bin/claude` **by path, not `command -v`**, because
    `shell-integration.sh:20` defines a `claude()` shell function (the cca wrapper) that shadows the
    binary in interactive shells.
  - **Supply chain is better than starship's, and SC16 should say so precisely.** Anthropic's
    `install.sh` downloads a per-platform manifest, extracts a SHA256, and **aborts on checksum
    mismatch**. So the unverified surface is the *script fetch* (TLS only), not the *payload*. This is
    materially stronger than `starship.rs/install.sh | bash`, which verifies nothing.
  - **The CLI is version-pinnable** — `install.sh` takes a `stable|latest|X.Y.Z` argument, surfaced as
    `CLAUDE_CLI_VERSION` (default `stable`). `verify-fresh` pins a concrete version for D9/I11
    reproducibility. Note the contrast with plugins: `claude plugin install` has **no** pin flag, so the
    manifest replay always takes marketplace-latest and that half of §4.12 cannot be made reproducible.
  - **Still to schedule (deferred, not forgotten):** wiring it into `bootstrap.sh`, adding a `claude`
    check to `doctor`, and the README row. **Deferred deliberately under HC2** — `origin/main` has 9
    unpulled commits and editing `bootstrap.sh`/`Makefile`/`README.md` before the fork merge manufactures
    avoidable conflicts. A brand-new file has no conflict surface, which is why the script itself could
    land now. The wiring belongs to unit 4 alongside the other installer wiring.
  - **PATH caveat that affects more than this check:** `doctor` runs under `SHELL := /usr/bin/env bash`
    (`Makefile:1`), a non-login shell that never sources `.zshrc` — where `~/.local/bin` is added
    (`stow/zsh/.zshrc:3`). So `doctor` only sees whatever PATH invoked `make`. Inside `verify-fresh`'s
    non-interactive run this affects the **existing** `starship`/`zoxide`/`node`/`go` checks too, not
    just `claude`; `verify-fresh` must export an explicit PATH or `doctor` fails for reasons unrelated to
    provisioning.

### 4.19 GPG signing is broken non-interactively, and the incoming `gnupg` package does not fix it

> Found while planning unit 1 (2026-07-29). Four coupled defects. This supersedes Q2's framing, which
> verified the signing key by *capability inspection* and never attempted an actual signature.

1. **Signing currently hangs, it does not merely fail.** `echo test | gpg --local-user
   6C32D9329BDB7DA9 --clearsign --batch` **times out**. `gpg-agent` *is* running
   (`/usr/bin/gpg-agent --supervised`, systemd socket-activated at
   `/run/user/1000/gnupg/S.gpg-agent`), the key has two keygrips and is **passphrase-protected with
   nothing cached**, and there is **no `~/.gnupg/gpg-agent.conf`** — so no `pinentry-program` and no
   cache TTL. In a TTY-less context the agent waits for a prompt that can never be answered.
   *(Caveat, stated rather than glossed: this was tested non-interactively only. An interactive terminal
   would likely prompt and succeed. The non-interactive path is the one that matters here.)*
   **Consequence:** unit 1 setting `commit.gpgsign = true` + `tag.gpgSign = true` globally makes **every
   non-interactive commit hang for the agent's timeout** — scripted commits, hook-driven commits, this
   project's own automation, and `verify-fresh`'s SC9 commit+tag. HC12 is therefore **not** satisfied by
   repointing `signingkey`; it needs a working agent + pinentry + cache configuration. Treat a hang, not
   a clean error, as the expected failure mode.
2. **The incoming `b2e95f8` is the intended fix and is load-bearing, not incidental.** §4.9 flagged it
   for review; its actual content is exactly the missing piece —
   `default-cache-ttl 86400`, `max-cache-ttl 31536000`, `pinentry-program /usr/bin/pinentry-curses`,
   plus `.zshrc`'s `export GPG_TTY=$(tty)` and `gpgconf --launch gpg-agent`.
3. **But the incoming package is mis-laid-out, so merging it changes nothing.** The file is at
   `stow/gnupg/gpg-agent.conf` — the *package root*. Stow packages mirror `$HOME`, so
   `stow -d stow -t $HOME gnupg` links it to **`~/gpg-agent.conf`**, not `~/.gnupg/gpg-agent.conf`, and
   `gpg-agent` never reads it. It must move to `stow/gnupg/.gnupg/gpg-agent.conf`. **This is a 9th stow
   package that arrives with Task 0** — `codebase-facts.md` lists 8 (`bin env git mise nvim ssh zellij
   zsh`) because `gnupg` exists only on `origin/main`. It has no row in the Section 3 reconciliation
   table and no entry anywhere in this design; add both.
4. **`pinentry-curses` is installed live but absent from `apt.txt`.** So a fresh box or the
   `verify-fresh` container gets no pinentry at all, and SC9's test commit hangs exactly as above. It
   joins `apt-common.txt` in unit 3, alongside `gnupg` and `lsb-release` (scan finding J).

Two guardrails this adds, both mirroring HC8's rule for `ssh`:

- **`~/.gnupg` holds live private key material** (`private-keys-v1.d/`, `pubring.kbx`,
  `openpgp-revocs.d/`). The `gnupg` package joins the **never-`--adopt`** list with `ssh`, and
  `stow-all.sh`'s existing `chmod 700 ~/.ssh` handling extends to `chmod 700 ~/.gnupg`. Scan finding
  **I** already requires `adopt-existing.sh` to gain an exclusion list — `gnupg` goes in it too.
- **SC9 inside the container** needs more than §4.17's "disposable container-local test key": it also
  needs `pinentry` present and a batch-friendly agent config (`--pinentry-mode loopback` with a
  scripted passphrase, or a passphraseless test key). Otherwise the container's test commit reproduces
  this exact hang and SC9 fails for an environmental reason.

**Related defect in the same incoming set — `a48b128`'s ssh-agent block.** §4.9 assigns `zsh` a
post-merge re-diff; the specific content it will find is:

```zsh
# SSH
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Three problems, all for unit 3.5 to resolve rather than merge verbatim into the shared `.zshrc`:
(a) it spawns a **new `ssh-agent` per shell** with no reuse check, leaking an agent process per
terminal; (b) `ssh-add` on a passphrase-protected key **prompts on every new shell**, and in a
non-interactive shell hangs — the same failure class as the GPG issue above, and a hazard for
`verify-fresh`, which starts shells non-interactively; (c) it hardcodes `id_ed25519` (Jan 2022) while
**I13 concluded the intended key is `id_rsa`** (Nov 2025), so the merged `.zshrc` and the corrected
`stow/ssh/.ssh/config` would disagree about which key is canonical. Guard it on
`[[ -z $SSH_AUTH_SOCK ]]` + interactive-shell detection, and settle the key question once for both files.

### 4.11 Factual corrections to Sections 1–3

- `.gitignore` is **not empty** (137 B) — `.worktrees/` and `.migration_backups/` already exist; only
  the harness-state rules are new.
- `~/.ssh` holds **three** private keys, not four (R1).
- **D10 is partially stale:** `asdf` is already off PATH; only a leftover `~/.asdf` directory remains,
  so the PATH-ordering bug cited is not currently live.
- The remote no longer has only `main` — `feat/harness-linux-migration` is already pushed. D11 remains
  purely additive.
- mise declares **8** uninstalled tools, not 7.
- The two root commits in `~/.dotfiles` (`d3bb970` "Initial commit", LICENSE only; `136f68a`
  "Squashed 'stow/nvim/.config/nvim/' content from commit 00b1f34") are **benign** — the second is the
  ordinary `git subtree add --squash` root. No `.git/shallow`, no `.git/info/grafts`, no replace refs.
  Task 0's plain `git merge origin/main` is unaffected and SC1 is not at risk from this.
- The symlink chain `~/.claude` → `~/.claude-accounts/<profile>` → `~/.claude-shared/*` is
  single-user-owned throughout; no privilege boundary is crossed. D8 is a correctness fix, not a
  security fix.

---

### 4.20 HC5 is already violated by the planning artifacts themselves (found 2026-07-29, round 5)

**This supersedes nothing in §4.1–§4.19; it adds a defect those rounds missed.**

The first real run of `scripts/sweep-secrets.sh --worktree` against this repo returned **36 hits**.
After discounting the deliberate test fixtures, the residue was the **real** `CC_NTFY_TOPIC` value and
the **real** Tailscale IP, quoted verbatim across eight tracked planning documents: `adversarial-review.md`,
`brief.md`, `codebase-facts.md`, `codebase-scan.md`, `design.md`, `plan-unit-1.md`, `plan-unit-2.md`.

The irony is the point: HC5 says *"no addressable endpoints in any tracked file"*, and §4.6 designs a
careful `${VAR}`-expansion scheme to keep the topic out of `settings.json` — while the documents
*describing* that scheme published the literal value to the same public remote. Three rounds of
adversarial review read those documents and none flagged it, because every reviewer was checking the
*designed artifact* against HC5 and nobody pointed HC5 at the *design*.

**Status of the exposure — this is a one-way door, and it is already through it.**

| | |
|---|---|
| Present on `origin/feat/harness-linux-migration` | **Yes** — pushed at `614e0c2`, before this session |
| Present on `origin/main` | No |
| Remediable by rewriting history | **No.** HC3 forbids force-push, and the branch is public |

**What was done:** both literals are redacted to `rrp-cc-<REDACTED>` / `<TAILSCALE-IP-REDACTED>` in all
eight documents, and the test fixtures were changed to obviously-fake values (a `fake`-infixed topic and
a `.99` host octet — not quoted here, because quoting them would trip the scanner in this very file,
which is the behaviour we want). This stops the leak compounding; it does **not** unpublish it.

**What is left for the user — the only real mitigation is rotation.** An ntfy topic is a bearer
credential in effect: anyone holding the string can publish notifications to the phone, and can
subscribe to read them. It is public, permanently, on a public remote. **Rotate `CC_NTFY_TOPIC` to a
fresh random value.** That is cheap (one `settings.json`-side value plus the phone subscription) and it
is the only action that actually revokes what was disclosed. The Tailscale IP is lower severity — it is
RFC-6598 CGNAT space, only reachable inside the tailnet, and is authenticated separately — but it should
be treated as disclosed network topology.

**Process change so this cannot recur:** `make sweep-secrets` runs over the whole worktree including
`docs/`, and the two fixture-bearing paths are exempted **by path** in an explicitly-labelled
`SWEEP_EXEMPT` list in the `Makefile`, never by value. The run always prints how many matches it
exempted, so a growing exemption count is visible rather than silent. **The sweep must be run against
the planning artifacts, not only against the code** — that is the specific gap this defect exposed.

---

### 4.21 §4.9's post-merge re-diff, executed — and `--adopt` on `zsh` would discard the merge

§4.9 requires a re-diff of `zsh`/`env`/`nvim` *after* the merge. The merge landed (`b70dd78`), so this
is that re-diff. None of the four merged config files is stowed yet; all four are real files that
diverge from the repo:

| Package file | Lines only in repo | Lines only in live |
|---|---|---|
| `stow/zsh/.zshrc` | **44** | 113 |
| `stow/mise/.config/mise/config.toml` | 14 | 0 |
| `stow/zellij/.config/zellij/layouts/web.kdl` | 7 | 5 |
| `stow/nvim/.config/nvim/lua/plugins/astrocore.lua` | 3 | 2 |

**The finding: `stow --adopt` on the `zsh` package would silently revert the merge.**

`--adopt` replaces the *repo* file with the *live* file. `stow/zsh/.zshrc` is one of the six files
`origin/main` just brought in, and its five substantive new lines were checked individually against the
live `~/.zshrc` — **all five are absent**:

```
# SSH
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
# GPG
gpgconf --launch gpg-agent
```

So adopting `zsh` would discard 44 repo-only lines including everything unit 1's merge just recovered —
and `gpgconf --launch gpg-agent` is part of the §4.19 signing fix. SC1 would still pass: it checks
commit *ancestry*, not content, exactly as §4.17 warned ("SC1's ancestry check protects commits, not
content"). The loss would be invisible to every existing gate.

**Consequences for unit 3.5.** The never-`--adopt` list is no longer just `ssh` (HC8) and `gnupg`
(§4.19). Reconciling `zsh` must be a **union merge**, hand-resolved, never `--adopt`. `mise` is the
opposite and safe: 14 repo-only lines and **0** live-only, so the repo is a strict superset and plain
stow is correct. `zellij` and `nvim` are small two-way diffs needing the same union treatment as `zsh`,
just far less of it.

**Note the ssh-agent defect rides along.** `eval "$(ssh-agent -s)"` in `.zshrc` spawns a *new* agent on
every shell (the `a48b128` defect §4.19 records). It is currently absent from live and present only in
the repo. Unit 3.5 should fix it while doing the union merge rather than faithfully propagating it —
but it must be a deliberate edit, recorded, not a silent drop that looks identical to the `--adopt`
data loss described above.
