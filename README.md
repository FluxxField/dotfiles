# Dotfiles (Stow + mise + smart installers)

Manage a full dev environment across Linux, macOS, and WSL2 using:

* **GNU Stow** for clean, reversible symlinks
* **mise** for versioned runtimes and global packages (Node, Go, Rust + `npm:` and `cargo:` backends)
* **Neovim** installed from GitHub releases (stable/nightly) with easy switching
* Linux install policy: **apt → mise → fallback**
* Optional **Neovim config via git subtree** (keep your nvim repo separate but vendor it here)
* **Startup checks/upgrades** (apt/brew/mise) + `fastfetch`, with safe caching
* Shared **fonts manifest** for Windows & Linux installs
* WSL niceties, host overlays, and idempotent bootstrap

---

## Quick start (fresh machine)

> If you clone to a different path than `~/.dotfiles`, update the `.zshrc` startup hook accordingly.

```bash
cd ~
git clone git@github.com:YOURUSER/dotfiles.git .dotfiles
cd .dotfiles

# (Optional, one-time per repo) vendor your Neovim config via subtree
# scripts/nvim-subtree.sh init git@github.com:YOURUSER/your-nvim-repo.git main

# Install tooling, mise, global toolchains & packages, fonts (by default), Neovim stable, etc.
bash bootstrap.sh

# Symlink all configs (zsh, git, nvim, starship, env, etc.)
./stow-all.sh

# Open a NEW terminal so mise activation & PATH apply
```

**Smoke test**

```bash
nvim --version | head -n1
node -v && npm -v && go version
lazygit --version
```

---

## Migrating an existing machine (safe adoption)

Import your current dotfiles into this repo without losing anything:

```bash
cd ~ && git clone git@github.com:YOURUSER/dotfiles.git .dotfiles && cd .dotfiles

# See what would change
make adopt-dry              # or: scripts/adopt-existing.sh --dry-run zsh nvim git

# Adopt: backs up conflicts to ./.migration_backups/, moves files into packages, then symlinks
make adopt                  # or: scripts/adopt-existing.sh zsh nvim git

git add -A && git commit -m "adopt: import existing dotfiles"

# Install/refresh tooling and stow
bash bootstrap.sh
./stow-all.sh
```

### Merge your existing files with repo versions

After `make adopt`, compare your repo files with the backups and merge differences:

```bash
# Use nvimdiff (default):
make adopt-merge

# Or explicitly choose a tool:
MERGE_TOOL=meld make adopt-merge
MERGE_TOOL=code make adopt-merge
```

What it does:

* Uses the **latest** `.migration_backups/<timestamp>/` snapshot.
* For each package, opens a 2-way diff: **repo** vs **backup**.
* Save your reconciled file in the repo; it auto-stages. Commit when done:

  ```bash
  git commit -m "merge: reconcile adopted configs"
  ```

> `make adopt-dry` / `make adopt` will **auto-install GNU Stow** if missing (apt on Linux, Homebrew on macOS) and require a build with `--adopt`.

---

## What this repo sets up

* **Shell & CLI**

  * `zsh` + **Starship** prompt
  * `ripgrep`, `fzf`, `fd`, `bat`, `lazygit` (via smart installer)
  * `fastfetch` summary on shell start (opt-in auto-upgrades)

* **Runtimes & globals (via mise)**

  * `rust@latest`, `node@lts`, `go@latest`
  * `npm:npm@latest`, `npm:prettier`
  * `cargo:ripgrep-all` (example; extend as you like)

* **Neovim**

  * Installed from GitHub release tarballs on Linux (stable/nightly channels)
  * Easy switching via symlink (`~/.local/bin/nvim`)
  * On macOS, uses Homebrew stable or `--HEAD` for nightly

* **Config management**

  * Stowed packages under `stow/` (`zsh`, `nvim`, `git`, `starship`, `env`, etc.)
  * Host overlays: `stow/hosts/@common`, `stow/hosts/$(hostname)`, `stow/hosts/wsl`

* **Fonts**

  * Shared manifest at `fonts/manifest.json` drives installs on both Windows & Linux

---

## Fonts (shared manifest for Windows & Linux)

Configure once in `fonts/manifest.json`:

```json
{
  "nerd_fonts": ["JetBrainsMono", "FiraCode"],
  "include_symbols": false,
  "extra_urls": [],
  "local_dir": "fonts/local"
}
```

