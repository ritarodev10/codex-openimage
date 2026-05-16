#!/usr/bin/env bash
# scan-image-slots.sh — emit JSON of image references in the current project.
#
# Usage:
#   scan-image-slots.sh [--detect-only]
#
# Modes:
#   default      — emit { framework, image_dir, slots: [...] }
#   --detect-only — emit { framework, image_dir, palette, site_name } only
#
# Output: JSON to stdout. Errors go to stderr. Exit non-zero on hard failure.
#
# Detects framework via marker files + package.json deps, picks an image_dir,
# walks source files for <img>, <Image>, <NextImage>, background-image: url(...),
# og:image / twitter:image meta tags, and resolves each match to an absolute path.
#
# Uses jq if installed, otherwise hand-rolled JSON via printf.

set -u
# Do NOT set -e: grep returning 1 (no match) is normal here.

ROOT="$(pwd)"
DETECT_ONLY=0

# ---------- args ----------
for arg in "$@"; do
  case "$arg" in
    --detect-only) DETECT_ONLY=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "scan-image-slots: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

HAS_JQ=0
command -v jq >/dev/null 2>&1 && HAS_JQ=1

# ---------- framework detection ----------
detect_framework() {
  local fw=""
  [ -f "$ROOT/next.config.js" ] || [ -f "$ROOT/next.config.mjs" ] || [ -f "$ROOT/next.config.ts" ] && fw="next"
  [ -z "$fw" ] && { [ -f "$ROOT/nuxt.config.js" ] || [ -f "$ROOT/nuxt.config.ts" ]; } && fw="nuxt"
  [ -z "$fw" ] && { [ -f "$ROOT/astro.config.mjs" ] || [ -f "$ROOT/astro.config.js" ] || [ -f "$ROOT/astro.config.ts" ]; } && fw="astro"
  [ -z "$fw" ] && { [ -f "$ROOT/svelte.config.js" ] || [ -f "$ROOT/svelte.config.ts" ]; } && fw="svelte"
  [ -z "$fw" ] && { [ -f "$ROOT/vite.config.js" ] || [ -f "$ROOT/vite.config.ts" ]; } && fw="vite"

  if [ -z "$fw" ] && [ -f "$ROOT/package.json" ]; then
    local pkg
    pkg="$(cat "$ROOT/package.json" 2>/dev/null)"
    if echo "$pkg" | grep -qE '"(next)"[[:space:]]*:'; then fw="next"
    elif echo "$pkg" | grep -qE '"(nuxt)"[[:space:]]*:'; then fw="nuxt"
    elif echo "$pkg" | grep -qE '"(astro)"[[:space:]]*:'; then fw="astro"
    elif echo "$pkg" | grep -qE '"(remix|@remix-run/[^"]+)"[[:space:]]*:'; then fw="remix"
    elif echo "$pkg" | grep -qE '"(gatsby)"[[:space:]]*:'; then fw="gatsby"
    elif echo "$pkg" | grep -qE '"(@sveltejs/kit|svelte)"[[:space:]]*:'; then fw="svelte"
    elif echo "$pkg" | grep -qE '"(vite)"[[:space:]]*:'; then fw="vite"
    fi
  fi
  [ -z "$fw" ] && fw="unknown"
  echo "$fw"
}

decide_image_dir() {
  local fw="$1"
  case "$fw" in
    next|nuxt|astro|vite|remix|gatsby) [ -d "$ROOT/public" ] && echo "public/images" || echo "images" ;;
    svelte) [ -d "$ROOT/static" ] && echo "static/images" || echo "images" ;;
    *) [ -d "$ROOT/public" ] && echo "public/images" || echo "images" ;;
  esac
}

detect_site_name() {
  if [ -f "$ROOT/package.json" ]; then
    local n
    n="$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$ROOT/package.json" | head -1 | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    [ -n "$n" ] && { echo "$n"; return; }
  fi
  basename "$ROOT"
}

