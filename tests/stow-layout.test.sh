#!/usr/bin/env bash
# Every stow package mirrors $HOME. A dotfile sitting at a package root would be
# linked to ~/<name> instead of its real location — how stow/gnupg/gpg-agent.conf
# was destined for ~/gpg-agent.conf rather than ~/.gnupg/gpg-agent.conf (§4.19).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
source "$HERE/assert.sh"

# gnupg specifically: the config must be under .gnupg/.
assert_file "$ROOT/stow/gnupg/.gnupg/gpg-agent.conf"
assert_fail test -e "$ROOT/stow/gnupg/gpg-agent.conf"

# General rule: no package may contain a top-level *file* that is not a dotfile
# destined for $HOME. Every real payload belongs under a dot-directory or is a
# dotfile itself. Flag anything else as a probable mis-layout.
bad=""
for pkg in "$ROOT"/stow/*/; do
  [ -d "$pkg" ] || continue
  case "$(basename "$pkg")" in hosts) continue ;; esac
  while IFS= read -r f; do
    case "$(basename "$f")" in
      .*) ;;                       # ~/.zshrc, ~/.gitconfig, ~/.tmux.conf — correct
      *) bad="$bad $f" ;;          # non-dotfile at package root — suspicious
    esac
  done < <(find "$pkg" -maxdepth 1 -type f)
done
assert_eq "$bad" "" "no non-dotfile at any stow package root"
echo "stow-layout ok"