**Windows (per-user fonts)**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $HOME '.dotfiles/scripts/win/install-fonts.ps1')
```

Then set your Windows Terminal profile:

```json
"fontFace": "JetBrainsMono Nerd Font"
```

**Linux / WSL (for WSLg GUI apps & Linux terminals)**

```bash
scripts/install-fonts-linux.sh
```

Installs into `~/.local/share/fonts/NerdFonts/...` and refreshes with `fc-cache`.

**Fonts during bootstrap**

* By default, `bootstrap.sh` installs fonts from `fonts/manifest.json`.
* **Linux/WSL:** installs to `~/.local/share/fonts` and refreshes cache.
* **WSL2:** also calls the Windows installer via PowerShell.
* Skip on a machine:

  ```bash
  DOTFILES_INSTALL_FONTS=0 bash bootstrap.sh
  # or set in ~/.config/dotfiles/env.sh:
  # export DOTFILES_INSTALL_FONTS=0
  ```

---

## Repo layout

```
.dotfiles/
├── README.md
├── Makefile
├── bootstrap.sh
├── stow-all.sh
├── fonts/
│   ├── manifest.json          # shared list of fonts for both OSes
│   └── local/                 # optional: extra .ttf/.otf you track
├── packages/
│   ├── apt.txt                # safe defaults on Linux; avoid version-critical stuff here
│   └── brew-Brewfile          # optional; brew bundle if you want
├── scripts/
│   ├── detect-os.sh
│   ├── install-apt.sh
│   ├── install-brew.sh
│   ├── install-mise.sh
│   ├── mise-setup-globals.sh
│   ├── nvim-manager.sh
│   ├── nvim-subtree.sh
│   ├── set-default-shell-zsh.sh
│   ├── wsl-post.sh
│   ├── smart-install.sh
│   ├── startup.sh
│   ├── merge-from-backup.sh
│   ├── install-fonts-linux.sh
│   └── win/
│       ├── install-fonts.ps1
│       └── sync-windows-terminal.ps1
└── stow/
    ├── zsh/                   # .zshrc (sources ~/.config/dotfiles/env.sh, runs startup hook)
    ├── git/                   # .gitconfig, .gitignore_global, aliases
    ├── nvim/                  # .config/nvim (can be a subtree of your separate nvim repo)
    ├── starship/              # .config/starship.toml
    ├── env/                   # .config/dotfiles/env.sh (env vars; stowed and sourced by .zshrc)
    └── hosts/
        ├── @common/           # overlay on all machines
        ├── $(hostname)/       # machine-specific overlay
        └── wsl/               # WSL overlay
```

---

## Makefile targets

```text
bootstrap              Install base tooling, fonts (configurable), mise + globals, Neovim, etc.
link / unlink / restow Stow, unstow, or restow all packages
adopt-dry / adopt      Dry-run or adopt existing files into repo (backs up conflicts)
adopt-merge            Interactively merge repo files with latest backup snapshot
mise-globals           Re-apply global mise toolchains and packages
nvim-stable            Install + switch to Neovim stable
nvim-nightly           Install + switch to Neovim nightly
nvim-switch-stable     Switch symlink to stable (Linux)
nvim-switch-nightly    Switch symlink to nightly (Linux)
nvim-subtree-pull      Pull latest nvim config from upstream subtree remote
nvim-subtree-push      Push changes in subtree back to upstream
fonts-linux            Install fonts per manifest on Linux/WSL
fonts-windows          Install fonts per manifest on Windows
doctor                 Quick tool presence checks
```

---

## Neovim: binary + config

### Binary install/switch

* **Linux:** tarballs installed to `~/.local/nvim/{stable,nightly}`, with `~/.local/bin/nvim` symlink
* **macOS:** Homebrew stable; nightly via `brew install --HEAD neovim`

```bash
# Install/switch stable
make nvim-stable
# Install/switch nightly
make nvim-nightly
# Switch back and forth (Linux)
make nvim-switch-stable
make nvim-switch-nightly
```

### Config via git subtree (keep your nvim repo separate)

One-time setup (run once in the dotfiles repo):

```bash
scripts/nvim-subtree.sh init git@github.com:YOURUSER/your-nvim-repo.git main
git push
```

Auto-update on bootstrap: `bootstrap.sh` runs `scripts/nvim-subtree.sh pull --auto` (no-op if unconfigured).
Manual:

```bash
make nvim-subtree-pull   # update vendored config from upstream
make nvim-subtree-push   # publish local changes back to upstream
```

---

## Startup checks / upgrades (and `fastfetch`)

Every interactive shell runs:

```
~/.dotfiles/scripts/startup.sh --auto
```

Default behavior (safe/fast):

* APT/Homebrew/mise checked on a **24h** cache (tweak via `DOTFILES_STARTUP_INTERVAL_HOURS`)
* No password prompts (skips upgrades if sudo isn’t cached)
* Prints a brief status and then runs **fastfetch** (or **neofetch**, or a tip to install)

Enable auto-upgrades on login (noninteractive) in `~/.config/dotfiles/env.sh`:

```bash
export DOTFILES_STARTUP_AUTO_UPGRADE=1
export DOTFILES_STARTUP_INTERVAL_HOURS=8   # optional, default 24
```

Manual full run (allows sudo prompts):

```bash
DOTFILES_STARTUP_AUTO_UPGRADE=1 ~/.dotfiles/scripts/startup.sh
```

---

## Linux install policy: **apt → mise → fallback**

* **apt first** for stable, non-version-critical packages (e.g., ripgrep, fzf, starship, lazygit if new enough).
* **mise** for version-controlled toolchains and **backends**:

  * Toolchains: `rust@latest`, `node@lts`, `go@latest`
  * Global packages: `npm:prettier`, `npm:npm@latest`, `cargo:ripgrep-all`, etc.
* **Fallback** for:

  * Official scripts/binaries (e.g., Starship, lazygit releases) when needed
  * `go install ...@latest` if appropriate

The helper script `scripts/smart-install.sh` applies this policy and exposes flags like `--min-version`.

---

## Environment variables

Create or edit `~/.config/dotfiles/env.sh` (stowed from `stow/env`), e.g.:

```bash
# Auto-upgrade on login (apt/brew/mise) – default is 0 (off)
export DOTFILES_STARTUP_AUTO_UPGRADE=0

