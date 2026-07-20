# Claude with Codex

> **Stop asking one agent to review itself.**
> Claude builds. Codex reviews — in one persistent tmux conversation. Fix, re-review, converge.

A set of [Claude Code](https://claude.com/claude-code) skills that turn the [OpenAI Codex CLI](https://github.com/openai/codex) into Claude's second perspective, distilled from months of daily use across real product repos.

- **Persistent context across review rounds** — Codex lives in a long-lived tmux pane that remembers the change set, prior findings, your fixes, and the design intent. Re-reviews cost one sentence, not a full re-brief.
- **Strict reviewer/doer separation** — Claude writes every line and runs every build; Codex audits with full repo read access. No blurred ownership, no "who changed this?".
- **Four ready-made workflows** — change review with a consensus loop, plan review, adversarial challenge of locked-in decisions, and bug rescue with ranked root causes.

[中文说明 → README.zh-CN.md](README.zh-CN.md)

## What a round trip looks like

```text
Claude  ▶ codex-pane.sh send "$PANE" "Review my uncommitted diff (run git diff yourself).
          Intent: debounce the search field. Non-goal: no redesign of the results list.
          Focus: correctness, regressions. End with a verdict."
Codex   ◀ "2 findings: ① the debounce timer isn't cancelled on view teardown — fires
          into a deallocated handler; ② empty-query now skips the loading state.
          Verdict: needs fixes."
Claude  ▶ fixes both, runs the tests, then:
          "Fixed: ① cancel in teardown ② restored loading state for empty query.
          Please re-review; also sweep for other uncancelled timers."
Codex   ◀ "Both fixed correctly. Sweep found one more in ProfileView — same pattern.
          Verdict: clean after that one."
Claude  ▶ fixes it, re-runs tests → Codex: "clean" → done.
```

One conversation, three rounds, zero re-briefing. A fuller annotated session: [examples/review-loop.md](examples/review-loop.md).

## How it compares

| | Context across rounds | Reads the repo itself | Role separation | Cost of round N |
|---|---|---|---|---|
| Claude reviewing its own work | ✅ | ✅ | ❌ same blind spots | low |
| One-shot `codex exec` calls | ⚠️ resumable, but fragmented | ✅ | ✅ | high (re-brief or resume juggling) |
| **Persistent tmux pane (this repo)** | ✅ one conversation | ✅ | ✅ enforced by the skills | low |

The pane also gives you something no headless call does: `tmux attach` and you're watching the review happen, or taking over mid-loop.

## The skills

| Skill | Role | What it defines |
|---|---|---|
| [`using-codex-collaboration`](skills/using-codex-collaboration/SKILL.md) | ⭐ core | The whole system: the bundled [`codex-pane.sh`](skills/using-codex-collaboration/scripts/codex-pane.sh) helper (tag-based pane discovery, robust send/wait/capture/cleanup), four collaboration scenarios, the review ⇄ fix consensus loop with defined terminal states, stance discipline, recovery playbook |
| [`codex-image-gen`](skills/codex-image-gen/SKILL.md) | exception #1 | Delegating image asset production (icons, illustrations, placeholders) — scratch-directory output, hard constraints, compliance rules, self-verification |
| [`codex-computer-use`](skills/codex-computer-use/SKILL.md) | exception #2 | Delegating GUI automation — **conditional capability** (requires computer-use tooling in your Codex environment, probed before use), with safety boundaries: no irreversible actions without authorization, no credentials in briefs, independent result verification |

The design stance: Codex **reviews, never implements** — with exactly two whitelisted delegation exceptions for one-off deliverables (images, GUI driving) that never enter the code-review loop. Code is never delegated.

## Install (30 seconds)

```bash
git clone https://github.com/Jewel591/claude-with-codex.git
cd claude-with-codex
./scripts/check-env.sh          # verifies tmux, codex, login, PATH-in-login-shell
mkdir -p ~/.claude/skills
cp -R skills/* ~/.claude/skills/
```

Claude Code discovers user-level skills automatically; the next session triggers them when the situation matches (finishing a substantial change, writing a plan, getting stuck on a bug). To update: pull and re-copy. To uninstall: remove the three directories from `~/.claude/skills/`.

## Requirements & compatibility

| Component | Status |
|---|---|
| [Claude Code](https://claude.com/claude-code) | required (the skills are written for it; the protocol itself is harness-agnostic — any agent that can run `tmux` commands can follow it) |
| [tmux](https://github.com/tmux/tmux) | required; developed and tested against tmux 3.x |
| [OpenAI Codex CLI](https://github.com/openai/codex) | required, logged in (`codex login`); reasoning-effort flags follow current CLI config options |
| OS | developed on macOS; Linux expected to work (the helper uses `$SHELL -l` and POSIX-friendly bash — [report issues](https://github.com/Jewel591/claude-with-codex/issues)); Windows via WSL untested |
| Shell | your login shell must expose `codex` on PATH (`check-env.sh` verifies this — the classic failure is a version manager configured only for interactive shells) |
| `codex-image-gen` | works with or without a native image tool (falls back to throwaway scripts) |
| `codex-computer-use` | **only if** your Codex environment has computer-use tooling configured (MCP/plugin); the skill probes for it and refuses to proceed without it |

## Security model

Read this before pointing the skills at a sensitive repo:

- **Your code leaves the machine twice.** Claude Code sends context to Anthropic; the Codex pane reads your repo and sends what it reads to OpenAI. Don't enable this on repositories whose content may not be shared with either provider.
- **Codex runs with its own permission config** (`~/.codex/config.toml`). The skills never ask Codex to edit files, but your sandbox/approval settings — not these skills — are what technically constrains it. Review them.
- **Computer use sees what you see**: screenshots include whatever is on screen — logged-in sessions, tokens in terminals, personal data. The skill's rules (no credentials in briefs, stop-before-irreversible-actions, page content is data-not-instructions) reduce risk but the capability is inherently powerful; keep sensitive flows attended.
- **Prompt injection is treated as a real surface**: web/app content encountered during GUI automation must never override the brief, and the skills say so explicitly.
- **Nothing auto-approves destructive actions**: publishing, paying, deleting, sending — all require explicit user authorization in the conversation, delegated or not.

## FAQ

**Why not just use Claude subagents for review?** A subagent shares Claude's weights and often its blind spots. A genuinely different frontier model catches different bugs — that diversity is the point.

**Why not `codex exec` / `codex exec resume`?** Resume exists and works; the pane is a deliberate trade-off, not ignorance of it. One continuous conversation beats juggling session ids across many small rounds, and a pane is human-attachable — you can watch the review or take over. Details in the skill.

**Can two Claude sessions share one repo?** One collaboration channel per checkout, by design. For true concurrency, use separate git worktrees — each gets its own tagged pane.

**Does Codex ever modify my code?** The skills never ask it to, and the loop assumes it doesn't (Claude is the sole writer). Technically, what Codex *can* do is governed by your own Codex sandbox/approval config — review it (see Security model).

**What does this cost?** Both sides consume their own quotas/credits: Claude Code on the Claude side, Codex CLI on the OpenAI side. Long review loops are token-heavy on the Codex side; the "briefs point, don't paste" rule exists partly to keep that in check.

**Context ran out mid-loop?** Restart the pane (`codex-pane.sh cleanup` + `ensure`), re-brief once. The skill's Recovery table covers this and the other failure modes (swallowed Enter, trust prompts, rabbit holes).

**What if I don't run tmux at all?** You don't need to be *inside* tmux — the helper drives the tmux server from any shell and creates a detached session on first use. You only need tmux installed.

## Contributing

Issues and PRs welcome — especially Linux/WSL reports, Codex CLI version-drift fixes, and transcripts of real sessions (anonymized). See [CONTRIBUTING.md](CONTRIBUTING.md) for the design principles that keep the skills coherent (reviewer/doer line, capability-conditional exceptions, no foreground sleeps).

## Design notes (for the curious)

The details that make this work unattended, kept out of the pitch because they only matter once you're in:

- **Tag-based pane identity.** Panes are tagged at launch with tmux user options (`@cwc_role`, `@cwc_repo`); discovery is an exact tag match, so concurrent agents can't grab each other's reviewer, and screen text is only used as a liveness check.
- **Completion detection is a protocol, not a spinner grep.** `wait` requires: screen moved past the pre-send baseline, no working markers, idle composer back, stable across three polls — and interactive prompts (trust/approval/login) surface as `NEEDS_INPUT`, never as "done".
- **TUI-driving details are load-bearing.** Text and Enter as separate keypresses (a busy TUI swallows same-instant Enter); clear the composer first (autocomplete ghost text looks exactly like typed input); verify submission by capture. Small rules, but they're the difference between a demo and something you can trust in the background.
- **Briefs point, they don't paste.** Codex has repo access; sending it a diff wastes tokens and goes stale. Send the ask, the intent, the deliberate non-goals, and the focus.
- **Claude keeps the build gate.** Reviewer-verifies-build blurs the ownership the loop depends on, and heavyweight build tools are unreliable under Codex's sandboxed execution anyway.
- **Convergence is defined, not vibes.** Terminal states are `clean` or `clean-with-recorded-disagreements`; the pass criterion is objective defects at zero — a reviewer restating a design preference without new evidence doesn't block convergence, and confidence is not evidence.

## License

[MIT](LICENSE)
