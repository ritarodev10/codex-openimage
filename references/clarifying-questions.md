# Clarifying Questions — When and How to Ask

Bad image-gen outputs usually trace back to under-specified prompts, not weak models. This skill should ask focused questions when context is missing — but only when the gaps actually block quality, not as a reflex.

## Policy

Before spawning codex:

1. Inventory the gaps. For each missing piece of context, decide:
   - **Fill from defaults** — size, quality, format, output path, postprocessing
   - **Auto-synthesize from project** — subject, palette, style anchor, scene (when surrounding content provides it)
   - **Ask the user** — only what you genuinely can't infer

2. **Hard rule**: ≤3 questions per round. If more gaps exist, ask the top 3, generate something, then iterate.

3. Use `AskUserQuestion` with multiple-choice options when the answer space is bounded (style family, mood, intent). Free-form only when the answer is open (the subject of the image).

4. Always offer the user "match the rest of the site" as an option when existing assets exist — it's almost always the right answer for production work.

5. If user says "you decide" or "surprise me" — pick sensible defaults, generate, and report what you chose so they can redirect.

## Gaps that ALWAYS need a question (cannot be inferred)

- **Intent**, when no path hint exists and the user didn't say what it's for
- **Subject**, when the user said "an image" with no further info
- **Text-overlay safe zone**, when the image is a section bg AND the headline text isn't visible in the surrounding code
- **People y/n + count + demographics**, when the prompt implies people but doesn't specify
- **Brand alignment vs differentiation**, when copying a known company's style (Stripe, Linear, Apple, etc.) is implied

## Gaps with sensible defaults (don't ask)

- **Size** → pick from `intent-presets.md`
- **Quality** → medium for iteration, high for `-final` filenames or hero/OG
- **Format** → PNG primary, WebP sibling, retina @2x via postprocess
- **Output path** → framework-detected via `project-detection.md`
- **Negative prompts** → content-type-derived from `negative-prompts.md`
- **`n` (variants)** → 1, unless prompt asks for variants

## Gaps that AUTO mode synthesizes (don't ask if mode is `auto`)

- **Subject** → from surrounding page content
- **Scene** → from section context + intent
- **Style** → from existing asset folder or style anchor library
- **Palette** → from `tailwind.config` / CSS vars
- **Tone** → from site copy

If `auto` mode can synthesize a usable prompt, show it as a one-line preview (not a 3-question gauntlet) and let the user redirect with one keystroke.

---

## Use cases — vague requests and the right questions

### Use case 1: "Generate me an image"

Maximally vague. Inventory: intent, subject, style, output path — all unknown.

Ask (3 questions):
1. **Intent** — what's it for? (hero / OG card / feature card / icon / mockup / illustration / other)
2. **Subject** — one sentence: "a calm sage-green abstract", "a person managing finances on a phone", etc.
3. **Style** — photoreal / flat illustration / 3D isometric / hand-drawn / match existing site

### Use case 2: "Create a hero image for my landing page"

Intent known (hero, responsive set). Subject + style unknown.

If page has copy:
- AUTO mode → synthesize from page content, show prompt preview, ask: "go / tweak X / different style?"

If page is empty / new project:
1. **Subject** — what's the product/service in one line?
2. **Visual style** — match existing site / pick fresh (photoreal / flat / 3D / editorial)
3. **Mood** — energetic / calm / premium / playful / serious

### Use case 3: "Add icons for my features section"

Intent known (icon, transparent bg). Set + style unknown.

Ask:
1. **Which features?** — paste names, or point at file containing them
2. **Style** — flat glyph / line / duotone / isometric / 3D

Don't ask size (1024² default) or palette (use brand).

### Use case 4: "Make an OG image"

Intent known. Subject + look unknown.

