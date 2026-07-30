# Codebase Facts — harness-linux-migration

> Pre-verified ground truth, gathered inline by the adversarial-review orchestrator on 2026-07-29.
> Critics receive ONLY this file + design.md + brief.md. Every line below was observed, not inferred.
> Where a design claim was checked, the verdict is marked **CONFIRMED**, **CORRECTED**, or **RESOLVED**
> (for an open question the design left unanswered).

## Repo identity & git state

- Repo: `~/.dotfiles`, remote `origin git@github.com:FluxxField/dotfiles.git`. No `dev` branch.
- Worktrees: `~/.dotfiles` on `main` @ `9df87f7`; `~/.dotfiles/.worktrees/feat/harness-linux-migration`
  on `feat/harness-linux-migration` @ `61b31a0`.
- `main` is an ancestor of the feature branch. The branch holds exactly 1 commit:
  `61b31a0 docs(plans): kickoff + design + brief …` (artifacts only; no code changed yet).
- **CONFIRMED** divergence: `git rev-list --left-right --count main...origin/main` → `3	9`.
  Local-only: `9df87f7` dev-services stack, `61b5bf8` audit script + apt sync, `9af57c0` cross-platform fixes.
  Remote-only, 9 commits: `a48b128` zsh ssh-agent, `b2e95f8` gpg-agent.conf, `14b692a` nvim win32yank,
  `226010f` env removed WINUSER, `ec0fa88` env WINUSR path, `080cbe0` nvim plugins, `432a8fa` zellij web
  layout, `3af1e20` merge commit, `3aaaa72` mise vercel global.
- **CORRECTED (design says the remote has only `main`):** `git ls-remote --heads origin` now shows TWO
  heads — `refs/heads/main` @ `a48b128` and `refs/heads/feat/harness-linux-migration` @ `61b31a0`.
  The feature branch is already pushed.
- **CONFIRMED** root-commit divergence, with added nuance: `~/.dotfiles` has **two** root commits
  (`136f68a9`, `d3bb9702`); the 2022 clone `~/github/dotfiles` has root `327614fb` — matching neither.
  `~/github/dotfiles` exists, HEAD `e4a76dc "added python and nvim python providers"`, same `origin` URL.

## Repo layout (feature worktree)

- `stow/` packages present (8): `bin env git mise nvim ssh zellij zsh`.
  **No `claude`, no `hosts`, no `tmux`** — CONFIRMED absent.
- `scripts/` (19 files + `win/`): `adopt-existing.sh audit.sh detect-os.sh ensure-locale.sh
  install-apt.sh install-brew.sh install-fonts.sh install-lazygit.sh install-mise-globals.sh
  install-mise.sh install-redis-stack.sh install-stripe.sh merge-from-backup.sh nvim-manager.sh
  nvim-subtree.sh ohmyzsh-install.sh set-default-shell-zsh.sh startup.sh wsl-post.sh`.
  **No `install-gh.sh`, `install-docker.sh`, `install-cc-switcher.sh`, `install-claude-plugins.sh`,
  `claude-profile-init.sh`, `verify-fresh.sh`** — CONFIRMED absent.
- `packages/`: `apt.txt`, `brew-Brewfile`. No split lists, no `claude-plugins.txt` — CONFIRMED absent.
- `win/windows-terminal/` and `scripts/win/{install-fonts.ps1,sync-windows-terminal.ps1}` exist
  (the WSL-era path the brief says is retained).

### **CORRECTED — `.gitignore` is NOT empty**

Design's Files-Touched row says ".gitignore | Currently **empty**. Add `.worktrees/`,
`.migration_backups/`, and the harness state exclusions." Actual content (137 bytes):

```
# Worktrees (one per feature branch)
.worktrees/

# Adoption safety net — snapshots of live files replaced by stow
.migration_backups/
```

Two of the three listed additions are already present. Only the harness-state exclusions are new.

### Makefile

