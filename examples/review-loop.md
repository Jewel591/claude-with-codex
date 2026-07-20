# Example: a full review ⇄ fix consensus loop

An annotated, lightly anonymized session showing the flagship workflow (scenario A of
`using-codex-collaboration`). Names and identifiers changed; the shape and the findings
are representative of real sessions.

**Setup**: Claude just finished a multi-file change in an iOS app — debouncing a search
field and reworking how results load. Before opening a PR, it brings in the reviewer.

---

## Round 1 — brief and first review

Claude (via `codex-pane.sh send`):

> I just finished a round of changes. Review the uncommitted working-tree diff (run
> git diff/status yourself). Intent: debounce the search field (300ms) and move result
> loading to an async stream. Deliberate trade-offs: no redesign of the results list;
> the legacy sort order stays. Focus on correctness, regressions, and edge cases.
> End with a verdict.

Note what's *not* in the brief: no pasted diff, no file list. The reviewer has repo
access — the brief carries only intent, non-goals, and focus.

Codex (after ~2 minutes, reading the diff itself):

> Findings, by severity:
>
> 1. **[bug] `SearchViewModel.swift` — the debounce task is never cancelled on view
>    teardown.** If the user types and dismisses the screen within 300ms, the task
>    fires into a view model that's being torn down; with the new async stream this
>    now also leaks the stream subscription. Failure scenario: type → back-swipe
>    within 300ms → crash or silent leak depending on timing.
> 2. **[regression] empty-query path skips the loading state.** Previously clearing
>    the field showed the full list immediately; now the guard returns before the
>    loading flag resets, so the spinner sticks after clearing a query.
> 3. **[nit] `debounceInterval` is a magic number in two places.**
>
> Verdict: needs fixes (1 and 2).

## Round 2 — fix, verify, re-review

Claude fixes both bugs, extracts the constant while it's there, **runs the test suite
itself** (the build/test gate never moves to the reviewer), then sends:

> Fixed per your findings: ① debounce task stored and cancelled in `onDisappear`,
> stream subscription torn down with it — added a regression test that dismisses
> mid-debounce; ② loading flag now resets before the empty-query early return —
> covered by an updated snapshot of the state machine, not the UI; ③ constant
> extracted. Please re-review. Also: any known side effects of cancelling in
> `onDisappear` vs `deinit`, and sweep the repo for other uncancelled task patterns.

The two piggybacked asks are the cheap-but-valuable part of every bug-fix round:
side-effect check on the chosen fix, and a same-pattern sweep — a pattern that broke
once usually exists elsewhere.

Codex:

> ① and ② fixed correctly; the mid-debounce dismissal test does reproduce the
> original crash when I revert your fix mentally against the old diff. On
> `onDisappear` vs `deinit`: fine here, but note `onDisappear` also fires on
> push-navigation — if a pushed detail screen should keep a pending search alive,
> you've changed that behavior. Decide intentionally. Sweep: one more uncancelled
> task in `ProfileHeaderView.swift` (avatar refresh), same shape, lower stakes.
>
> Verdict: clean once you've decided the push-navigation question and handled
> the profile instance.

## Round 3 — one fix, one held disagreement, convergence

The push-navigation point is real but, in this app, pending searches *should* die on
push — that's existing product behavior. Claude fixes the profile instance, and holds
the other point **with a reason** instead of churning the code:

> Profile task now cancelled, same pattern + test. Held: keeping cancellation in
> `onDisappear` — pending searches are meant to die on push in this app (existing
> behavior, confirmed against main). Not changing unless you see a concrete failure.

Codex:

> Profile fix verified. The held item is a legitimate product call and consistent
> with main's behavior — recording it, no objection. Verdict: **clean**.

Terminal state reached: `clean` (round 3, one recorded-then-accepted disagreement).
Claude closes the loop, reports the three rounds and the held decision to the user,
and the change proceeds to a PR.

---

## What to notice

- **Zero re-briefing.** Rounds 2 and 3 reference "your findings" — the pane remembers.
- **The doer never changes.** Codex found the bugs; Claude wrote every fix and ran
  every test.
- **Each real bug got a regression test** at the level that can catch it.
- **The held finding wasn't a stalemate.** A stated reason + consistency with existing
  behavior converted it from an open finding into a recorded decision. Convergence is
  objective-defects-at-zero, not the reviewer winning every point.
