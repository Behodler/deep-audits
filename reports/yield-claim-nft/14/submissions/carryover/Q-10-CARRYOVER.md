# [CARRYOVER] Q-10 — setPool repoints _pairToken without re-validating stored custom _primeToPairPath (stale path can route swap to wrong token)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** QA
- **Status:** open (still-open carryover; out of run-14 changed-file scope)
- **Location:** `src/dispatchers/Uniboost.sol` (`setPool`)
- **First seen:** yield-claim-nft-13  ·  **Still present as of:** yield-claim-nft-14
- **Original report:** [reports/yield-claim-nft/13/submissions/qa-report.md](../../../13/submissions/qa-report.md)
- **Fingerprint:** `7c4bcba2…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
