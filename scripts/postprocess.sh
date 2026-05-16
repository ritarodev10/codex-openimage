#!/usr/bin/env bash
# postprocess.sh — strip EXIF, emit WebP, emit @2x retina, write sidecar .meta.json
#
# Usage:
#   postprocess.sh [flags] <path.png> [<path2.png> ...]
#
# Flags:
#   --prompt "..."   original prompt text to record in sidecar
#   --no-webp        skip WebP sibling
#   --no-retina      skip @2x retina variant
#   --no-strip       skip EXIF strip
#
# Detects tools at startup and degrades gracefully if any are missing.

set -u

PROMPT=""
DO_WEBP=1
DO_RETINA=1
DO_STRIP=1

FILES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prompt)   PROMPT="${2:-}"; shift 2 ;;
    --no-webp)  DO_WEBP=0; shift ;;
    --no-retina) DO_RETINA=0; shift ;;
    --no-strip) DO_STRIP=0; shift ;;
    -h|--help)  sed -n '2,16p' "$0"; exit 0 ;;
    --) shift; while [ "$#" -gt 0 ]; do FILES+=("$1"); shift; done ;;
    -*) echo "postprocess: unknown flag: $1" >&2; exit 2 ;;
    *)  FILES+=("$1"); shift ;;
  esac
done

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "postprocess: no input files (pass one or more PNG paths)" >&2
  exit 2
fi

# ---------- tool detection ----------
HAS_EXIFTOOL=0; command -v exiftool >/dev/null 2>&1 && HAS_EXIFTOOL=1
HAS_SIPS=0;     command -v sips     >/dev/null 2>&1 && HAS_SIPS=1
HAS_CWEBP=0;    command -v cwebp    >/dev/null 2>&1 && HAS_CWEBP=1
HAS_MAGICK=0;   command -v magick   >/dev/null 2>&1 && HAS_MAGICK=1
HAS_CONVERT=0;  command -v convert  >/dev/null 2>&1 && HAS_CONVERT=1
HAS_JQ=0;       command -v jq       >/dev/null 2>&1 && HAS_JQ=1

[ "$DO_STRIP"  -eq 1 ] && [ "$HAS_EXIFTOOL" -eq 0 ] && [ "$HAS_SIPS" -eq 0 ] \
  && echo "postprocess: warning — no exiftool or sips; EXIF strip will be skipped" >&2
[ "$DO_WEBP"   -eq 1 ] && [ "$HAS_CWEBP" -eq 0 ] && [ "$HAS_MAGICK" -eq 0 ] && [ "$HAS_CONVERT" -eq 0 ] \
  && echo "postprocess: warning — no cwebp or imagemagick; WebP siblings will be skipped" >&2
[ "$DO_RETINA" -eq 1 ] && [ "$HAS_SIPS" -eq 0 ] && [ "$HAS_MAGICK" -eq 0 ] && [ "$HAS_CONVERT" -eq 0 ] \
  && echo "postprocess: warning — no sips or imagemagick; @2x retina will be skipped" >&2

# ---------- helpers ----------
iso_now() {
  if date -u +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
    date -u +%Y-%m-%dT%H:%M:%SZ
  else
    python3 -c 'import datetime; print(datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"))'
  fi
}

img_dims() {
  # echo "WIDTH HEIGHT" for a file. Try sips, then magick identify, then python.
  local f="$1"
  if [ "$HAS_SIPS" -eq 1 ]; then
    sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null \
      | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w, h}'
  elif [ "$HAS_MAGICK" -eq 1 ]; then
    magick identify -format '%w %h' "$f" 2>/dev/null
  elif command -v identify >/dev/null 2>&1; then
    identify -format '%w %h' "$f" 2>/dev/null
  else
    python3 - "$f" <<'PY' 2>/dev/null || echo "0 0"
import sys, struct
p = sys.argv[1]
with open(p, 'rb') as fh:
    head = fh.read(24)
# PNG: 8-byte sig + IHDR chunk (length=13)
if head[:8] == b'\x89PNG\r\n\x1a\n':
    w, h = struct.unpack('>II', head[16:24])
    print(w, h); sys.exit()
print("0 0")
PY
  fi
}