Targets present: `help bootstrap startup link unlink restow adopt adopt-dry adopt-merge ensure-locale
ohmyzsh-install mise-install mise-install-globals nvim-subtree-pull nvim-subtree-push nvim-stable
nvim-nightly nvim-current fonts-linux fonts-windows audit install-stripe install-redis-stack doctor`.
**Absent:** `verify-fresh install-gh install-docker claude-plugins claude-profile-init` — CONFIRMED.

### **`make doctor` can never fail — it always exits 0**

```make
doctor:
	@command -v stow      >/dev/null || echo "MISSING: stow"
	… 12 such lines (stow zsh nvim mise starship lazygit zoxide eza rg fzf node go) …
	@echo "doctor done (no output = all present)"
```

Every check is `command -v … || echo`, so no non-zero exit is ever produced, and the final line prints
unconditionally. Observed live output on this machine:

```
MISSING: eza
doctor done (no output = all present)
```

— i.e. it reports a miss and simultaneously claims all present, and `$?` is 0.

### `stow-all.sh` — overlay selection does NOT use a platform variable

```bash
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT_DIR"
HOSTNAME=$(hostname)
for pkg in $(find stow -maxdepth 1 -mindepth 1 -type d -not -name hosts -printf "%f\n" | sort); do
  stow -d stow -t "$HOME" "$pkg"
done
[[ -d "stow/hosts/@common" ]]        && stow -d stow -t "$HOME" hosts/@common
[[ -d "stow/hosts/$HOSTNAME" ]]      && stow -d stow -t "$HOME" "hosts/$HOSTNAME"
grep -qi microsoft /proc/version && [[ -d "stow/hosts/wsl" ]] && stow -d stow -t "$HOME" hosts/wsl
[[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
[[ -d "$HOME/.ssh" ]]        && chmod 700 "$HOME/.ssh"
```

Notes: WSL detection is an inline `/proc/version` grep, not `$PLATFORM`. There is **no `linux` overlay
branch at all**. No `--no-folding` flag, so stow's default tree-folding applies (relevant to the
`stow/claude` design claim — folding links a whole directory when the target dir does not yet exist,
and descends to link individual entries only when the target dir already exists as a real directory).
`ROOT_DIR` is derived from the script's own location, so running it from the worktree stows from the
worktree. `chmod 700 ~/.ssh` runs unconditionally; private keys are not chmod'd.

### `scripts/detect-os.sh` — full current contents

```bash
#!/usr/bin/env bash
set -euo pipefail
OS="linux"; WSL="0"
[[ "$(uname -s)" == "Darwin" ]] && OS="mac"
grep -qi microsoft /proc/version 2>/dev/null && WSL="1"
export OS WSL
```

No `PLATFORM` — CONFIRMED. Note `set -euo pipefail` in a *sourced* file: `bootstrap.sh` does
`source scripts/detect-os.sh`, so those shell options leak into the caller.

### `bootstrap.sh` — order and platform branches

`cd "$(dirname "$0")"` → `source scripts/detect-os.sh` → stow install (brew on mac / apt on linux) →
`install-apt.sh` (linux only) → `ensure-locale.sh` → fonts (linux; + Windows fonts via `pwsh.exe`
when `WSL=1`) → `ohmyzsh-install.sh` → `install-mise.sh` → `install-mise-globals.sh` (comment says it
runs inside zsh so `.zshrc`/omz/mise activation are sourced) → `nvim-subtree.sh pull --auto` →
`nvim-manager.sh use stable` → `install-lazygit.sh` → starship via `curl | bash` →
`install-stripe.sh` → `install-redis-stack.sh` → `set-default-shell-zsh.sh` → `wsl-post.sh` if WSL.
Most steps are suffixed `|| true`. **No gh, docker, cc-switcher, or claude-plugins step.**

`scripts/set-default-shell-zsh.sh` runs `sudo chsh -s "$(command -v zsh)" "$USER" || true`.

`scripts/install-apt.sh` reads the **relative** path `packages/apt.txt` (depends on cwd = repo root),
runs `sudo apt update`, then `grep -v … | xargs sudo apt install -y`, then sets up `bat`/`fd`
alternatives.

