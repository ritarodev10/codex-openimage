---
name: "codex-openimage"
description: "Use when the user asks to generate, edit, replace, or batch-create images and visual assets — landing-page heroes, OG cards, feature illustrations, product shots, icons, mockups, concept art, infographics, dark/light variants, retina sets, or whole-site asset packs. This skill orchestrates generation by spawning codex in the background (which runs the OpenAI Image API under the hood); Claude does not call the API directly. Requires `OPENAI_API_KEY` and a working `codex` CLI in PATH."
---

# Imagegen — Codex-Orchestrated Image Generation

This skill **spawns codex as a background worker** to generate or edit images. Claude's job is orchestration: detect intent, synthesize prompts from project context, build manifests for batches, fan out parallel codex spawns, postprocess outputs, and report.

The image API itself is called by codex's own imagegen skill — we do not duplicate that layer.

## Modes

Pick the mode that matches the user's ask. Then follow that mode's recipe below.

| Mode | When it fires | Spawn count |
|---|---|---|
| `generate` | User gives an explicit prompt and wants a new image | 1 |
| `auto` | User says "add an image here" — no prompt, prompt is synthesized from surrounding content | 1 |
| `replace` | User wants to regenerate an existing image asset | 1 |
| `edit` | User wants partial edit of an existing image (inpaint / mask / bg removal / dark-mode variant) | 1 |
| `auto-pack` | User wants images for a whole page, section, or site | N (parallel) |

Variants (`n=4`) of the same concept use a single spawn with codex's batch param; they don't require parallel spawns.

## Asking before spawning

If the user's request lacks context that would block quality, ask up to **3 focused questions** before spawning codex — not a 10-question gauntlet. See `references/clarifying-questions.md` for the full policy and use-case library.

Quick rules:
- Inventory the gaps. Fill what you can from defaults (size, format, quality), auto-synthesize what you can from project context (palette, subject from page copy), and only **ask** for what genuinely can't be inferred.
- Use `AskUserQuestion` with multi-choice when the answer space is bounded (style family, mood, intent slug)
- Always offer "match existing site" as an option when prior assets exist
- For batches >3 images, the cost-approval question is **non-optional**
- After 2 rounds of questions, stop asking — pick defaults, generate, let the user redirect via "more like X / less like Y"

## Required environment

- `OPENAI_API_KEY` exported in shell — codex needs it
- `codex` >=0.130 in PATH — older versions break with the superset wrapper
- macOS `sips` available (for retina @2x — defaults exist for Linux too)

If `OPENAI_API_KEY` is missing, do **not** spawn codex. Tell the user to set it and stop.

## The codex spawn template

Every mode ends with one or more `Bash` calls in this shape:

```bash
codex exec --dangerously-bypass-approvals-and-sandbox "<SYNTHESIZED_PROMPT>" 2>&1 | tee <LOG_PATH>
```

- Always run via `Bash` with `run_in_background: true` so Claude isn't blocked
- The harness notifies on completion — never poll, never `sleep`
- Save the log to a per-spawn path so multiple parallel spawns don't collide

The `<SYNTHESIZED_PROMPT>` must always:
1. Tell codex to use its **own imagegen skill**
2. Specify exact output PNG path (absolute)
3. Specify aspect ratio / size (use `references/intent-presets.md`)
4. Embed the user's creative intent plus any inherited style anchor and negative prompts
5. End with: `When done, print only the absolute path to the saved file as the last line.`

That last line is how the orchestrator finds the file deterministically — codex sometimes saves to `~/.codex/generated_images/<session>/` and copies to the requested path. The trailing path line is the contract.

## Mode: `generate`

1. Read user's explicit prompt
2. Detect intent (hero / og / feature-card / icon / avatar / ...) from filename or path — see `references/intent-presets.md`
3. Pull project context: `references/project-detection.md` (palette, framework output dir, existing image style)
4. Append negative prompts for the content type from `references/negative-prompts.md`
5. Build the codex prompt, spawn, wait for notification
6. Run `scripts/postprocess.sh <png>` to compress + emit WebP sibling + write `.meta.json`
7. Report: path, dimensions, size on disk, cost estimate

## Mode: `auto`

Same as `generate` but you synthesize the prompt yourself:

1. Read the file the image will be referenced in (MDX/HTML/JSX/Markdown)
2. Extract: nearest heading, first 1-2 paragraphs of surrounding section, alt text of neighboring images
3. Pull brand context (palette, site name, tagline) per `references/project-detection.md`
4. Detect intent from target filename/path
5. Synthesize a prompt that includes: subject + scene + style + palette + negative guards
6. **Show the synthesized prompt to the user as a one-line preview before spawning** — give them a chance to redirect. If they say "go", proceed.
7. Spawn → postprocess → report (same as `generate`)

