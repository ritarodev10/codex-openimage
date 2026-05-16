# Intent → Preset Table

Map an intent slug to size, format, quality, naming, and responsive set. Use this to avoid asking the user for dimensions.

## Single-asset intents

| Intent | Single size | Format | Quality | Transparent BG | Naming |
|---|---|---|---|---|---|
| `hero` | 1920×1080 | PNG (+WebP sibling) | high | no | `hero.png` |
| `section-bg` | 1920×1080 | PNG (+WebP) | high | no | `<section>-bg.png` |
| `banner` | 1920×600 | PNG (+WebP) | high | no | `<name>-banner.png` |
| `og` | 1200×630 | PNG | high | no | `og.png` or `og-<page>.png` |
| `og-twitter` | 1200×675 | PNG | high | no | `twitter-card.png` |
| `feature-card` | 1024×1024 | PNG (+WebP) | medium | no | `feat-<slug>.png` |
| `feature-illust` | 1024×1024 | PNG | medium | yes | `illust-<slug>.png` |
| `product-mockup` | 1536×1024 | PNG (+WebP) | high | no | `product-<slug>.png` |
| `ui-mockup` | 1536×1024 | PNG (+WebP) | high | no | `mockup-<slug>.png` |
| `icon` | 1024×1024 | PNG | medium | yes | `icon-<slug>.png` |
| `logo` | 1024×1024 | PNG | high | yes | `logo<-variant>.png` |
| `favicon-source` | 1024×1024 | PNG | high | yes | `favicon-src.png` |
| `avatar` | 512×512 | PNG | medium | optional | `avatar-<slug>.png` |
| `pattern-tile` | 1024×1024 | PNG | medium | optional | `pattern-<slug>.png` |
| `mobile-hero` | 768×1280 | PNG (+WebP) | high | no | `<name>-mobile.png` |
| `infographic` | 1536×2048 | PNG | high | no | `info-<slug>.png` |
| `concept-art` | 1536×1024 | PNG | high | no | `concept-<slug>.png` |
| `placeholder` | 1024×1024 | PNG (low) | low | no | `placeholder-<slug>.png` |

`+WebP sibling` means postprocess emits a `.webp` alongside.

## Responsive intent sets

When an intent is responsive (typically `hero`, `section-bg`, `banner`, `og` family), generate the **full set** below. Each row is a separate codex spawn (3 per asset).

### Hero / section-bg / banner

| Variant | Size | Aspect | Safe zone (default text overlay) |
|---|---|---|---|
| `mobile`  | 768×1024  | 3:4 portrait | center horizontal band, middle 60% height |
| `tablet`  | 1280×960  | 4:3          | left half OR right half (pick by layout) |
| `desktop` | 1920×1080 | 16:9         | left-third for headline; right-two-thirds focal |

Naming: `<name>-mobile.png`, `<name>-tablet.png`, `<name>-desktop.png`.

### OG cards (no responsive — fixed surface)

Generate only the canonical sizes:
- `og.png` 1200×630 (Facebook, LinkedIn, generic)
- `twitter-card.png` 1200×675 (Twitter large card)
- Optional: `og-square.png` 1080×1080 (Instagram share)

## Retina rule

After the base PNG is generated, postprocess emits `<name>@2x.png` for any asset with base width <2000px. Skip if base is already ≥2000px wide (no benefit on desktop displays).

## Format selection rule

- Subject needs cutout / transparency → PNG, transparent BG
- Photoreal / hero / bg with rich gradient → JPG primary + WebP sibling (or PNG + WebP — JPG if file size matters more than perfect lossless)
- Flat illustration / vector-like → PNG + WebP
- Animated / video — out of scope, refer user to motion tools

WebP sibling is **always** emitted for web assets (web pickup `<picture>` element works better with it).

## Quality decision rule

- `quality: low` only for `placeholder` intent or explicit user "draft" / "preview" / "cheap"
- `quality: medium` default for iteration and most cards/icons
- `quality: high` for hero, OG, product-mockup, logo, infographic, concept-art, and any filename ending in `-final`
- If a user explicitly says "high quality" or "final" — bump to high regardless

## Cost reference (gpt-image-1.5, approximate)

| Quality | 1024² | 1536×1024 | 1920×1080 |
|---|---|---|---|
| low    | $0.011 | $0.016 | $0.020 |
| medium | $0.042 | $0.063 | $0.084 |
| high   | $0.167 | $0.250 | $0.333 |

Use this to compute the "~$X estimated" guardrail before batches. Multiply by `n` for variants and by 3 for full responsive sets.

## Selecting intent from file path / context

Path-based hints (used by `auto` and `replace` modes):

- `hero-*` / `*-hero.*` / inside `hero/` → `hero` (responsive)
- `*-bg-*` / `bg-*` / `background-*` / inside `bg/` → `section-bg` (responsive)
- `og*` / `social-card` / `share-*` / inside `og/` → `og`
- `twitter*` → `og-twitter`
- `feat-*` / `feature-*` / inside `features/` → `feature-card` (or `feature-illust` if folder contains other transparent illustrations)
- `icon-*` / `*-icon.*` / inside `icons/` → `icon`
- `logo*` → `logo`
- `favicon*` → `favicon-source`
- `avatar-*` / `team-*` / `user-*` / inside `team/` → `avatar`
- `product-*` / inside `products/` → `product-mockup`
- `mockup-*` / `dashboard-*` / `app-*` → `ui-mockup`
- `placeholder*` → `placeholder`

If no path hint matches, ask the user once: "what kind of image — hero, OG card, feature card, icon, mockup?"
