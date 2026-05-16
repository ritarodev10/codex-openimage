# Negative Prompts — Quality Guardrails

Inject the relevant block into every codex prompt based on detected content type. Stack multiple blocks when relevant (e.g., a hero with people gets `people` + `web-asset` + `hero`).

## Universal (always include)

```
Avoid: watermark, signature, stock-photo logos, generic gradient mesh, AI-generated text artifacts, garbled letters, fake UI typography, jpeg compression banding, oversaturation, harsh bloom, halo around edges, oversharpening.
```

## Web asset (any image destined for production web)

```
Avoid: cliché stock photography aesthetic, tacky lens flares, cheap vector clip-art look, generic AI illustration tropes (blob people, gradient over-mesh, neon over-glow), overcrowded composition, decorative elements competing with content.
Composition: balanced, restrained, premium-feeling, leaves room for typography over the image when needed.
```

## People / portraits

```
Avoid: extra fingers, mangled hands, asymmetric faces, dead eyes, melted skin, prosthetic-looking teeth, plastic skin texture, uncanny-valley expressions, blurred or distorted facial features.
Subjects: real-looking people with natural skin texture, plausible anatomy, candid expressions, varied ages/ethnicities where contextually appropriate.
```

## UI / app mockup

```
Avoid: fake UI text that doesn't render as real letters, broken icons, misaligned grid, inconsistent corner radii, three different fonts in one frame, made-up brand logos that resemble real ones.
Style: realistic typography, clean lines, consistent spacing, plausible dashboard / app interface aesthetic, modern OS chrome conventions if relevant.
```

## Product mockup

```
Avoid: warped product geometry, distorted labels, illegible packaging text, melted edges, multiple seams visible, fake brand wordmarks that look like real brands.
Style: clean studio lighting, accurate proportions, sharp product silhouette, plausible material rendering (matte/gloss as specified), color-accurate.
```

## Hero / landing page

```
Composition: clear focal point, generous negative space for headline + subhead overlay, single subject or unified scene, no distracting background details, depth via lighting not clutter.
Avoid: busy backgrounds, multiple competing focal points, mid-2010s startup-illustration tropes (giant smiling characters with disproportionate limbs).
```

## Section background with text overlay

```
Composition: quiet visual region in the safe zone for text overlay; soft tonal falloff toward that region; no busy detail behind text; sufficient contrast for either dark or light text as specified.
Avoid: busy patterns in safe zone, hard edges crossing text region, high-frequency texture under headline.
```

## Icon / logo

```
Style: simple, recognizable silhouette readable at small sizes; consistent stroke/weight; balanced composition; transparent background; minimal color palette.
Avoid: over-detailed, multiple competing shapes, gradients that fail at small sizes, text inside icons, photorealistic rendering for icon use.
```

## Illustration / flat graphic

```
Style: cohesive flat or semi-flat illustration, consistent line weights, intentional palette, geometric clarity, no photo elements mixed in.
Avoid: mixing photo and illustration, inconsistent stroke weights, default Adobe Stock illustration look, "corporate Memphis" trope (unless explicitly requested).
```

## Infographic / diagram

```
Style: clear hierarchy, legible labels, consistent iconography, geometric precision.
Avoid: hallucinated chart data, fake numbers that look like real data, broken axes, illegible micro-text.
Note: image generation is unreliable for precise text — prefer SVG/code for actual data viz. Use image only for decorative diagram concept.
```

## Concept art

```
Style: cinematic lighting, painterly atmosphere, intentional color script, strong silhouette.
Avoid: generic ArtStation aesthetic, over-rendered surface noise, unmotivated lighting.
```

## Safety guardrails (always check, refuse if violated)

Before spawning, refuse and propose alternatives if the prompt names:

- Real specific people by name (politicians, celebrities, influencers) → propose "person resembling that role" generically
- Trademarked characters (Disney, Nintendo, etc.) → propose generic equivalent
- Specific brand logos or wordmarks (Coca-Cola, Apple, etc.) → propose fictional brand
- Real children
- Suggestive / explicit content
- Hate symbols, violent imagery

Codex's own imagegen skill enforces these — we're double-checking before burning tokens.
