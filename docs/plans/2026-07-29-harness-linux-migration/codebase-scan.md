# Codebase Scan — Dotfiles Harness Ownership + Native-Linux Provisioning

**Date:** 2026-07-29
**Design:** `docs/plans/2026-07-29-harness-linux-migration/design.md` (revision 4; §4 authoritative)
**Facts:** `docs/plans/2026-07-29-harness-linux-migration/codebase-facts.md` (505 lines, pre-verified)
**Repo:** `~/.dotfiles`, worktree `.worktrees/feat/harness-linux-migration` @ `614e0c2`

> **Scope note.** `codebase-facts.md` already holds verified ground truth for `stow-all.sh`,
> `detect-os.sh`, `bootstrap.sh` ordering, `doctor`, `unlink`/`restow`, `apt.txt`, both `.gitconfig`s,
> the mise config, `cca-lib.sh` + `cmd_doctor`, `known_marketplaces.json`, the full
> `installed_plugins.json` dump, and `stow/ssh/.ssh/config`. **This scan does not restate those.** It
> answers the two questions the review deferred here, resolves the §4.17 CLI gap, and records what
> only reading the *remaining* files surfaced — including four findings that change unit 4/5 scope.
>
> Everything below was executed or read, not inferred. Corrections to `codebase-facts.md` are marked
> **CORRECTS**.

---

## Part 1 — The three items handed to this phase

### Q1. Does the `verify-fresh` container's non-root user have passwordless sudo?

**Answer: no, and it is ours to provide — not a blocker.** Verified against a real `ubuntu:24.04` pull.

| Fact | Observed |
|---|---|
| uid/gid 1000 exists | `ubuntu:x:1000:1000:Ubuntu:/home/ubuntu:/bin/bash` |
| `ubuntu` already in `sudo` group | `sudo:x:27:ubuntu` |
| `sudo` **binary** | **ABSENT** |
| `/etc/sudoers.d` | **does not exist** |
| TTY | `tty` → `not a tty`, rc=1 |

So the Dockerfile must `apt-get install -y sudo` **and** write a NOPASSWD drop-in. All four consumers
(`install-apt.sh`, `install-gh.sh`, `install-docker.sh`, `set-default-shell-zsh.sh`) then work
non-interactively.

**Second constraint the answer exposes:** SC6 requires the container's **username *and* UID differ
from the live machine's**. Live is `keenan`, **uid 1000**. The stock `ubuntu` user is *also* uid 1000
— reusing it satisfies "different username" and silently fails "different UID". The Dockerfile must
create a distinct user (e.g. `builder`, uid 1234), not reuse `ubuntu`.

Minimum bootstrap set the Dockerfile must install — **every one of these is absent from `ubuntu:24.04`**
and cannot be self-provisioned:

| Binary | Absent | Why it can't come later |
|---|---|---|
| `sudo` | ✓ | `install-apt.sh` needs it to run at all — chicken-and-egg |
| `curl` | ✓ | needed before `install-apt.sh` (starship, repo keys) |
| `git` | ✓ | repo must be present before anything runs |
| `gpg` | ✓ | `gpg --dearmor` in both existing repo installers; **and SC9's signing** |
| `python3` | ✓ | `cca::json_get` and the session parser in `cca-lib.sh` |
| `lsb_release` | ✓ | `install-redis-stack.sh:28` — see finding **J** |
| `make`, `stow`, `zsh`, `locale-gen` | ✓ | reachable via `apt.txt`, but `make doctor`/`make audit` (§4.12 steps 6–7) need `make` |

### Q2. Does `cca` support fully non-interactive profile creation in a TTY-less container?

**Answer: yes mechanically — but `cca init` is the wrong entry point, and using it would break SC11.**

*Non-interactivity confirmed.* Grepping `bin/cca`, `lib/cca-lib.sh`, `install.sh` for
`read`/`tty`/`/dev/tty`/prompt/confirm returns **only** loop reads from files and pipes. No prompt, no
`/dev/tty`. TTY-less is fine.

*But there is no profile-creation subcommand.* `bin/cca` subcommands are exactly:
`init launch status login use sessions convos orphans route go handoff resume doctor`. **There is no
`cca create` / `cca add`.** And `cmd_init` (`bin/cca:9-74`) is a one-time *legacy migration*, not
provisioning — it **hardcodes** the slugs `kjweb` and `rrp` (`bin/cca:47`, `:60`).

Three ways `cca init` breaks inside `verify-fresh`:

1. **It refuses when `$SHARED_DIR` exists** (`bin/cca:16-19`) — and §4.12 **step 2** creates
   `~/.claude-shared` via §4.1's `mkdir -p`. So by step 3 it always refuses.
2. **`--force` then writes into the repo working tree.** `ACCOUNTS_JSON="$SHARED_DIR/accounts.json"`
   (`cca-lib.sh:8`), and `accounts.json` is in the design's **Versioned** list — after stow it is a
   symlink into the repo. `cmd_init`'s `cat > "$ACCOUNTS_JSON"` (`bin/cca:64`) writes **through the
   symlink into the tracked file**, breaking SC11's `git status --porcelain`-clean assertion. It also
   `rm -rf`s `~/.claude` (`bin/cca:59`).
3. It refuses while a `claude` process is running (`cca::claude_running`). Bypass exists:
   `CCA_CLAUDE_RUNNING=0`.

**The primitive `claude-profile-init.sh` actually wants is the library function
`cca::ensure_shell <slug>`** (`lib/cca-lib.sh`) — non-interactive, idempotent, creates all 9
`SHARED_ITEMS` symlinks as `../../.claude-shared/$item`, and warns (does not clobber) when a real file
is in the way:

```bash
cca::ensure_shell() { # <slug>
  dir="$(cca::account_dir "$1")"; mkdir -p "$dir"
  for item in "${SHARED_ITEMS[@]}"; do
    target="../../.claude-shared/$item"
    if [ -L "$dir/$item" ]; then ln -sfn "$target" "$dir/$item"
    elif [ -e "$dir/$item" ]; then echo "WARN: … real file, not a symlink — leaving as-is" >&2
    else ln -s "$target" "$dir/$item"; fi
  done
}
```

