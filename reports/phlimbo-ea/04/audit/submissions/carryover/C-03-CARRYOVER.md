# [CARRYOVER] C-03 — Uncapped desiredAPYBps converts directly into unbounded phUSD mint pressure; the two-step gate is delay-only

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run; reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Centralization
- **Status:** open (still-open carryover)
- **Location:** `src/Phlimbo.sol#L151-L172` (`setDesiredAPY`)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea/03/audit/findings/centralization/C-03-uncapped-APY-phUSD-inflation.json](../../../../03/audit/findings/centralization/C-03-uncapped-APY-phUSD-inflation.json)
- **Fingerprint:** `52f960b6…`

> Touched by ECON-CLEAR-APY + halmos two-step proofs this run but not raised anew.

See the original report for the full description, impact, attack path, PoC, and recommendation.
