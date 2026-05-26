# Design: `/recheck` — single-finding re-verification

**Status:** implemented (`.claude/commands/recheck.md`), documented in `CLAUDE.md`
**Date:** 2026-05-26

## Problem

The ledger lets us track findings across runs, but there was no cheap way to answer
*"I pulled the latest code — is finding M-01 still real / did the fix land?"* for **one**
specific finding. The only existing options were both wrong-sized:

- **Full regression scan** (`/full-audit` / `/analyze`) — heavy, and its sanitizer only
  *fingerprint-matches* a finding and marks it "still-open"; it does not re-prove the exploit.
- **Manual `/ledger fixed`** — records a human *judgment*, not a verification.

So re-verification was a genuine gap.

## Three operations were being conflated

| Operation | Question | Touches code? | Command |
|---|---|---|---|
| **Discovery** | What bugs are in this code? | yes (whole scope) | `/analyze`, `/full-audit` |
| **Triage** | What's my judgment on this finding? | no | `/ledger` |
| **Re-verification** | Does *this specific* finding still hold at HEAD? | yes (one finding's region) | **`/recheck`** (new) |

`/recheck` fills the third row. It is **not** a lightweight `/full-audit`; it answers a
different question and is blind to new bugs by construction.

## The side-effect concern (the core of the design)

Running a *scoped* re-check through the discovery pipeline is dangerous because
`finding-manager` advances **`lastAuditedCommit`** (the regression diff baseline). If that
baseline moves after looking at only one finding, every future regression scan computes
`changed_since(newBaseline, HEAD)` and **silently skips everything that changed between the
old baseline and now**. Coverage is lost without any error.

Naively running `/full-audit` just to recheck M-01 also creates a near-empty new versioned
run dir and moves `lastRun` — noise that misrepresents what was actually audited.

## The invariant that makes `/recheck` safe

`/recheck` is **baseline-preserving and single-entry**:

1. **Never writes `lastAuditedCommit`.** Only a full-scope scan earns the right to advance the baseline.
2. **Never bumps `lastSeenRun`.** That means "observed by a discovery scan"; recheck isn't discovery.
3. **Touches only the target entry.** No other entry, no `lastRun` pointer.
4. **Proposes, never applies, status changes.** Respects human triage statuses
   (`acknowledged`/`wont-fix`/`false-positive`) absolutely; prints the exact `/ledger` command instead of flipping.

Recheck records its outcome in dedicated, additive fields on the one entry:
`lastRecheckedCommit`, `lastRecheckedAt`, `recheckResult`.

## Mechanism: PoC-replay first

The cleanest, most deterministic re-verification is *re-running the finding's existing PoC*
against the new code:

- **STILL-LIVE** — PoC compiles and the exploit assertion still passes → finding holds.
- **LIKELY-FIXED** — PoC compiles but the exploit assertion now fails / reverts at the patch → fix landed.
- **INCONCLUSIVE** — PoC no longer *compiles* (interface drift). This is bit-rot, **not** a fix;
  regenerate the PoC before concluding anything.

Scanner re-run (`code-scanner`/`econ-scanner`, scoped to the finding's contract/function) is a
fallback only when no PoC exists, and is explicitly weaker.

### Implementation wrinkle: workspace vs submodule

PoCs live in `workspace/<project>/` (a separate writable clone), while "pull latest" updates
the `lib/` submodule. A faithful recheck must therefore **sync the workspace source to the
submodule's target commit, preserving the `test/` PoCs**, then replay — never run against
stale workspace source, and never write to read-only `lib/`.

## Scope guard / when to prefer `/full-audit`

`/recheck` computes the diff between the finding's last-audited commit and the target commit:

- **Empty diff** → nothing changed for this finding; exit.
- **Within the finding's contract** → NARROW; recheck is appropriate.
- **Broader than the finding's contract** → warn and recommend `/full-audit`, because recheck
  cannot see new issues the broader change may have introduced.

The honest framing baked into the command's output: *recheck answers "is this specific thing
still real?" cheaply and safely, but it is not a substitute for regression discovery.*

## Output

- Addendum (not a new run dir): `reports/<owner-run>/reverify/<label>-<short-commit>.md`
- Single-entry ledger update with recheck-only fields; proposed `/ledger` command for any status change.

## Naming

Chosen `/recheck` over `/re-evaluate` — "evaluate" implies discovery, and the whole point is
that this is *not* discovery.

## Agent wiring

- **project-manager** — resolve name; current HEAD / target commit; changed-file scope guard; sync workspace source (preserving PoCs)
- **finding-manager** — load entry by selector; recheck-touch the single entry; propose status changes
- **poc-validator** — replay PoC, classify STILL-LIVE / LIKELY-FIXED / INCONCLUSIVE
- **code-scanner / econ-scanner** — scoped fallback when no PoC exists
