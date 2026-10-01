# Carryover QA Report — originating audit 14 (carried into yield-claim-nft-20)

> **Carryover QA report — audit 14** (cut down from `yield-claim-nft/reports/14/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 20): **L-11**.
> Removed as no longer live: none.
> Structural sections not copied (they carry no live findings of their own): title block + Summary, "Carryover open findings" (pointers), "Centralization Risks" ("None new this run"), Appendix (4naly3er).
> Retained counts: Low 1.
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Re-observed in run 20: none; carried for recall only.
> Line numbers and links were accurate at the originating commit, and relative links reflect the repository
> layout of that run (`reports/yield-claim-nft/NN/`, `lib/yield-claim-nft/src/...`); the source now lives at
> `yield-claim-nft/src/src/...`. Re-verify every location against current HEAD `2bfa090`.
>
> Triage any of these with `/ledger yield-claim-nft`.
>
> *The text below is a verbatim copy of the retained sections of the original report.*

---

## Low Risk Findings

### [L-11] MultiPooler same-pool in-batch floor staleness <!-- id: ycn14l11 -->

**Location**: [`src/MultiPooler.sol#L60-L67`](../../../../lib/yield-claim-nft/src/MultiPooler.sol#L60-L67) (`pool`), interacting with [`src/dispatchers/Uniboost.sol#L211-L255`](../../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L211-L255) (`pool`)

**Classification**: Low — non-obvious Law-3 owner/keeper operational footgun (in scope). Confirmed kept by the sanitizer and validity-checker (not a known-invalid pattern); Low severity confirmed by both the severity-classifier and the severity-auditor.

**Description**:
`MultiPooler.pool(PoolCall[] calls)` forwards one `Uniboost.pool(amountIn, minPairOut, minTargetOut, minLP)` call per row, atomically and all-or-nothing — any single row's revert bubbles up and reverts the entire batch. The contract is a fund-less forwarder gated by a single trusted `onlyPooler` keeper, and backs a per-row UI form where an operator fills in each dispatcher's pooling parameters off-chain.

Each row's slippage floors (`minPairOut`, `minTargetOut`, `minLP`) are computed off-chain against the pool reserves observed *before* the batch is submitted. `Uniboost.pool` performs two UniV2 swaps (prime → pair, ~half pair → target) and then `addLiquidity` against the shared pool. If two rows in the same batch target dispatchers sitting on the **same** UniV2 pool, the earlier row's swaps move that pool's reserves, so by the time the later row executes its floors are stale (computed against pre-batch reserves that no longer hold).

**Impact** (primary branch first):

- **Primary (more likely, under safe tight-floor config):** the later row's now-stale floors are not met, so its `pool` call reverts and — because the batch is atomic — the **entire batch reverts**. This is a self-inflicted DoS: wasted keeper gas, **no loss of funds**, no degraded position. This is the load-bearing branch.
- **Secondary (only if floors are set loose):** if the floors are loose enough to still clear against the drifted reserves, the later row pools at a degraded LP ratio. The loss is **bounded by that row's own `minPairOut`/`minTargetOut`/`minLP`** floors — it cannot exceed the slippage the operator already accepted for that row.

In all cases the value at risk is protocol-owned liquidity (POL) only: there is no theft, no external attacker, no cross-user impact. The hazard is entirely keeper-avoidable, and the **default one-pool-per-dispatcher deployment is unaffected** (it only arises when two batched dispatchers deliberately share a UniV2 pool).

**Recommendation**:
The batch-building UI / keeper must not co-batch two dispatchers that share a UniV2 pool. Concretely:

- Net all same-pool rows into a single `Uniboost.pool` call rather than batching them as separate rows; or
- If separate same-pool rows are unavoidable, order them deterministically and size each later row's floors to tolerate the in-batch reserve drift introduced by the earlier rows on that shared pool.
- Optionally document this constraint in `MultiPooler` NatSpec so future operators inherit the safe-config rule.

No code change is strictly required (the atomic revert already fails safe in the primary branch); the fix is operational guidance plus optional documentation.

