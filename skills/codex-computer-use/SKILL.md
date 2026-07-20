---
name: codex-computer-use
description: When computer use is needed (driving a GUI — screenshot/click/type loops, desktop app operations, browser UI operations, system settings panels, any task that can only be done "with eyes and hands") — delegate to the tmux Codex pane instead of grinding through it with your own computer-use tools. Applies to any task requiring human-like screen viewing and mouse/keyboard control — including when your own computer-use tools won't connect, click imprecisely, or fail repeatedly (which is exactly why this skill exists: Claude-side computer use can be unstable while Codex-side is stable).
---

# Codex Computer Use (delegation SOP)

## Positioning & the exception to the hard line

`using-codex-collaboration` draws a hard line: "Codex reviews, never does." **Computer-use tasks are the second whitelisted exception** (the first is image generation, see `codex-image-gen`): GUI operation is not code implementation — it is a one-off interface-driving process that produces no repo code and never enters the code-review loop. Why: Claude-side computer use can be unstable (click drift, dropped connections, repeated failures) while Codex-side computer use is reliable — so this class of task is **delegated by default**; don't burn rounds failing on your own first.

The exception covers only "driving the screen to complete the task"; code work before or after (writing scripts, editing config files, opening PRs) stays with you, never delegated.

## When this skill applies

Either condition qualifies:

- The task can only be done through a GUI, with no CLI / API equivalent (spend 30 seconds checking first — anything `gh`, an official CLI, curl, or AppleScript/`osascript` can do should never consume computer use, regardless of who performs it).
- A dedicated automation tool exists (browser extensions, Playwright, XCUITest, …) but has proven unstable / failed 2+ times in practice, or the scenario is clearly outside its coverage (non-browser desktop apps, system dialogs).

## Workflow

1. **Locate/launch the Codex pane**: follow `using-codex-collaboration` Step 1 / 1b (pane location, launch command, send-keys discipline, ghost-text discipline, background-polling discipline all apply). Computer-use tasks usually have no natural home repo — when there isn't one, open the pane in any stable directory (e.g. home), but every file path in the brief must be absolute.
2. **Send the delegation brief**, which must include:
   - **Task goal** (one sentence defining "done", e.g. "on the App Store Connect website, update app X's promotional text to the following")
   - **Target and entry point** (which app / which URL / which window, and how to get there)
   - **Hard constraints**: what to do and what never to touch (e.g. "change only the promotional text field, leave every other metadata field alone", "do not click any Submit / send-for-review button")
   - **Login-state assumption**: assume the browser/app is already signed in; if a password/verification code is requested mid-flow, stop and report back — never guess or hunt for credentials
   - **Report-back requirement**: on completion, report what was done plus a screenshot of the final state or a textual description of the key screens, for verification
3. **Poll and wait** (background polling, no foreground sleep) per `using-codex-collaboration` Step 3. GUI work is slower than text work — allow ~10 minutes before judging it hung.
4. **Verify the result yourself** — Codex saying "done" ≠ done. Verify through a channel independent of Codex: query the final state via API/CLI when possible (e.g. read the field back), otherwise have Codex screenshot and view the image yourself, or open the page read-only and confirm.
5. **Iterate with concrete feedback when it falls short** ("the field on the third tab was never saved before navigating away" beats "it didn't work"). The same pane accumulates context — no need to restate every constraint.

## Safety boundaries (delegation relaxes nothing)

- **Irreversible / outward-facing operations** (submitting for review, publishing, deleting, paying, sending emails/messages): must not appear in the brief without the user's explicit authorization in the current conversation; the brief must explicitly say "stop before X". A delegated operation carries the same approval requirements as one you perform yourself.
- **Credential discipline**: never paste passwords/tokens into the brief for Codex to type. When login is required, ask the user to sign in manually first, then delegate.
- **Execution drift**: if Codex deviates from the brief and performs extra operations, report what actually happened faithfully — never just "task complete".

## Known boundaries

- This skill only changes *who moves the mouse* — it waives no process constraints: repo changes downstream still follow your normal PR workflow; release/submission actions still follow your normal release process.
- As with `codex-image-gen`, acceptance looks only at the task result, not at how Codex implemented it internally (whatever computer-use toolchain it uses is its business).