So `claude-profile-init.sh` should `source .../lib/cca-lib.sh` and call `cca::ensure_shell`, honouring
`CCA_HOME` (`cca-lib.sh:3` — `CCA_HOME="${CCA_HOME:-$HOME}"`, so a synthetic profile root is a
one-variable change). This also confirms **I6 is fixed by versioning `keybindings.json`**:
`ensure_shell` creates that symlink unconditionally, so the target existing is the whole fix.

### Q3. §4.17 — the Claude Code CLI is never provisioned

**Resolvable; recommend the installer, not the Non-Goal.** The real binary is
`~/.local/bin/claude` → `~/.local/share/claude/versions/2.1.220` (three versions retained:
`2.1.218/219/220`). That is Anthropic's **native-installer** layout — not npm (`npm ls -g` has no
claude), not mise, not `/usr/local/bin`, and there is no `~/.claude/local`. Note `command -v claude`
resolves to a **shell function**, not the binary — defined at `~/.claude-shared/shell-integration.sh:20`
(the `cca` wrapper that prints `→ rrp (default)`).

Recommendation: add `scripts/install-claude-cli.sh` following the *existing* starship precedent in
`bootstrap.sh:67` (`curl -fsSL … | bash`) plus a `doctor` check — closing §4.17 without the
"Non-Goal + make §4.12 steps 3–4 conditional" branch, which would leave SC12 untested on a fresh box.

> **✅ DONE (user decision, 2026-07-29).** Script written, executable, verified. Two facts from actually
> reading `https://claude.ai/install.sh` (HTTP 200, 7984 B) that improve on the recommendation above:
> **(1) it is version-pinnable** — it takes a `stable|latest|X.Y.Z` argument, surfaced as
> `CLAUDE_CLI_VERSION`, so `verify-fresh` can pin for D9/I11 reproducibility; **(2) it is not in
> starship's risk class** — it downloads a per-platform manifest, extracts a SHA256, and **aborts on
> checksum mismatch**, so the payload is verified and only the script fetch is TLS-only. It also refuses
> to run under `sudo` with `SUDO_USER` set (would install into root's home); plain root in a container is
> unaffected. Verified behaviour: pinned-and-present → no-op exit 0; install producing no binary → exit 1.

**The plugin CLI supports exactly what `packages/claude-plugins.txt` needs** (verified `--help`):

```
claude plugin install <plugin>   -s, --scope <user|project|local>   (default: user)
claude plugin marketplace add <source>   --scope <user|project|local>   --sparse <paths...>
```

`<source>` accepts "a URL, path, or GitHub repo" → **D8's relocation is directly expressible**
(`marketplace add ~/.claude-shared/local-marketplace`). §4.13's user-scope-only manifest maps 1:1 onto
`-s user`.

⚠️ **`claude plugin install` has no version-pin flag** — only `--config` and `--scope`. So the replay
always installs *latest from the marketplace*. `verify-fresh` is therefore **not** reproducible across
upstream marketplace changes, which qualifies D9/I11's reproducibility claim (I11 pins
`cc-account-switcher`, but nothing can pin the plugins).

---

## Part 2 — New findings that change scope

> These are the reason to read this file. **A**, **B**, **D**, and **I** each block or silently
> invalidate work the plan is about to schedule.

### A. ✅ RESOLVED — `cc-account-switcher` had no git remote; now published private

> **Resolved 2026-07-29 (user decision).** Published as
> `github.com/FluxxField/cc-account-switcher`, **private**, `master` → `main`, **pin tag `v0.1.0` =
> `0e66044`**; `feat/shared-and-routing` pushed too. Pre-publication sweep: **no credentials/tokens in
> any of the 27 commits**, but two business emails and client names (`roofco`, `roof-report-pro`) in 9
> files — hence private (also the reversible direction). **New requirement this creates:** a private
> remote can't be cloned anonymously, so `verify-fresh` must feed the switcher from the host via
> `CCA_SOURCE` (git bundle of the pinned tag, or read-only bind-mount) — **never a token in the build
> context**. See design §4.18. Original finding retained below.



```
$ git -C ~/github/cc-account-switcher remote -v      → (empty)
$ git -C ~/github/cc-account-switcher tag            → (empty)
$ git -C ~/github/cc-account-switcher branch -a      → * master  +feat/shared-and-routing
$ git config --get-regexp '^remote\.'                → (empty)
```

It is a **local-only repo on `master`** (not `main`), with one local worktree
(`cc-account-switcher--wt-shared-routing`). So `scripts/install-cc-switcher.sh` — spec'd as
"Clones/updates `cc-account-switcher` and runs its `install.sh`", **pinned to a tag/commit** (I11,
HC9, D2) — has no source, and SC10 ("installs the pinned switcher during `verify-fresh`") cannot pass.
This blocks §4.12 steps 3–4 and therefore SC12.

Needs a user decision before unit 5 (see Handoff). Options: publish it to a remote first (a new
unit-1 task, and the only one consistent with HC9/I11 as written), or have `verify-fresh` `COPY` the
working tree into the build context (unblocks the container but leaves "pinned + reproducible"
unsatisfied on a real fresh box).

### B. 🔴 `/proc/version` inside a container on this host says `microsoft` — the "clean linux" run is a WSL run

Containers share the host kernel. Inside `docker run ubuntu:24.04`:

```
Linux version 6.18.33.2-microsoft-standard-WSL2 …
```

So `detect-os.sh`'s `grep -qi microsoft /proc/version` → `WSL=1`, and `stow-all.sh`'s independent
inline copy of that grep (`stow-all.sh:92`) also fires. **`verify-fresh` would silently exercise the
WSL path while claiming to test native Linux.** Consequences:

- §4.7's `PLATFORM` cannot be a purely *derived* export. `detect-os.sh` currently hard-assigns
  (`OS="linux"; WSL="0"` then overwrites) with no env respect, so it must become
  `PLATFORM="${PLATFORM:-<derived>}"` for `make verify-fresh PLATFORM=linux` to mean anything.
- Deleting `stow-all.sh:92`'s inline grep (§4.7 already requires this) is what makes the override
  actually take effect for overlay selection — otherwise `hosts/wsl` stows regardless of `$PLATFORM`.
