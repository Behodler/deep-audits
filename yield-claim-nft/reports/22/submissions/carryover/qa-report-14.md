# Carryover QA report — originating audit 14 (carried into yield-claim-nft-22)

> **Carryover QA report — audit 14** (pruned copy of `yield-claim-nft/reports/14/submissions/qa-report.md`, taken from the run-21 pruned carryover `reports/21/submissions/carryover/qa-report-14.md` — whose finding text is itself the verbatim original — re-checked against the ledger at run 22). Carried at `0fd6bdf` (`0fd6bdfd386c6cd3a6a2b565ed2ef5b363879630`), run 22, branch `master`.
> Retained (still live in the ledger: `open` / `qa-bundled` / `fix-pending`): **L-11**.
> Removed as no longer live: **none since run 21** (the retained set is unchanged; entries disposed before run 21 are named in the provenance notes below).
> Labels are the originals — gaps in the sequence are removals (named above or in the originating/earlier carryover headers), not omissions. Global issue IDs in `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped).
> **Why still valid:** the only source change in this run's range `267660b..0fd6bdf` is the new file `src/migration/UniPoolerCutoverEscrow.sol` (plus its tests and `test/mocks/MockV3ExitRouter.sol`). None of the contracts under the entries below changed, no fix landed for any of them, and no human triage has disposed of them, so each is still live exactly as last reported. Not being re-observed by a run-22 tool is **not** a fix.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder. Re-verify every location against `0fd6bdf` before acting.
> *The finding text below is a verbatim copy of the originating report. `Carryover status (run 21 …)` blocks were added by the run-21 qa-bundler and are kept as history; the run-22 status of every entry is the table below.*
>
> | Ledger label | issueId | Fingerprint | Status | First seen | Last seen (after run 22) | Re-observed in run 22 | Contract |
> |---|---|---|---|---|---|---|---|
> | L-11 | — | `531916f45896a9a46cea592b4129c2953fac1d225371de6ed4a186ccc9b29ab8` | `open` | yield-claim-nft-14 | yield-claim-nft-16 | no (carried; code unchanged) | `src/MultiPooler.sol` |

<details><summary>Provenance notes from the run-21 carryover header (kept verbatim: label-collision warnings, facet and instance notes)</summary>

> **Carryover QA report — audit 14** (pruned copy of `yield-claim-nft/reports/14/submissions/qa-report.md`; originating commit `4f80541`; carried at `267660b`, run 21).
> Retained (still `open`): **L-11**. Removed as disposed: **none** — L-11 was the run's only new finding. The report's "Carryover open findings" table (pointers to runs 10/13 — now carried in full in those files), "Centralization Risks" (none) and the 4naly3er appendix are not copied.
> Line numbers and links are as written at the originating commit; relative links resolve from the **original** report's directory (`reports/NN/submissions/`), not from this `carryover/` folder, and many point at the retired `lib/yield-claim-nft/...` reference tree. Re-verify every location against `267660b` before acting.
> Global issue IDs in the `<!-- id: -->` stamps are the originating run's, copied verbatim (never restamped). Where an originating report minted an ID inconsistently (run 08 stamped QA items with `l`), the original stamp is kept and the discrepancy is noted, not corrected.
> *The finding text below each heading is a verbatim copy of the originating report; the `Carryover status` block after each section is added by the run-21 qa-bundler.*

</details>

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

> **Carryover status (run 21, `267660b`).** Ledger **L-11** · fingerprint `531916f45896a9a46cea592b4129c2953fac1d225371de6ed4a186ccc9b29ab8` · status **`open`** · severity `low` · first seen `yield-claim-nft-14` · last seen `yield-claim-nft-16` · re-observed by run-21 inputs: **no (not re-raised; absence of a re-raise is not a fix)**.
