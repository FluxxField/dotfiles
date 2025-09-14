#!/usr/bin/env bash
# Startup checks/upgrades with optional auto-upgrade.
# Modes:
#   Default: show counts + fastfetch (never blocks)
#   --auto: terse output; if DOTFILES_STARTUP_AUTO_UPGRADE=1, try noninteractive upgrades
#   Manual (no --auto): allow sudo prompts and do full upgrades if DOTFILES_STARTUP_AUTO_UPGRADE=1
#
# Env:
#   DOTFILES_STARTUP_INTERVAL_HOURS=24   # cache window for checks/upgrades
#   DOTFILES_STARTUP_AUTO_UPGRADE=0|1    # enable real upgrades (apt/brew/mise)
#
set -euo pipefail

AUTO=0
[[ "${1:-}" == "--auto" ]] && AUTO=1

OS="$(uname -s)"
CACHE_DIR="${HOME}/.cache/dotfiles/startup"
INTERVAL_HOURS="${DOTFILES_STARTUP_INTERVAL_HOURS:-24}"
AUTO_UPGRADE="${DOTFILES_STARTUP_AUTO_UPGRADE:-0}"

mkdir -p "$CACHE_DIR"
now_epoch() { date +%s; }
stamp_file() { echo "${CACHE_DIR}/${1}.stamp"; }

should_run() {
  local key="$1" now last
  now="$(now_epoch)"
  if [[ ! -f "$(stamp_file "$key")" ]]; then return 0; fi
  last="$(cat "$(stamp_file "$key")" 2>/dev/null || echo 0)"
  local diff=$(( (now - last) / 3600 ))
  [[ "$diff" -ge "$INTERVAL_HOURS" ]]
}
mark_ran() { now_epoch >"$(stamp_file "$1")"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }
print() { (( AUTO )) && echo "$*" || echo "• $*"; }

# ---------- APT ----------
apt_check_or_upgrade() {
  [[ "$OS" == "Linux" ]] || return 0
  has_cmd apt-get || return 0
  should_run apt || return 0

  # Always do update; in --auto require cached sudo to avoid blocking
  if has_cmd sudo; then
    if (( AUTO )); then
      if sudo -n true 2>/dev/null; then
        sudo apt-get update -o=Dpkg::Use-Pty=0 >/dev/null 2>&1 || true
      else
        print "APT: skipped 'update' (sudo not cached)"
      fi
    else
      sudo apt-get update -o=Dpkg::Use-Pty=0 >/dev/null 2>&1 || true
    fi
  else
    apt-get update -o=Dpkg::Use-Pty=0 >/dev/null 2>&1 || true
  fi

  if (( AUTO_UPGRADE )); then
    # Noninteractive upgrade in --auto; interactive allowed otherwise
    if has_cmd sudo; then
      if (( AUTO )); then
        if sudo -n true 2>/dev/null; then
          sudo DEBIAN_FRONTEND=noninteractive \
            apt-get -y -o Dpkg::Options::="--force-confdef" \
                       -o Dpkg::Options::="--force-confold" \
            upgrade >/dev/null 2>&1 || true
          print "APT: auto-upgrade attempted"
        else
          print "APT: skipped 'upgrade' (sudo not cached)"
        fi
      else
        # Manual run may prompt for password
        sudo DEBIAN_FRONTEND=noninteractive \
          apt-get -y -o Dpkg::Options::="--force-confdef" \
                     -o Dpkg::Options::="--force-confold" \
          upgrade || true
        print "APT: upgrade completed (manual)"
      fi
    fi
  else
    # Just show count of upgradable packages
    local count
    count="$(apt list --upgradable 2>/dev/null | awk 'NR>1 {c++} END{print c+0}')"
    print "APT: ${count} package(s) upgradable"
  fi

  mark_ran apt
}

# ---------- HOMEBREW ----------
brew_check_or_upgrade() {
  [[ "$OS" == "Darwin" ]] || return 0
  has_cmd brew || return 0
  should_run brew || return 0

  brew update --quiet >/dev/null 2>&1 || true
  if (( AUTO_UPGRADE )); then
    # In --auto keep it quiet; manual can be verbose
    if (( AUTO )); then
      brew upgrade --quiet >/dev/null 2>&1 || true
      print "Homebrew: auto-upgrade attempted"
    else
      brew upgrade || true
      print "Homebrew: upgrade completed (manual)"
    fi
  } else {
    local count
    count="$(brew outdated --quiet | wc -l | tr -d ' ')"
    print "Homebrew: ${count} package(s) outdated"
  fi
  mark_ran brew
}

# ---------- MISE ----------
mise_check_or_upgrade() {
  has_cmd mise || return 0
  should_run mise || return 0

  if (( AUTO_UPGRADE )); then
    # Prefer 'mise upgrade' if present; fallback to 'mise install -y'
    if mise --help 2>/dev/null | grep -qE '^ +upgrade '; then
      if (( AUTO )); then
        mise upgrade --yes >/dev/null 2>&1 || true
      else
        mise upgrade --yes || true
      fi
      print "mise: upgrade attempted"
    else
      if (( AUTO )); then
        mise install -y >/dev/null 2>&1 || true
      else
        mise install -y || true
      fi
      print "mise: install attempted"
    fi
  else
    local out count
    out="$(mise outdated 2>/dev/null || true)"
    count="$(printf "%s\n" "$out" | awk 'NF{c++} END{print c+0}')"
    print "mise: ${count} update(s) available"
  fi

  mark_ran mise
}

run_fastfetch() {
  if has_cmd fastfetch; then
    fastfetch
  elif has_cmd neofetch; then
    neofetch
  elif (( ! AUTO )); then
    echo "Tip: install fastfetch for a system summary (e.g., 'sudo apt-get install fastfetch')."
  fi
}

main() {
  apt_check_or_upgrade
  brew_check_or_upgrade
  mise_check_or_upgrade
  run_fastfetch
}

main
