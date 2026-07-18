# [CARRYOVER] L-09 — Unwired/wrong dispatch hook has no hookTypeId guard: silently accrues zero phUSD debt (M-04 fail-open class reborn)

> **This is a carryover stub, not new analysis.** This finding was reported in a
> prior run and is **still open** (not fixed, not triaged). It is reproduced here so
> it is not lost between runs. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/dispatchers/Uniboost.sol#L125` (base ATokenDispatcherV2._dispatch hook path) (`_dispatch -> hook.onDispatch`)
- **First seen:** yield-claim-nft-13  ·  **Still present as of:** yield-claim-nft-17
- **Original report:** [reports/yield-claim-nft-13/submissions/qa-report.md](../../yield-claim-nft-13/submissions/qa-report.md)
- **Fingerprint:** `563df2e6…`
- **Run-17 note:** CLASS RECURRED this run on the 4th dispatcher: PromotionUniV2_Eth reuses base ATokenDispatcherV2._dispatch -> hook.onDispatch(GROSS) with NO hookTypeId/keccak256 guard (source-confirmed no such literal); ctor defaults hook = no-op DefaultDispatchHook; forget setHook => NFTs mint with ZERO phUSD debt. Story-044 faithfulness record F-02-044 RECONCILES here (hook CALL is faithful/gross; gap is the fail-open) — NO separate finding minted. Do NOT collapse into wont-fix Q-08 (BalancerPoolerV2, distinct contract/fingerprint); do NOT re-file. Same fingerprint reused (CANDIDATE-3), no new label. lastSeenRun bumped 16->17.

See the original report for the full description, impact, attack path, PoC, and recommendation.
