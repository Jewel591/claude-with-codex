# Contributing

Issues and PRs are welcome. The most valuable contributions right now:

- **Linux / WSL reports** — the helper aims to be portable (`$SHELL -l`, POSIX-friendly bash) but is developed on macOS; environment reports with `check-env.sh` output attached are gold.
- **Codex CLI version drift** — TUI markers (`esc to interrupt`, `Worked for`, the `›` composer) and config flags change across releases; fixes with the version number cited are easy to merge.
- **Anonymized real transcripts** — a good `examples/` session showing a workflow (especially plan review, adversarial challenge, or bug rescue — change review already has one) teaches more than a page of instructions.

## Design principles (PRs should preserve these)

1. **Reviewer/doer separation is the product.** Codex reviews; the primary agent writes every edit and runs the build/test gate. Any change that lets the reviewer modify the working tree or own verification breaks the core contract — that's a redesign discussion, not a PR.
2. **Delegation exceptions are whitelisted and capability-conditional.** New exceptions need a strong case: one-off deliverables, never entering the code-review loop, with an explicit capability probe when the ability isn't guaranteed by a stock install (see `codex-computer-use`).
3. **The channel must work unattended.** No foreground sleeps; completion detection follows the full `wait` contract (baseline + no working markers + idle composer + stability + `NEEDS_INPUT` for interactive prompts); text and Enter are separate keypresses; composers get cleared before sending.
4. **Pane identity comes from tags, not screen text.** Discovery matches `@cwc_role`/`@cwc_repo` user options; screen text is a liveness check only.
5. **Skills explain why, not just what.** Prefer a sentence of reasoning over an ALL-CAPS must — the agents reading these files follow rules better when the failure mode is named.
6. **Keep briefs light.** Anything the reviewer can fetch itself (diffs, file contents) stays out of the message templates.

## Practical notes

- Shell changes: run `shellcheck` and `bash -n` on both scripts; CI checks these.
- Skill text changes: keep the frontmatter `name` matching the directory name, and remember the `description` is the trigger — it must say *when* to use the skill, not just what it does.
- English is the source language for skill bodies; the two READMEs are maintained in parallel (update both or say so in the PR).
- One logical change per PR.