## Mode: `replace`

Regenerate an existing asset while preserving its role.

1. Read original file with `file` / `sips` → capture exact dimensions, format, transparent-bg or not
2. Look for sidecar `<path>.meta.json` — if present, use its `prompt` field as base
3. If no sidecar: ask the user "describe the new version, or say 'same but X'" — do not silently re-prompt blind
4. `grep -r "<basename>" .` to find all references — flag any if the path changes (it shouldn't; same path preserves the layout)
5. Backup: `cp <path> <path>.bak`
6. Spawn codex with the new prompt; **force exact original dimensions**
7. Postprocess, update sidecar `.meta.json` with new prompt + parent prompt diff
8. Report: old vs new thumbnail paths, references that consume the image

## Mode: `edit`

Partial edit of an existing image.

1. Read original, determine if mask is needed (user said "the X" → mask region; user said "everything but X" → invert)
2. If mask needed, either:
   - Accept user-supplied mask path
   - Or generate one with simple geometry (rectangle by user-described region)
3. Spawn codex with edit-mode instructions, original as `input_image`, optional `mask`
4. Honor original aspect ratio exactly
5. Postprocess, update sidecar with edit history (append, don't overwrite)
6. Report

## Mode: `auto-pack` — whole-site or section asset pack

The most powerful mode. Generates a stylistically consistent set of images for a page or site.

1. **Scan**: run `scripts/scan-image-slots.sh <root>` → JSON list of every image slot in the codebase
   - Includes: `<img>` / `<Image>` / `background-image:` / `next/image` / OG metadata / favicon / PWA manifest icons / empty referenced paths
2. **Style anchor**: derive once for the whole pack
   - Brand palette from `tailwind.config` / CSS vars
   - Style descriptor (flat illustration / photoreal / 3D / editorial) — inferred from existing brand asset, or ask once
   - One-sentence lighting + mood lock
   - See `references/style-anchors.md`
3. **Manifest**: render `templates/pack-manifest.yaml` with one entry per slot
   - Each entry: path, intent, size, synthesized prompt, est. cost
   - Show the manifest table to user, get one approval for the whole batch
4. **Lock style via reference image**:
   - Generate the **hero / largest asset first** (single codex spawn)
   - Pass that hero as `input_image` to every subsequent generation via codex's edit API
   - This is the trick that keeps a 10-image pack visually consistent
5. **Fan out**:
   - Issue parallel `Bash` calls with `run_in_background: true` in a **single message**, max 3-4 concurrent
   - One spawn per remaining manifest entry
   - Track task IDs, wait for all notifications
6. **Postprocess each as it lands** — compress, WebP sibling, retina @2x, sidecar `.meta.json`
7. **Report**: thumbnail grid (paths), total cost, file tree, any failed slots

Cost guardrail: print "N images, ~$X estimated, proceed?" for any batch of more than 3 before spawning.

## Parallel spawn pattern (auto-pack & multi-aspect-ratio)

Issue all `Bash` calls in **one message** so they run concurrently:

```
[message with multiple tool calls]
  Bash(run_in_background=true, command="codex exec ... > /tmp/.../1.log")
  Bash(run_in_background=true, command="codex exec ... > /tmp/.../2.log")
  Bash(run_in_background=true, command="codex exec ... > /tmp/.../3.log")
```

Each writes to a unique log path. The harness sends one notification per completion. Aggregate when all are done.

**Cap concurrency at 3-4** to avoid OpenAI rate limits and codex resource pressure. For packs >4 slots, generate the hero first (for style anchor), then process remaining in waves of 3.

## Variants of the same concept

If user wants 4 variants of one image (a/b/c/d hero options), don't fan out 4 spawns — that's wasteful. Tell codex `n=4` in the prompt; one API call returns 4 images. Save as `<name>-v1.png` … `<name>-v4.png`.

## Responsive variants (multi-viewport)

For hero, section background, and any image rendered at multiple viewport widths, generate **a set per breakpoint**, not a single asset scaled with CSS. The image API can't change aspect ratio in a single call, so each viewport needs its own spawn.

**Default responsive set** (apply automatically when intent ∈ {hero, section-bg, banner, og-twitter}):
- `mobile`  → 768×1024 (3:4 portrait)
- `tablet`  → 1280×960 (4:3)
- `desktop` → 1920×1080 (16:9)

Naming convention: `<name>-mobile.png`, `<name>-tablet.png`, `<name>-desktop.png` (plus `@2x` retina each via postprocess).

**Spawn strategy**:
1. Generate the **largest variant first** (desktop) — this is the style anchor
2. Pass desktop as `input_image` to mobile + tablet spawns so subject, color, and lighting stay consistent across breakpoints
3. The mobile + tablet spawns can run in parallel after the desktop completes
4. Total spawns for a single responsive asset: 3 (sequential 1 → parallel 2)

**Text-safe zone awareness** (critical for section-bg with text overlay):

If the image will sit behind copy, the generated composition must keep the text area visually quiet — no busy detail in the headline zone, soft color falloff toward the text, or solid negative space in the corner where copy lives.

Detect text overlay by:
- File path hints: `hero-bg`, `section-bg`, `banner-bg`
- User explicitly says "with text on top" or "headline goes here"
- Reading the JSX/MDX that consumes the image: if there's a `<h1>`/`<h2>` rendered over it, treat as text overlay

When text overlay detected, append to the prompt:
- The safe zone location for **each** viewport (mobile center, tablet center-left, desktop left-third are common)
- "Generous negative space / soft falloff in the safe zone, no busy detail there, low contrast in that region"
- For dark text → "luminous / bright in safe zone"; for light text → "deep tonal / shadowed in safe zone"

Different viewports usually need **different safe zones**:
- Mobile (3:4): centered text → safe zone is horizontal band in middle 60%
- Tablet (4:3): off-center → safe zone left or right half
- Desktop (16:9): often left-third for headline, right-two-thirds for visual focal

So the three responsive spawns aren't crops of the same image — they're three **separately composed** images sharing palette/subject/lighting via the input-image style anchor.

**Output**: also emit a `<picture>` snippet for the user to copy:
```html
<picture>
  <source media="(min-width: 1024px)" srcset="hero-desktop.png 1x, hero-desktop@2x.png 2x" />
  <source media="(min-width: 640px)"  srcset="hero-tablet.png 1x, hero-tablet@2x.png 2x" />
  <img src="hero-mobile.png" srcset="hero-mobile@2x.png 2x" alt="..." />
</picture>
```

Save the snippet next to the assets as `<name>.picture.html` for easy paste.

## Postprocess every output

After each codex completion, run:
```
scripts/postprocess.sh <output.png>
```
Which:
- Strips EXIF
- Emits `<output>.webp` sibling
- For assets <2000px wide: emits `<output>@2x.png` retina variant
- Writes `<output>.meta.json` sidecar with prompt, model, dimensions, size, timestamp
- Optionally runs `pngquant` if installed

## Cost defaults baked into codex prompts

- `quality: medium` for iteration, `high` only if the filename ends in `-final` or user explicitly says "final"
- `n: 1` unless prompt requests variants
- Refuse real-person likeness and trademarked characters by default — let codex's imagegen skill enforce this

## Safety

If the user prompt names a real person, a trademarked character, or copyrighted brand mark, refuse and propose a generic alternative. Codex's imagegen skill enforces this too — we're double-checking at the orchestration layer.

## Sidecar metadata

Every generated image gets a `<path>.meta.json` sidecar. Schema in `templates/sidecar-meta.json`. Why: when the user (or future-Claude) does `replace` mode, the sidecar holds the original prompt so we don't blind-guess.

## Reporting

After every run (single or pack), print a compact summary:

```
Generated: 5 images, 3.2 MB total, ~$0.40 est.
  hero.png         1920×1080   480 KB   public/images/
  og.png           1200×630    210 KB   public/images/
  feat-budgets.png 1024×1024   380 KB   public/images/features/
  feat-goals.png   1024×1024   360 KB   public/images/features/
  feat-cash.png    1024×1024   390 KB   public/images/features/
Style anchor: flat geometric illustration, sage/sand/clay palette
Sidecars: 5 .meta.json files written
```

If the user is in a browser-visible context, also `open` the first generated image.

## Reference map

- **`references/intent-presets.md`** — intent → size/format/quality/naming presets table
- **`references/project-detection.md`** — framework → output path; palette extraction from CSS/Tailwind
- **`references/negative-prompts.md`** — content-type-specific quality guardrails
- **`references/style-anchors.md`** — style descriptor library for `auto-pack` mode
- **`references/asset-pack-scan.md`** — what slots to find and how, per framework
- **`references/clarifying-questions.md`** — when to ask vs default; 20 use cases mapping vague requests to right questions
- **`references/prompting.md`** — prompting principles (kept from legacy)
- **`references/sample-prompts.md`** — copy/paste prompt recipes by taxonomy (kept from legacy)
- **`scripts/scan-image-slots.sh`** — scans codebase for image slots, prints JSON
- **`scripts/postprocess.sh`** — compress + WebP + retina + sidecar
- **`templates/pack-manifest.yaml`** — `auto-pack` manifest skeleton
- **`templates/sidecar-meta.json`** — per-image metadata schema
- **`legacy/`** — pre-codex direct-CLI implementation (preserved for fallback)