- `bootstrap.sh:77` then runs `wsl-post.sh` in the container — see finding **D**.
- Corollary for `hosts/linux`: no container on this host can validate the auto-detected `linux` branch.
  Only the explicit override path is testable here.

### C. 🟠 Docker on this machine cannot pull images as configured

```
$ docker pull ubuntu:24.04
docker: error getting credentials - err: exec: "docker-credential-desktop.exe": executable file not found in $PATH
$ cat ~/.docker/config.json
{ "credsStore": "desktop.exe" }
```

A Docker-Desktop leftover: the engine is healthy (`29.5.2`, endpoint `unix:///var/run/docker.sock`)
but every pull dies in the credential helper. **Verified fix:** point `DOCKER_CONFIG` at a config
containing `{}` — the pull then succeeds. `make verify-fresh` must set this (or the plan must fix
`~/.docker/config.json`), otherwise SC2 fails before the container starts.

### D. 🔴 `bootstrap.sh` creates real files at stow-owned paths — stow conflicts are structural, not incidental

`bootstrap.sh` runs **before** `stow-all.sh` (it ends with "Run ./stow-all.sh to link configs"), and
three of its steps write the exact paths stow then wants to own. Against a pristine `$HOME` this is a
guaranteed conflict, not a maybe:

| Step | Writes | Stow package it collides with |
|---|---|---|
| `ohmyzsh-install.sh:35-56` — `touch "$ZRC"` then appends OMZ block | `~/.zshrc` | `zsh` |
| `install-mise.sh:13` — `curl -fsSL https://mise.run/zsh \| sh` (its own comment: "adds `eval "$(mise activate zsh)"` to your `~/.zshrc` automatically") | `~/.zshrc` | `zsh` |
| `install-mise-globals.sh` — `mise use -g -y …` ×12 | `~/.config/mise/config.toml` | `mise` |
| `wsl-post.sh:11` — `git config --global core.autocrlf input` | `~/.gitconfig` | `git` |

`wsl-post.sh` **will** run in the container, per finding **B**.

Worse than a first-run conflict: `mise use -g` and `git config --global` are *also* run
post-provisioning in normal use. Once those paths are stow symlinks into the repo, both write
**through the symlink into tracked files** — breaking SC11's clean-tree assertion on any later
`mise use -g`. §4.5 already reasoned exactly this way about `settings.json` ("an in-place post-stow
edit would edit the tracked repo file"); the same argument applies to `~/.gitconfig` and the mise
config and the design does not cover it.

This is the failure §4.12/SC2 exists to catch — but the plan needs explicit tasks for it rather than
discovering it at `verify-fresh` runtime.

### E. 🟠 `install-mise-globals.sh` is missing from Files-Touched and contradicts §4.8/§4.15

It hardcodes a second, duplicate declaration of the same tool set as `config.toml`:

```bash
mise use -g -y cargo-binstall / cargo:ripgrep-all / cargo:bottom / cargo:zellij / cargo:eza / cargo:just
```

§4.15's disambiguating rule sends **`bottom` → apt (removed from mise)** and `eza` → apt-if-packaged.
This script would **re-install the very entries unit 3 removes** on the next bootstrap, so the
tool-ownership policy is unenforceable until it is edited. Also a live name mismatch that makes
`audit.sh`'s name comparison disagree with itself: **`cargo:ripgrep-all`** (script) vs
**`cargo:ripgrep_all`** (`config.toml`, and the installed tool). Add the file to Files-Touched, unit 3.

### F. 🟠 `audit.sh` has the identical never-fails defect §4.2 fixed for `doctor`

`scripts/audit.sh` accumulates `any_missing` / `any_untracked` into **function-local** variables
(`:98`, `:118`, `:166`, `:180`), returns nothing, and ends with an unconditional
`printf "\n${BOLD}Audit complete.${RESET}\n"` (`:202`). It also deliberately drops `-e` (`:13`). So
**`make audit` always exits 0**, exactly like `make doctor` did.

SC3 ("`make audit` reports all five classes clean") and §4.12 **step 7** therefore pass vacuously —
the same defect D14/§4.2 was written to close, one file over. Give `audit.sh` a failure counter and a
non-zero exit alongside the `doctor` fix in unit 4, or `verify-fresh` can only grep its output.

### G. 🟠 The `~/.cargo/bin` cleanup is ~12 binaries, not 2 — and D10's PATH bug *is* live

Design names two cargo-direct binaries (`exa`, `zellij`). Actual `~/.cargo/bin`, excluding rustup shims:

```
bacon  btm  cargo-install-update  cargo-install-update-config  cargo-shuttle  cargo-sqlx
cargo-tauri  coreutils  exa  fd  gitui  nu  rtx  sccache  sqlx  starship  stylua  trunk
zellij  zesh  zoxide
```

Three corrections that matter:

- **CORRECTS `codebase-facts.md`: `bottom` is installed.** It is `~/.cargo/bin/btm` — `btm --version`
  → `bottom 0.10.2`. facts.md's "absent from PATH" is a *binary-name* artifact (`bottom` the package,
  `btm` the binary). A name-based audit check structurally cannot see it — relevant to §4.15's fifth
  audit class, which must map package→binary names, not compare strings.
- **CORRECTS `codebase-facts.md`/§4.11: D10's PATH-precedence bug is live, via cargo not asdf.**
  `command -v starship` → `~/.cargo/bin/starship`; `command -v zoxide` → `~/.cargo/bin/zoxide`.
  `$PATH` order puts `~/.cargo/bin` at **position 6 and again at 8**, *ahead of* `~/.local/bin` at 7.
  Both tools are separately provisioned (`zoxide` in `apt.txt`, `starship` via `bootstrap.sh:67`), so
  `doctor` is currently validating the cargo copies. facts.md was right that *asdf* is off PATH; the
  bug class D10 cites is nonetheless active.
- **`rtx` is present** — mise's former name, a third stale version manager alongside the leftover
  `~/.asdf`. D10's scope should include it.

### H. 🟡 A stale `~/.local/share/mise/shims/` exists and is not on PATH

