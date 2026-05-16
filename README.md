# codex-openimage

> Bring high-quality OpenAI image generation to any AI coding agent — for the price of a ChatGPT subscription, not the API.

## What this is

`codex-openimage` is an **open-source skill / prompt-pack** that lets any AI coding agent (Claude Code, OpenCode, Pi, Cursor, Continue, Aider, or anything that can shell out to a CLI) generate production-grade web images by orchestrating the OpenAI Codex CLI in the background.

The skill itself doesn't call the OpenAI Image API. It tells your coding agent *how* to delegate image generation to `codex exec` — a single line that spawns Codex in the background, which then runs its own bundled `imagegen` skill against OpenAI's image endpoint. Your agent waits for Codex to finish, post-processes the result (WebP sibling, retina @2x, sidecar metadata), and reports back.

Why this matters: **image generation via Codex consumes your ChatGPT subscription's included limits, not direct API credits.** A single high-quality 1536×1024 image costs ~$0.25 on the API. The same image, generated via Codex while you're on ChatGPT Plus, costs $0.00 incrementally — you've already paid for the subscription. For anyone iterating on landing pages, OG cards, hero images, or whole-site asset packs, this is the difference between "I can afford 5 attempts" and "I can iterate 200 times this month."

## Why a separate skill (vs. just using `codex` directly)

Codex's built-in `imagegen` already wraps the OpenAI Image API. We deliberately don't duplicate that — we sit one layer above it and add the parts that aren't a single API call:

- **Intent presets** — `hero`, `og`, `feature-card`, `icon`, `logo`, `avatar`, `placeholder`, etc. Each maps to size, format, quality, and naming convention so you stop specifying dimensions every time.
- **Project detection** — auto-resolves the output dir for Next.js / Nuxt / Astro / SvelteKit / Vite / Rails / Phoenix / Django / static HTML. Extracts brand palette from `tailwind.config` or CSS variables. No more dumping into `/tmp`.
- **Responsive variant sets** — `mobile` / `tablet` / `desktop` with separate compositions (not just resizes) so section backgrounds with text overlay get the safe zone right at every breakpoint.
- **Style anchoring** — generate the hero first, use it as `input_image` for every subsequent spawn so a 10-image pack stays visually coherent instead of looking like 10 separate AI requests.
- **Parallel fan-out** — for whole-site asset packs, spawn 3-4 Codex processes concurrently and aggregate when all finish.
- **Post-processing pipeline** — strip EXIF, emit WebP sibling, generate `@2x` retina variant, write `.meta.json` sidecar so future `replace`-mode runs know the original prompt.
- **Clarifying-question policy** — ask up to 3 focused questions when the request is genuinely ambiguous; never gauntlet the user.

## Modes

| Mode | Triggers when… | What happens |
|---|---|---|
| `generate` | User gives an explicit prompt for a new image | One Codex spawn, post-process, report. |
| `auto` | User says "add an image here" without a prompt | Skill reads surrounding code, synthesizes prompt, shows preview, then spawns. |
| `replace` | User wants to regenerate an existing image asset | Reads sidecar (if present), preserves dimensions + role, backs up original, regenerates. |
| `edit` | Partial edit of an existing image (mask / inpaint / dark-mode variant) | Codex edit API with the original as `input_image` and optional mask. |
| `auto-pack` | "Generate all images for this page/site" | Scans codebase for image slots, builds a manifest, anchors style, fans out in waves. |

## Use cases

