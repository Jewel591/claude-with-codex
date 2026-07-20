---
name: using-codex-collaboration
description: Use proactively whenever the work involves substantial code changes (multi-file, core logic, architecture), a freshly written execution plan, a sticky bug that resists single-perspective diagnosis, or a non-obvious design decision that needs adversarial challenge — establishes when and how to bring Codex in as a reviewer (not as an executor). The ONLY channel is the persistent Codex pane reached via tmux (send-keys / capture-pane) — this holds even when Claude's own session is NOT running inside tmux (drive the tmux server externally; create a detached session if needed). Direct `codex` CLI invocation (codex exec etc.) is FORBIDDEN unless the user explicitly requests it, because it loses context. Covers locating/launching the Codex pane, the predefined collaboration scenarios (review-uncommitted, plan review, adversarial challenge, bug rescue), and the review⇄fix consensus loop that runs until Codex passes.
---

# Using Codex Collaboration

## Why this skill exists

Codex is a **second perspective** — a reviewer that catches what the primary engineer missed. It is **not** a task-outsourcing endpoint.

Hard line:

- ✅ Codex does: plan review, code review, architecture review, independent bug diagnosis, sanity-checking design decisions. To do these it freely runs its own read tools (`git diff`, `git status`, `rg`, file reads) — that is expected and encouraged.
- ❌ Codex does **not**: implement features, write new code, run the build/tests as a gate, finish work the primary engineer should finish.

Treating "use Codex" as "outsource the task" is a misread, even if Codex has tokens to spare and the task is large or cross-file. **The primary engineer (you, Claude) finishes the work; Codex audits it.** This is a *behavioral* guarantee, enforced by your discipline — you are the sole writer to the working tree. Never ask Codex to edit/implement, and never proceed on the assumption that Codex changed files. After every Codex round, *you* make the edits.

(Two narrow, whitelisted exceptions to the "Codex reviews, never does" line exist as sibling skills: `codex-image-gen` for producing image assets and `codex-computer-use` for GUI automation. Both cover one-off outputs that never enter the code-review loop; code work is never delegated.)

## The collaboration channel — the tmux Codex pane (ONLY entry point)

There is a **persistent Codex TUI** running in a tmux pane, whose context accumulates across rounds. You talk to Codex by sending text to its pane and reading the pane back.

**Placement rule**: when you (Claude) are yourself running inside tmux, split the Codex pane into **your own window's right side** (`split-window -dh`) — the pairing is visible to any human who attaches, and the pane dies with your window instead of leaking. Only when Claude is *not* inside tmux, fall back to a unified collaboration session named **`codex-collab`**: one window per repo checkout (window name = repo basename, cosmetic; the authoritative key is the pane's working directory). Never create per-repo sessions.

Two disciplines for the in-window split: ① always pass `-d` so your own pane stays the active pane; ② address the Codex pane **only by pane ID (`%N`)**, never by name or index.

**This channel does not require Claude itself to be running inside tmux.** `tmux` is a client to a server: `tmux list-panes -a`, `send-keys`, `capture-pane`, `new-window`/`new-session -d` all work from any shell. If the current Claude session is not in tmux, drive the tmux server externally — locate an existing Codex pane, or create one in `codex-collab` (Step 1b). "I'm not inside tmux" is never a reason to fall back to `codex exec`.

### ⛔ Hard rule: never invoke the `codex` CLI directly (unless the user explicitly asks)

**Do NOT run `codex`, `codex exec`, `codex exec review`, `codex exec resume`, or any `codex …` command via your shell tool — unless the user has explicitly requested a direct CLI invocation in the current conversation.** Each `codex exec` is a brand-new process with **zero conversation context** — it forgets everything from prior rounds, so you waste tokens re-briefing and the collaboration fragments. The persistent tmux pane is the *whole point*: it remembers the change set, the prior findings, your fixes, and the design intent across rounds.

"User explicitly asks" means the user names the CLI form themselves (e.g. "run it with codex exec"). A general "have Codex check this" is **not** explicit permission — that goes through the tmux pane.

