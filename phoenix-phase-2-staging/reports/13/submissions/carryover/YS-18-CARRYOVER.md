# [CARRYOVER] YS-18 (9caa24f4) — Stale NatSpec on the fixed strategy: _acquireShares doc still says 'the full nominal amount'

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger phoenix-phase-2-staging`.

- **Severity:** QA
- **Status:** open (still-open)
- **Entry point:** `migrate:ys-swap-deploy`
- **Location:** `lib/vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol#L93-L113` (`_acquireShares`)
- **First seen:** phoenix-phase-2-staging-12  ·  **Still present as of:** phoenix-phase-2-staging-13
- **Carryover reason:** vault bumped to 0110ce4 added source comments explaining convertToAssets, but no evidence the `_acquireShares` doc text claiming 'full nominal amount' was corrected. Conservative STILL-OPEN.
- **Original report:** [reports/phoenix-phase-2-staging/12/findings/qa/YS-18-stale-natspec-on-fixed-strategy.json](../../../12/findings/qa/YS-18-stale-natspec-on-fixed-strategy.json)
- **Fingerprint:** `9caa24f4`

See the original report for the full description, impact, attack path, and recommendation.
