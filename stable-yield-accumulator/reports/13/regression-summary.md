# stable-yield-accumulator — Run-13 Regression Summary

| | |
|---|---|
| **Project** | `stable-yield-accumulator` |
| **Run** | `stable-yield-accumulator-13` |
| **Mode** | REGRESSION (re-prove-at-HEAD) |
| **Baseline (run-12 cold scan)** | `71abe3e088559cb5d9c10e8475dc67e7cc57fac9` |
| **HEAD (this run)** | `0fef726ed9178754ce7b038a31037418078097d4` |
| **In-scope contract** | `src/StableYieldAccumulator.sol` (sole in-scope file) |
| **Date** | 2026-06-08 |

## Headline

The 2-commit upstream gap that this audit family was behind during the run-12 cold scan is **submodule-plumbing only**. The sole in-scope contract, `src/StableYieldAccumulator.sol`, is **byte-for-byte identical** at the baseline and at HEAD (git blob `d9984cfe…` at both `71abe3e` and `0fef726`). Therefore **all run-12 cold-scan findings still apply verbatim at HEAD**:

- **Nothing fixed** — no in-scope code changed.
- **Nothing regressed** — no entry was previously `fixed`, so no REGRESSION flag is raised.
- **No new findings** — the changed-files set does not intersect the in-scope surface (`changed-files ∩ in-scope = ∅`).

All 10 ledger entries (M-01, C-01, L-01..L-06, QA-01, QA-02) were re-proven **STILL-LIVE** and remain `open`.

## Commit delta

The two commits between baseline and HEAD carry no `[story-NNN]` tags and touch no in-scope Solidity:

| Commit | Subject |
|---|---|
| `ffea560` | phlimbo-ea version bump to fix submodule error |
| `0fef726` | Use absolute URL for phlimbo-ea submodule |

`git diff --stat 71abe3e..0fef726` touches only submodule plumbing:

- `.gitmodules` (phlimbo-ea remote URL → absolute)
- `lib/phlimbo-ea` submodule pointer (`1b1a32c → 6cb0bc0`)

**In-scope byte-identity proof.** The blob hash of `src/StableYieldAccumulator.sol` is `d9984cfe…` at **both** `71abe3e` and `0fef726`. The writable `workspace/` SYA source carries the same `d9984cfe…` blob, so every PoC replayed this run ran against the exact HEAD in-scope bytecode.

**Nested-dependency note (phlimbo-ea, vendoring-only).** The only nested-dep pointer that moved is `lib/phlimbo-ea 1b1a32c → 6cb0bc0`. That move is purely additive vendoring (new files under `lib/immutable/…`); `phlimbo-ea/src/Phlimbo.sol` is **byte-identical** across the move (blob `0370b7b6…`). This preserves L-02's anchor — the `collectReward` fixed-amount pull that L-02 depends on is unchanged.

## Finding reconciliation

All entries re-proven **STILL-LIVE** at HEAD `0fef726`. M-01, L-01, and L-02 were verified **empirically** (PoC replay / byte-identical external anchor); the remainder are pure-reasoning findings on the byte-identical in-scope contract and hold **by byte-identity**.

| Label | Sev | Verdict | Basis |
|---|---|---|---|
| **M-01** | Medium | STILL-LIVE | Empirical PoC replay PASS at HEAD: `poc-M-01.t.sol` 2/2 PASS; `PaymentFloor_SYA.t.sol` property-4 5/5 PASS. In-scope blob byte-identical (`d9984cfe…`). |
| **C-01** | Centralization | STILL-LIVE (suppressed) | In-scope blob byte-identical (`d9984cfe…`); centralization surface unchanged. Stays suppressed under Law 3 + KI#4/#5. |
| **L-01** | Low | STILL-LIVE | Empirical PoC replay PASS at HEAD: `Invariant_SYA.t.sol` 8/8 PASS + zero-floor PASS. In-scope blob byte-identical (`d9984cfe…`). |
| **L-02** | Low | STILL-LIVE | External anchor byte-identical: `phlimbo-ea/src/Phlimbo.sol` blob `0370b7b6…` unchanged across `1b1a32c → 6cb0bc0`; in-scope blob byte-identical (`d9984cfe…`). |
| **L-03** | Low | STILL-LIVE | Byte-identity. In-scope blob `d9984cfe…` unchanged; doc/impl mismatch persists. (F-01 faithfulness extension carried forward.) |
| **L-04** | Low | STILL-LIVE | Byte-identity. In-scope blob `d9984cfe…` unchanged. |
| **L-05** | Low | STILL-LIVE | Byte-identity. In-scope blob `d9984cfe…` unchanged. |
| **L-06** | Low | STILL-LIVE | Byte-identity. In-scope blob `d9984cfe…` unchanged. |
| **QA-01** | QA | STILL-LIVE | Byte-identity. In-scope blob `d9984cfe…` unchanged. |
| **QA-02** | QA | STILL-LIVE | Byte-identity. In-scope blob `d9984cfe…` unchanged. |

## Submissions carry-forward

No new reports are required this run. The run-12 submissions remain **valid, unchanged, and authoritative**:

- `reports/stable-yield-accumulator/12/submissions/M-01-submission.md` — M-01 (Medium)
- `reports/stable-yield-accumulator/12/submissions/qa-report.md` — L-01..L-06, QA-01, QA-02, C-01 bundle
- `reports/stable-yield-accumulator/12/submissions/spec-conformance.md` — F-01 (Law-2 faithfulness)

Because the in-scope contract is byte-identical to the run-12 baseline, these reports describe HEAD exactly; no regeneration is needed.

## Watch-items preserved

- **M-01 stays a top-of-band Medium.** Do **not** auto-suppress under KI#8 or KI#2 — the finding is the asymmetric-partial-misconfig decimal fail-open (a non-obvious owner footgun enabling a Law-1 exploit), not a covered known issue. The Plausible-High dissent is **recorded, not actioned**; the classifier's strict-C4 Medium verdict stands. Remediation remains mandatory.
- **C-01 stays suppressed** under Law 3 (owner trusted for KNOWING actions) + known issues #4/#5. Kept `open` as the tracked centralization residual; reject any "owner drains" High re-raise.

## Ledger state after this run

- `lastAuditedCommit` → `0fef726ed9178754ce7b038a31037418078097d4`
- `lastRun` → `stable-yield-accumulator-13`
- `updatedAt` → `2026-06-08T00:00:00Z`
- All 10 entries: `lastSeenRun` → `stable-yield-accumulator-13`, `lastSeenCommit` → `0fef726…`, `reconciliation` set to the STILL-LIVE note; all `status` values, severities, labels, fingerprints, and triage notes preserved. No new entries, no REGRESSION flags.
