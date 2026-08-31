# [CARRYOVER] L-09 — Uniboost has no hookTypeId guard: an unwired/wrong dispatch hook silently accrues zero phUSD debt (M-04 fail-open class reborn on a third dispatcher)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open carryover; out of run-14 changed-file scope)
- **Location:** `src/dispatchers/Uniboost.sol#L125-L125` (`_dispatch (hook invoked via base src/dispatchers/ATokenDispatcherV2.sol:125)`)
- **First seen:** yield-claim-nft-13  ·  **Still present as of:** yield-claim-nft-14
- **Original report:** [reports/yield-claim-nft/13/submissions/qa-report.md](../../../13/submissions/qa-report.md)
- **Fingerprint:** `563df2e6…`

See the original report for the full description, impact, attack path, PoC, and recommendation.