The only shell commands you may run against Codex are `tmux …` commands (`send-keys`, `capture-pane`, `list-panes`, `new-window`, `new-session`, `split-window`, `load-buffer`/`paste-buffer`, and `kill-pane`/`kill-window` for end-of-session cleanup of a pane/window you launched). Nothing else.

### Step 1 — locate the Codex pane (works inside AND outside tmux)

Resolve it freshly each time (panes can move). **The authoritative match key is the repo path**: a candidate pane counts only if its working directory equals your repo root AND it shows the Codex TUI signature — never grab "any Codex pane somewhere" (that's how a review for repo A lands in repo B's Codex). Search order: ① your own session's panes (covers the human-attended split layout), ② the unified `codex-collab` session, ③ fallback: all panes of all sessions.

Targets are **pane IDs** (`%N`): unique server-wide and immutable for the pane's lifetime, so a stored `$CODEX` never drifts when other windows open/close — this is what makes any number of concurrent agents safe, each talking only to its own pane.

```bash
REPO="$(pwd)"   # repo root (the repo you're working in)
is_codex() { tmux capture-pane -t "$1" -p 2>/dev/null \
  | grep -qiE 'gpt-[0-9]|Context [0-9]+% left|esc to interrupt|Worked for'; }
MYPANE=""; CANDIDATES=""
if [ -n "$TMUX" ]; then
  MYPANE="$(tmux display-message -p '#{pane_id}')"
  CANDIDATES="$(tmux list-panes -s -F '#{pane_id} #{pane_current_path}')"$'\n'
fi
CANDIDATES="$CANDIDATES$(tmux list-panes -st codex-collab -F '#{pane_id} #{pane_current_path}' 2>/dev/null)"$'\n'
CANDIDATES="$CANDIDATES$(tmux list-panes -a -F '#{pane_id} #{pane_current_path}' 2>/dev/null)"
CODEX=""
while read -r t p; do
  [ -z "$t" ] || [ "$t" = "$MYPANE" ] || [ "$p" != "$REPO" ] && continue
  if is_codex "$t"; then CODEX="$t"; break; fi
done <<EOF
$CANDIDATES
EOF
echo "CODEX=$CODEX"
```

`CODEX` is now the pane target (e.g. `%13`). Empty → no Codex pane is running for this repo; go to Step 1b.

### Step 1b — if no Codex pane exists, launch one

Start the Codex TUI in the repo root, explicitly pinning your preferred model and reasoning effort (see "Model & reasoning effort" below); everything else (sandbox, etc.) inherits the user's `~/.codex/config.toml`. Placement rule: **inside tmux → split into your own window's right side; outside tmux → a new window in the unified `codex-collab` session** (created on first use; this also boots the tmux server if none is running):

```bash
REPO="$(pwd)"; WIN="$(basename "$REPO" | tr ' ' '-')"
# Launch via a login shell: tmux exec's commands through a non-login shell, so
# PATH from version managers (volta/nvm/asdf/homebrew) may be missing and a bare
# 'codex …' silently fails → the pane exits instantly. Adjust the shell to the user's.
LAUNCH='zsh -lc "codex -c model_reasoning_effort=high"'
if [ -n "$TMUX" ]; then
  # inside tmux: split into own window; -d keeps your own pane active
  CODEX="$(tmux split-window -dh -t "$(tmux display-message -p '#{pane_id}')" -c "$REPO" -P -F '#{pane_id}' "$LAUNCH")"
else
  # outside tmux: unified collaboration session
  if tmux has-session -t codex-collab 2>/dev/null; then
    CODEX="$(tmux new-window -t codex-collab -n "$WIN" -c "$REPO" -P -F '#{pane_id}' "$LAUNCH")"
  else
    tmux new-session -d -s codex-collab -n "$WIN" -c "$REPO" -x 220 -y 50 "$LAUNCH"
    CODEX="$(tmux list-panes -st codex-collab -F '#{pane_id}' | head -1)"
  fi
fi
echo "CODEX=$CODEX"
```