file_size() {
  if stat -f%z "$1" >/dev/null 2>&1; then stat -f%z "$1"
  else stat -c%s "$1" 2>/dev/null || echo 0
  fi
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"; s="${s//$'\r'/\\r}"; s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

strip_exif() {
  local f="$1"
  if [ "$HAS_EXIFTOOL" -eq 1 ]; then
    exiftool -overwrite_original -all= "$f" >/dev/null 2>&1
  elif [ "$HAS_SIPS" -eq 1 ]; then
    sips -d allxmp -d profile "$f" >/dev/null 2>&1 || true
  fi
}

emit_webp() {
  local src="$1" dst="$2"
  if [ "$HAS_CWEBP" -eq 1 ]; then
    cwebp -q 85 "$src" -o "$dst" >/dev/null 2>&1
  elif [ "$HAS_MAGICK" -eq 1 ]; then
    magick "$src" -quality 85 "$dst" >/dev/null 2>&1
  elif [ "$HAS_CONVERT" -eq 1 ]; then
    convert "$src" -quality 85 "$dst" >/dev/null 2>&1
  else
    return 1
  fi
}

emit_retina() {
  local src="$1" dst="$2" base_w="$3"
  local target=$((base_w * 2))
  if [ "$HAS_SIPS" -eq 1 ]; then
    cp "$src" "$dst" && sips -z $((target * 9 / 16)) "$target" "$dst" >/dev/null 2>&1
  elif [ "$HAS_MAGICK" -eq 1 ]; then
    magick "$src" -resize "${target}x" "$dst" >/dev/null 2>&1
  elif [ "$HAS_CONVERT" -eq 1 ]; then
    convert "$src" -resize "${target}x" "$dst" >/dev/null 2>&1
  else
    return 1
  fi
}

# ---------- per-file pipeline ----------
process_one() {
  local in="$1"
  if [ ! -f "$in" ]; then
    echo "postprocess: not found: $in" >&2; return 1
  fi

  local generated_at; generated_at="$(iso_now)"
  [ "$DO_STRIP" -eq 1 ] && strip_exif "$in"

  local dims w h
  dims="$(img_dims "$in")"
  w="${dims%% *}"; h="${dims##* }"
  [ -z "$w" ] && w=0; [ -z "$h" ] && h=0

  local stem="${in%.*}"
  local webp_path="" retina_path=""

  if [ "$DO_WEBP" -eq 1 ]; then
    if emit_webp "$in" "${stem}.webp"; then webp_path="${stem}.webp"; fi
  fi

  if [ "$DO_RETINA" -eq 1 ] && [ "$w" -gt 0 ] && [ "$w" -lt 2000 ]; then
    if emit_retina "$in" "${stem}@2x.png" "$w"; then retina_path="${stem}@2x.png"; fi
  fi

  local size_bytes; size_bytes="$(file_size "$in")"
  local postprocessed_at; postprocessed_at="$(iso_now)"
  local meta="${stem}.meta.json"

  if [ "$HAS_JQ" -eq 1 ]; then
    jq -n \
      --arg original_prompt "$PROMPT" \
      --arg model "gpt-image-1.5" \
      --argjson width "$w" --argjson height "$h" \
      --arg format "png" \
      --argjson size_bytes "$size_bytes" \
      --arg generated_at "$generated_at" \
      --arg postprocessed_at "$postprocessed_at" \
      --arg webp_path "$webp_path" \
      --arg retina_path "$retina_path" \
      '{original_prompt: $original_prompt, model: $model, width: $width, height: $height, format: $format, size_bytes: $size_bytes, generated_at: $generated_at, postprocessed_at: $postprocessed_at, webp_path: $webp_path, retina_path: $retina_path}' \
      > "$meta"
  else
    {
      printf '{\n'
      printf '  "original_prompt": "%s",\n' "$(json_escape "$PROMPT")"
      printf '  "model": "gpt-image-1.5",\n'
      printf '  "width": %s,\n' "$w"
      printf '  "height": %s,\n' "$h"
      printf '  "format": "png",\n'
      printf '  "size_bytes": %s,\n' "$size_bytes"
      printf '  "generated_at": "%s",\n' "$generated_at"
      printf '  "postprocessed_at": "%s",\n' "$postprocessed_at"
      printf '  "webp_path": "%s",\n' "$(json_escape "$webp_path")"
      printf '  "retina_path": "%s"\n' "$(json_escape "$retina_path")"
      printf '}\n'
    } > "$meta"
  fi

  local kb=$(( (size_bytes + 1023) / 1024 ))
  local webp_b="false"; [ -n "$webp_path" ] && webp_b="true"
  local retina_b="false"; [ -n "$retina_path" ] && retina_b="true"
  printf 'processed %s: %s KB, webp=%s, retina=%s\n' "$in" "$kb" "$webp_b" "$retina_b"
}

for f in "${FILES[@]}"; do
  process_one "$f" || true
done
