# [CARRYOVER] L-02 — setDesiredAPY commit is mempool-visible; stakers front-run to capture rate-change delta

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run; reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open carryover)
- **Location:** `src/Phlimbo.sol#L151-L172` (`setDesiredAPY`)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea/03/audit/findings/low/L-02-setDesiredAPY-commit-frontrun.json](../../../../03/audit/findings/low/L-02-setDesiredAPY-commit-frontrun.json)
- **Fingerprint:** `470bf433…`

> **Note on labels:** this is **ledger** label L-02 (setDesiredAPY MEV front-run), NOT
> this run's run-label L-02 (pauseWithdraw MINIMUM_STAKE bypass, a NEW finding).
> Carryover stubs use ledger labels.

See the original report for the full description, impact, attack path, PoC, and recommendation.
