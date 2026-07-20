---
name: codex-image-gen
description: When the task is to produce image assets (app icons, illustrations, placeholder art, draft marketing visuals, etc.), delegate to the tmux Codex pane instead of writing drawing scripts yourself. Applies to any task whose deliverable is "one or a set of image files".
---

# Codex Image Generation (delegation SOP)

## Positioning & the exception to the hard line

`using-codex-collaboration` draws a hard line: "Codex reviews, never does." **Image asset generation is a whitelisted exception to that line**: an image is not a code implementation — it is a one-off deliverable, it never enters the code-review loop, and it does not amount to "Codex wrote feature code". The exception covers only the production of image files; code implementation, scripts that land in the repo, and feature development remain non-delegable, always.

## Workflow

1. **Locate/launch the Codex pane**: follow `using-codex-collaboration` Step 1 / 1b (send-keys discipline, ghost-text discipline, and background-polling discipline all apply). Image tasks aren't picky about the repo directory, but the deliverable's destination must be an absolute path in the brief.
2. **Send the brief**, which must include:
   - Purpose and content intent (one sentence, e.g. "app icon for X: dark background + brand-green database/pulse motif")
   - **Hard constraints**: exact dimensions (e.g. 1024×1024), format (PNG/JPG), alpha-channel requirements (App Store icons must have no alpha), color style
   - **Compliance constraints**: no third-party trademarks/logos — nominative use applies to words only; someone else's logo inside your graphic asset is infringement
   - **Absolute output path** (a scratch/asset directory you control, not some tool's temp directory)
3. **Poll and wait** (background polling, no foreground sleep). On completion, **view the generated image yourself with your image-reading tool** — file-exists ≠ content-acceptable; verify dimensions (`sips -g pixelWidth -g pixelHeight` on macOS) and alpha.
4. **Iterate with concrete feedback when it falls short** ("the column seam pokes through the top face" beats "doesn't look good"). The same pane accumulates context — no need to restate every constraint.
5. Once the image is final, **the engineering hookup (asset catalog, config, PR) stays with you** — that's code, never delegated.

## Known boundaries

- If Codex has no native image-generation capability, it will write a throwaway drawing script to produce the image — that's fine; the acceptance criterion is the output file, not the production method. But the script must not land in the repo (use-and-discard in a temp directory).
- Formal design work with high aesthetic demands (e.g. a final brand icon) should still come from a human designer — this skill covers "good-enough" assets (v1 icons, placeholders, diagrams).
