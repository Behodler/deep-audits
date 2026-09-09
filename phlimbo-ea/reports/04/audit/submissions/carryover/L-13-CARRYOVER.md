# [CARRYOVER] L-13 — _updatePhUSDEmissionRate truncates phUSDPerSecond to zero at low totalStaked x low APY

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run (only cross-referenced by the new
> run-label L-02 as a shared consequence); reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open carryover)
- **Location:** `src/Phlimbo.sol#L461-L470` (`_updatePhUSDEmissionRate`)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea/03/audit/findings/low/L-13-precision-truncation-low-stake-low-APY.json](../../../../03/audit/findings/low/L-13-precision-truncation-low-stake-low-APY.json)
- **Fingerprint:** `a2a6d4a6…`

> The dust-regime emission-zeroing here is the SHARED CONSEQUENCE that this run's new
> L-02 (pauseWithdraw MINIMUM_STAKE/INV-6 bypass) makes reachable; the two are distinct
> root causes and remain distinct ledger entries.

See the original report for the full description, impact, attack path, PoC, and recommendation.
