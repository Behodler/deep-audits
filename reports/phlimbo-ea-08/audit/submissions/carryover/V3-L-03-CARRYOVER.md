# [CARRYOVER] V3-L-03 — PhlimboV3 zombie _stakers entries monotonically inflate owner flush gas cost

> **This is a carryover stub, not new analysis.** This finding was reported in a prior run and is
> **still open** (not fixed, not triaged). It is reproduced here so it is not lost between runs.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low (unchanged — carried over, no re-classification)
- **Status:** open (still-open, re-detected this run as `08-08`)
- **Location:** `src/PhlimboV3.sol#L537-L552` (`pauseWithdraw`)
- **First seen:** phlimbo-ea-07 · **Still present as of:** phlimbo-ea-08
- **Original report:** [reports/phlimbo-ea-07/audit/submissions/qa-report.md](../../../../phlimbo-ea-07/audit/submissions/qa-report.md)
- **Fingerprint:** `59e14f41…`

## Interaction note (does NOT re-weigh either entry)

`pauseWithdraw` never prunes `_stakers`, so zombie (`amount == 0`) members accumulate permanently
and every future rotation must iterate them. This **compounds `08-03`'s cursor economics** — a
longer `_stakers` list means more chunks and more opportunities to hit a bricking index. **That
interaction does not re-weigh either entry**; both stand at their existing severities.

## ⚠ Fingerprint caveat (scheme defect, not a finding about this contract)

This run's re-detection (`08-08`) hashes to **`7d9df6f8`**, **not** this entry's **`59e14f41`** —
because `rootCauseClass` is free text and the wording drifted. **The semantic carryover is
correct and accepted**; the entry identity is **preserved as `59e14f41`** and was deliberately
**not** re-fingerprinted (re-fingerprinting would fork the entry).

**The scheme defect this exposes:** a real **REGRESSION could be MISSED** if a `fixed` entry's
wording drifts. Recorded in the run metadata for the human.

See the original report for the full description, impact, and recommendation.