`scripts/audit.sh` computes `DOTFILES_ROOT` from its own dirname and reports **four** classes:
apt.txt-not-installed, installed-not-in-apt.txt, mise-declared-not-installed,
mise-installed-not-declared. It runs `set -uo pipefail` deliberately without `-e`.

## Live machine state (WSL, hostname-scoped)

| Path | Actual state |
|---|---|
| `~/.zshrc` | REAL regular file (not a symlink) |
| `~/.gitconfig` | REAL regular file |
| `~/.tmux.conf` | REAL regular file, 48 lines |
| `~/.config/nvim` | REAL directory (git repo) |
| `~/.config/mise` | REAL directory |
| `~/.config/zellij` | REAL directory |
| `~/.config/dotfiles` | **ABSENT** |
| `~/.local/bin/nvimx` | **ABSENT** |
| `~/.local/bin/ccz` | REAL regular file (untracked helper) |
| `~/.ssh/config` | **ABSENT** |
| `~/.aws` | SYMLINK → `/mnt/c/Users/Keenan/.aws` |
| `~/.azure` | SYMLINK → `/mnt/c/Users/Keenan/.azure` |

Nothing is stowed — CONFIRMED.

`~/.ssh` contents: private keys `id_ed25519` (0600, Jan 2022), `id_rsa` (0600, Nov 2025),
`enduring-laptop` (0600, Jul 2023) — **three** private keys, not four; plus `.pub` files (0644),
`authorized_keys` (0600), `known_hosts`, `known_hosts.old`, and a stray
`.id_ed25519.pub.swp` (0644, 12k, Jan 2022). R1's count of "four private keys" is off by one unless
the `.swp` or `authorized_keys` is being counted.

### **RESOLVED — Q2: the declared GPG signing key is NOT in the keyring**

`stow/git/.gitconfig` declares `signingkey = 665F3EDCE9AB996D` with `commit.gpgsign = true` **and**
`tag.gpgSign = true`. The only secret key present:

```
sec   rsa3072/6C32D9329BDB7DA9 2024-03-15 [SC]
      327EE4D3BFA642EFB1340F1C6C32D9329BDB7DA9
uid   [ultimate] Keenan Johns (Github Account) <keenanjj13@gmail.com>
ssb   rsa3072/22CCA793A5FD9571 2024-03-15 [E]
```

`665F3EDCE9AB996D` does not appear in `gpg --list-secret-keys`. Stowing the repo `.gitconfig` unchanged
makes every `git commit` and `git tag` on this machine fail immediately.

### **RESOLVED — Q1: the keyring's uid email is `keenanjj13@gmail.com`**

Live `~/.gitconfig`:
```
[user] email = keenanjj13@gmail.com / name = Keenan
[init] defaultBranch = master
[credential "https://github.com"]   helper = ; helper = !/usr/bin/gh auth git-credential
[credential "https://gist.github.com"] helper = ; helper = !/usr/bin/gh auth git-credential
```
Repo `stow/git/.gitconfig`: `name = Keenan Johns`, `email = keenanjj13@protonmail.com`,
`signingkey`, `commit.gpgsign=true`, `tag.gpgSign=true`, `gpg.program=gpg`, `core.editor=nvim`,
`core.excludesfile=~/.gitignore_global`, `core.autocrlf=input`, `pull.rebase=false`,
`init.defaultBranch=main`, `merge.tool=nvimdiff`, `diff.tool=nvimdiff`. It has **no** credential
helper. `stow/git/.gitignore_global` exists in the repo; `~/.gitignore_global` is ABSENT live.

### **RESOLVED — Q6: `~/.config/nvim` HAS uncommitted work**

`git -C ~/.config/nvim status --short` returns modifications (≥8 files shown before the head cap):
`lazy-lock.json`, `lua/community.lua`, `lua/consts/language_packs.lua`,
`lua/plugins/{astrocore,astrolsp,autocmds,blink,init}.lua`. HEAD is `0bf7e19 chore: updated plugins`.
So the 17-file divergence includes genuinely uncommitted changes. `scripts/nvim-subtree.sh` uses
`PREFIX="stow/nvim/.config/nvim"` and reads `subtree.nvim.{remote,url,branch}` from git config.

