# Project Detection

How to detect framework, output paths, palette, and existing image style so we don't have to ask the user.

## Framework → output directory

Probe in this order; first match wins.

| Marker file/dir | Framework | Default image dir |
|---|---|---|
| `next.config.{js,ts,mjs}` | Next.js | `public/images/` |
| `nuxt.config.{js,ts}` | Nuxt | `public/images/` or `assets/images/` |
| `astro.config.{js,ts,mjs}` | Astro | `public/images/` or `src/assets/images/` |
| `svelte.config.{js,ts}` | SvelteKit | `static/images/` |
| `remix.config.{js,ts}` | Remix | `public/images/` |
| `vite.config.{js,ts,mjs}` (no above) | Vite | `public/images/` |
| `gatsby-config.{js,ts}` | Gatsby | `static/images/` or `src/images/` |
| `Gemfile` + `config/application.rb` | Rails | `app/assets/images/` |
| `mix.exs` + `assets/` | Phoenix | `assets/static/images/` or `priv/static/images/` |
| `manage.py` + Django settings | Django | `static/images/` (per `STATICFILES_DIRS`) |
| `app.json` / `package.json` with `expo` | Expo / React Native | `assets/images/` |
| `index.html` + no framework | Vanilla / static site | `images/` or `assets/images/` |

If multiple frameworks detected (monorepo), ask which app the asset belongs to.

If `public/` doesn't exist but the framework expects it, fall back to where existing images live: `find . -type d -name images | head -5`.

## OG / social-card location

Detect from framework metadata patterns:

- Next.js App Router: `app/opengraph-image.{png,jpg}` or `app/<route>/opengraph-image.tsx` — write to the route folder
- Next.js Pages Router: usually `public/og.png`, referenced via `<meta property="og:image">` in `_document.tsx` or `Head`
- Astro: `src/og/` or `public/og.png`
- Generic: read `<meta property="og:image" content="...">` from HTML and write to that path

## Favicon / PWA icon paths

Standard locations to write to:
- `public/favicon.ico` (32×32 source, generate from `favicon-source` intent)
- `public/apple-touch-icon.png` (180×180)
- `public/icon-192.png`, `public/icon-512.png` (PWA)
- `public/manifest.json` `icons` array — read and respect declared sizes

## Palette extraction

In priority order:

1. **Tailwind config** — read `tailwind.config.{js,ts}`, extract `theme.colors` and `theme.extend.colors`. Pull primary/accent/brand keys if present.
2. **CSS custom properties** — grep `*.css`, `*.scss` for `--color-*`, `--brand-*`, `--accent-*`, `--primary-*`. Read their hex/rgb/oklch values.
3. **`globals.css` / `app.css` / `index.css`** — `:root { ... }` declarations
4. **`package.json` brand fields** — some projects store `brand.colors`
5. **Logo file inspection** — if a logo exists in `public/`, sample dominant colors with `sips -g pixelWidth` + image-magick `convert <logo> -resize 1x1 txt:-` (or just describe the logo to codex and let it infer).

Output of this step: a compact palette string for codex prompts:
```
Palette: sage #6B8E72 (primary), warm sand #E8DCC4 (secondary), clay #C8754D (accent), bone #FAFAF5 (bg), graphite #2A2A28 (text)
```

If no palette can be inferred, omit the palette line — don't invent one. Codex's imagegen skill will pick something neutral.

## Existing image style inference

If the target output folder already has images, sample them to match style:

```bash
find <out-dir> -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.webp' \) | head -5
```

Pass the first 1-2 paths to codex as `input_image` references and tell it: "match the visual style of these existing assets (palette, illustration vs photo, lighting, composition mood) — do not copy subject, only style".

This is the highest-fidelity style match available — better than describing style in words.

## Site name / tagline

For prompt synthesis context:
- Site name: from `<title>` in `index.html`, or `siteMetadata.title` (Gatsby), or `metadata.title` export (Next App Router), or `package.json` `name`
- Tagline: from `<meta name="description">` or `metadata.description`
- Use only as context, never inject the literal text into images (text rendering is unreliable)

## Detection script call pattern

This logic should be runnable via `scripts/scan-image-slots.sh --detect-only` which prints JSON:

```json
{
  "framework": "next",
  "image_dir": "public/images",
  "og_path": "app/opengraph-image.png",
  "favicon_dir": "public",
  "palette": "sage #6B8E72 (primary), ...",
  "site_name": "Finwell",
  "tagline": "Track every dollar...",
  "style_anchor_candidates": ["public/images/hero-old.png", "public/images/about.png"]
}
```

Skill consumes that JSON and weaves it into every codex prompt.
