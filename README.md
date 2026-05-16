# codex-openimage

> Claude Code skill that orchestrates the OpenAI Image API via codex for web asset generation.

## What it is

Generating production-grade images for a website is rarely a single API call. You need careful prompts, the right size + format for each slot, a consistent style across a whole pack, responsive variants for hero/section backgrounds, and reasonable file sizes on disk.

`codex-openimage` is a Claude Code skill that handles that orchestration. The actual API call is delegated to the `codex` CLI (which has its own `imagegen` skill talking to the OpenAI Image API). This skill sits one layer above: it detects intent, scans your project, synthesizes prompts, fans out parallel codex spawns, anchors style across a pack, and postprocesses every output (EXIF strip, WebP sibling, `@2x` retina, sidecar metadata).

Claude never calls the image endpoint directly. Every generation goes through a `codex exec` background spawn, which keeps API keys and rate-limit concerns scoped to codex.

## Why a separate skill

The codex CLI already ships with its own `imagegen` skill that wraps the OpenAI Image API. We deliberately don't duplicate that layer. Instead this skill adds the parts that are awkward inside a single API call:

- intent presets (hero / og / feature-card / icon / logo / ...)
- project detection (framework → output dir, palette extraction from Tailwind/CSS)
- parallel fan-out for multi-asset packs
- responsive variant sets (mobile/tablet/desktop) with safe-zone aware prompts
- style anchoring (generate hero first, reuse it as `input_image` for the rest)
- post-processing pipeline (strip EXIF, emit WebP, retina @2x, write `.meta.json` sidecar)

## Modes

| Mode | When it fires |
|---|---|
| `generate` | User gives an explicit prompt for a new image. |
| `auto` | User says "add an image here" — prompt synthesized from surrounding content. |
| `replace` | Regenerate an existing image while preserving its role + dimensions. |
| `edit` | Partial edit of an existing image (inpaint / mask / dark-mode variant). |
| `auto-pack` | Whole-page or whole-site asset pack with one style anchor. |

## Requirements

- `codex` CLI **>= 0.130** in `PATH`
- `OPENAI_API_KEY` exported in your shell (codex consumes it)
- Optional but recommended:
  - `cwebp` — fast WebP sibling output (falls back to ImageMagick)
  - `exiftool` — clean EXIF strip (falls back to `sips -d` on macOS)
  - `jq` — clean JSON output from scripts (falls back to hand-rolled printf JSON)
  - `sips` (macOS, preinstalled) or `magick` / `convert` (ImageMagick) for retina @2x

The skill degrades gracefully when optional tools are missing — it warns once and skips the corresponding step.

## Install

Clone the repo and symlink it into your Claude Code skills directory. Pick whichever path matches your install:

```bash
git clone https://github.com/ritarodev10/codex-openimage.git
cd codex-openimage

# Option A — global skills dir
ln -s "$(pwd)" ~/.claude/skills/codex-openimage

# Option B — skills-manager managed dir (if you use one)
ln -s "$(pwd)" ~/.claude/skills-manager/skills/codex-openimage
```

Restart Claude Code or `/refresh` so the skill is picked up.

## Quickstart

A typical interaction:

> **User:** generate a hero image for my landing page
>
> **Claude (this skill):**
> 1. detects framework (Next.js) and output dir (`public/images`)
> 2. reads `app/page.tsx` to extract the nearest heading + first paragraph
> 3. infers intent → `hero`, responsive set on, text overlay detected
> 4. synthesizes a prompt with palette + safe-zone + negative guards
> 5. shows the prompt as a one-line preview; user says "go"
> 6. spawns `codex exec ...` for the desktop variant
> 7. on completion, spawns mobile + tablet in parallel using desktop as `input_image`
> 8. runs `scripts/postprocess.sh` on each → WebP + @2x + `.meta.json`
> 9. writes a `<picture>` snippet next to the assets, reports total cost + size

For a whole site:

> **User:** generate every image my landing page needs
>
> **Claude:** runs `scripts/scan-image-slots.sh`, drafts `pack-manifest.yaml`, asks for one batch approval, then fans out — hero first as style anchor, remaining slots in waves of 3.

## File structure

```
.
├── SKILL.md                       # orchestrator (modes, spawn template, recipes)
├── README.md
├── LICENSE                         # MIT
├── LICENSE.original                # original Apache-2.0 (preserved)
├── references/
│   ├── intent-presets.md           # intent → size/format/quality/naming
│   ├── project-detection.md        # framework → output path; palette extraction
│   ├── negative-prompts.md         # quality guardrails per content type
│   ├── style-anchors.md            # style descriptor library for auto-pack
│   ├── asset-pack-scan.md          # what slots to find and how
│   ├── prompting.md                # prompting principles (legacy, still useful)
│   └── sample-prompts.md           # copy/paste recipes (legacy, still useful)
├── scripts/
│   ├── scan-image-slots.sh         # codebase → JSON list of image slots
│   └── postprocess.sh              # strip EXIF + WebP + retina @2x + sidecar
├── templates/
│   ├── pack-manifest.yaml          # auto-pack manifest skeleton
│   └── sidecar-meta.json           # example per-image .meta.json
├── assets/                         # skill icon
└── legacy/                         # pre-codex direct-CLI files (fallback)
    ├── README.md
    ├── scripts/image_gen.py
    ├── references/{cli,codex-network,image-api}.md
    └── agents/openai.yaml
```

## License

MIT. See `LICENSE`. The original repo template shipped under Apache-2.0; that text is preserved as `LICENSE.original` for attribution.
