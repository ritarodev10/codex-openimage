# Legacy — Pre-Codex Direct-CLI Implementation

These files predate the `codex-openimage` orchestration layer. Back then the skill
called the OpenAI Image API directly via a Python CLI rather than delegating to
the `codex` worker.

Kept for:

- **Fallback** — if `codex` is unavailable, `legacy/scripts/image_gen.py` can be
  invoked manually with `OPENAI_API_KEY` set.
- **Historical reference** — prompting guidance, network notes, and the original
  agent definition show how the skill evolved.

## Contents

| Path | What it was |
|---|---|
| `scripts/image_gen.py` | Standalone Python CLI that called `images.generate` / `images.edit` / `images.variations` directly. |
| `references/cli.md` | Usage docs for the Python CLI. |
| `references/codex-network.md` | Notes on running the legacy CLI inside the codex sandbox network. |
| `references/image-api.md` | OpenAI Image API endpoint reference. |
| `agents/openai.yaml` | Original agent definition that wrapped the Python CLI. |

These are **not** wired into the active skill. `SKILL.md` does not reference them.
If you need to invoke the legacy path, call the script directly:

```bash
python3 legacy/scripts/image_gen.py --help
```
