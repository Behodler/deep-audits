# [CARRYOVER] L-09 — Uniboost has no hookTypeId guard: unwired/wrong dispatch hook silently accrues zero phUSD debt (M-04 fail-open class reborn)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged away). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low (Law-3 operational footgun, in scope)
- **Status:** open (re-confirmed still-open at f46a5cb in run-16)
- **Location:** `src/dispatchers/Uniboost.sol#L125` (`_dispatch`, hook invoked via base `ATokenDispatcherV2.sol:125`)
- **First seen:** yield-claim-nft-13  ·  **Still present as of:** yield-claim-nft-16
- **Original report:** [reports/yield-claim-nft-13/submissions/qa-report.md](../../yield-claim-nft-13/submissions/qa-report.md)
- **Fingerprint:** `563df2e6…`
- **Run-16 note:** Still OPEN, awaiting owner triage. **NOT** auto-folded into wont-fix Q-08 (`96c60b72…`, BalancerPoolerV2): distinct fingerprint/contract — Q-08's owner acceptance covers only the live BalancerPoolerV2, not this newly-in-scope Uniboost.

See the original report for the full description, impact, attack path, and recommendation.
