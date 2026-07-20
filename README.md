# claude-with-codex

**Claude leads, Codex assists.** A set of battle-tested [Claude Code](https://claude.com/claude-code) skills that turn the OpenAI Codex CLI into Claude's second perspective — a persistent reviewer, adversarial challenger, and (in two narrow, whitelisted cases) a delegate — all driven through a long-lived tmux pane whose context accumulates across rounds.

[中文说明 → README.zh-CN.md](README.zh-CN.md)

## The idea

Two frontier coding agents are better than one — **if** the division of labor is explicit:

- **Claude is the primary engineer.** It writes every line, runs every build, owns every decision.
- **Codex is the second perspective.** It reviews plans and diffs, challenges locked-in decisions, and diagnoses stubborn bugs from a fresh angle — with full read access to the repo.
- The channel is a **persistent Codex TUI in a tmux pane**, not one-shot `codex exec` calls. Persistence is the whole point: Codex remembers the change set, prior findings, your fixes, and the design intent across review rounds, so re-reviews are cheap and briefs stay light.
- Reviews run as a **review ⇄ fix consensus loop**: Codex flags, Claude fixes immediately, Codex re-reviews — until a clean verdict (capped at ~5 rounds, with an explicit protocol for holding your ground on judgment-tier disagreements).

Two carefully-scoped exceptions where Codex *does* execute instead of review: **image asset generation** and **computer use (GUI automation)** — one-off deliverables that never enter the code-review loop. Code is never delegated.

## The skills

| Skill | Role | What it defines |
|---|---|---|
| [`using-codex-collaboration`](skills/using-codex-collaboration/SKILL.md) | ⭐ core | The whole system: tmux channel setup & pane discovery, send/wait/read mechanics, four collaboration scenarios (change review, plan review, adversarial challenge, bug rescue), the consensus loop, stance discipline, recovery playbook |
| [`codex-image-gen`](skills/codex-image-gen/SKILL.md) | exception #1 | Delegating image asset production (icons, illustrations, placeholders) with hard constraints, compliance rules, and self-verification |
| [`codex-computer-use`](skills/codex-computer-use/SKILL.md) | exception #2 | Delegating GUI automation (desktop apps, browser UI, system panels) with safety boundaries: no irreversible actions without authorization, no credentials in briefs, independent result verification |

## Requirements

- [Claude Code](https://claude.com/claude-code) (the skills are written for it, but the protocol is harness-agnostic — any agent that can run `tmux` commands can follow it)
- [tmux](https://github.com/tmux/tmux)
- [OpenAI Codex CLI](https://github.com/openai/codex), logged in (`codex login`)

Check everything at once:

```bash
./scripts/check-env.sh
```

## Install

Copy (or symlink) the skill directories into your user-level skills directory:

```bash
git clone https://github.com/Jewel591/claude-with-codex.git
cd claude-with-codex
cp -R skills/* ~/.claude/skills/
```

That's it. Claude Code discovers user-level skills automatically; the next session will trigger them when the situation matches (finishing a substantial change, writing a plan, getting stuck on a bug, needing an image or a GUI driven).

To update, pull and re-copy. To uninstall, remove the three directories from `~/.claude/skills/`.

## Design notes (why it works this way)

- **tmux pane, never `codex exec`.** Each `codex exec` is a fresh process with zero memory — you pay full re-briefing cost every round and the collaboration fragments. The pane keeps one continuous conversation per repo.
- **Pane discovery is keyed on the repo path**, addressed by immutable pane IDs (`%N`) — so multiple concurrent Claude sessions each talk only to their own Codex, and a review for repo A can never land in repo B's pane.
- **Briefs point, they don't paste.** Codex has repo access; sending it a diff wastes tokens and goes stale. Send the ask, the intent, the deliberate non-goals, and the focus.
- **Claude keeps the build gate.** Codex's sandbox makes platform build tools fail spuriously, and delegating verification blurs ownership. Claude compiles/tests between rounds so Codex always re-reviews working code.
- **Stance discipline is written down.** Codex sounds more confident than it is and rarely softens across rounds. The loop's pass criterion is *objective defects at zero* — not Codex approving every design choice. Recorded disagreements count as converged.
- **The TUI-driving details are load-bearing.** Text and Enter as separate keypresses (a busy TUI swallows same-instant Enter), clearing the composer before sending (autocomplete ghost text can fabricate messages), polling `capture-pane` for the idle prompt instead of sleeping blind. These small rules are the difference between "works in a demo" and "works unattended".

## License

[MIT](LICENSE)
