# Dotfiles Harness Ownership + Native-Linux Provisioning — Brief

## Hard Constraints

1. **WSL must keep working throughout.** Every change is additive with respect to the current
   platform. `PLATFORM=wsl` continues to select `hosts/wsl/`, and `win/` + `scripts/win/` are
   retained as the documented WSL-era path. At no point may the machine be left unable to provision.
2. **Reconcile the fork before anything else.** Local `main` and `origin/main` have diverged (3 local,
   9 remote commits). `git merge`, never `git rebase` — the local commits may exist elsewhere.
3. **Never force-push, hard-reset, `git branch -D`, or delete remote refs.** The 2022 clone's history
   exists in no other location; it is pushed as `archive/2022-pre-rewrite` before its clone is removed.
4. **No credentials or transcripts in the repo.** `.credentials.json`, `.claude.json`,
   `history.jsonl`, `projects/`, `sessions/`, `todos/`, `shell-snapshots/`, `stats/`, `debug/` stay
   untracked. The remote is public.
5. **No addressable endpoints committed.** `CC_NTFY_TOPIC` and the Tailscale IP are templated into
   gitignored env with a committed `.example`.
6. **Machine state is regenerated, not copied.** Any file carrying an absolute `/home/keenan` path
   (`installed_plugins.json`, `known_marketplaces.json`, `plugin-catalog-cache.json`, the plugin
   caches) is gitignored and rebuilt from `packages/claude-plugins.txt` on a new box.
7. **Reconciliation is per-package.** No wholesale `stow --adopt` and no wholesale overwrite. Every
   package follows its row in the Section 3 table, and live files are backed up to
   `.migration_backups/` before being replaced.
8. **`~/.ssh` private-key permissions are never widened.** Four private keys live there.
9. **`cc-account-switcher` and `astro_config` remain independent repos.** Declared and installed, not
   vendored.

## Non-Goals

- Migrating the OS itself, or provisioning the physical Linux machine.
- Migrating `~/.aws` / `~/.azure` *contents* out of `/mnt/c` — the dangling-symlink risk is
  documented as Q5, but the data move is separate work.
- Fonts, GUI, and dev-service daemon verification — explicitly outside the Docker harness.
- Refactoring `cc-account-switcher` itself, or any harness skill/hook behaviour. The harness is
  *versioned* here, not redesigned. The one exception is the `local-marketplace` relocation, which is
  a prerequisite for cross-profile correctness.
- Resolving the duplicate `superpowers` install (Q4) — flagged for a decision, not fixed here.
- macOS support beyond keeping the existing `mac` branches intact; it is not tested.

## Success Criteria

1. `git log` shows local and remote history reconciled, with no commits lost from either side.
2. `make verify-fresh` passes: `bootstrap.sh` + `stow-all.sh` complete non-interactively in a clean
   `ubuntu:24.04` container as a non-root sudo user, `make doctor` reports nothing missing, and every
   stow symlink resolves to a real file.
3. `make audit` reports no untracked-but-installed apt packages and no declared-but-uninstalled mise
   tools.
4. On this machine, every package in the Section 3 table is genuinely stowed — `~/.zshrc`,
   `~/.gitconfig`, `~/.tmux.conf`, `~/.config/{nvim,mise,zellij,dotfiles}`, `~/.local/bin/{nvimx,ccz}`
   all resolve into `~/.dotfiles`, with the pre-existing content preserved in `.migration_backups/`.
5. Switching profiles with `cca` leaves the same plugins enabled under both `rrp` and `kjweb`:
   `rrp/settings.json` is a symlink to shared, and `workflow-navigator@local` resolves under both.
6. A fresh `~/.claude-shared` can be reconstructed from the repo plus
   `scripts/install-claude-plugins.sh` and `scripts/claude-profile-init.sh`, with no absolute
   `/home/keenan` path in any tracked file.
7. `README.md` describes only things that exist — in particular `stow/hosts/` is real, and no table
   row says "install manually on a new machine."
8. `~/github/dotfiles` is gone locally, and its history is reachable from `origin/archive/2022-pre-rewrite`.