Ask:
1. **Headline / topic** — what should the visual support? (won't render as text but drives composition)
2. **Brand-consistent or striking?** — match site or stand out in feeds

### Use case 5: "I need product mockups"

Intent known. Subject + count + presentation unknown.

Ask:
1. **Product type** — app screen / physical product / packaging / wearable
2. **Count** — how many / which variants
3. **Presentation** — clean studio bg / lifestyle / on a device frame / flat layflat

### Use case 6: "Generate placeholder images"

Easy intent (placeholder, quality=low). But still vague.

Ask:
1. **Count** — how many
2. **Filename pattern** — `placeholder-1.png`, `card-bg.png`, etc.
3. **Subject hint** — fully generic / theme (food, tech, people, abstract)

### Use case 7: "Replace this image with something better"

Mode is `replace`. Target known. Improvement direction unknown.

Ask:
1. **What's not working?** — style / subject / composition / palette / mood / quality
2. **Direction** — same subject + different style / new subject entirely / preserve concept tighten execution

If sidecar `.meta.json` exists, surface the original prompt as a baseline.

### Use case 8: "Make this image dark mode" / "Make a light variant"

Mode is `edit`. Usually no questions needed — direction is clear. Generate, iterate.

Edge case: if the original image has dark-text-on-light-bg, "dark mode" means inverting the *background* not the *text*. Ask once: "swap background to dark / invert all colors / re-illustrate in dark palette?"

### Use case 9: "Create marketing visuals"

Hopelessly vague.

Ask:
1. **Channel** — social posts (IG / Twitter / LinkedIn) / display ads / landing page / pitch deck / email
2. **Format** — single image / set of 4-8 / story-format / variable
3. **Campaign topic / message** — one line

### Use case 10: "Generate avatars for the team page"

Intent known. Approach unknown.

Ask:
1. **Style** — photoreal headshots / illustrated avatars / monogram-only / silhouette
2. **Count** — how many team members
3. **Demographics** — anything specified in copy, or leave open?

Sensitive area: if photoreal real people are requested but the user can't name them, propose generic illustrated or monogram alternatives instead. Don't generate fake-photoreal "team members" — it's misleading.

### Use case 11: "Add an image to this MDX post"

Mode is `auto`. Read the file first.

- If post topic is clear → synthesize, show preview, generate
- If post is empty/stub → ask: "what's the post about in one line?"
- If post is technical with no obvious visual → ask: "decorative or illustrative? (decorative = mood-setting, illustrative = depicts a concept)"

### Use case 12: "Generate images for the whole site"

Mode is `auto-pack`. Run scan, build manifest.

After scan completes, ask:
1. **Style anchor** — pick one from the library, or "match existing assets" if any exist
2. **Confirm palette** — show detected palette, ask confirm or override
3. **Cost approval** — "12 images, ~$3.20 estimated, proceed?"

Cost question is non-optional for batches >3 images.

### Use case 13: "Section background with text on top"

Intent known. Safe zone direction needed.

Ask:
1. **What text?** — paste the headline (not for rendering, for safe-zone composition)
2. **Text color** — dark text (need bright safe zone) / light text (need shadowed safe zone)
3. **Position** — left / center / right / corner

Skip these questions if you can read the JSX and see the text element's position directly.

### Use case 14: "Make it look like Stripe's marketing illustrations"

Style copy request. Risky.

Respond:
- "I can do flat geometric editorial illustration in that tradition (Stripe / Linear / Vercel family). I won't clone Stripe's exact look — it'd date your site and feel derivative. Want me to lean toward that family with your palette, or differentiate harder?"
- Then proceed based on answer.

### Use case 15: "Logo for my startup"

Out-of-scope for production. Image-gen unreliable for final logos.

Respond:
- "Image-gen models can't reliably produce a production-ready logo (raster, no vector control, typography varies run-to-run). I can generate **logo concepts/exploration** — moodboard direction — but for final, mix it with vector tooling. Want concepts (yes / no / I know what I want)?"

### Use case 16: "Open Graph for each blog post"

Bulk request. Scan posts, build manifest.

Ask once:
1. **Per-post or shared template** — unique OG per post (one-by-one based on title/excerpt) / shared template with title text overlay added separately
2. **Style** — match site / editorial photo / abstract illustration

Then run as auto-pack with shared style anchor.

### Use case 17: "Hero that includes our product screenshot"

Hybrid request. Image-gen can't recreate a real UI accurately.

Respond:
- "I can generate the surrounding scene/environment and you composite your real product screenshot in, OR I can generate a stylized fake-UI mockup. Which?"
- For option A: generate the bg, then user composites in their app
- For option B: spawn codex with ui-mockup prompt; warn about hallucinated UI text

### Use case 18: "I want it to feel premium"

Vague aesthetic word. Easy to misinterpret.

Ask:
1. **Premium reference** — point at 2-3 sites/brands that feel "premium" to them, OR pick from: minimalist Swiss / editorial photo / 3D dimensional / cinematic / mixed
2. **Palette direction** — neutral & sparse / rich tonal / warm / cool / mono

"Premium" means very different things across product categories (luxury watch vs B2B SaaS vs DTC consumer).

### Use case 19: "Generate variants" (no specifics)

Variant-style request without specifics.

Ask:
1. **What varies** — palette / composition / subject / mood
2. **Count** — 2 / 4 / 8

Use `n` in codex prompt, not parallel spawns.

### Use case 20: "Replace all my images with AI-generated versions"

Risky bulk replace.

Respond:
- "Replacing all images is high-risk — current images might have brand context I can't infer. Want me to: (a) propose 3-5 high-value swaps with rationale, (b) generate alternates without replacing originals, (c) replace 1-by-1 with your approval each time?"
- Don't bulk-replace without explicit per-image approval.

---

## When NOT to ask (proceed with defaults)

- User gave a specific subject + intent — fill defaults, generate, iterate
- AUTO mode and surrounding content is rich — synthesize, show preview, proceed on "go"
- Cost-related question is below threshold (≤3 images, <$1)
- User explicitly said "just do it" / "you decide" / "surprise me"
- Replacing an asset and a sidecar `.meta.json` exists — reuse prompt, ask only about delta

## Question fatigue avoidance

If the user has answered questions twice already in this thread, default harder. Don't ask a third round — generate something with best-guess defaults, show it, and let them redirect via natural follow-up ("more like X / less like Y").