### **PARTIALLY STALE — D10: `asdf` is already off PATH**

`command -v asdf` → not found. `~/.asdf` directory still exists. So the PATH-ordering bug D10 cites is
not currently live; only the leftover directory remains.

### mise: 13 declared, 5 installed — and the gap is not what the design assumes

Repo `stow/mise/.config/mise/config.toml` `[tools]`: `cargo-binstall`, `cargo:bottom`, `cargo:eza`,
`cargo:just`, `cargo:ripgrep_all`, `cargo:zellij`, `go`, `node=lts`,
`npm:@mermaid-js/mermaid-cli`, `npm:npm`, `npm:tree-sitter-cli`, `npm:typescript`, `rust`
(13 entries; design says 7 uninstalled, actual count is **8**).
Live `~/.config/mise/config.toml` `[tools]`: `cargo:ripgrep_all`, `go`, `node=lts`, `npm:npm`, `rust`.
`mise ls --installed`: `cargo:ripgrep_all`, `go` (3 versions), `node` (2), `npm:npm`, `rust`.

Cross-manager duplication and third-party installs the design does not account for:
- `bottom` is declared in **both** `packages/apt.txt` and mise (`cargo:bottom`), and is **absent** from PATH.
- `zellij` is declared in mise but actually installed at `~/.cargo/bin/zellij` (direct cargo, not mise).
- `eza` is declared in mise, is checked by `make doctor`, and is **absent**; what exists is the
  predecessor `exa` at `~/.cargo/bin/exa` (`ls` in this shell resolves to it — `ls -A` errors with
  "exa: Unknown argument -A"). `eza`/`exa` appear in neither `apt.txt` nor as a mise-installed tool.
- `just` is declared in mise and absent from PATH.

### apt.txt — 42 entries; the 24-untracked claim spot-checked

Contents: `build-essential htop zsh stow ripgrep fzf fd-find bat curl wget unzip zip make python3-pip
fonts-powerline zoxide pandoc poppler-utils ffmpeg git fontconfig xdg-utils ghostscript
texlive-latex-base texlive-latex-recommended texlive-extra-utils gdu luarocks lua5.4 imagemagick
bottom cloc cmake pkg-config rsync sqlite3 tmux mysql-client mysql-server postgresql
postgresql-contrib redis`.

All 11 spot-checked packages are dpkg-INSTALLED and absent from `apt.txt` — **CONFIRMED**:
`docker-ce gh jq tailscale syncthing stripe redis-stack-server awscli mosh tesseract-ocr openjdk-11-jdk`.
Note `apt.txt` lists `redis` while `redis-stack-server` is what is installed.

### README

References `stow/hosts/` at lines 124, 223, 397, 537, 538, 539, 577 (`@common`, `$(hostname)`, `wsl`)
— a tree that has never existed. Line 564: "The following require external repo setup not yet
scripted — install manually on a new machine:". Both CONFIRMED.

### `stow/env` and `stow/bin` current contents

`stow/env/.config/dotfiles/env.sh` (**tracked today**) exports only:
`DOTFILES_STARTUP_AUTO_UPGRADE=0`, `DOTFILES_STARTUP_INTERVAL_HOURS=24`, `DOTFILES_INSTALL_FONTS=1`,
`LANG`, `LC_ALL`, `GOPATH`, `PATH`. **No `CC_NTFY_TOPIC`, no Tailscale host.** There is no
`env.sh.example` in the repo.
`stow/bin/.local/bin/nvimx` is the only file in `stow/bin`.

`~/.local/bin/ccz` (untracked, `#!/usr/bin/env zsh`) — the Tailscale IP `100.114.199.<REDACTED>` appears
**only inside a comment** (`ssh keenan@100.114.199.<REDACTED>  then  zellij attach <name>`); the executable
logic is `git rev-parse --abbrev-ref HEAD` → `zellij attach --create "$slug"`. R2 CONFIRMED as an
exposure, with the nuance that it is a comment, not a functional dependency.