It holds shims for `btm`, `exa`, `bacon`, `coreutils`, `cargo-shuttle`, `eslint`, … all →
`~/.local/bin/mise`. But **no `shims` entry is on `$PATH`** (mise runs in activate/installs mode —
`$PATH` carries `~/.local/share/mise/installs/*/bin`). Dead state that mise once managed these tools
through; it will confuse audit class 5's "attributable to a mise-managed install" test, which must
read `mise ls`, not the shims directory.

### I. 🔴 `adopt-existing.sh` violates HC8 and HC4 as written, and is missing from Files-Touched

Three separate problems, all in a script `make adopt` / `make adopt-merge` invoke:

1. **HC8 violation.** `list_packages()` (`:72-74`) excludes **only** `hosts`:
   `find stow -maxdepth 1 -mindepth 1 -type d -not -name hosts`. With no arguments, `PKGS` defaults to
   that list (`:120-122`) — so bare `make adopt` runs **`stow --adopt` against `ssh`**, which HC8
   forbids outright ("`--adopt` is never run against the `ssh` package"). Once vendored, it hits
   `claude` too. Needs an explicit exclusion list, not a convention.
2. **HC4/C6 contradiction.** Its own printed Next-steps (`:126-129`) are
   `git add -A && git commit -m "adopt: import existing dotfiles"`. C6 says "Never `git add -A` while
   staging it". The script *instructs the user to do the forbidden thing* — and the harness state is
   what makes it unrecoverable on a public remote.
3. **HC7's backup guarantee does not hold for the harness.** `backup_conflicts_for_pkg` (`:77-91`)
   iterates `find . -type f -o -type l` and copies only when the target is `-e && ! -L`. A real
   **directory** at a stow-owned path is never backed up — so `~/.claude-shared` is *not* covered by
   this path. §4.1/HC7's "HC7 moves live `~/.claude-shared` into `.migration_backups/`" must be an
   explicit unit-5 step, not delegated to `adopt-existing.sh`.

Also: **`~/.dotfiles/.migration_backups/` does not exist yet** — first `adopt_pkg` creates it
(`:104`, `$ROOT_DIR/.migration_backups/$ts/$pkg`). And since `ROOT_DIR` derives from the script's own
location, running it from the worktree writes backups **into the worktree**, which is gitignored there
too — but is a different directory from `~/.dotfiles/.migration_backups`. Worth pinning down before
HC7's off-machine copy is taken.

### J. 🟠 `install-redis-stack.sh` already fails on a genuinely fresh box

`scripts/install-redis-stack.sh:28` uses `$(lsb_release -cs)`. **`lsb_release` is absent from
`ubuntu:24.04` and `lsb-release` is absent from `apt.txt`.** Today the failure is invisible because
`bootstrap.sh:71` suffixes `|| true`. `verify-fresh` will expose it. Same shape for `gpg`/`gnupg`:
used by both existing repo installers *and* required by SC9's signing test, absent from `apt.txt`.
Both should join `apt-common.txt` in unit 3 — and note `audit.sh`'s `is_system_pkg` already filters
`lsb-release`, `gpg`, `gnupg`, `sudo`, `locales`, `ca-certificates`, so adding them creates **no**
audit noise.

### K. 🟡 `$OS` carries two incompatible value spaces

`detect-os.sh` exports `OS=linux|mac`. But three scripts define their own `OS="$(uname -s)"` →
`Linux|Darwin`:

| File | Line | Compares against |
|---|---|---|
| `scripts/install-lazygit.sh` | 18 | `Darwin` (`:22`), `case "$OS"` (`:29`) |
| `scripts/startup.sh` | 17 | `Linux` (`:41`), `Darwin` (`:94`) |
| `scripts/nvim-manager.sh` | 14 | `Linux` (`:190`, `:197`) |

Currently safe — each is invoked as `bash scripts/…` (separate process) and shadows locally. But it is
a landmine for §4.7: making any of them `source detect-os.sh` (to reach `$PLATFORM`) turns
`"$OS" == "Linux"` into dead code silently. Either rename or leave them strictly self-contained, and
say which. Related, already in facts.md: `detect-os.sh`'s `set -euo pipefail` leaks into `bootstrap.sh`
and into `install-stripe.sh`/`install-redis-stack.sh`, the only two scripts that source it.

### L. 🟡 `bootstrap.sh` writes git history during `verify-fresh`

`bootstrap.sh:58` runs `nvim-subtree.sh pull --auto`. `nvim-subtree.sh` reads
`subtree.nvim.{remote,url,branch}` from git config and does a real subtree pull — a git write into the
repo mid-`verify-fresh`, ahead of SC11's `git status --porcelain`-clean assertion. A clean pull commits
(tree stays clean, HEAD moves); a conflicted one leaves a dirty tree and fails SC11 for an unrelated
reason. Needs an explicit container posture (skip via a flag, or assert against a known HEAD).

### M. 🟡 `Makefile:72` `fonts-windows` hardcodes `$$HOME/.dotfiles/…`

`pwsh … -File "$$HOME/.dotfiles/scripts/win/install-fonts.ps1"` — wrong in any worktree. Cosmetic, but
the Makefile is already being modified for five new targets plus `doctor`/`unlink`/`restow`.

### N. ✅ §4.1's stow mechanism verified working on the installed stow

stow **2.3.1**. `--no-folding` is **absent from `stow --help`** but present in `man stow` (line 158)
and **functional** — tested end to end:

```
$ stow --no-folding -d stowtest -t $PWD/stowtarget pkg
stowtarget/.testdir            → REAL directory
stowtarget/.testdir/f          → symlink ../../stowtest/pkg/.testdir/f
```

So §4.1's "parent stays a real directory, each entry linked individually" holds. `--adopt` is also
supported (`adopt-existing.sh:65` already asserts this). No stow upgrade needed.

### O. 🟡 `settings.json` has no `${VAR}` precedent to reason from

