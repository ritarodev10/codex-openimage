# Asset-Pack Scan — Finding Every Image Slot

For `auto-pack` mode, scan the codebase to find every place an image is (or should be) referenced. Output a JSON list consumed by the skill.

## What counts as a slot

1. **Direct img references** in JSX/TSX/HTML/MDX/Vue/Svelte/Astro:
   - `<img src="...">`
   - `<Image src="...">` (Next.js, Astro)
   - `<NextImage>`, `<picture>`, `<source srcset>`
2. **CSS background images**:
   - `background-image: url(...)` in `.css` / `.scss` / `.module.css`
   - Tailwind arbitrary: `bg-[url('...')]`
3. **Metadata**:
   - `<meta property="og:image">`, `<meta name="twitter:image">`
   - Next App Router: `metadata.openGraph.images`, `metadata.twitter.images`
   - Astro/Nuxt frontmatter: `image:` field
4. **Manifest icons**:
   - `manifest.json` `icons` array
   - `apple-touch-icon` `<link>`
5. **Favicons**:
   - `<link rel="icon">`, `favicon.ico` reference
6. **Open Graph image co-located files**:
   - Next: `app/opengraph-image.{png,jpg,tsx}`, `app/twitter-image.{png,jpg}` (in any route folder)
7. **Empty / missing referenced paths**:
   - Any string that ends in `.{png,jpg,jpeg,webp,svg,gif,avif}` and points to a file that doesn't exist on disk → slot needing fill

## Output schema

```json
{
  "framework": "next",
  "image_dir": "public/images",
  "slots": [
    {
      "id": "hero-home",
      "kind": "img",
      "src": "/images/hero.png",
      "abs_path": "/abs/.../public/images/hero.png",
      "exists": false,
      "context_file": "app/page.tsx",
      "context_line": 12,
      "surrounding_text": "...hero section: 'Track every dollar...'...",
      "alt_text": "Hero illustration of a person managing finances",
      "responsive_set": true,
      "text_overlay": true,
      "intent_guess": "hero",
      "size_hint": [1920, 1080]
    },
    {
      "id": "og-default",
      "kind": "og-meta",
      "src": "/og.png",
      "abs_path": "/abs/.../public/og.png",
      "exists": false,
      "context_file": "app/layout.tsx",
      "context_line": 8,
      "responsive_set": false,
      "intent_guess": "og"
    }
  ]
}
```

## Surrounding text extraction

For each slot, capture the **nearest heading + first paragraph + section name** from the file. This is the raw material for prompt synthesis.

Rules:
- Look upward in the same file for the nearest `<h1>` / `<h2>` / `<h3>` / `# ` / `## ` heading
- Capture 1-2 paragraphs of body copy that follow that heading
- Strip JSX tags, leave only text
- Max 500 chars total

## Text-overlay detection

Mark `text_overlay: true` if any of:
- A `<h1>`, `<h2>`, or large text element is positioned over the image in the same JSX block (look for `absolute`, `inset-0`, `z-` Tailwind classes)
- File path matches `hero-bg`, `section-bg`, `banner-bg`
- The image is used as `background-image:` in CSS with text-layer siblings
- User explicitly says "with text on top"

Text-overlay slots need safe-zone aware prompts and typically a responsive set.

## Responsive set detection

Mark `responsive_set: true` if:
- `<picture>` element with multiple `<source media="...">`
- `srcset` with multiple sizes
- Code references `<name>-mobile`, `<name>-tablet`, `<name>-desktop` patterns
- Intent is `hero`, `section-bg`, or `banner` (default to true)

## Intent guess

Use `references/intent-presets.md` path-hint rules. Surface as `intent_guess`; user can override.

## Frameworks — special places to look

### Next.js (App Router)

```
app/**/page.{tsx,jsx}            — <Image src>
app/**/layout.{tsx,jsx}          — metadata.openGraph.images
app/opengraph-image.{tsx,png,jpg} — co-located OG
app/icon.{tsx,png,jpg}            — favicon
public/**                         — direct assets
```

### Next.js (Pages Router)

```
pages/**/*.{tsx,jsx}              — <Image>, <Head> with og meta
pages/_app.{tsx,jsx}              — global meta
pages/_document.{tsx,jsx}         — head links
```

### Astro

```
src/pages/**/*.astro              — <img>, <Image>, frontmatter image:
src/layouts/**/*.astro            — meta tags
public/**                         — direct assets
astro.config.{js,ts}              — site URL for OG
```

### SvelteKit

```
src/routes/**/*.svelte            — <img>, <svelte:head>
src/app.html                      — root head
static/**                         — direct assets
```

### Vue / Nuxt

```
pages/**/*.vue                    — <img>, useHead
layouts/**/*.vue                  — meta
public/** or assets/**            — direct assets
nuxt.config                       — site head
```

### Generic HTML

```
**/*.html                          — <img>, <meta>, <link>
**/*.css                           — background-image
```

## Implementation hint for scripts/scan-image-slots.sh

```
1. Detect framework (read package.json, look for config files)
2. Walk files matching framework-specific globs
3. For each file, regex-extract image references + their line numbers
4. For each ref, resolve absolute path and check if file exists
5. Walk upward for heading + body context
6. Detect text-overlay markers in surrounding JSX/HTML
7. Guess intent from path
8. Emit JSON
```

Keep it dependency-free (bash + grep + awk). For a richer parser, future versions can use tree-sitter. v1 = regex.