FRAMEWORK="$(detect_framework)"
IMAGE_DIR="$(decide_image_dir "$FRAMEWORK")"
SITE_NAME="$(detect_site_name)"
# TODO(v2): extract palette from tailwind.config / CSS vars / theme files.
PALETTE=""

# ---------- JSON helpers ----------
json_escape() {
  # Escape \, ", control chars, newlines for JSON string content.
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

emit_detect_only() {
  if [ "$HAS_JQ" -eq 1 ]; then
    jq -nc \
      --arg framework "$FRAMEWORK" \
      --arg image_dir "$IMAGE_DIR" \
      --arg palette "$PALETTE" \
      --arg site_name "$SITE_NAME" \
      '{framework: $framework, image_dir: $image_dir, palette: $palette, site_name: $site_name}'
  else
    printf '{"framework":"%s","image_dir":"%s","palette":"%s","site_name":"%s"}\n' \
      "$(json_escape "$FRAMEWORK")" \
      "$(json_escape "$IMAGE_DIR")" \
      "$(json_escape "$PALETTE")" \
      "$(json_escape "$SITE_NAME")"
  fi
}

if [ "$DETECT_ONLY" -eq 1 ]; then
  emit_detect_only
  exit 0
fi

# ---------- slot scanning ----------
SLOT_FILES_PATTERN='.*\.\(tsx\|jsx\|ts\|js\|vue\|astro\|svelte\|html\|mdx\|md\)$'
CSS_FILES_PATTERN='.*\.\(scss\|css\)$'

# Build a list of candidate source files, skipping noise dirs.
SRC_FILES=$(find "$ROOT" \
  \( -path '*/node_modules' -o -path '*/.next' -o -path '*/.nuxt' -o -path '*/dist' \
     -o -path '*/build' -o -path '*/.git' -o -path '*/.svelte-kit' -o -path '*/.output' \
     -o -path '*/coverage' \) -prune -o \
  -type f -regex "$SLOT_FILES_PATTERN" -print 2>/dev/null)

CSS_SRC_FILES=$(find "$ROOT" \
  \( -path '*/node_modules' -o -path '*/.next' -o -path '*/.nuxt' -o -path '*/dist' \
     -o -path '*/build' -o -path '*/.git' -o -path '*/.svelte-kit' -o -path '*/.output' \
     -o -path '*/coverage' \) -prune -o \
  -type f -regex "$CSS_FILES_PATTERN" -print 2>/dev/null)

# Intent guess from a path string (basename hints).
intent_from_path() {
  local p="$1"
  local b
  b="$(basename "$p" | tr '[:upper:]' '[:lower:]')"
  case "$b" in
    hero*|*-hero*|*_hero*) echo "hero" ;;
    og*|twitter*|social-card*|share-*) echo "og" ;;
    feat*|feature*) echo "feature-card" ;;
    icon*|*-icon*) echo "icon" ;;
    logo*) echo "logo" ;;
    favicon*) echo "favicon-source" ;;
    avatar*) echo "avatar" ;;
    product-*) echo "product-mockup" ;;
    placeholder*) echo "placeholder" ;;
    *) echo "unknown" ;;
  esac
}

