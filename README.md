# Dotfiles

Manage dotfiles with GNU Stow. Safe, idempotent, cross‑platform (Linux, macOS, WSL2).

## Usage

- `bash bootstrap.sh` – install core tooling, shells, and language managers.
- `./stow-all.sh` – symlink all packages in `stow/` into `$HOME`.
- `make doctor` – quick checks.

## Host‑specific config

Place overrides in `stow/hosts/$(hostname)/`. These are stowed *after* `@common`.

## Secrets

Keep secrets outside git in `secrets/` or a password manager CLI. Consider `age` or `git‑crypt` if you must commit encrypted data.