**End-of-session cleanup**: the Codex pane/window you launched is yours to close when your session wraps up (consensus reached, no further rounds expected) — a pane split into your own window: `tmux kill-pane -t "$CODEX"` (also restores your full width); a window in `codex-collab`: `tmux kill-window -t "$CODEX"` (the session auto-dies with its last window and is recreated on demand). Do NOT kill panes/windows you didn't launch (another session may be mid-loop).

Then **poll until Codex is ready** — its input prompt `›` appears in the capture — before sending the first message (Codex takes a few seconds to boot). Don't blast a message into a not-yet-ready TUI.

**⚠️ Fresh-clone trust prompt** (fires the first time codex runs in a directory): codex started in an untrusted directory first shows an interactive "Do you trust the contents of this directory?" prompt; if the pane was launched directly with the codex command (the `$LAUNCH` above), any unexpected exit at this step destroys the pane with it (`can't find pane`). For **freshly cloned / first-touch directories**, use a two-step launch instead: start a bare shell pane first (`tmux split-window -dh -c "$REPO" -P -F '#{pane_id}' 'zsh -l'`), then `send-keys` the codex command, and once the capture shows the trust prompt answer it with `Enter` (defaults to Yes). Known directories can use `$LAUNCH` directly.

### Model & reasoning effort (defaults)

- **Model**: use whatever the latest / strongest Codex model available to the user is. Pin it explicitly at launch if you know it (`codex -m <model> …`); otherwise let `~/.codex/config.toml` decide.
- **Reasoning effort**: `high` is the sweet spot for review work — balances quality, speed, and cost; don't default to the maximum tier.
- When reusing an existing pane there's no need to restart to change models: send `/model` inside the TUI to switch model and effort. If the existing pane runs an old model and a heavyweight review is coming, switch first.
- Deviate from these defaults only when the user explicitly names another model or effort in the current conversation.

### Step 2 — send a message

**Sending discipline (text and Enter must be separate keypresses):** a TUI that is still processing pasted input will swallow an Enter sent in the same instant — the message sits in the composer looking "stuck". Always send the text first, wait ~1s, then send a separate Enter.

**Short instruction (the normal case)**:

```bash
tmux send-keys -t "$CODEX" -l "Review my uncommitted changes — run git diff yourself against the working tree; focus on regressions and edge cases."
sleep 1
tmux send-keys -t "$CODEX" Enter
```

