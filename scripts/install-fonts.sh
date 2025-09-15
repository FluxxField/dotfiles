#!/usr/bin/env bash
# Install fonts from shared manifest into ~/.local/share/fonts
# - Nerd Fonts families (latest release)
# - Optional symbols-only pack
# - Extra URLs (.ttf/.otf/.zip)
# - Local repo fonts directory
#
# Usage:
#   scripts/install-fonts-linux.sh
set -euo pipefail

MANIFEST="$(cd "$(dirname "$0")/.." && pwd)/fonts/manifest.json"
FONT_BASE="$HOME/.local/share/fonts"
FONT_DIR="$FONT_BASE/NerdFonts"

need() { command -v "$1" >/dev/null 2>&1 || {
  echo "Missing dependency: $1" >&2
  exit 1
}; }

need curl
need unzip
need fc-cache || true # from fontconfig; we'll warn if missing

if [[ ! -f "$MANIFEST" ]]; then
  echo "Manifest not found: $MANIFEST" >&2
  exit 1
fi

# Parse JSON via python3 (portable)
need python3
meta="$(
  python3 - "$MANIFEST" <<'PY'
import json, sys, os
p=sys.argv[1]
mf=json.load(open(p))
families=[s for s in mf.get("nerd_fonts",[]) if s and s.strip()]
for s in families: print("NF:"+s)
print("INCLUDE_SYMBOLS:"+("1" if mf.get("include_symbols") else "0"))
for u in mf.get("extra_urls",[]): 
    if u: print("URL:"+u)
print("LOCAL_DIR:"+mf.get("local_dir",""))
PY
)"

FONTS=()
INCLUDE_SYMBOLS=0
EXTRA_URLS=()
LOCAL_DIR=""

while IFS= read -r line; do
  case "$line" in
  NF:*) FONTS+=("${line#NF:}") ;;
  INCLUDE_SYMBOLS:*) INCLUDE_SYMBOLS="${line#INCLUDE_SYMBOLS:}" ;;
  URL:*) EXTRA_URLS+=("${line#URL:}") ;;
  LOCAL_DIR:*) LOCAL_DIR="${line#LOCAL_DIR:}" ;;
  esac
done <<<"$meta"

mkdir -p "$FONT_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1) Nerd Fonts families
for name in "${FONTS[@]}"; do
  url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${name}.zip"
  echo "Downloading $name Nerd Font..."
  curl -fsSL "$url" -o "$TMP/$name.zip"
  unzip -qo "$TMP/$name.zip" -d "$TMP/$name"
  mkdir -p "$FONT_DIR/$name"
  find "$TMP/$name" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -exec cp -f {} "$FONT_DIR/$name/" \;
done

# Symbols-only pack
if [[ "$INCLUDE_SYMBOLS" == "1" ]]; then
  echo "Downloading NerdFontsSymbolsOnly.zip..."
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip" -o "$TMP/SymbolsOnly.zip"
  unzip -qo "$TMP/SymbolsOnly.zip" -d "$TMP/SymbolsOnly"
  mkdir -p "$FONT_DIR/SymbolsOnly"
  find "$TMP/SymbolsOnly" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -exec cp -f {} "$FONT_DIR/SymbolsOnly/" \;
fi

# 2) Extra URLs
for u in "${EXTRA_URLS[@]}"; do
  [[ -z "$u" ]] && continue
  base="$TMP/$(basename "$u")"
  echo "Downloading extra: $u"
  curl -fsSL "$u" -o "$base"
  case "$base" in
  *.zip | *.ZIP)
    dir="$TMP/extra-$(date +%s%N)"
    mkdir -p "$dir"
    unzip -qo "$base" -d "$dir"
    find "$dir" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -exec cp -f {} "$FONT_DIR/" \;
    ;;
  *)
    cp -f "$base" "$FONT_DIR/"
    ;;
  esac
done

# 3) Local repo fonts
if [[ -n "$LOCAL_DIR" ]]; then
  src="$(cd "$(dirname "$MANIFEST")/.." && pwd)/$LOCAL_DIR"
  if [[ -d "$src" ]]; then
    find "$src" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -exec cp -f {} "$FONT_DIR/" \;
  fi
fi

echo "Rebuilding font cache..."
if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$FONT_BASE" || true
else
  echo "Warning: 'fc-cache' not found; install 'fontconfig' to refresh cache." >&2
fi

echo "Fonts installed under: $FONT_DIR"
