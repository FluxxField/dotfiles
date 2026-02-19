#!/usr/bin/env bash
# Audit installed tools vs what dotfiles track.
#
# Reports:
#   APT  — entries in apt.txt not installed on this machine
#   APT  — manually installed packages not tracked in apt.txt
#   MISE — config.toml entries not installed
#   MISE — globally installed tools not in config.toml
#
# Usage:
#   scripts/audit.sh           # full report (colors if TTY)
#   scripts/audit.sh --no-color
set -uo pipefail   # no -e: arithmetic comparisons return non-zero for "false"

DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APT_LIST="$DOTFILES_ROOT/packages/apt.txt"
MISE_CONFIG="$DOTFILES_ROOT/stow/mise/.config/mise/config.toml"

# ── colour ────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--no-color" ]] || [[ ! -t 1 ]]; then
  RED='' YELLOW='' GREEN='' CYAN='' BOLD='' RESET=''
else
  RED='\033[0;31m' YELLOW='\033[1;33m' GREEN='\033[0;32m'
  CYAN='\033[0;36m' BOLD='\033[1m' RESET='\033[0m'
fi

header() { printf "\n${BOLD}${CYAN}=== %s ===${RESET}\n" "$*"; }
ok()     { printf "  ${GREEN}ok${RESET}  %s\n" "$*"; }
warn()   { printf "  ${YELLOW}??${RESET}  %s\n" "$*"; }
miss()   { printf "  ${RED}!!${RESET}  %s\n" "$*"; }

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'
}

# Returns 0 if the package name should be skipped (system/base/lib noise).
# Uses a grep-based approach so prefix and exact patterns are unambiguous.
is_system_pkg() {
  local pkg="$1"
  # Prefix matches — anything starting with these is a dep/system package
  local prefixes=(
    'lib'           # C libraries
    'python3-'      # Python bindings
    'python3.'      # python3.11, python3.12, …
    'linux-'        # kernel
    'fonts-'        # managed by fonts/manifest.json
    'cloud-'        # cloud-init family
    'iputils-'      # ping, tracepath, …
    'isc-dhcp-'     # DHCP client
    'ncurses-'      # terminal libs
    'fontconfig-'   # fontconfig helper packages (not fontconfig itself)
    'landscape-'    # Ubuntu Landscape
    'openssh-'      # SSH server/client (system-managed)
    'update-'       # update-manager, update-notifier, …
    'ubuntu-'       # ubuntu-standard, ubuntu-keyring, …
    'wsl-'          # WSL system packages
    'x11-'          # X11 system packages
  )
  for pfx in "${prefixes[@]}"; do
    [[ "$pkg" == "$pfx"* ]] && return 0
  done

  # Exact matches — known system/base/init/noise packages
  local exact=(
    adduser apparmor apport apt apt-transport-https apt-utils
    aspell at avahi-utils base-files base-passwd bash bash-completion
    bcache-tools binutils btrfs-progs bzip2 ca-certificates
    command-not-found console-setup dash dbus dbus-x11
    debconf debconf-i18n diffutils e2fsprogs eatmydata ed eject ethtool
    file findutils fwupd gawk grep gzip hostname
    info init iproute2 kbd kmod less locales lsb-release lvm2 lxd-agent-loader
    man-db manpages mawk mdadm media-types mesa-vulkan-drivers motd-news-config
    mount multipath-tools nano netbase netplan.io
    open-iscsi open-vm-tools overlayroot passwd patch perl pollinate
    procps psmisc python3 pulseaudio-utils rsyslog screen
    sensible-utils show-motd snapd software-properties-common
    sosreport ssh-import-id sudo sysvinit-utils time tzdata
    udev unattended-upgrades usrmerge whiptail wslu xfsprogs
    dirmngr gpg gnupg lsof
    # Ubuntu 22.04 base image specifics
    byobu ubuntu-advantage-tools ubuntu-keyring ubuntu-standard
    landscape-client landscape-common lxd-agent-loader
    ncurses-base ncurses-bin ncurses-term
  )
  for ex in "${exact[@]}"; do
    [[ "$pkg" == "$ex" ]] && return 0
  done

  return 1
}

