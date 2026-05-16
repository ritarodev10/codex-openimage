# codex-openimage

> Get OpenAI's best image generation into any AI coding agent — for the price of a ChatGPT subscription instead of the API.

## The problem this fixes

Codex can generate beautiful images. But if you've tried using it while building a web project, you've probably watched something like this happen: you ask for a hero image. Codex generates one. Then, unprompted, it decides the result "doesn't quite match the page tone," verifies the image against your code, regenerates, looks again, maybe adjusts the prompt, runs another round. By the time it's done, you've spent ten minutes and four generations for what should have been a thirty-second task.

That's Codex being agentic in a context where you wanted a tool. It's great behavior when you're exploring; it's friction when you're shipping.

The other thing is cost. OpenAI's image API is fantastic but priced per call. At roughly $0.25 a pop for a high-quality 1536×1024, iteration adds up fast. Meanwhile, the same model runs against your ChatGPT subscription limits when invoked through the Codex CLI — meaning if you're already on Plus or Pro, every image is effectively free until you exhaust your monthly quota.

`codex-openimage` is what sits between your coding agent and Codex. It turns the agentic image flow into a disciplined one: synthesize a good prompt, spawn one Codex call in the background, post-process the result, report back. No second-guessing, no surprise regenerations, no API bill. Just an image, in the right folder, at the right size.

## Who this is for

Any AI coding agent that can run a shell command. The skill ships in the standard `SKILL.md` format that Claude Code and OpenCode read natively, but the underlying approach is portable — paste the orchestration logic into your agent's system prompt (Cursor, Windsurf, Cline, Roo Code, Aider, etc.) and it works. The image generation itself is happening in a Codex subprocess; your agent is just the conductor.

## What it actually does

When your agent receives an image-related request, this skill takes over. It reads the project to figure out what you need — the intent (`hero`, `og`, `feature-card`, `icon`, etc. each comes with sensible defaults for size, format, and quality), the right output folder for your framework, and the palette and visual style of any existing assets. If something genuinely can't be inferred it asks — at most three focused questions, never a quiz.

The two things this skill does that you can't get from a single Codex call:

**Responsive sets composed right.** For heroes, section backgrounds, and any image with text on top, it generates separate mobile, tablet, and desktop variants — each composed with the proper text safe zone for that viewport. Image models can't crop their way out of bad composition, so each viewport gets its own spawn, not a resize.

**Style-coherent asset packs.** For whole-site generation, it scans the codebase for every image slot, generates the most prominent asset first, then uses that image as a visual reference for every subsequent spawn. Without this anchor, parallel image gens drift apart — you end up with ten unrelated pictures instead of a family.

Every output is post-processed into web-ready form (WebP sibling, retina `@2x`, metadata sidecar) and saved to the right folder for your project.

## Modes at a glance

| Mode | Triggers when… | What happens |
|---|---|---|
| `generate` | You give an explicit prompt | One Codex spawn, post-process, report. |
| `auto` | You say "add an image here" with no prompt | Skill reads the surrounding code, synthesizes the prompt, shows a preview, then spawns. |
| `replace` | You want to regenerate an existing asset | Reads the sidecar (if present), preserves dimensions and role, backs up the original, regenerates. |
| `edit` | You want to partially edit an existing image | Codex edit API with mask support — inpaint, swap background, dark-mode variant. |
| `auto-pack` | "Generate all images for this page/site" | Scans the codebase, drafts a manifest, anchors style on the hero, fans out the rest. |

## Use cases

A non-exhaustive list of things this is designed to handle gracefully:

| What you want | Mode | Something you'd actually say |
|---|---|---|
| Hero image for a landing page (responsive set) | `generate` or `auto` | "hero for my fintech landing page" |
| Open Graph / social card | `generate` | "OG card for this blog post" |
| Icons or illustrations for a features grid | `auto-pack` | "icons for the features section" |
| Product mockup | `generate` | "product photo of our app on an iPhone" |
| Team avatars | `generate` | "10 illustrated avatars, flat style" |
| Section background with text on top | `generate` (responsive) | "hero background, headline goes top-left" |
| Dark-mode variant of an existing image | `edit` | "make hero.png dark mode" |
| Refresh an existing image | `replace` | "regenerate this, less busy, warmer palette" |
| Every image a landing page needs | `auto-pack` | "generate every image my landing page references" |
| Placeholder gallery | `generate` (n=N) | "5 abstract placeholders for the grid" |
| Logo direction concepts | `generate` (variants) | "4 logo concepts, flat geometric" |
| OG image per blog post | `auto-pack` | "OG image for each post under /blog" |
| Favicon source | `generate` | "favicon source at 1024px for the brand" |
| Empty-state illustration | `generate` | "empty-state for the inbox view" |
| Marketing variants to A/B | `generate` (n=N) | "4 hero options — let's pick" |
| Multi-viewport section bg | `generate` (responsive) | "3 viewports, same vibe, text-safe on each" |

## What you need

**A ChatGPT Plus subscription** (or higher) — image generation isn't available on the free tier, and Plus at $20/month is the minimum that unlocks it through Codex. Higher tiers give you more monthly image quota; Plus is plenty for most projects.

Sign in to Codex with `codex login` so it uses your ChatGPT session. If you point it at an `OPENAI_API_KEY` instead, you're back to per-image API pricing and the cost advantage disappears.