## Claude Code harness — live state

`~/.claude` is a SYMLINK → `/home/keenan/.claude-accounts/rrp` (the active-profile switch).
Accounts: `~/.claude-accounts/{rrp,kjweb}`.

Full `~/.claude-shared` inventory (15 entries, nothing else):
`accounts.json agents/ CLAUDE.md commands/ handoffs/ hooks/ plugins/ routes settings.json
settings.json.bak-20260723-103211 settings.json.bak2-105016 settings.local.json
shell-integration.sh skills/ statusline.sh`

Counts — **CONFIRMED**: `skills` 17, `hooks` 16, `commands` 10, `agents` 4.
`CLAUDE.md` 13k, `settings.json` 8.2k, `settings.local.json` 705 B, `statusline.sh` 1.2k (executable),
`shell-integration.sh` 1.2k, `accounts.json` 163 B, `routes` 40 B.

**There is no `local-marketplace/` in `~/.claude-shared`.** It exists at
`~/.claude-accounts/rrp/local-marketplace` (and therefore at `~/.claude/local-marketplace` via the
profile symlink) — D8's premise CONFIRMED.

`routes` full contents: `/home/keenan/github/roof-report-pro	rrp` (one tab-separated line).

`accounts.json`: `{"kjweb": {label KJ, color cyan, expectedEmail keenan@kjweb.dev},
"rrp": {label RRP, color magenta, expectedEmail ""}}`.

### settings.json divergence — exactly 2 entries

`~/.claude-accounts/rrp/settings.json` is a **REAL file** (8274 B).
`~/.claude-accounts/kjweb/settings.json` is a **SYMLINK** → `../../.claude-shared/settings.json`
(so kjweb and shared are literally the same file).

`diff rrp/settings.json ~/.claude-shared/settings.json`:
```
309,311c309
<     "vercel@claude-plugins-official": true,
<     "superpowers@superpowers-marketplace": true,
<     "workflow-navigator@local": true
---
>     "vercel@claude-plugins-official": true
```
That is the **only** difference in the file. Shared/kjweb `enabledPlugins`:
`typescript-lsp@claude-plugins-official, superpowers@claude-plugins-official,
rust-analyzer-lsp@claude-plugins-official, frontend-design@claude-plugins-official,
hookify@claude-plugins-official, vercel@claude-plugins-official`. D7 CONFIRMED (2 extra entries,
3 changed lines).

### **Q4 nuance — the two superpowers installs come from different marketplaces**

`rrp` enables `superpowers@superpowers-marketplace`; shared/kjweb enables
`superpowers@claude-plugins-official`. Collapsing `rrp/settings.json` into shared (D7) therefore does
not merely "restore sharing" — it makes **both** superpowers sources enabled for **both** profiles,
which is the duplicate-skill-source condition Q4 flags, propagated rather than resolved.

### `cc-account-switcher` — the sharing contract

`~/github/cc-account-switcher/lib/cca-lib.sh:18`:
```bash
SHARED_ITEMS=(CLAUDE.md settings.json settings.local.json keybindings.json plugins agents commands hooks skills)
ACCOUNT_ITEMS=(.credentials.json .claude.json projects todos statsig shell-snapshots history.jsonl stats-cache.json debug stats file-history paste-cache)
IGNORED_ITEMS=(backups cache session-env sessions .last-cleanup)
```
`ROUTES_FILE="$SHARED_DIR/routes"`. An in-file comment records that `skills` was missing from
`SHARED_ITEMS` until 2026-07-23 and warns: "Anything omitted from BOTH lists is invisible to
init/ensure_shell/doctor — see `cca::is_known_item`."

**`local-marketplace` appears in none of the three lists** — it is exactly the blind-spot class that
comment describes.