# ── APT ───────────────────────────────────────────────────────────────────────
apt_audit() {
  command -v apt-get >/dev/null 2>&1 || return 0

  # ── 1. In apt.txt but not installed ──
  header "APT — in apt.txt but NOT installed"
  local any_missing=0
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if pkg_installed "$pkg"; then
      ok "$pkg"
    else
      miss "$pkg  ← not installed"
      any_missing=$(( any_missing + 1 ))
    fi
  done < "$APT_LIST"
  if [[ $any_missing -eq 0 ]]; then
    printf "  All tracked packages are installed.\n"
  fi

  # ── 2. Manually installed but not in apt.txt ──
  header "APT — manually installed but NOT tracked in apt.txt"

  local tracked
  tracked="$(grep -v '^\s*#' "$APT_LIST" | grep -v '^\s*$' | sort)"

  local any_untracked=0
  local filtered=0
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue

    if is_system_pkg "$pkg"; then
      filtered=$(( filtered + 1 ))
      continue
    fi

    if printf '%s\n' "$tracked" | grep -qx "$pkg"; then
      continue
    fi

    warn "$pkg  ← installed, not tracked"
    any_untracked=$(( any_untracked + 1 ))
  done < <(apt-mark showmanual 2>/dev/null | sort)

  if [[ $any_untracked -eq 0 ]]; then
    printf "  Nothing interesting untracked  (%d system/lib packages filtered).\n" "$filtered"
  else
    printf "\n  (%d system/lib packages filtered)\n" "$filtered"
  fi
}

# ── MISE ──────────────────────────────────────────────────────────────────────
mise_audit() {
  command -v mise >/dev/null 2>&1 || { printf "mise not found, skipping\n"; return 0; }

  # Parse tool names from [tools] section only (stop at next top-level section)
  local config_tools
  config_tools="$(awk '
    /^\[tools\]/ { in_tools=1; next }
    /^\[/        { in_tools=0 }
    in_tools && /=/ {
      sub(/[[:space:]]*=.*/, "")
      gsub(/^[[:space:]"]+|[[:space:]"]+$/, "")
      print
    }
  ' "$MISE_CONFIG" | sort)"

  local installed_tools
  installed_tools="$(mise ls --global 2>/dev/null | awk '{print $1}' | sort)"

  # ── 3. In config but not installed ──
  header "MISE — in config.toml but NOT installed"
  local any_missing=0
  while IFS= read -r tool; do
    [[ -z "$tool" ]] && continue
    if printf '%s\n' "$installed_tools" | grep -qx "$tool"; then
      ok "$tool"
    else
      miss "$tool  ← not installed"
      any_missing=$(( any_missing + 1 ))
    fi
  done <<< "$config_tools"
  if [[ $any_missing -eq 0 ]]; then
    printf "  All configured tools are installed.\n"
  fi

  # ── 4. Installed but not in config ──
  header "MISE — installed globally but NOT in config.toml"
  local any_untracked=0
  while IFS= read -r tool; do
    [[ -z "$tool" ]] && continue
    if ! printf '%s\n' "$config_tools" | grep -qx "$tool"; then
      warn "$tool  ← installed, not in config"
      any_untracked=$(( any_untracked + 1 ))
    fi
  done <<< "$installed_tools"
  if [[ $any_untracked -eq 0 ]]; then
    printf "  Nothing untracked.\n"
  fi
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
printf "\n${BOLD}Dotfiles Audit — %s${RESET}\n" "$(date)"
printf "  dotfiles root : %s\n" "$DOTFILES_ROOT"
printf "  apt list      : %s\n" "$APT_LIST"
printf "  mise config   : %s\n" "$MISE_CONFIG"

apt_audit
mise_audit

printf "\n${BOLD}Audit complete.${RESET}\n\n"
