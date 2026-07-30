# Finding — does Claude Code expand `${VAR}` in settings.json?

**Date:** 2026-07-29
**Claude Code version:** `2.1.220 (Claude Code)`
**Why this exists:** brief.md requires this "decided and RECORDED in unit 2, not improvised".
design.md §4.5 has two structurally different branches and unit 5 cannot start without knowing which.
There is no in-repo precedent — no `${` appears anywhere in settings.json or settings.local.json.

## Method

Tested against a throwaway `CLAUDE_CONFIG_DIR` under `/tmp` (mode 700), never the live profile.
Three distinct consumers, because they are different code paths and may disagree.

Two deviations from the planned method, both forced and both material:

1. **A throwaway config dir is not logged in.** The first run returned `Not logged in · Please run /login`.
   Resolved by **symlinking** `~/.claude-accounts/rrp/.credentials.json` into the sandbox rather than
   copying it — the secret is never duplicated on disk. A `.claude.json` stub carrying only the
   onboarding/trust flags (no project history) was generated alongside it.
2. **Every probe needed a control.** The planned probes were run and then re-run with an input that
   *cannot* match. Where the control produced the same result, the probe proves nothing and is recorded
   as inconclusive rather than as a pass. This caught a false positive — see the permission-glob row.

## Results

| Consumer | Probe | Observed output | Expands? |
|---|---|---|---|
| `env` block | `"CC_EXPANSION_PROBE": "${HOME}/probe-marker"` | `${HOME}/probe-marker` | **no** |
| permission glob | `"deny": ["Read(${HOME}/**)"]` | read succeeded (not blocked) | **inconclusive** |
| `additionalDirectories` | `["${HOME}/github"]` | *"I don't have any additional working directories configured"* | **no** |

**`env` block — no.** The literal `${HOME}/probe-marker` came back. This is self-controlling: the
variable was *set at all*, which proves the sandbox `settings.json` was read. Unexpanded.

**Permission glob — inconclusive, and the planned probe was invalid.** The plan's probe reads
`/etc/hostname` under `"allow": ["Read(${HOME}/**)"]`, but `/etc/hostname` is not under `$HOME`, so it
cannot discriminate. Re-run against a file that *is* under `$HOME`: the read succeeded — but so did the
control with `"allow": ["Read(/nonexistent-control-path/**)"]`, so Read was permitted regardless.
Switching to `deny` (which overrides allow) did not block either, and **neither did the literal-path
control** `"deny": ["Read(/home/keenan/**)"]`. So permission entries were not being enforced in this
harness at all — `claude -p` emitted *"Ignoring N permissions entries … this workspace has not been
trusted"*. **No conclusion may be drawn about this consumer.** Had the plan been followed literally, this
row would have been recorded as "expands" on the strength of a read that would have succeeded anyway.

**`additionalDirectories` — no, and this one is properly controlled.** `${HOME}/github` did not
register. The literal-path control `["/home/keenan/github"]` **did** register and was echoed back, so
the probe discriminates and the negative result is real.

## Decision

**Branch B — expansion does not work (any consumer).** `settings.json` gets exactly the `env.sh`/`routes`
treatment: the real file becomes gitignored, a tracked `settings.json.example` carries `$HOME`-relative
placeholders, and `install-env.sh` materializes the real file (substituting the actual `$HOME`)
**before** `stow-all.sh` runs. `settings.json` moves from the Versioned list to the
gitignored-materialized list for §4.1's assertions, and `packages/harness-manifest.txt` must be updated
to reclassify it from `versioned` to `ignored` with `settings.json.example` added as `versioned`.
`CC_NTFY_TOPIC` is removed from the committed file entirely and the notifying hook reads
`$CC_NTFY_TOPIC` from the environment (§4.4 mechanism 2).

Two of three consumers definitively do not expand, and the third is unresolved — the plan's stated tie-break
("**Mixed result:** Branch B applies — it is the safe superset") therefore selects Branch B outright. The
unresolved consumer cannot change this: Branch B is already the branch that assumes no expansion anywhere.

## Consequences for unit 5

- Which §4.5 branch: **B**
- `packages/harness-manifest.txt` change required: **reclassify `settings.json` `versioned` → `ignored`,
  add `settings.json.example` as `versioned`**
- `install-env.sh` must materialize `settings.json`: **yes**, before `stow-all.sh`

**Not permitted under either branch:** rewriting a stowed `settings.json` in place. It is a symlink into
the repo, so a post-stow edit would modify the tracked file and break SC11's `git status --porcelain` check.

## Incidental finding — `.credentials.json` is per-account, not shared

Locating the credential for the sandbox showed it lives at `~/.claude-accounts/<slug>/.credentials.json`
(present for both `rrp` and `kjweb`), **not** at `~/.claude-shared/.credentials.json` — that path does not
exist. So it is an `ACCOUNT_ITEM`, not a `SHARED_ITEM`.

Consequence: unit 5 vendors `~/.claude-shared/**` into `stow/claude/.claude-shared/`, and the credential
is not in that tree, so it was never reachable by the harness `git add`. The
`stow/claude/.claude-shared/.credentials.json` `.gitignore` rule and its `never` manifest entry are
harmless belt-and-braces, but they describe a path that does not exist. Keep them (defence in depth, and
the classification is still correct), but do not treat them as the control that satisfies HC4 for
credentials — the real control is that the account directories are outside the vendored tree entirely.