`grep '\${' ~/.claude-shared/settings.json ~/.claude-shared/settings.local.json` → **no matches
anywhere**. Every value is a literal (`"CC_NTFY_TOPIC": "rrp-cc-<REDACTED>"`,
`"CLAUDE_CODE_DISABLE_1M_CONTEXT": "0"`, `"CLAUDE_CODE_SUBAGENT_MODEL": "sonnet"`). So §4.4/§4.5's
expansion question has **no in-repo evidence either way** and must be settled empirically in unit 2,
exactly as the brief requires. The scan deliberately did not test it live (it would mean editing active
settings).

### P. Small confirmations worth having before unit 5

- **`handoffs/` is empty** → §4.1's `mkdir -p` + gitignore treatment is trivially safe.
- **`plugins/.last_inuse_sweep`** is a single-line ISO timestamp (`2026-07-29T21:43:43.572Z`),
  rewritten continuously (mtime today 14:43) — confirms §4.17's gitignore call; it would otherwise
  dirty the tree on every session.
- **HC4's `.bak` claim CONFIRMED:** `grep -c rrp-cc-<REDACTED>` → `settings.json:1`,
  `settings.json.bak-20260723-103211:1`, `settings.json.bak2-105016:1`. Both backups carry the topic.
- **The 2022 clone is ready for C7:** `~/github/dotfiles` HEAD `e4a76dc571d9710471ac9c4ec77173f869fdc91f`,
  on `main`, **working tree clean**, `origin` → the same `FluxxField/dotfiles`, with
  `remotes/origin/main` present. The `archive/2022-pre-rewrite` push is executable as designed.

---

## Files to Create

| Path | Description |
|---|---|
| `packages/apt-common.txt` | Platform-agnostic packages + the 24 installed-but-untracked. **Add `lsb-release`, `gnupg` (finding J).** |
| `packages/apt-linux.txt` | Native-Linux-only packages. |
| `packages/apt-wsl.txt` | WSL-only packages (`wslu`, and whatever `wsl-post.sh` implies). |
| `packages/claude-plugins.txt` | User-scope-only manifest (§4.13). Schema maps 1:1 to `-s user` / `--scope user`. No version column — the CLI has no pin flag (Q3). |
| `scripts/install-gh.sh` | Model on `install-stripe.sh`; **add** pinned-fingerprint verification (SC16) — no sibling does this. |
| `scripts/install-docker.sh` | Same. Plus the README `docker`-group note (I8). |
| `scripts/install-cc-switcher.sh` | **Blocked on finding A** — no remote to clone from. |
| `scripts/install-claude-plugins.sh` | Replay via `claude plugin marketplace add --scope user` + `claude plugin install -s user`. |
| `scripts/claude-profile-init.sh` | `source` `cca-lib.sh`, call `cca::ensure_shell` — **not** `cca init` (Q2). |
| `scripts/install-env.sh` | Copy `*.example` → real only when absent (§4.3, SC14). |
| `scripts/claude-path-template.sh` | Parameterize/reverse `/home/keenan` in shell/hook/skill files (§4.5, D15). |
| `scripts/assert-gitignore-safe.sh` | `git check-ignore -q` per never-versioned entry; coverage generated from a live-tree scan (§4.17). |
| `scripts/install-claude-cli.sh` | **New — closes §4.17** (Q3). Native installer + `doctor` check. |
| `scripts/verify-fresh.sh` + Dockerfile | Scaffolded unit 4, completed unit 5 (§4.17). Must handle Q1's bootstrap set, B's `PLATFORM` override, C's `DOCKER_CONFIG`. |
| `scripts/unstow-all.sh` (or a mode flag) | Single shared codepath for link/unlink (§4.14). |
| `stow/claude/.claude-shared/**` | The vendored harness — inventory below. |
| `stow/claude/.claude-shared/routes.example` | D12. |
| `stow/hosts/{@common,wsl,linux,$(hostname)}/` | Documented since forever, never existed. |
| `stow/tmux/.tmux.conf` | Adopt the 48-line live config. |
| `stow/bin/.local/bin/ccz` | Adopt the live helper (Tailscale IP is comment-only). |
| `stow/env/.config/dotfiles/env.sh.example` | §4.3. |

### Vendored harness inventory — exact, with exec bits

**CORRECTS `codebase-facts.md`'s counts** (facts counted *entries*, the plan needs *files*):

| Path | Count | Note |
|---|---|---|
| `skills/` | 17 dirs, **19 files** | 17 × `SKILL.md` + `harness-stats/harness-stats.sh` + `adversarial-review/critic-agent.md` |
| `hooks/` | 16 entries = **15 scripts + `lib/`** → **17 files** | `lib/{hook-session.sh, session-label.sh}` |
| `commands/` | 10 files | all `.md` |
| `agents/` | 4 files | `critic.md`, `go-build-resolver.md`, `implementer.md`, `web-build-resolver.md` |
| `local-marketplace/` | **10 files, 124K** | contains its own `hooks/{session-start,hooks.json,run-hook.cmd}` — a hook tree inside the relocated tree |

**Exec bits are mixed *within* directories — a blanket `chmod` is wrong.** Stow symlinks inherit the
target's mode, so git must carry these exactly:

- **Executable (0755):** all 15 `hooks/*.sh`, `hooks/lib/session-label.sh`, `statusline.sh`,
  `skills/harness-stats/harness-stats.sh`
- **Not executable (0644):** `hooks/lib/hook-session.sh`, `shell-integration.sh`

`--no-folding` will create `hooks/` **and** `hooks/lib/` as real directories and symlink each file, so
the repo tree must mirror that nesting exactly.

## Files to Modify