| Want… | Mode | Example ask |
|---|---|---|
| Landing-page hero (responsive) | `generate` / `auto` | "hero for my fintech landing page" |
| Open Graph / social card | `generate` | "OG card for this blog post about X" |
| Feature-section illustrations | `auto-pack` | "icons + illustrations for the features grid" |
| Product mockup | `generate` | "product render of our app on an iPhone, studio lighting" |
| Team / avatar set | `generate` | "10 illustrated avatars in flat geometric style" |
| Section background with text overlay | `generate` (responsive) | "hero background, headline goes top-left, must keep left third quiet" |
| Dark-mode variant of an existing image | `edit` | "make `hero.png` dark mode" |
| Refresh an existing image | `replace` | "regenerate this hero, less busy, warmer palette" |
| Whole-site asset pack | `auto-pack` | "generate every image my landing page references" |
| Placeholder gallery | `generate` (n=N) | "5 abstract placeholders for the case-study grid" |
| Concept exploration / moodboard | `generate` (variants) | "4 logo direction concepts, flat geometric" |
| OG-per-post for a blog | `auto-pack` | "OG image for each post under `app/blog/`" |
| Favicon source | `generate` | "favicon source @1024 for the brand" |
| Empty-state illustration | `generate` | "empty-state illustration for the inbox view" |
| Marketing variants | `generate` (n=N) | "4 hero variants — pick the best" |
| Section-bg responsive set | `generate` (responsive) | "3 viewports of the same bg, text safe-zone aware" |

## Requirements

### Subscription

Image generation via Codex requires an **active ChatGPT subscription**. The minimum tier is:

| Plan | Monthly | Includes Codex image gen? | Notes |
|---|---|---|---|
| **Free** | $0 | ❌ | Image generation is excluded from the free tier. |
| **Plus** | $20 | ✅ | Entry point — most users start here. Image gens consume your monthly limits ~3-5× faster than text. |
| **Pro (5×)** | $100 | ✅ | 5× the Plus limits. |
| **Pro (20×)** | $200 | ✅ | 20× the Plus limits. Best value if you're generating packs daily. |
| **Business / Enterprise** | $20/seat+ | ✅ | Codex included; per-seat billing. |

Subscription image generation is metered in "included limits," not dollar credits. The exact image quota varies by tier and is consumed faster than text generation. Check your usage at `chatgpt.com/settings`.

> If you point Codex at an API key (`OPENAI_API_KEY`) instead of a ChatGPT session, billing falls back to per-image API pricing — defeats the cost advantage. Don't.

### Tooling

- **Codex CLI ≥ 0.130** in `PATH` — install: `npm install -g @openai/codex@latest` (or `brew install codex`)
- Codex authenticated to your ChatGPT account: `codex login` (one-time)
- One of:
  - **Claude Code** (uses the skill via `SKILL.md` frontmatter)
  - **OpenCode** (uses the skill via the same frontmatter)
  - **Any agent that can shell out** — copy the `SKILL.md` content into your agent's system/instruction prompt, the orchestration is portable

### Optional (graceful degradation)

- `cwebp` — fast WebP sibling emission (falls back to `magick` or skips with a warning)
- `exiftool` — clean EXIF strip (falls back to `sips -d` on macOS, skips on others)
- `jq` — clean JSON output from `scan-image-slots.sh` (falls back to hand-rolled JSON)
- `sips` (macOS, preinstalled) or ImageMagick `magick` / `convert` for retina @2x

## Install

```bash
git clone https://github.com/ritarodev10/codex-openimage.git ~/codex-openimage
```

Then symlink into your agent's skill discovery path:

```bash
# Claude Code
ln -s ~/codex-openimage ~/.claude/skills/codex-openimage

# OpenCode
ln -s ~/codex-openimage ~/.config/opencode/skills/codex-openimage

# skills-manager (if used)
ln -s ~/codex-openimage ~/.skills-manager/skills/codex-openimage
```

Restart your agent or run its skill-refresh command. The skill activates automatically when the agent receives an image-related request.

For **other agents** without a native skill loader (Cursor, Continue, Aider, Pi, etc.), you have two options:
1. Paste the contents of `SKILL.md` into your agent's system instructions / project rules
2. Reference the skill at the start of an image task: "Read `~/codex-openimage/SKILL.md` and use that approach"

The orchestration itself is plain bash + tool-agnostic — any agent that can run `codex exec` in the background and read JSON can drive it.

## Quickstart

A typical interaction:

> **User:** generate a hero image for my landing page
>
> **Agent (this skill):**
> 1. Detects framework (Next.js) and output dir (`public/images`)
> 2. Reads `app/page.tsx` for nearest heading + first paragraph + brand palette
> 3. Infers intent → `hero`, responsive set on, text overlay detected
> 4. Synthesizes a prompt with palette + safe-zone + negative guards
> 5. Shows the prompt as a one-line preview; user says "go"
> 6. Spawns `codex exec ...` for the desktop variant in the background
> 7. On completion, spawns mobile + tablet in parallel using desktop as `input_image` (style lock)
> 8. Runs `scripts/postprocess.sh` on each → WebP sibling + `@2x` retina + `.meta.json`
> 9. Writes a `<picture>` snippet next to the assets; reports total time + size on disk
> 10. Offers to open the output folder in your OS file explorer

For an asset pack:

> **User:** generate every image my landing page needs
>
> **Agent:**
> 1. Runs `scripts/scan-image-slots.sh` → finds 8 image slots (`hero`, `og`, `twitter-card`, 5 feature cards)
> 2. Drafts `pack-manifest.yaml` with synthesized prompts + cost estimate (~$0.00 on subscription, ~$2.10 if API-billed)
> 3. Asks for one batch approval
> 4. Generates hero first (style anchor), then fans out the rest in waves of 3
> 5. Reports thumbnail grid + folder reveal prompt

## Cost comparison

For a typical 8-image landing-page pack at high quality:

|  | Per-image | 8 images | Notes |
|---|---|---|---|
| **OpenAI API direct** | ~$0.25 | ~$2.00 | Billed per generation, immediate hard cost. |
| **ChatGPT Plus ($20/mo) via Codex** | $0.00* | $0.00* | *Already paid. Consumes monthly image quota. |
| **ChatGPT Pro 20× ($200/mo)** | $0.00* | $0.00* | *Same idea, 20× the quota. |

The break-even point for hobbyist usage is ~80 images/month. For anyone iterating on UI assets, you'll cross that in a week.

## File structure

```
.
├── SKILL.md                       # orchestrator — modes, recipes, policies
├── README.md                      # you are here
├── LICENSE                        # MIT
├── LICENSE.original               # original Apache-2.0 (preserved for attribution)
├── references/
│   ├── intent-presets.md          # intent → size/format/quality/naming
│   ├── project-detection.md       # framework → output path; palette extraction
│   ├── negative-prompts.md        # quality guardrails per content type
│   ├── style-anchors.md           # style descriptor library for auto-pack
│   ├── asset-pack-scan.md         # what slots to find and how
│   ├── clarifying-questions.md    # 20 use cases mapping vague asks → right questions
│   ├── prompting.md               # prompting principles (kept from upstream)
│   └── sample-prompts.md          # copy/paste recipes by taxonomy (kept from upstream)
├── scripts/
│   ├── scan-image-slots.sh        # codebase → JSON list of image slots
│   └── postprocess.sh             # strip EXIF + WebP + retina @2x + sidecar
├── templates/
│   ├── pack-manifest.yaml         # auto-pack manifest skeleton
│   └── sidecar-meta.json          # example per-image .meta.json
├── assets/                        # skill icon
└── legacy/                        # pre-codex direct-CLI files (preserved, fallback)
```

## Contributing

Pull requests welcome — especially:
- New intent presets for content types not yet covered
- Additional framework detection patterns
- Better palette extraction heuristics
- Use cases / clarifying-question patterns from your own workflow

Issues: please include the agent you're using (Claude Code / OpenCode / other), your subscription tier, and a minimal reproduction.

## License

MIT. See `LICENSE`. The original upstream skill shipped under Apache-2.0; that text is preserved as `LICENSE.original` for attribution.

---

Sources for subscription/pricing data (verified May 2026):
- [Using Codex with your ChatGPT plan — OpenAI Help Center](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan)
- [Codex Pricing — OpenAI Developers](https://developers.openai.com/codex/pricing)
- [ChatGPT Plans](https://chatgpt.com/pricing/)
