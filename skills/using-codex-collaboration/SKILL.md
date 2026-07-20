---
name: using-codex-collaboration
description: Use proactively whenever the work involves substantial code changes (multi-file, core logic, architecture), a freshly written execution plan, a sticky bug that resists single-perspective diagnosis, or a non-obvious design decision that needs adversarial challenge — establishes when and how to bring Codex in as a reviewer (not as an executor). The ONLY channel is the persistent Codex pane reached via tmux — this holds even when Claude's own session is NOT running inside tmux (drive the tmux server externally). Direct `codex` CLI invocation (codex exec etc.) is FORBIDDEN unless the user explicitly requests it. Covers the bundled codex-pane.sh helper (find-or-launch, send, wait, capture, cleanup), the predefined collaboration scenarios (change review, plan review, adversarial challenge, bug rescue), and the review⇄fix consensus loop that runs until a clean verdict.
---

# Using Codex Collaboration

## Why this skill exists

Codex is a **second perspective** — a reviewer that catches what the primary engineer missed. It is **not** a task-outsourcing endpoint.

Hard line:

- ✅ Codex does: plan review, code review, architecture review, independent bug diagnosis, sanity-checking design decisions. To do these it freely runs its own read tools (`git diff`, `git status`, `rg`, file reads) — that is expected and encouraged.
- ❌ Codex does **not**: implement features, write new code, run the build/tests as a gate, finish work the primary engineer should finish.

Treating "use Codex" as "outsource the task" is a misread, even if the task is large or cross-file. **The primary engineer (you, Claude) finishes the work; Codex audits it.** This is a *behavioral* guarantee, enforced by your discipline — you are the sole writer to the working tree. Never ask Codex to edit/implement, and never proceed on the assumption that Codex changed files. After every Codex round, *you* make the edits.

(Two narrow, whitelisted exceptions exist as sibling skills: `codex-image-gen` for producing image assets and `codex-computer-use` for GUI automation. Both cover one-off deliverables that never enter the code-review loop, and both have extra capability prerequisites — see their own files. Code work is never delegated.)

## The collaboration channel — the tmux Codex pane (ONLY entry point)

There is a **persistent Codex TUI** running in a tmux pane, whose context accumulates across rounds. You talk to Codex by sending text to its pane and reading the pane back.

Why a persistent pane instead of one-shot CLI calls? Newer Codex CLI versions do support resuming non-interactive sessions (`codex exec resume`), so this is a deliberate trade-off, not a hard limitation — the pane wins on three fronts that matter for collaboration: **one continuous, human-attachable conversation** (anyone can `tmux attach` and watch or take over mid-loop), **zero re-briefing friction across many small rounds**, and **a single accumulating context** holding the change set, prior findings, your fixes, and the design intent. Fragmenting that across CLI invocations costs tokens and loses the thread.

### ⛔ Hard rule: never invoke the `codex` CLI directly (unless the user explicitly asks)

**Do NOT run `codex`, `codex exec`, `codex exec review`, `codex exec resume`, or any `codex …` command via your shell tool — unless the user has explicitly requested a direct CLI invocation in the current conversation.** "User explicitly asks" means the user names the CLI form themselves (e.g. "run it with codex exec"). A general "have Codex check this" is **not** explicit permission — that goes through the tmux pane.

The only shell commands you may run against Codex are the bundled `scripts/codex-pane.sh` helper and raw `tmux …` commands. Nothing else. "I'm not inside tmux" is never a reason to fall back to the CLI — tmux is a client/server system; every command here works from any shell against the tmux server, whether or not you are inside tmux yourself.

## Driving the pane — use the bundled helper