`rrp` profile symlinks (→ `../../.claude-shared/…`): `agents CLAUDE.md commands hooks
keybindings.json plugins settings.local.json skills`. Real per-account: `.claude.json`
`.credentials.json` `settings.json` `backups/ cache/ daemon/ debug/ file-history/ history.jsonl
jobs/ local-marketplace/ paste-cache/ projects/ session-env/ sessions/ shell-snapshots/` plus
`.last-cleanup .last-update-result.json daemon.lock daemon.log daemon.status.json
mcp-needs-auth-cache.json`.

### **NEW — `keybindings.json` is an already-dangling shared symlink**

`~/.claude-accounts/rrp/keybindings.json` → `../../.claude-shared/keybindings.json`, and
**`~/.claude-shared/keybindings.json` does not exist**. It is in `SHARED_ITEMS`. The design's versioned
list for `stow/claude/.claude-shared/` does not mention `keybindings.json` at all.

### Plugin state

`~/.claude-shared/plugins/` contents: `.last_inuse_sweep blocklist.json (0600) cache/ data/
installed_plugins.json (5.3k) known_marketplaces.json (807 B) marketplaces/
plugin-catalog-cache.json (407k, 0600) workflow-navigator → /home/keenan/.claude/local-marketplace/plugins/workflow-navigator
workflow-navigator.bak-20260724/`

The `workflow-navigator` symlink routing through `~/.claude` — CONFIRMED, as is the `.bak` sibling.

`known_marketplaces.json` in full:
- `claude-plugins-official` → github `anthropics/claude-plugins-official`,
  installLocation `/home/keenan/.claude/plugins/marketplaces/claude-plugins-official`
- `superpowers-marketplace` → github `obra/superpowers-marketplace`,
  installLocation `/home/keenan/.claude/plugins/marketplaces/superpowers-marketplace`
- `local` → source `file`, path `/home/keenan/.claude/local-marketplace/.claude-plugin/marketplace.json`,
  installLocation `/home/keenan/.claude/local-marketplace`

All three route through `~/.claude`. The first two land in shared anyway (because `plugins` **is** a
per-profile symlink to shared); only `local` breaks under `kjweb`, because `local-marketplace` is not
shared. D8's root-cause analysis CONFIRMED.

### **NEW — hardcoded `/home/keenan` inside files slated for VERSIONING**

Success criterion 6 requires "no absolute `/home/keenan` path in any tracked file". Counts of files/
occurrences containing `/home/keenan` among the artifacts the design puts under `stow/claude`:

| Versioned target | `/home/keenan` hits |
|---|---|
| `settings.json` | **6 occurrences** |
| `hooks/` | **4 of 16 files** — `continuous-learning.sh`, `session-stats.sh`, `wip-snapshot.sh`, `context-pressure.sh` |
| `skills/` | **3 files** |
| `local-marketplace/` | **1 file** |
| `settings.local.json`, `CLAUDE.md`, `statusline.sh`, `shell-integration.sh`, `accounts.json` | 0 |
| `commands/`, `agents/` | 0 |

The `settings.json` occurrences (lines 132-136, 195):
```
"Read(//home/keenan/**)", "Read(//home/keenan/github/**)", "Read(//home/keenan/.claude/**)",
"Edit(//home/keenan/github/**)", "Edit(//home/keenan/.claude/**)"
…
"/home/keenan/github"          ← additionalDirectories
```
D6 gitignores only the *machine-state JSON* (`installed_plugins.json`, `known_marketplaces.json`,
`plugin-catalog-cache.json`, caches). It does not address absolute paths inside the versioned files.

`shell-integration.sh` is already portable — it uses `"${CCA_HOME:-$HOME}/.claude-accounts"`.

`CC_NTFY_TOPIC` confirmed at `~/.claude-shared/settings.json:3` = `rrp-cc-<REDACTED>`, inside the
`env` block of a file the design versions.

### **NEW (round-1 follow-up) — `installed_plugins.json` is already 4/14 broken**

Full record dump (`plugins` map, 14 records). `EXISTS`/`MISSING` = whether `installPath` resolves:

