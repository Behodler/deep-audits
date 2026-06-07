# [CARRYOVER] L-07 — collectReward is mempool-visible: searchers can sandwich a funding deposit to capture rewards intended for long-term stakers

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). Code is byte-identical
> to the last audited commit (HEAD == 1b1a32c), so it remains open at this commit.
> It was not independently re-surfaced this run; reproduced here so it is not lost.
> Triage it with `/ledger phlimbo-ea`.

- **Severity:** Low
- **Status:** open (still-open carryover)
- **Location:** `src/Phlimbo.sol#L270-L286` (`collectReward`)
- **First seen:** phlimbo-ea-03  ·  **Still present as of:** phlimbo-ea-04
- **Original report:** [reports/phlimbo-ea-03/audit/findings/low/L-07-collectReward-sandwich-MEV.json](../../../../phlimbo-ea-03/audit/findings/low/L-07-collectReward-sandwich-MEV.json)
- **Fingerprint:** `d75339ce…`

> Distinct from this run's M-03 (permissionless re-anchor griefing) and ledger L-08
> (zero-totalStaked funder leak), though all three touch `collectReward`.

See the original report for the full description, impact, attack path, PoC, and recommendation.