| Path | Lines | Change | Notes from the scan |
|---|---|---|---|
| `scripts/detect-os.sh` | 15 | Add `PLATFORM` | Must be `${PLATFORM:-…}`-overridable, not derived — finding **B**. Currently hard-assigns and `export`s; `set -euo pipefail` leaks to 3 sourcers. |
| `scripts/install-apt.sh` | 20 | Split lists + `$DOTFILES_ROOT` | cwd bug at `:11` (§4.17). Copy `audit.sh:15`'s `DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"`. |
| `scripts/audit.sh` | 202 | Union 3 lists per `$PLATFORM`; 5th class; **+ exit semantics** | `APT_LIST` at `:16`, `MISE_CONFIG` at `:17`. **Finding F** — add the failure counter, or SC3 stays vacuous. Class-5 must map package→binary (`bottom`→`btm`) and read `mise ls`, not `shims/` (**G**, **H**). |
| `scripts/install-mise-globals.sh` | 43 | **Was missing from Files-Touched** | Finding **E** — re-installs the mise entries unit 3 removes; `ripgrep-all` vs `ripgrep_all`. |
| `scripts/adopt-existing.sh` | 132 | **Was missing from Files-Touched** | Finding **I** — HC8 (`ssh` adopted), HC4 (`git add -A` advice), HC7 (dirs not backed up). |
| `scripts/install-redis-stack.sh` | 34 | `lsb_release` dep | Finding **J**. Or add `lsb-release` to `apt-common.txt` and leave the script alone. |
| `scripts/ohmyzsh-install.sh` | 56 | Stop writing `~/.zshrc` (or reorder vs stow) | Finding **D** — `touch "$ZRC"` at `:34`, appends `:37-56`. |
| `scripts/install-mise.sh` | 13 | Same | Finding **D** — `mise.run/zsh` edits `~/.zshrc`. |
| `scripts/wsl-post.sh` | 19 | `git config --global` → `~/.gitconfig` | Finding **D**. Runs in the container per **B**. |
| `bootstrap.sh` | 81 | `PLATFORM` branches (`:10,15,21,32,35,77`); wire 5 new installers | Ends *before* `stow-all.sh` — §4.12 steps 1/2 are separate invocations, which is correct. `:58` subtree pull → finding **L**. `:67` starship `curl\|bash` → SC16. |
| `stow-all.sh` | 37 | `$PLATFORM` overlays; `mkdir -p` + `--no-folding` for `claude`; delete inline grep `:92` | Deleting `:92` is what makes **B**'s override effective. |
| `Makefile` | 96 | 5 new targets; `doctor` exit semantics; fix `unlink`/`restow` (§4.14) | `doctor` = 12 checks at `:84-96`; add `claude`. `:72` hardcodes `~/.dotfiles` (**M**). `:30` has a stray double-tab. |
| `.gitignore` | 5 | Harness-state rules, own commit first (C6) | **CORRECTS design row:** not empty — `.worktrees/`, `.migration_backups/` present. |
| `README.md` | 582 | `hosts/` real; `PLATFORM`; harness; `verify-fresh`; docker-group | `hosts/` refs: **124, 223, 397, 537, 538, 539, 577**. "install manually" table: **564-568** (gh, docker-ce). `apt.txt` refs: **192, 401, 549, 578**. |
| `stow/git/.gitconfig` | 30 | email→gmail, signingkey→`6C32D9329BDB7DA9`, adopt `gh auth git-credential` | HC12 — must land in **unit 1**. |
| `stow/mise/.config/mise/config.toml` | 19 | Resolve 8 uninstalled; `bottom`→apt; fold in `vercel` | Keep in lockstep with `install-mise-globals.sh` (**E**). |
| `stow/ssh/.ssh/config` | 16 | `IdentityFile` → `id_rsa` | Only change needed — no topology (facts.md). |
| `stow/zsh/.zshrc` | 70 | WSL branches → `hosts/wsl/` | `:21-23` sources `~/.config/dotfiles/env.sh` — the only consumer, and the reason §4.3 matters. |
| `stow/env/.config/dotfiles/env.sh` | 17 | + `CC_NTFY_TOPIC`, Tailscale host; `git rm --cached` | Currently tracked (§4.3). |
| `stow/nvim/.config/nvim` | — | Subtree pull **after** HC10's push | HC10 gate first. |

## Files Unchanged (negative space)

| Path | Why |
|---|---|
| `~/github/cc-account-switcher/**` | HC9 — declared and installed, never vendored or refactored. Read-only here (Q2). |
| `scripts/nvim-subtree.sh` | Mechanism unchanged (D3); only the drift is reconciled. |
| `scripts/merge-from-backup.sh` (141) | Already the rollback path (§4.15/HC7) — referenced, not modified. |
| `scripts/install-stripe.sh`, `install-redis-stack.sh` | Pattern *sources* for the new installers. Only `install-redis-stack.sh`'s `lsb_release` dep is in play (**J**). |
| `win/`, `scripts/win/` | D5/D18 — retained, maintained. |
| `scripts/install-fonts.sh` (117), `install-brew.sh` (12) | Out of the Docker harness scope (Non-Goals). |
| `scripts/nvim-manager.sh` (210), `startup.sh` (165), `install-lazygit.sh` (77) | Self-contained `OS="$(uname -s)"` — leave that way (**K**). |
| `~/.claude-accounts/{rrp,kjweb}/**` except `settings.json` | Per-account state stays untracked (Section 2). |

## Blast Radius (files not in the design's table)

| Path | Why affected | Action |
|---|---|---|
| `scripts/install-mise-globals.sh` | Re-installs the mise entries unit 3 removes; duplicate tool declaration | **Add to Files-Touched, unit 3** (**E**) |
| `scripts/adopt-existing.sh` | Adopts `ssh` (HC8); advises `git add -A` (HC4); doesn't back up dirs (HC7) | **Add to Files-Touched, unit 3.5** (**I**) |
| `scripts/ohmyzsh-install.sh`, `scripts/install-mise.sh`, `scripts/wsl-post.sh` | Create real files at stow-owned paths | **Add, unit 4** (**D**) |
| `scripts/install-redis-stack.sh` | `lsb_release` absent on a fresh box | Add `lsb-release` to `apt-common.txt`, unit 3 (**J**) |
| `~/.docker/config.json` | Broken `credsStore` blocks every pull | `verify-fresh` sets `DOCKER_CONFIG`, unit 4 (**C**) |
| `~/.cargo/bin` (~12 non-rustup binaries) | §4.8 cleanup is far wider than `exa`+`zellij` | Enumerate in unit 3 (**G**) |
| `~/.local/share/mise/shims/` | Stale, off-PATH; confuses audit class 5 | Remove or explicitly ignore, unit 3 (**H**) |
| `~/.asdf`, `~/.cargo/bin/rtx` | Two stale version managers, not one | Fold into D10, unit 3 (**G**) |
| `README.md:564-568` | The "install manually" table SC7 must delete | Already implied; exact lines recorded |