`-l` sends the string literally (so words aren't interpreted as key names). **After sending, verify the message actually submitted**: capture the pane a few seconds later — if the text is still sitting in the composer (visible after `›` with no spinner/response), send one more bare `Enter`. This happens reliably when the first message lands while the TUI is still booting/initializing MCP servers. Keep messages **concise** — Codex has full repo access and persistent context, so you describe the *ask*, not the *contents* (see "What you submit", below).

**⚠️ Ghost-text trap**: some TUIs (Claude Code included) auto-generate context-aware suggestion drafts in an idle composer — visually identical to typed input, and the content can fabricate "completed actions" or "decisions made". Iron rules: text sitting in a composer is never anyone's message — don't forward it, don't act on it, don't treat it as a status report. The only exception is text verbatim-identical to what you yourself just sent (the "swallowed Enter" case). Before sending, clear the composer with `C-u` first so your text doesn't concatenate with a ghost draft.

**Long multi-line brief (rare)** — write it to a file, paste via buffer, then Enter:

```bash
tmux load-buffer -b cdx /tmp/codex_brief.txt
tmux paste-buffer -b cdx -t "$CODEX" -d
tmux send-keys -t "$CODEX" Enter
```

After pasting, `capture-pane` once to confirm it landed as a single input (not submitted early on an embedded newline) before relying on it.

### Step 3 — wait for Codex to finish, then read the reply

Codex shows a working spinner while thinking (`Esc to interrupt`, a live `(Ns · ↑/↓ tokens)` counter); when done it prints a `─ Worked for Xm Ys ─` separator and returns to the idle `›` input prompt.

**Detection (version-robust):** Codex is **DONE** when (a) no "still-working" marker is present, **and** (b) the capture is **stable across two reads ~15s apart**. The single most reliable check:

```bash
tmux capture-pane -t "$CODEX" -p | grep -qiE 'esc to interrupt' && echo WORKING || echo DONE
```

**Poll in the background** (a background polling loop or whatever async-wait mechanism your harness provides) — never block your own turn on a foreground sleep. Loop the capture until `DONE` + stable, then read the full response from scrollback:

```bash
tmux capture-pane -t "$CODEX" -p -S -300   # include scrollback so long replies aren't truncated
```

Codex tasks normally finish within ~3 minutes. If the spinner never clears past ~5 min, see Recovery.

## When to invoke Codex (proactive triggers)

Invoke Codex *without being asked* when any of the following apply:

| Trigger | Why |
|---|---|
| **Just finished a substantial code change** — multi-file edit, core logic touched, architecture adjustment, anything hard to review by eye | Catch bugs / regressions / mis-applied patterns before they ship |
| **Just produced a detailed execution plan** — before implementation starts | Catch holes, surface better alternatives, while the cost of redoing is still low |
| **Stuck on a tricky problem** — bug that resists diagnosis, design decision where the reasoning feels off | Independent diagnosis from a fresh angle |

Default bias: review one extra time rather than miss a critical issue. But review ≠ rewrite — Codex audits what you delivered, not delivers it for you.

## Collaboration scenarios (predefined)

Pick the scenario, send the matching concise instruction to `$CODEX`, wait, then act on the response. Because the pane has repo access and persistent context, **you do not paste diffs/files Codex can read itself** — you tell it *what to look at and what to scrutinize*.

### A. Review uncommitted changes / a feature branch → run the consensus loop  ⭐ flagship

The most common scenario after you finish a change set. **Do not send the diff.** Tell Codex to review the changes — it will run `git diff` / `git status` / read files on its own. Same flow for branch/PR review (diff vs main, before a PR turns Ready).

> Round 1 message (example): `I just finished a round of changes. Review the uncommitted working-tree diff (run git diff/status yourself). This round's intent: <one sentence>. Deliberate trade-offs: <known-acceptable non-goals — don't re-litigate them>. Focus on correctness, regressions, and edge cases; for UI changes also check UX/IA (all three states present, async feedback, navigation consistency).`

Tip: if you maintain a review-standards skill on the Codex side (severity tiers, output contract, UX/IA checklist), name it in round 1 — don't rely on auto-triggering. Frame it as "reference", not "execute verbatim": Codex has its own review methodology; the skill supplements blind spots and unifies output format.

Then run the **review ⇄ fix consensus loop** (see next section).

### B. Plan / design review (before implementation)

You just wrote an execution plan. Send the plan (or point Codex at the doc/PR description) and ask it to find holes, missing cases, and better alternatives — *forward-looking*. Adopt what holds up before you start building.

### C. Adversarial challenge (a decision you just locked in)

For UI/UX choices, architecture, schema, API contracts, product scope. Frame it as a challenge so Codex attacks rather than agrees:

> `I just locked in this design: <decision + context>. Play the opposition: expose hidden assumptions, show where it breaks under real conditions, propose superior alternatives. Do not agree with me.`

UI/UX iteration almost always wants this pass — easy to fall in love with a layout; the cost of shipping the wrong IA is high.

### D. Bug diagnosis / rescue

A bug resists your diagnosis. Describe the symptom, the suspected area, and what you already ruled out; let Codex inspect the repo and propose a root cause from a fresh angle. You implement the fix.

**Ask for discriminators, not just causes.** Require the output shape `ranked root causes + a verification method / decision point for each`. Static analysis can rank the true root cause low — but a good discriminator (an observable that cleanly splits hypothesis A's causal chain from hypothesis B's) lets live verification converge in one step even when the ranking is wrong.

**Run static + dynamic in parallel.** When the symptom is runtime-visible (unresponsive UI / rendering glitch / event not firing), don't serialize: Codex does the token-heavy static sweep (source + build artifacts + runtime libraries) in its pane while you drive the live reproduction (automation / debugger / log injection) yourself. Feed the runtime evidence back into the same pane for the re-review round — the two channels cross-check each other's blind spots (static analysis can't see "data tree fine but visually invisible"; dynamic alone can't rule out a compile-time mis-binding).

## The review ⇄ fix consensus loop (run until Codex passes)

This is the spine of scenario A (and applies whenever Codex returns findings). **Loop until consensus, with a deadlock cap:**

1. **Codex reviews** → returns findings (defects / regressions / smells), ideally with a verdict.
2. **You read the findings → fix immediately.** Don't summarize-and-wait, don't ask permission — the user invoked the review, the fix is the assumed next step. Fix in priority order (bugs > guard holes > architectural smells > nits). **You** apply every edit; Codex never touches the tree.
3. **You run the compile/build/test gate yourself** (Codex doesn't — see below) so the next round reviews working code.
4. **Send Codex a re-review request:** `Fixed per your findings: <what changed, item by item>. Please re-review — anything remaining or newly introduced?` Codex re-inspects (it remembers the prior round — that's the tmux advantage). For bug fixes, piggyback two extra asks on this round — cheap for Codex, high-value: `1) any known side effects / applicability limits of this fix; 2) sweep the whole repo for other instances of the same anti-pattern`. A pattern that broke once usually exists elsewhere; Codex's quota makes the exhaustive sweep free.
5. **Repeat 1–4 until Codex explicitly passes** — a verdict like `pass / clean / no issues / looks good`. That's the stop condition.

**Termination & deadlock cap:**
- **Pass = done.** When Codex's latest verdict is a clean pass, stop the loop and report.
- **Cap at 5 rounds.** If you've completed ~5 review⇄fix rounds without convergence, **stop and surface to the user** with the current state (what's still contested, your read) rather than looping forever.
- **You disagree with a finding?** If you judge a finding a false positive or a deliberate, already-accepted scope choice, **don't blindly "fix" it** — push back in your next message to Codex (`this one is a deliberate trade-off because …, not changing it`) and update the scope note so it stops re-flagging. If Codex still insists and it's genuinely a product/scope call, escalate to the user; don't ping-pong indefinitely.
- **Treat Codex as advisory, not authoritative.** Its verdict is one strong signal; final engineering judgment is yours. You apply that judgment by deciding *which* findings to fix — not *whether* to start fixing.

### Stance discipline: Codex is stubborn, but you don't have to yield

Codex's delivery style is more confident than its actual certainty, and it **tends to stand by its original verdict in later rounds** — re-asserting costs it nothing and its tone never softens. That is not evidence it's right; it's just style. The real failure mode this guards against: your original choice was sound, but after Codex insisted for a few rounds you drifted into the inferior alternative.

Handle findings in two tiers:

- **Objectively decidable findings** (bugs, regressions, boundary holes, data safety): fix when there's evidence; when there isn't, demand a verifiable failure scenario from Codex — this tier is settled by facts, and "standing one's ground" doesn't apply.
- **Judgment/direction findings** (architectural leaning, abstraction level, module boundaries, naming and organization, approach trade-offs): **Codex's preference is not an obligation.** If your choice has clear reasons and works, reply and hold (`keeping my original approach here: the reason is …. Unless you can point to a concrete failure/cost it causes, not changing`), and log it in the scope note. When Codex re-insists without new arguments, treat it as a **recorded disagreement — that still counts as converged**: the loop's pass criterion is objective defects reaching zero, not Codex nodding at every design choice.
- One-line test: **change because you were persuaded; hold because you have reasons — never either one because the other side was more insistent.** If after re-reading a finding you still think "that scenario won't happen / that cost is accepted", hold, and bring the disagreement to the user for adjudication rather than caving to make the loop converge.

Anti-pattern (do **not** do this):

> "Codex flagged N issues: [list]. Should I start fixing?" ← **WRONG.** Stopping to ask forces a "yes, go" every round. Start fixing; report when the round is done.

## What you submit to Codex

The pane has persistent context *and* repo access, so briefs are **light** — point and scope, don't paste. Include:

1. **The ask** — review uncommitted / review this plan / challenge this decision / diagnose this bug (one sentence).
2. **One-line intent** — what this change/decision is trying to achieve.
3. **Deliberate non-goals / known-acceptable debt** — so Codex respects them instead of re-litigating.
4. **What to scrutinize** — concrete focus (regressions? a specific edge case? a security surface?), not "anything wrong?".

What you do **not** put in the message: the diff itself, full file contents, anything Codex can pull with `git diff`/`rg`/file reads. Let it fetch. (Exception: a decision that lives only in your head / a discussion with no diff anchor — then paste that context, since Codex can't read your mind.)

## Codex is the reviewer; you are the doer

- ❌ Don't ask Codex to implement, refactor, or write the fix — it reviews; you write.
- ❌ Don't act as if Codex edited files — it didn't; the tree only changes when **you** edit it.
- ✅ Codex running `git diff` / `rg` / reading files to *inspect* is correct and expected — that's reviewing, not doing.

## Compile / build / test validation stays with you

Codex's sandbox can't reliably write to user-level cache dirs (`~/Library/Caches`, `~/.cache`), so platform build tools (`xcodebuild`, SwiftPM, …) fail spuriously, and its tool calls are timeout-bounded. **You** run the build / typecheck / tests. Don't ask Codex to "verify the build" — give it the change to review for correctness; you own the actual compile/test gate, and you run it between loop rounds so Codex always re-reviews working code.

## Recovery — when the channel misbehaves

| Symptom | Action |
|---|---|
| **No Codex pane found** (`CODEX` empty) | Launch one (Step 1b), wait for the `›` ready prompt, then send. |
| **Codex pane unresponsive / spinner never clears past ~5 min** (rabbit-holed) | Send an interrupt: `tmux send-keys -t "$CODEX" Escape`, then re-send a tighter prompt ("working-tree diff only + these named files, no web search"). |
| **Reply truncated when read** | Re-capture with more scrollback: `tmux capture-pane -t "$CODEX" -p -S -500` (or `-S -`). |
| **Message landed garbled / submitted early** | You likely sent multi-line text without buffering. Re-send via `load-buffer`/`paste-buffer`, confirm with one capture, then Enter. |
| **Codex says it lost context / `Context 0% left`** | The persistent session is exhausted. Tell the user to `/clear` or restart the Codex pane (or relaunch it via Step 1b), then re-brief the current ask once. |

Auto-retry transient issues once or twice with a tighter prompt — don't ask permission. If a third attempt still fails, surface to the user with the evidence (last capture tail).

## Quick reference

```
Trigger detected (finished substantial change / wrote a plan / stuck on a bug / locked a design)
   ↓
Locate $CODEX via tmux — works even if Claude is NOT inside tmux
   (match key = repo path + TUI signature; search own session → codex-collab → all panes;
    absent → inside tmux: split-window -dh into own window (right side, -d keeps
    own pane active); outside tmux: new-window in unified `codex-collab` session;
    wrap-up: kill-pane the split pane you launched / kill-window the codex-collab window)
   ↓
Pick scenario:
   · review uncommitted / branch → "review the changes, run git diff yourself"  (DON'T paste the diff)
   · plan review        → send the plan, ask for holes/alternatives
   · adversarial        → "I locked in X, play the opposition, don't agree"
   · bug rescue         → symptom + ruled-out, ask for ranked causes + discriminators
   ↓
tmux send-keys -t "$CODEX" -l "<concise ask + intent + non-goals + focus>" ; sleep 1 ; send-keys … Enter
   ↓
Poll capture-pane in the background (NEVER foreground sleep) until 'esc to interrupt' gone + stable
   ↓
Read reply (capture-pane -p -S -300) → IMMEDIATELY fix findings yourself (don't pause to ask)
   ↓
Run the build/test gate yourself → send "fixed <item by item>, please re-review" → Codex re-reviews
   ↓
Loop until Codex passes (clean verdict).  Cap ~5 rounds → else surface to user.
   · judgment-tier disagreements (architecture/trade-offs): hold with reasons, record, still converged —
     don't get dragged by Codex's insistence
   ↓
NEVER: run `codex`/`codex exec*` via shell (sole exception: user explicitly names codex exec)
       · ask Codex to write code · let Codex run the build gate · use "not inside tmux" as a CLI excuse
```
