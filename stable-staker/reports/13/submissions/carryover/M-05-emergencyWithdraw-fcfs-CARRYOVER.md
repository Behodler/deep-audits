# [CARRYOVER] M-05-emergencyWithdraw-fcfs — emergencyWithdraw realizes underwater loss FCFS via direct share over-redemption (bufferless par bank-run): early exiters whole, late exiters absorb the entire shortfall

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed by story-013, not newly triaged). It is
> reproduced here so it is not lost between runs. Triage it with `/ledger stable-staker`.

- **Severity:** Medium
- **Status:** acknowledged (deferred, still present)
- **Location:** `src/StableStaker.sol#L304-L318` (`emergencyWithdraw`)
- **First seen:** stable-staker-07  ·  **Still present as of:** stable-staker-13 (HEAD d95f4a6)
- **Why still open:** Acknowledged-DEFERRED (human-set). story-013 does not touch emergencyWithdraw, which is still non-pro-rata FCFS-at-par; the reflax relinquishPrincipal dependency has landed but the pro-rata fix is unblocked-but-unapplied. Triage status preserved unchanged.
- **Original report:** [reports/stable-staker/07/submissions/M-05-emergencyWithdraw-fcfs-socialization.md](../../../07/submissions/M-05-emergencyWithdraw-fcfs-socialization.md)
- **Fingerprint:** `0dca43f3…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