## Patterns Observed

**Installer scripts** — `install-stripe.sh` / `install-redis-stack.sh` are the canonical sibling pair
for `install-gh.sh` / `install-docker.sh`. Fixed shape, follow it exactly:

1. Shebang + comment block: purpose, macOS behaviour, literal line `# Idempotent — safe to re-run.`
2. `set -euo pipefail`
3. Early-exit guard: `if command -v X >/dev/null 2>&1; then echo "[x] already installed…"; exit 0; fi`
4. `source "$(dirname "$0")/detect-os.sh"`
5. mac branch → `brew`, with a `brew not found; skipping` escape
6. `curl -fsSL <key> | gpg --dearmor | sudo tee /usr/share/keyrings/<name>-archive-keyring.gpg >/dev/null`
7. `echo "deb [signed-by=/usr/share/keyrings/<name>-archive-keyring.gpg] <url> …" | sudo tee /etc/apt/sources.list.d/<name>.list >/dev/null`
8. `sudo apt-get update -o=Dpkg::Use-Pty=0 >/dev/null` then `sudo apt-get install -y <pkg>`
9. Closing `echo "[x] Installed…"`

`install-lazygit.sh` is the *other* installer shape (GitHub-release download): `need()` dependency
helper, local `OS="$(uname -s)"`/`ARCH="$(uname -m)"`, `case` on OS→arch→asset suffix, `exit 2` on
unsupported arch. Use this shape for `install-cc-switcher.sh` / `install-claude-cli.sh`, not the
apt-repo shape.

**Logging:** `[<tool>] message` prefix throughout. `audit.sh` alone uses colour + `header/ok/warn/miss`
helpers gated on `[[ ! -t 1 ]]`.

**Idempotency:** every installer guards on `command -v`. New scripts must too — §4.12 step 5 runs
`stow-all.sh` twice and asserts no diff (SC13).

**Path derivation:** two competing idioms. `audit.sh:15` and `adopt-existing.sh:16` use
`"$(cd "$(dirname "$0")/.." && pwd)"` (correct, cwd-independent); `stow-all.sh:85` uses
`"$(cd "$(dirname "$0")" && pwd)"` + `cd`; `install-apt.sh:11` uses a **bare relative path** (the bug
§4.17 fixes). Prefer the `audit.sh` form.

**Error handling — the house style §4.6/D16 explicitly rejects:** `bootstrap.sh` suffixes ~10 steps
with `|| true`; `audit.sh:13` drops `-e` on purpose; `doctor` and `audit` never exit non-zero;
`set-default-shell-zsh.sh:9` ends `|| true`. The new hard-gate scripts must break this pattern
deliberately and say so in a comment.

**Makefile:** `SHELL := /usr/bin/env bash`, `.DEFAULT_GOAL := help`, every target `.PHONY`, recipes are
one-liners delegating to `bash scripts/<x>.sh`. `doctor` is the only multi-line recipe and the only one
using `@`.

**Package lists:** line-delimited, `#` comments, stripped with
`grep -v '^\s*#' | grep -v '^\s*$'` (`install-apt.sh:11`, `audit.sh:116`) — the split lists must keep
that format or both consumers break.

## Sibling Mirrors

### `install-gh.sh` / `install-docker.sh` — apt-repo installers

| Guard / Invariant | New | `install-stripe.sh` | `install-redis-stack.sh` |
|---|---|---|---|
| `command -v` early-exit idempotency guard | **REQUIRED** | ✓ `:7-10` | ✓ `:9-12` |
| `set -euo pipefail` | **REQUIRED** | ✓ `:5` | ✓ `:7` |
| `source detect-os.sh` + mac→brew branch with skip | **REQUIRED** | ✓ `:12-18` | ✓ `:14-20` |
| `signed-by=` keyring, never `apt-key add` | **REQUIRED** (SC16) | ✓ `:26` | ✓ `:27` |
| `apt-get update -o=Dpkg::Use-Pty=0` (non-TTY safe) | **REQUIRED** | ✓ `:30` | ✓ `:31` |
| `[tool]`-prefixed progress echo | **REQUIRED** | ✓ | ✓ |
| **Pinned GPG fingerprint verification** | **REQUIRED — SC16/I7** | ✗ **neither sibling does this** | ✗ |
| Avoid `lsb_release` (absent on fresh boxes) | **REQUIRED** | ✓ (no use) | ✗ `:28` uses it — **finding J** |

⚠️ The last two rows are where the new scripts must **exceed** their siblings. Fingerprint pinning has
no precedent in this repo — SC16 requires inventing it, so the plan needs the actual known-good
fingerprints as task inputs, not "pin the fingerprint" as an instruction.

### `install-cc-switcher.sh` / `install-claude-cli.sh` — non-apt installers

| Guard / Invariant | New | `install-lazygit.sh` | `install-mise.sh` |
|---|---|---|---|
| `command -v` early-exit | **REQUIRED** | ✓ (update-in-place) | ✓ `:6-9` |
| Explicit dependency check (`need curl`) | **REQUIRED** | ✓ `:11-16` | ✗ |
| OS/arch → asset mapping with `exit 2` on unsupported | **REQUIRED** | ✓ `:29-48` | ✗ |
| Pinned version, not "latest" | **REQUIRED — I11** | ✗ uses latest tag | ✗ |
| Does not silently edit `~/.zshrc` | **REQUIRED — finding D** | ✓ | ✗ **`:13` does** |
| Source actually exists | **BLOCKED — finding A** | ✓ GitHub | ✓ mise.run |

### `claude-profile-init.sh` — no sibling in this repo

Its sibling is upstream: `cca::ensure_shell` in `~/github/cc-account-switcher/lib/cca-lib.sh`.
Invariants to mirror rather than reimplement: honour `CCA_HOME` (`cca-lib.sh:3`); link text is
**exactly** `../../.claude-shared/$item` (what `cmd_doctor` string-compares); `ln -sfn` when a symlink
already exists, `WARN` and leave alone when a real file is there — never clobber; iterate
`SHARED_ITEMS` from the library, do not hardcode the 9 names (that list changed on 2026-07-23 and the
in-file comment says omissions are how `skills/` was lost).