| Plugin key | scope | version | installPath root | |
|---|---|---|---|---|
| `typescript-lsp@claude-plugins-official` | user | 1.0.0 | `~/.claude` | EXISTS |
| `superpowers@claude-plugins-official` | user | 6.1.1 | `~/.claude` | EXISTS |
| `superpowers@superpowers-marketplace` | project | 4.2.0 | `~/.claude` | EXISTS |
| `superpowers@superpowers-marketplace` | user | 6.1.1 | `~/.claude-accounts/.shared-rrp.33991` | **MISSING** |
| `frontend-design@claude-plugins-official` | project | `0b420de37255` | `~/.claude-accounts/.shared-rrp.59780` | **MISSING** |
| `frontend-design@claude-plugins-official` | project | `0b420de37255` | `~/.claude-accounts/rrp` | EXISTS |
| `frontend-design@claude-plugins-official` | user | `0b420de37255` | `~/.claude-accounts/.shared-rrp.59780` | **MISSING** |
| `rust-analyzer-lsp@claude-plugins-official` | user | 1.0.0 | `~/.claude` | EXISTS |
| `workflow-navigator@local` | project | 1.0.0 | `~/.claude` | EXISTS |
| `workflow-navigator@local` | project | 1.0.0 | `~/.claude` | EXISTS (duplicate record) |
| `hookify@claude-plugins-official` | project | `unknown` | `~/.claude` | EXISTS |
| `hookify@claude-plugins-official` | user | `0b420de37255` | `~/.claude-accounts/.shared-rrp.59780` | **MISSING** |
| `vercel@claude-plugins-official` | user | 0.44.0 | `~/.claude-accounts/rrp` | EXISTS |

Material observations:

1. **`~/.claude-accounts/.shared-rrp.*` does not exist at all** (`ls -d /home/keenan/.claude-accounts/.shared-rrp.*` → no matches). Four records point into ephemeral shared-dir paths left over from `cca` profile switching. This state is **already partly broken before the migration starts** — strong independent support for D6 (regenerate, do not copy).
2. **The two superpowers installs are the same upstream commit.** `superpowers@claude-plugins-official` 6.1.1 and `superpowers@superpowers-marketplace` 4.2.0 both record
   `gitCommitSha: a98c5dfc9de0df5318f4980d91d24780a566ee60`. The version labels differ because the two
   marketplace manifests label the same commit differently. De-duplicating is therefore safe — it is
   literally the same code, not two variants.
3. **Q4 undercounts.** The design describes two superpowers installs (official user-scope, marketplace
   project-scope). There are **three records**, and **two are user-scope** — the extra being
   `superpowers@superpowers-marketplace` user/6.1.1, whose `installPath` is already gone.
4. **`vercel@claude-plugins-official` resolves under `~/.claude-accounts/rrp`, not `~/.claude`.** It is
   enabled in shared (hence for `kjweb` too), but its cache lives inside the `rrp` profile — a second
   instance of the exact per-profile-path-for-shared-content bug D8 diagnoses for `local-marketplace`.
   Same for one `frontend-design` record.
5. `workflow-navigator@local` has a **duplicate** project-scope record; `hookify` carries
   `version: "unknown"` and a git SHA (`0b420de37255`) used as a version string.

### GPG key `6C32D9329BDB7DA9` — usability confirmed

`gpg --list-secret-keys --with-colons`: `sec:u:3072:1:6C32D9329BDB7DA9:1710522857:::u:::scESC:::+:::23::0:`
— capability field `scESC` includes **s** (sign) and **c** (certify); the expiry field is empty (**no
expiry**); trust `u` = ultimate. `pub rsa3072/6C32D9329BDB7DA9 2024-03-15 [SC]`, uid
`Keenan Johns (Github Account) <keenanjj13@gmail.com>`, encryption subkey `22CCA793A5FD9571 [E]`.

**Not verifiable from this session:** whether the public key is registered on GitHub.
`gh api user/gpg_keys` returns 404 — the token lacks the `admin:gpg_key` scope, and adding a scope is
the user's call. Check with:
`gh auth refresh -h github.com -s admin:gpg_key && gh api user/gpg_keys`.

