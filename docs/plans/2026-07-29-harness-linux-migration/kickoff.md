# Dotfiles Harness Ownership + Native-Linux Provisioning — Kickoff

**Date:** 2026-07-29
**Branch:** feat/harness-linux-migration
**Work type:** feature (Tier 4 — Large Feature / Refactor)
**Repos:** dotfiles (`~/.dotfiles`, remote `FluxxField/dotfiles`)
**Worktrees:**
- `~/.dotfiles/.worktrees/feat/harness-linux-migration`

> Note: this is NOT an RRP repo. There is no `dev` branch — the feature branch cuts off
> `main` and the PR targets `main`.

## Problem

The dotfiles repo has not been meaningfully updated in months and no longer describes the
machine it manages. Nothing is stowed: `~/.zshrc`, `~/.gitconfig`, `~/.config/{nvim,mise,zellij}`
and `~/.tmux.conf` are all real files that diverge from their `stow/` counterparts, and
`~/.config/dotfiles/env.sh` + `~/.local/bin/nvimx` were never created at all. Separately, the
entire Claude Code harness (17 skills, 16 hooks, 10 commands, 4 agents, the `workflow-navigator`
plugin, the profile-switcher wiring) is unversioned in any repo. A Windows → native-Linux OS
migration is planned, and the repo's provisioning path still assumes WSL.

## Design Decision

Vendor the CC harness as a **new `stow/claude` package** (Approach A) rather than splitting it
into a separate repo or a second `git subtree`. Stow's tree-folding naturally separates versioned
declarations from regenerable machine state, keeps one repo and one `stow-all.sh` for a fresh box,
and avoids repeating the drift the existing `nvim` subtree already exhibits. `cc-account-switcher`
and `astro_config` stay their own repos — dotfiles declares and invokes their installers.

Platform support becomes explicit via a `PLATFORM` (`wsl` | `linux` | `mac`) export driving
`stow/hosts/` overlays, so WSL keeps working throughout and the migration is incremental and
reversible.

## Skill Chain

brainstorm ✓ → adversarial-review → codebase-scan → writing-plans → cross-cut-plan-audit →
security-plan-audit → implement → seam-analysis → drift-detection → post-build-quality →
verification → PR
