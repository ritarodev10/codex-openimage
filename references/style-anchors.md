# Style Anchors — Cohesive Look Across a Pack

For `auto-pack` mode (or any time multiple images need to feel like one family), pick a style anchor once and apply it to every prompt in the pack. Without this, parallel spawns produce visually inconsistent results.

## How to pick a style

1. **If existing brand assets exist** → describe their style, use that. Highest fidelity.
2. **If brand guidelines / docs exist** → read them, extract the style cues.
3. **If neither** → ask the user one question, multiple choice:
   - flat geometric illustration
   - photorealistic editorial
   - 3D isometric / dimensional
   - hand-drawn / sketchy
   - cinematic / atmospheric
   - mixed (photo subject on flat-color bg)
4. **If `auto-pack` and user said "you decide"** → pick based on industry context (fintech → flat geometric or editorial photo; SaaS dev tools → terminal / line-art; consumer → photoreal or 3D; agency → editorial photo or mixed).

## Style descriptor library

Each block is meant to be **pasted as-is** into a codex prompt as the style anchor. Pick one, don't mix.

### Flat geometric illustration

```
Style: flat geometric illustration. Bold, deliberate shapes assembled from clean primitives. No outlines or 1px hairline outlines only. Subtle 2-color soft drop shadows (offset shadows in single tone). Limited 4-6 color palette with one warm accent. Texture-free or very subtle paper-grain noise. Off-balance, asymmetric composition. Modern editorial illustration tradition (think Stripe / Linear / Vercel marketing).
```

### Photorealistic editorial

```
Style: photorealistic editorial photography. Natural ambient lighting, shallow depth of field with intentional focal point, real human moments captured candidly. Cohesive color grade — warm midtones, lifted blacks, soft contrast. Avoid stock-photo composition; favor honest, unposed editorial framing. Single subject or unified small group, never a posed corporate cluster.
```

### 3D isometric / dimensional

```
Style: clean 3D isometric render at 30°/30° axes, soft global illumination, single warm key light, gentle ambient occlusion. Matte materials with subtle subsurface detail. Limited tonal palette (3-5 hues plus white/charcoal). Floating elements with soft shadows beneath. Modern product illustration (think Pitch / Mercury / Cron).
```

### Hand-drawn / sketchy

```
Style: hand-drawn illustration with visible pencil or pen-and-ink texture, deliberate imperfection in linework, organic shapes. Limited 3-4 color palette, watercolor wash for fills or flat ink fills. Off-register feel, paper-grain background optional. Editorial sketchiness (NYT, New Yorker tradition), not children's-book cartoon.
```

### Cinematic / atmospheric

```
Style: cinematic still frame, anamorphic-feeling composition, atmospheric haze, single dramatic light source, deep shadows with detail preserved, color graded cool-shadow / warm-highlight or vice versa. Sense of scale and mood. Photoreal or hyper-real, painterly only at edges.
```

### Mixed (photo subject on flat bg)

```
Style: high-quality photo subject (person or product) sharply cut out, placed on flat geometric illustrated background. Background is a 2-3 color flat composition with simple shapes (circle, arch, blob). Subject and background share a single warm or cool color temperature. Premium e-commerce / consumer-app feel.
```

### Minimalist / Swiss

```
Style: minimalist Swiss-design influenced. Lots of negative space, a single small focal element, neutral palette with one bold accent color. Geometric type-poster sensibility. Restraint over ornamentation. Could be photo or illustration, but the *amount* of content is minimal.
```

### Brutalist / mono

```
Style: high-contrast mono palette (one dark, one light, one accent maximum). Heavy shapes, intentional asymmetry, exposed grid feel. Editorial / zine aesthetic. Either monochrome photo or stark vector illustration.
```

### Soft / pastel / organic

```
Style: soft organic shapes with rounded corners, pastel palette, gentle gradients, blurred soft shadows, slight grain. Friendly approachable feel. Could be illustrated or 3D, never sharp photo. Common in wellness / lifestyle / health-tech marketing.
```

## Pack consistency rule

Once a style is chosen for a pack:

1. Prefix every prompt with the chosen style block
2. **Lock the palette** — same hex codes repeated literally in every prompt
3. **Lock the lighting** — "key light from upper-left" repeated literally
4. Generate the **largest / most prominent asset first** (typically `hero-desktop`)
5. Pass that asset as `input_image` to every subsequent spawn — this is the single biggest consistency lever, more reliable than text description alone

## Anti-cliché check

Before locking a style, scan the user's existing site / brand. If the proposed style is going to feel like:

- Stripe's marketing illustration → ask if they want differentiation
- Linear's monochrome moodboard → ask if they want differentiation
- Default "corporate Memphis" with floating limbs → push back, propose alternatives

The skill should help the user feel distinctive, not blend in.

## Format reference for the codex prompt

Final shape of a single-spawn prompt with style anchor:

```
Use your imagegen skill to generate a [INTENT_PRESET] image.

[STYLE_ANCHOR_BLOCK]

Palette: [PALETTE_LINE]

Subject: [SUBJECT]
Scene: [SCENE]
Composition: [COMPOSITION_HINT including safe-zone if text overlay]

[NEGATIVE_PROMPTS_BLOCK]

Output: save PNG to [ABSOLUTE_PATH], dimensions [W]x[H]
When done, print only the absolute path to the saved file as the last line.
```