### `doctor` / `audit` exit semantics — siblings of each other

| Guard | `doctor` (fixing) | `audit.sh` (**also needs it — F**) |
|---|---|---|
| Accumulates failures | ✗ today | ✗ (function-locals, discarded) |
| Exits non-zero on any miss | ✗ → **REQUIRED** (D14) | ✗ → **REQUIRED** (SC3) |
| No unconditional success line | ✗ `Makefile:96` → **REQUIRED** | ✗ `audit.sh:202` → **REQUIRED** |

## Gotchas

1. **`/proc/version` says `microsoft` inside the container** — the "clean Linux" test runs the WSL
   path unless `PLATFORM` is an explicit override. Finding **B**. This is the single most likely way
   `verify-fresh` passes while proving nothing.
2. **`docker pull` is broken on this machine** (`credsStore: desktop.exe`). Set `DOCKER_CONFIG`.
   Finding **C**.
3. **`cc-account-switcher` has no remote.** Finding **A** — decide before unit 5.
4. **`cca init` ≠ profile creation.** Use `cca::ensure_shell`; `cca init` would `rm -rf ~/.claude` and
   write through the `accounts.json` symlink into the repo. Finding Q2.
5. **`mise use -g` and `git config --global` write through stow symlinks into tracked files.** §4.5
   reasoned this way about `settings.json` but the same trap applies to `~/.gitconfig` and
   `~/.config/mise/config.toml`. Finding **D**.
6. **`ubuntu:24.04` has no `sudo` binary** despite `ubuntu` being in the `sudo` group — and its uid is
   1000, same as `keenan`, so reusing it defeats SC6. Finding Q1.
7. **`--no-folding` is missing from `stow --help`** on 2.3.1. It works (verified); don't let anyone
   "fix" it by dropping the flag. Finding **N**.
8. **`bottom` is installed as `btm`.** A name-based audit check can't see it. Finding **G**.
9. **`~/.cargo/bin` precedes `~/.local/bin` on `$PATH`** (positions 6/8 vs 7), so `starship` and
   `zoxide` resolve to cargo copies. Finding **G**.
10. **Exec bits are mixed inside `hooks/lib/`** — `session-label.sh` 0755, `hook-session.sh` 0644. No
    blanket chmod. Finding Q/inventory.
11. **`audit.sh`'s `is_system_pkg` filters `sudo`, `lsb-release`, `gpg`, `gnupg`, `locales`,
    `ca-certificates`** — so the Dockerfile's and finding J's additions create zero audit noise. Also
    filters `fonts-*` (deliberately, per `fonts/manifest.json`).
12. **`apt.txt` lists `redis` but `redis-stack-server` is installed** (facts.md) — the split must not
    reintroduce the class-1 audit failure this already causes.
13. **`bootstrap.sh` never calls `stow-all.sh`.** §4.12 steps 1 and 2 are two invocations. Don't
    "helpfully" wire stow into bootstrap — it would run before `install-env.sh` materializes the
    `.example` files.
14. **`adopt-existing.sh` writes `.migration_backups/` relative to its own location**, so running it
    from the worktree does not populate `~/.dotfiles/.migration_backups/`. Pin the destination before
    HC7's off-machine copy.
15. **`handoffs/` is empty and `.last_inuse_sweep` changes every session** — the first is free to
    `mkdir -p`, the second will dirty the tree on literally every session if unignored.

---

## Handoff

**Both escalated items are now decided and actioned — see design §4.18.** Nothing is blocked.

| Item | Resolution |
|---|---|
| **Finding A** — switcher had no remote | Published **private** as `FluxxField/cc-account-switcher`, `main`, **pin `v0.1.0` = `0e66044`**. New planning requirement: `verify-fresh` supplies it from the host via `CCA_SOURCE` (bundle / bind-mount), no token in the build context. |
| **Q3 / §4.17** — CLI never provisioned | `scripts/install-claude-cli.sh` **written, executable, verified, on the branch**. Version-pinnable via `CLAUDE_CLI_VERSION`. §4.12 steps 3–4 stay unconditional. |

Two things `writing-plans` must carry that came out of doing the above:

1. **The CLI installer's wiring is deliberately not done.** `bootstrap.sh`, `Makefile` (`doctor`), and
   `README.md` edits are **deferred to unit 4 under HC2** — `origin/main` has 9 unpulled commits and
   editing those three files before the fork merge manufactures avoidable conflicts. The new script has
   no conflict surface, which is why it could land now. Schedule the wiring; don't assume it's done.
2. **`doctor` runs under a non-login bash** (`Makefile:1`) that never sources `.zshrc`, where
   `~/.local/bin` is added (`stow/zsh/.zshrc:3`). So inside `verify-fresh`'s non-interactive run this
   breaks the **existing** `starship`/`zoxide`/`node`/`go` checks too, not just `claude` —
   `verify-fresh` must export an explicit PATH or `doctor` fails for reasons unrelated to provisioning.

One correction to Q3 above, now that the installer has been read rather than assumed:
**`install-claude-cli.sh` is not in starship's risk class.** Anthropic's `install.sh` fetches a
per-platform manifest, extracts a SHA256, and **aborts on mismatch** — the payload is verified and only
the script fetch is TLS-only. Starship verifies nothing. SC16's "accepted residual risk" is starship
alone, and brief SC16/SC17 now say so.

Everything else is ready to plan.

```
─────────────────────────────────────────
Continuing feat/harness-linux-migration.

Next phase: writing-plans
Brief:  docs/plans/2026-07-29-harness-linux-migration/brief.md
Design: docs/plans/2026-07-29-harness-linux-migration/design.md
Scan:   docs/plans/2026-07-29-harness-linux-migration/codebase-scan.md

Read all three files. design.md §4 is authoritative over §§1-3 and the Design Contract.
The scan has the exact file paths, line counts, and patterns — plus four findings
(A, B, D, I) that change unit 3/4/5 scope and two that need a user decision.
Do not re-explore files the scan or codebase-facts.md already covers.
─────────────────────────────────────────
```
