---
name: codex-image-gen
description: When the task is to produce image assets (app icons, illustrations, placeholder art, draft marketing visuals, etc.), delegate to the tmux Codex pane instead of writing drawing scripts yourself. Applies to any task whose deliverable is one or more image files.
---

# Codex Image Generation (delegation SOP)

## Positioning & the exception to the hard line

`using-codex-collaboration` draws a hard line: "Codex reviews, never does." **Image asset generation is a whitelisted exception to that line**: an image is not a code implementation — it is a one-off deliverable, it never enters the code-review loop, and it does not amount to "Codex wrote feature code". The exception covers only the production of image files; code implementation, scripts that land in the repo, and feature development remain non-delegable, always.

## Capability note

How Codex produces the image depends on its environment. If the pane has a native image-generation tool (e.g. an `$imagegen`-style capability in newer Codex versions), tell it to use that explicitly in the brief — don't leave the method to chance. If it has no native capability, it will typically write a throwaway drawing script — that's acceptable: the acceptance criterion is the output file, not the production method. Either way the script/tool residue must stay in a temp directory, never the repo.

## Workflow

1. **Locate/launch the Codex pane**: use `using-codex-collaboration`'s bundled `codex-pane.sh` (ensure/send/wait/capture — all its disciplines apply). Image tasks aren't picky about the repo directory.
2. **Send the brief**, which must include:
   - Purpose and content intent (one sentence, e.g. "app icon for X: dark background + brand-green database/pulse motif")
   - **Hard constraints**: exact dimensions (e.g. 1024×1024), format (PNG/JPG), alpha-channel requirements (App Store icons must have no alpha), color style
   - **Compliance constraints**: default to no third-party trademarks, logos, or brand-distinctive visual elements in the asset — nominative fair use covers *naming* another product in text, not reproducing its marks in your graphics; only deviate with an explicit license or after legal review
   - **Absolute output path in a scratch directory you control** — never a path inside the repo working tree. The "you are the sole writer to the working tree" guarantee applies to delegation too: Codex writes to scratch, and *you* copy the accepted file into the repo yourself.
3. **Poll and wait** in the background (`codex-pane.sh wait`). On completion, **view the generated image yourself with your image-reading tool** — file-exists ≠ content-acceptable; verify dimensions (`sips -g pixelWidth -g pixelHeight` on macOS, or ImageMagick `identify`) and alpha.
4. **Iterate with concrete feedback when it falls short** ("the column seam pokes through the top face" beats "doesn't look good"). The same pane accumulates context — no need to restate every constraint.
5. Once the image is accepted, **you copy it from scratch into the repo, and the engineering hookup (asset catalog, config, PR) stays with you** — that's code, never delegated.

## Known boundaries

- Formal design work with high aesthetic demands (e.g. a final brand icon) should still come from a human designer — this skill covers "good-enough" assets (v1 icons, placeholders, diagrams).