`scripts/codex-pane.sh` (in this skill's directory) is the canonical way to manage the pane. It solves four problems that hand-rolled tmux one-liners get wrong: **identity** (panes are tagged with tmux user options `@cwc_role`/`@cwc_repo` at launch, so discovery is an exact tag match — screen-text matching is only a liveness check, and a review for repo A can never land in repo B's pane), **statelessness** (every invocation re-derives the pane from tags — nothing depends on a `$CODEX` variable surviving across your separate shell calls), **launch fragility** (login-shell launch so version-manager PATHs work; two-step launch so the first-run trust prompt can't destroy the pane; auto-accepts that trust prompt), and **completion detection** (see `wait` below).

```bash
SKILL_DIR=<this skill's directory>   # you know it when the skill loads

# 1. Find-or-launch the pane for the current repo (prints the pane id, e.g. %13).
#    Placement: inside tmux → split into your own window (right side, non-active);
#    outside tmux → a window in the shared `codex-collab` session.
PANE=$("$SKILL_DIR/scripts/codex-pane.sh" ensure)            # optional: --repo DIR --model M --effort E

# 2. Send a message (clears ghost text, sends text and Enter separately,
#    verifies submission, re-sends a swallowed Enter once).
"$SKILL_DIR/scripts/codex-pane.sh" send "$PANE" "Review my uncommitted changes — run git diff yourself. Focus on regressions and edge cases."

# 3. Wait for the reply. Run this in the BACKGROUND (background shell / async task),
#    never as a foreground block of your own turn.
"$SKILL_DIR/scripts/codex-pane.sh" wait "$PANE" --timeout 600
#    exit 0 DONE → read the reply     exit 2 NEEDS_INPUT → look at the pane: Codex is
#    showing an interactive prompt (trust/approval/login) that needs a decision
#    exit 3 TIMEOUT → see Recovery

# 4. Read the reply, including scrollback.
"$SKILL_DIR/scripts/codex-pane.sh" capture "$PANE" --lines 400

# 5. End of session (consensus reached, no more rounds expected): close the pane
#    you launched. Refuses to kill panes it didn't create.
"$SKILL_DIR/scripts/codex-pane.sh" cleanup "$PANE"
```

What `wait` actually checks — this matters, because naive "spinner gone = done" fires early on boot screens and half-typed composers: the screen must have **moved past the pre-send baseline**, show **no working markers**, be back at the **idle composer**, and hold **stable across three consecutive polls**; interactive prompts (trust / approval / login) are reported as `NEEDS_INPUT`, never as done. If you must fall back to raw tmux (helper unavailable), replicate that whole contract, not just the spinner grep — and poll from a background task, never a foreground sleep.

**Sending discipline** (the helper implements this; keep it if hand-rolling): a TUI still processing pasted input swallows an Enter sent in the same instant, and an idle composer may hold autocomplete "ghost text" that looks exactly like typed input — never treat composer contents as anyone's message. So: clear with `C-u`, send text literally (`-l`), wait ~1s, send Enter separately, then capture to verify submission.

**Model/effort defaults**: `ensure` launches with `model_reasoning_effort=high` (a good review-work balance — don't default to the maximum tier) and the user's configured default model; pass `--model` to pin one, or send `/model` inside the TUI to switch a live pane. Deviate only when the user names a model/effort explicitly.

**Concurrency limitation (by design)**: one collaboration channel per repo checkout. If you need two agents working the same repo concurrently, give them separate git worktrees — don't share a pane, and don't spawn two panes for one checkout.

**Cleanup discipline**: close what you launched when your session wraps up; never kill panes/windows you didn't create (another session may be mid-loop; the helper's tag check enforces this).

## When to invoke Codex (proactive triggers)

Invoke Codex *without being asked* when any of the following apply:

| Trigger | Why |
|---|---|
| **Just finished a substantial code change** — multi-file edit, core logic touched, architecture adjustment, anything hard to review by eye | Catch bugs / regressions / mis-applied patterns before they ship |
| **Just produced a detailed execution plan** — before implementation starts | Catch holes, surface better alternatives, while the cost of redoing is still low |
| **Stuck on a tricky problem** — bug that resists diagnosis, design decision where the reasoning feels off | Independent diagnosis from a fresh angle |

Default bias: review one extra time rather than miss a critical issue. But review ≠ rewrite — Codex audits what you delivered, not delivers it for you.

## Collaboration scenarios (predefined)

Pick the scenario, send the matching concise instruction, wait, then act on the response. Because the pane has repo access and persistent context, **you do not paste diffs/files Codex can read itself** — you tell it *what to look at and what to scrutinize*.

### A. Review uncommitted changes / a feature branch → run the consensus loop  ⭐ flagship

The most common scenario after you finish a change set. **Do not send the diff.** Tell Codex to review the changes — it will run `git diff` / `git status` / read files on its own. Same flow for branch/PR review (diff vs main, before a PR turns Ready).

> Round 1 message (example): `I just finished a round of changes. Review the uncommitted working-tree diff (run git diff/status yourself). This round's intent: <one sentence>. Deliberate trade-offs: <known-acceptable non-goals — don't re-litigate them>. Focus on correctness, regressions, and edge cases; for UI changes also check UX/IA (all states present, async feedback, navigation consistency). End with a verdict.`

Tip: if you maintain a review-standards skill on the Codex side (severity tiers, output contract, UX/IA checklist), name it in round 1 — don't rely on auto-triggering. Frame it as "reference", not "execute verbatim".

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

**Run static + dynamic in parallel.** When the symptom is runtime-visible (unresponsive UI / rendering glitch / event not firing), don't serialize: Codex does the token-heavy static sweep in its pane while you drive the live reproduction (automation / debugger / log injection) yourself. Feed the runtime evidence back into the same pane for the re-review round — the two channels cross-check each other's blind spots.

## The review ⇄ fix consensus loop (run until it converges)

This is the spine of scenario A (and applies whenever Codex returns findings).

1. **Codex reviews** → returns findings (defects / regressions / smells), ideally with a verdict.
2. **You read the findings → fix immediately.** Don't summarize-and-wait, don't ask permission — the user invoked the review, the fix is the assumed next step. Fix in priority order (bugs > guard holes > architectural smells > nits). **You** apply every edit; Codex never touches the tree.
3. **You run the compile/build/test gate yourself** (see below) so the next round reviews working code.
4. **Send a re-review request:** `Fixed per your findings: <what changed, item by item>. Held: <findings you're not fixing, each with its reason>. Please re-review — anything remaining or newly introduced?` For bug fixes, piggyback two extra asks — low-cost for a reviewer already deep in this context, high-value for you: `1) any known side effects / applicability limits of this fix; 2) sweep the repo for other instances of the same anti-pattern` (a pattern that broke once usually exists elsewhere).
5. **Repeat 1–4 until the loop reaches a terminal state.**

**Terminal states — there are exactly two, plus one escalation:**

- **`clean`** — Codex's latest verdict is a pass with nothing outstanding. Done.
- **`clean-with-recorded-disagreements`** — every *objective* finding (bug, regression, boundary hole, data safety) is fixed or refuted with evidence, and the only open items are *judgment-tier* findings (architecture leaning, abstraction level, naming, approach trade-offs) that you have explicitly held with stated reasons and Codex has re-flagged without new arguments. That **counts as converged** — the loop's pass criterion is objective defects at zero, not the reviewer endorsing every design choice. Record the disagreements in your report.
- **Escalate to the user** only when something is genuinely theirs to decide: a contested finding that is a product/scope call rather than an engineering call, or ~5 completed rounds without convergence on objective findings. Escalation is not a terminal state — it's handing the specific open question to its owner, with your read attached.

**Handling findings you disagree with** — don't blindly "fix" a false positive or re-litigate a deliberate scope choice. Push back in the next message (`this one is a deliberate trade-off because …, not changing it`) and keep it listed under "Held" so the reviewer stops re-flagging blind. Treat the reviewer as advisory, not authoritative: its verdict is one strong signal; final engineering judgment is yours — you apply that judgment by deciding *which* findings to fix, not *whether* to start fixing.

### Stance discipline: confidence is not evidence

A reviewer's delivery style is often more confident than its actual certainty, and judgment-tier findings tend to get restated across rounds with undiminished conviction and no new arguments. Repetition is not evidence. The failure mode this guards against: your original choice was sound, but after a few rounds of insistence you drift into the inferior alternative just to make the loop converge.

Two tiers, two rules:

- **Objectively decidable findings**: fix when there's evidence; when there isn't, demand a verifiable failure scenario. Facts settle this tier — "standing one's ground" doesn't apply.
- **Judgment/direction findings**: the reviewer's preference is not an obligation. If your choice has clear reasons and works, reply and hold (`keeping my original approach: <reason>. Unless you can point to a concrete failure or cost it causes, not changing`), and record it. One-line test: **change because you were persuaded; hold because you have reasons — never either one because the other side was more insistent.**

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

Keep the build/typecheck/test gate on your side of the line, for two reasons. Practically, Codex's sandboxed, timeout-bounded execution makes heavyweight platform build tools (Xcode, SwiftPM, large bundlers) unreliable in its environment — failures there are often sandbox artifacts, not code defects. Structurally, "reviewer also verifies the build" blurs the ownership the whole system depends on. Don't ask Codex to "verify the build" — give it the change to review for correctness; you run the actual gate between loop rounds so Codex always re-reviews working code.

## Recovery — when the channel misbehaves

| Symptom | Action |
|---|---|
| **`ensure` fails / pane won't boot** | Check `codex` runs in a login shell (`$SHELL -lc 'codex --version'`); run the repo's `check-env.sh`. |
| **`wait` returns `NEEDS_INPUT`** | Capture the pane and look: trust prompt → Enter accepts; approval/login prompts → decide or surface to the user. Never treat these as completion. |
| **`wait` times out / spinner never clears** (rabbit-holed) | Send an interrupt: `tmux send-keys -t "$PANE" Escape`, then re-send a tighter prompt ("working-tree diff only + these named files, no web search"). |
| **Reply truncated when read** | Re-capture with more scrollback: `capture "$PANE" --lines 800`. |
| **Message landed garbled / submitted early** | Multi-line text sent unbuffered. Write the brief to a file, `tmux load-buffer -b cdx <file>; tmux paste-buffer -b cdx -t "$PANE" -d`, confirm with one capture, then Enter. |
| **Codex says it lost context / `Context 0% left`** | The persistent session is exhausted. Restart the pane (`cleanup` + `ensure`), then re-brief the current ask once. |

Auto-retry transient issues once or twice with a tighter prompt — don't ask permission. If a third attempt still fails, surface to the user with the evidence (last capture tail).

## Quick reference

```
Trigger detected (finished substantial change / wrote a plan / stuck on a bug / locked a design)
   ↓
PANE=$(codex-pane.sh ensure)        # tag-based find-or-launch; works inside OR outside tmux
   ↓
Pick scenario:
   · review uncommitted / branch → "review the changes, run git diff yourself" (DON'T paste the diff)
   · plan review        → send the plan, ask for holes/alternatives
   · adversarial        → "I locked in X, play the opposition, don't agree"
   · bug rescue         → symptom + ruled-out, ask for ranked causes + discriminators
   ↓
codex-pane.sh send "$PANE" "<concise ask + intent + non-goals + focus>"
   ↓
codex-pane.sh wait "$PANE"          # in the background; DONE / NEEDS_INPUT / TIMEOUT
   ↓
codex-pane.sh capture "$PANE" → IMMEDIATELY fix findings yourself (don't pause to ask)
   ↓
Run the build/test gate yourself → send "fixed <items>; held <items + reasons>" → re-review
   ↓
Loop to a terminal state: clean · clean-with-recorded-disagreements
   (escalate to the user only for product/scope calls or ~5 rounds without convergence)
   ↓
codex-pane.sh cleanup "$PANE"       # close what you launched; never what you didn't
   ↓
NEVER: run `codex`/`codex exec*` directly (sole exception: user explicitly names it)
       · ask Codex to write code · let Codex run the build gate · foreground-sleep while waiting
```
