# [CARRYOVER] YS-02 (106d5c6e) — Leg-1 broadcast dead on arrival: owner not an authorized withdrawer on the 3 old strategies

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** Low (candidate Low→Medium re-weigh **REJECTED** by classifier + severity-auditor this run; ledger severity unchanged)
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-leg1`
- **Location:** `script/SkimAndLeg1Migration.s.sol#L196-L200` (`run` / skim step)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Re-verified:** STILL-LIVE on fork at e935a05 — `authorizedWithdrawers[OWNER]==false` on all 3 old strategies; leg1 first mutating call `skimSurplus` reverts 'AYieldStrategy: unauthorized'. story-061 granted withdrawer only on the new V2 strategies. Recoverable via a one-line `setWithdrawer(OWNER,true)` on each old strategy + re-run.
- **Original report:** [reports/phoenix-phase-2-staging/12/findings/low/YS-02-deployer-not-authorized-withdrawer.json](../../../12/findings/low/YS-02-deployer-not-authorized-withdrawer.json)
- **Fingerprint:** `106d5c6e`

See the original report for the full description, impact, attack path, and recommendation.