**The Codex CLI**, version 0.130 or newer. Install with `npm install -g @openai/codex@latest` or `brew install codex`.

**One of**:
- Claude Code, OpenCode, or any agent that reads the `SKILL.md` frontmatter format
- Any other coding agent that can shell out — the orchestration is portable, just paste `SKILL.md` into your agent's system instructions

**Optional, but the skill uses them if present**:
- `cwebp` for fast WebP siblings
- `exiftool` for cleaner EXIF stripping
- `jq` for prettier JSON from the scanner
- `sips` on macOS (preinstalled) or ImageMagick for retina @2x

When any of these are missing, the skill notices once and degrades gracefully — it doesn't fail, it just skips the corresponding step and tells you.

## Install

Clone the repo wherever you like to keep external skills:

```bash
git clone https://github.com/ritarodev10/codex-openimage.git ~/codex-openimage
```

Then symlink it into your agent's skill discovery path. For Claude Code:

```bash
ln -s ~/codex-openimage ~/.claude/skills/codex-openimage
```

For OpenCode:

```bash
ln -s ~/codex-openimage ~/.config/opencode/skills/codex-openimage
```

Restart your agent (or run its skill-refresh command). The skill activates automatically when you next ask for an image.

For agents without a native skill loader — Cursor, Windsurf, Cline, Roo Code, Aider, and so on — there are two options. Either paste the contents of `SKILL.md` into your agent's project rules (`.cursorrules`, `.windsurfrules`, `.clinerules`, `AGENTS.md`, etc.), or reference it at the start of an image task: *"Read `~/codex-openimage/SKILL.md` and follow that approach for any image generation."*

## A typical interaction

You're working on a landing page and you say:

> generate a hero image for this

What the skill does next, behind the scenes:

1. Notices you're in a Next.js project and the output folder is `public/images/`.
2. Reads `app/page.tsx` to find the nearest heading and first paragraph for context.
3. Recognizes this as a `hero` request, which means responsive variants and a likely text overlay.
4. Extracts your brand palette from `tailwind.config.ts`.
5. Synthesizes a prompt that includes subject, scene, palette, safe zones for each viewport, and content-type-specific negative prompts.
6. Shows you the prompt as a one-line preview.

You say "go." It spawns Codex in the background for the desktop variant. When that finishes (you're notified, no polling), it spawns mobile and tablet in parallel, using the desktop image as a style reference so they share palette, lighting, and mood. Each variant gets post-processed: WebP sibling, retina `@2x`, EXIF stripped, sidecar metadata written.

You end up with six files in `public/images/`, a `<picture>` snippet ready to paste, and a one-line report:

```
Generated: 3 images, 6 files total, 2.8 MB on disk
  hero-desktop.png  1920×1080  + .webp + @2x
  hero-tablet.png   1280×960   + .webp + @2x
  hero-mobile.png   768×1024   + .webp + @2x
Style locked via desktop as input_image.
Open the folder? [y/n]
```

For a whole-site pack, it's the same shape scaled up: scan, manifest, one approval, fan out, anchor, report.

## Cost in practice

For a typical 8-image landing-page pack at high quality:

| | Per image | 8 images |
|---|---|---|
| OpenAI Image API direct | ~$0.25 | ~$2.00 |
| ChatGPT Plus via Codex | $0.00 incrementally | $0.00 incrementally |

The subscription path bills against your monthly image quota instead of charging per call. Break-even versus the API lands around 80 images a month — easy to cross in a week if you're iterating on UI work, and the underlying model is the same either way.

## Repo layout

```
.
├── SKILL.md                       # the orchestrator — modes, recipes, policies
├── README.md
├── LICENSE                        # MIT
├── LICENSE.original               # original Apache-2.0 (preserved for attribution)
├── references/
│   ├── intent-presets.md          # intent → size/format/quality/naming
│   ├── project-detection.md       # framework → output path; palette extraction
│   ├── negative-prompts.md        # quality guardrails per content type
│   ├── style-anchors.md           # style descriptor library for packs
│   ├── asset-pack-scan.md         # what slots to find and how
│   ├── clarifying-questions.md    # 20 use cases mapping vague asks → right questions
│   ├── prompting.md               # prompting principles (kept from upstream)
│   └── sample-prompts.md          # copy/paste recipes by taxonomy
├── scripts/
│   ├── scan-image-slots.sh        # codebase → JSON list of image slots
│   └── postprocess.sh             # strip EXIF + WebP + retina + sidecar
├── templates/
│   ├── pack-manifest.yaml         # auto-pack manifest skeleton
│   └── sidecar-meta.json          # example per-image .meta.json
├── assets/                        # skill icon
└── legacy/                        # pre-codex direct-CLI implementation (preserved)
```

## Contributing

Pull requests welcome, especially for: new intent presets for content types we haven't covered, additional framework detection patterns, better palette extraction heuristics, and clarifying-question recipes from your own workflow.

When filing issues, please mention the agent you're using, your subscription tier, and a minimal reproduction.

## License

MIT. The upstream skill this is derived from shipped under Apache-2.0; that text is preserved as `LICENSE.original` for attribution.

---

Subscription and pricing data verified against:
- [Using Codex with your ChatGPT plan — OpenAI Help Center](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan)
- [Codex Pricing — OpenAI Developers](https://developers.openai.com/codex/pricing)
- [ChatGPT Plans](https://chatgpt.com/pricing/)