# Resolve a src like /images/foo.png against ROOT and image_dir.
resolve_abs() {
  local src="$1"
  case "$src" in
    /*) printf '%s%s' "$ROOT" "$src" ;;
    http://*|https://*|data:*) printf '%s' "$src" ;;
    *) printf '%s/%s' "$ROOT" "$src" ;;
  esac
}

# Slot emission state.
SLOT_COUNT=0
TMP_SLOTS="$(mktemp -t scan-slots.XXXXXX)"
trap 'rm -f "$TMP_SLOTS"' EXIT

emit_slot() {
  local kind="$1" src="$2" file="$3" line="$4"
  local abs exists intent id
  abs="$(resolve_abs "$src")"
  case "$src" in http://*|https://*|data:*) exists="true" ;; *) [ -f "$abs" ] && exists="true" || exists="false" ;; esac
  intent="$(intent_from_path "$src")"
  SLOT_COUNT=$((SLOT_COUNT + 1))
  id="slot-${SLOT_COUNT}"
  local rel_file="${file#$ROOT/}"
  if [ "$HAS_JQ" -eq 1 ]; then
    jq -nc \
      --arg id "$id" --arg kind "$kind" --arg src "$src" \
      --arg abs_path "$abs" --argjson exists "$exists" \
      --arg context_file "$rel_file" --argjson context_line "$line" \
      --arg intent_guess "$intent" \
      '{id:$id, kind:$kind, src:$src, abs_path:$abs_path, exists:$exists, context_file:$context_file, context_line:$context_line, intent_guess:$intent_guess}' \
      >> "$TMP_SLOTS"
  else
    printf '{"id":"%s","kind":"%s","src":"%s","abs_path":"%s","exists":%s,"context_file":"%s","context_line":%s,"intent_guess":"%s"}\n' \
      "$id" "$kind" "$(json_escape "$src")" "$(json_escape "$abs")" "$exists" \
      "$(json_escape "$rel_file")" "$line" "$intent" >> "$TMP_SLOTS"
  fi
}

# Pass 1: <img src="...">, <Image src="...">, <NextImage src="...">
scan_jsx_img() {
  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # match <img ... src="..." | <Image ... src="..." | <NextImage ... src="..."
    grep -nE '<(img|Image|NextImage)[^>]*[[:space:]]src=("|'"'"')([^"'"'"']+)' "$f" 2>/dev/null \
      | while IFS=: read -r ln rest; do
          src=$(printf '%s' "$rest" | grep -oE 'src=("|'"'"')[^"'"'"']+' | head -1 | sed -E 's/^src=("|'"'"')//')
          [ -n "$src" ] && emit_slot "img" "$src" "$f" "$ln"
        done
  done <<< "$SRC_FILES"
}

# Pass 2: og:image / twitter:image meta tags
scan_meta() {
  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    grep -nE '(og:image|twitter:image)' "$f" 2>/dev/null \
      | grep -E 'content=("|'"'"')[^"'"'"']+' \
      | while IFS=: read -r ln rest; do
          src=$(printf '%s' "$rest" | grep -oE 'content=("|'"'"')[^"'"'"']+' | head -1 | sed -E 's/^content=("|'"'"')//')
          kind="og-meta"
          printf '%s' "$rest" | grep -q 'twitter:image' && kind="twitter-meta"
          [ -n "$src" ] && emit_slot "$kind" "$src" "$f" "$ln"
        done
  done <<< "$SRC_FILES"
}

# Pass 3: background-image: url(...) in CSS/SCSS
scan_css_bg() {
  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    grep -nE 'background(-image)?[[:space:]]*:[^;]*url\(' "$f" 2>/dev/null \
      | while IFS=: read -r ln rest; do
          src=$(printf '%s' "$rest" | grep -oE "url\(['\"]?[^'\")]+['\"]?\)" | head -1 \
                  | sed -E "s/^url\(['\"]?//; s/['\"]?\)$//")
          [ -n "$src" ] && emit_slot "css-bg" "$src" "$f" "$ln"
        done
  done <<< "$CSS_SRC_FILES"
}

scan_jsx_img
scan_meta
scan_css_bg

# ---------- emit final JSON ----------
if [ "$HAS_JQ" -eq 1 ]; then
  # Each line in $TMP_SLOTS is a JSON object; jq -s slurps them into an array.
  jq -s --arg framework "$FRAMEWORK" --arg image_dir "$IMAGE_DIR" \
    '{framework: $framework, image_dir: $image_dir, slots: .}' "$TMP_SLOTS"
else
  printf '{"framework":"%s","image_dir":"%s","slots":[' \
    "$(json_escape "$FRAMEWORK")" "$(json_escape "$IMAGE_DIR")"
  first=1
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ "$first" -eq 1 ]; then first=0; else printf ','; fi
    printf '%s' "$line"
  done < "$TMP_SLOTS"
  printf ']}\n'
fi
