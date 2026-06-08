# [CARRYOVER] L-01 — claim() charges 0 payment while delivering skimmed yield (post-denormalize floor not re-guarded)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger stable-yield-accumulator`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/StableYieldAccumulator.sol#L494-L509` (`claim`)
- **First seen:** stable-yield-accumulator-11  ·  **Still present as of:** stable-yield-accumulator-12
- **Original report:** [reports/stable-yield-accumulator-11/findings.json](../../../stable-yield-accumulator-11/findings.json)
- **Fingerprint:** `0da2e7cf…`

Re-confirmed this run (DEDUP-003 / CODE-001 / ECON-01 + invariant property-3/4 + halmos
SYMBOLIC-001/002 at HEAD 71abe3e). Re-quantified as **dust-only standalone** (<1 ulp of reward
token per claim, strictly unprofitable to farm) and **MUST NOT be re-escalated**. Note: the NEW
M-01 (this run) weaponizes exactly this zero-payment floor ~1e12x via a decimal misconfig — see
M-01; the proper fix (revert if `actualPayment == 0` for non-zero delivered yield) hardens both.
No severity change.

See the original report for the full description, impact, attack path, PoC, and recommendation.