# Cache window for startup checks (hours)
export DOTFILES_STARTUP_INTERVAL_HOURS=24

# Fonts during bootstrap (Linux + Windows via WSL): 1=install, 0=skip
export DOTFILES_INSTALL_FONTS=1

# Add anything else global you want here:
# export EDITOR="nvim"
```

`.zshrc` sources this file **before** running the startup hook, and also runs:

```zsh
if [ -t 1 ] && [ -x "$HOME/.dotfiles/scripts/startup.sh" ]; then
  "$HOME/.dotfiles/scripts/startup.sh" --auto || true
fi
```

---

## Windows Terminal settings

Keep your Windows Terminal JSONs in the repo and sync them:

```
win/windows-terminal/
  settings.json
  schemes.json
scripts/win/sync-windows-terminal.ps1
```

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $HOME '.dotfiles/scripts/win/sync-windows-terminal.ps1')
# add -Mode Symlink if you prefer live-linking (requires Dev Mode or admin)
```

---

## Script reference

### `bootstrap.sh`

Idempotent setup: installs Stow, runs `install-apt.sh` (Linux), **installs fonts** (Linux + Windows via WSL by default), installs mise & globals, pulls Neovim subtree (if configured), installs Neovim stable, runs smart installers (starship/lazygit), and prints next steps.

### `stow-all.sh`

Stows all packages under `stow/`, then overlays `hosts/@common`, `hosts/$(hostname)`, and `hosts/wsl` (if detected).

### `scripts/install-apt.sh`

Installs safe defaults from `packages/apt.txt` (includes `fontconfig` and `unzip` for fonts). Adds QoL aliases (e.g., `batcat`→`bat`, `fdfind`→`fd`) if needed.

### `scripts/install-brew.sh`

Installs Homebrew on macOS if missing and wires shell env. Use `brew bundle` with `packages/brew-Brewfile` if you want.

### `scripts/install-mise.sh`

Official installer (adds activation to your `~/.zshrc`):

```bash
curl -fsSL https://mise.run/zsh | sh
```

### `scripts/mise-setup-globals.sh`

Applies global toolchains and packages:

```bash
mise use -g -y rust@latest
mise use -g -y node@lts
mise use -g -y go@latest
mise use -g -y npm:npm@latest
mise use -g -y npm:prettier
mise use -g -y cargo:ripgrep-all
mise reshim
```

### `scripts/nvim-manager.sh`

Install/switch Neovim channels.

```
Usage: nvim-manager.sh {install|switch|current} {stable|nightly}

Linux:
  install stable   # download tarball to ~/.local/nvim/stable
  install nightly  # download tarball to ~/.local/nvim/nightly
  switch stable    # symlink ~/.local/bin/nvim -> stable
  switch nightly   # symlink ~/.local/bin/nvim -> nightly
  current          # show current symlink target

macOS:
  install stable   # brew install neovim
  install nightly  # brew install --HEAD neovim
  switch ...       # (advisory) PATH determines which brew nvim wins
  current          # prints nvim version
```

