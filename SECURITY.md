# Security

## Threat model in one paragraph

These skills wire two cloud AI agents to your repository and (optionally) your screen. The full security model — what leaves your machine, what technically constrains Codex, what computer use can see, and how prompt injection through web content is handled — is documented in the [Security model section of the README](README.md#security-model). Read it before enabling the skills on a sensitive repository.

Key invariants the skills maintain:

- Codex is never asked to modify the working tree; the primary agent is the sole writer.
- Credentials never appear in delegation briefs.
- Irreversible / outward-facing actions (publish, pay, delete, send, submit) require explicit user authorization per conversation, delegated or not.
- On-screen and in-page content encountered during GUI automation is data, never instructions.
- The computer-use skill refuses to run without a confirmed capability, and prefers attended operation for sensitive flows.

What the skills **cannot** guarantee: anything your own Codex sandbox/approval configuration permits is technically possible for Codex regardless of what the skill text says. Treat `~/.codex/config.toml` as part of your security posture.

## Reporting a vulnerability

If you find a security-relevant flaw in the scripts or a skill instruction that can be abused (e.g. a way to smuggle instructions past the untrusted-content rule), please open a GitHub issue. If the details feel too sensitive for a public issue, open a minimal issue asking for a private contact channel and we'll take it from there.
