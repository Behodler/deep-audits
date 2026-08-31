# [CARRYOVER] L-07 — replaceDispatcher() carries stale per-index price across differing-decimals primeToken

> **This is a carryover stub, not new analysis.** Reported in a prior run and **still open**
> (not fixed, not triaged). Carried over from prior run, unchanged at the flattened path
> introduced by story-039. Triage it with `/ledger yield-claim-nft`.

- **Severity:** Low
- **Status:** open (still-open)
- **Location:** `src/NFTMinterV2.sol#L227-L247` (`replaceDispatcher`)
- **First seen:** yield-claim-nft-10  ·  **Still present as of:** yield-claim-nft-12
- **Original report:** [reports/yield-claim-nft/10/submissions/qa-report.md](../../../10/submissions/qa-report.md)
- **Fingerprint:** `ac91a046…` — see ledger `ac91a046b297df79136825b5446d76e74368e175351e7a306bb3051b36a82a76`

`replaceDispatcher()` carries a stale per-index price to a new dispatcher whose `primeToken` may have different decimals (price re-denomination). Unchanged by story-039. See the original QA report for full description, impact, and recommendation.