### `scripts/nvim-subtree.sh`

Manage your separate Neovim repo as a subtree under `stow/nvim/.config/nvim`.

```
Usage:
  nvim-subtree.sh init <repo-url> [branch]  # one-time add
  nvim-subtree.sh pull [--auto]             # update subtree from upstream
  nvim-subtree.sh push                      # publish changes upstream

Repo-local config:
  subtree.nvim.remote (default: nvim-origin)
  subtree.nvim.url
  subtree.nvim.branch (default: main)
```

### `scripts/adopt-existing.sh`

Safely import legacy dotfiles into this repo. **Auto-installs Stow** if missing.

```
Usage:
  adopt-existing.sh             # adopt all packages
  adopt-existing.sh zsh nvim    # adopt selected packages
  adopt-existing.sh --dry-run   # show changes only

Behavior:
  - Backs up real files that would be replaced to ./.migration_backups/<ts>/<pkg>/
  - Uses `stow --adopt` to move your existing files into package dirs
  - Restows to create symlinks
```

### `scripts/merge-from-backup.sh`

Interactively merge repo files with the latest backup snapshot from adoption.

```
Usage:
  MERGE_TOOL=nvimdiff|meld|code scripts/merge-from-backup.sh [pkg...]
```

### `scripts/smart-install.sh`

Implements **apt → mise → fallback** installation policy.

```
Usage examples:
  smart-install.sh starship
  smart-install.sh lazygit --min-version 0.41.0
  smart-install.sh "npm:prettier"
  smart-install.sh "cargo:ripgrep-all"
```

### `scripts/startup.sh`

Cached checks/upgrades + `fastfetch`. **Won’t block your prompt** in `--auto`.

```
Usage:
  startup.sh [--auto]

Env:
  DOTFILES_STARTUP_INTERVAL_HOURS=24
  DOTFILES_STARTUP_AUTO_UPGRADE=0|1
```

### `scripts/install-fonts-linux.sh`

Installs fonts listed in `fonts/manifest.json` into `~/.local/share/fonts`, then runs `fc-cache`.

### `scripts/win/install-fonts.ps1`

Installs fonts listed in `fonts/manifest.json` into the per-user Windows fonts folder and refreshes font cache.

### `scripts/win/sync-windows-terminal.ps1`

Copies or symlinks `win/windows-terminal/settings.json` into the correct Windows Terminal directory.

### `scripts/detect-os.sh`

Exports `OS` (`linux`|`mac`) and `WSL` (`1` if WSL detected).

### `scripts/set-default-shell-zsh.sh`

If `zsh` exists, sets it as the login shell via `chsh` (best-effort; safe to fail).

### `scripts/wsl-post.sh`

WSL niceties: clipboard tool, Git line endings (`core.autocrlf=input`), and optional `win32yank.exe` shim for Neovim clipboard.

---

## Host overlays

* `stow/hosts/@common/` stows after your base packages
* `stow/hosts/$(hostname)/` stows after `@common`
* `stow/hosts/wsl/` stows last on WSL

Put machine-specific tweaks (aliases, term settings, etc.) into the appropriate overlay and re-run `./stow-all.sh`.

---

## Troubleshooting

* **`nvim` wrong binary** → Ensure `~/.local/bin` is early in `PATH` (set in `.zshrc`).
* **`mise` not recognized after bootstrap** → Open a new shell (installer adds activation to your `~/.zshrc`) or `source ~/.zshrc`.
* **`git subtree` missing** → Linux: `sudo apt install git-subtree` (in `packages/apt.txt`). macOS: `brew install git`.
* **Startup upgrades blocking prompt** → They won’t in `--auto`. To do real upgrades, set `DOTFILES_STARTUP_AUTO_UPGRADE=1`. For immediate full upgrades with prompts, run `~/.dotfiles/scripts/startup.sh` without `--auto`.
* **Nightly Neovim download fails** → Check CPU arch handling in `nvim-manager.sh`; open an issue to add your arch if needed.

---

## Contributing / customizing

* Add more stow packages under `stow/<name>/` mirroring `$HOME` paths.
* Extend `mise-setup-globals.sh` with more `npm:` or `cargo:` globals and tool pins.
* Layer host-specific overrides in `stow/hosts/`.
* Tweak `packages/apt.txt` as you like; keep version-critical stuff out (we use mise for that).

---

Happy dotfiling ✨