### **NEW (round-2 follow-up) — `make restow` is broken and `make unlink` bypasses `stow-all.sh`**

`cat -A` of the Makefile confirms `restow:` is followed by a **tab-indented recipe line**, not
prerequisites:

```
restow:$
^Iunlink link$
```

So `make restow` runs the shell command `unlink link` (coreutils `/usr/bin/unlink` against a file named
`link`), which fails — it does **not** run the `unlink` and `link` targets. Pre-existing bug.

`make unlink` has its **own** stow loop that does not go through `stow-all.sh`:

```make
unlink:
	find stow -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | xargs -I{} stow -d stow -t $$HOME -D {}
```

Two consequences: (1) any per-package flag handling added to `stow-all.sh` (e.g. `--no-folding` for
`claude`) is **not** mirrored here, so unlink is asymmetric with link; (2) unlike `stow-all.sh`'s
forward loop, this one has **no `-not -name hosts` filter**, so it attempts `stow -D hosts` — a
directory that was never stowed as a package (the overlays are stowed as `hosts/@common`,
`hosts/$HOSTNAME`, `hosts/wsl`). `make link` does call `bash stow-all.sh`.

### **NEW (round-2 follow-up) — `cca doctor` scan scope, and why it missed `keybindings.json`**

`cca::untracked_items()` (cca-lib.sh) scans **only the per-account directory**:

```bash
cca::untracked_items() { # <slug>
  local dir e; dir="$(cca::account_dir "$1")"      # = $ACCOUNTS_DIR/$slug
  [ -d "$dir" ] || return 0
  while IFS= read -r e; do
    cca::is_known_item "$e" || printf '%s\n' "$e"
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
}
```

It does **not** scan `~/.claude-shared`. Two consequences for the design:

1. **D8 is achievable without touching `cc-account-switcher`.** Moving `local-marketplace` out of
   `~/.claude-accounts/rrp/` into `~/.claude-shared/` makes the unknown-item warning disappear on its
   own, because the scan only looks at the account dir. Nothing needs adding to `SHARED_ITEMS`, so the
   Non-Goal boundary holds.
2. **`cmd_doctor` cannot detect a dangling shared symlink.** For each `SHARED_ITEMS` entry it checks
   only `[ ! -L "$dir/$item" ] || [ "$(readlink …)" != "../../.claude-shared/$item" ]` — link presence
   and link *text*, never whether the target resolves. `rrp/keybindings.json` is a correctly-pointed
   symlink to a file that does not exist, so it passes `cca doctor` silently. That is why the bug went
   unnoticed, and it means SC10 (`cca doctor` clean) will **not** catch it — `keybindings.json` needs
   its own explicit criterion.

Also confirmed from `cmd_doctor`: it already reports `PROBLEM: rrp/settings.json symlink missing/wrong`
today, because `settings.json` is in `SHARED_ITEMS` and `rrp`'s is a real file — independent
confirmation of D7's premise. And its header comment records that a dangling `~/.claude` default link
"is how all 14 hooks broke on 2026-07-23".

### **NEW (round-2 follow-up) — `stow/ssh/.ssh/config` carries no network topology**

Full content: a header comment, one `Host *` block (`AddKeysToAgent yes`,
`IdentityFile ~/.ssh/id_ed25519`, `ServerAliveInterval 60`, `ServerAliveCountMax 3`), and a
**commented-out** example host (`myserver.example.com`). No real hostnames, ports, or `ProxyJump`
entries. The only correction it needs is the `IdentityFile` line. No endpoint-exposure concern.

## Tracked→gitignored transitions the design implies

Two files are **currently tracked** but designed to become gitignored-with-a-committed-`.example`:
- `stow/env/.config/dotfiles/env.sh` (tracked now; no `.example` exists)
- `~/.claude-shared/routes` (not yet tracked; `routes.example` does not exist)

After the transition a fresh clone contains no real `env.sh` / `routes`, so `stow env` and the claude
package have no file to link unless something copies the `.example` into place first. No such copy
step exists in `bootstrap.sh`, `stow-all.sh`, or the Makefile today.
