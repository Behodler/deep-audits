# QA Report — yield-claim-nft

| Field | Value |
|-------|-------|
| Project | yield-claim-nft |
| Run | yield-claim-nft-14 |
| Submodule commit | `4f8054139b5ca0ffc3efd37da873715ad501b4e9` (`4f80541`) |
| Story | story-042 (MultiPooler atomic batch `pool()` + parameterized `Uniboost.pool` amount) |
| Mode | Regression scan (baseline run-13 @ `aa86be6`) |

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (new this run) | 1 |
| Low Risk (open carryover) | 6 |
| QA (open carryover) | 2 |
| Centralization | 0 |
| **Total** | **9** |

This run introduced one new first-party contract, `src/MultiPooler.sol` (plus its
interface `src/interfaces/IUniboostPooler.sol`), auto-pulled into scope under the
default-in-scope denylist. It produced exactly one new finding (L-11). No High,
Medium, Centralization, or regression findings surfaced. The remaining open
Low/QA items are carried over from prior runs and are referenced — not
re-authored — in the carryover section below.

---

## Low Risk Findings

### [L-11] MultiPooler same-pool in-batch floor staleness <!-- id: ycn14l11 -->

**Location**: [`src/MultiPooler.sol#L60-L67`](../../../lib/yield-claim-nft/src/MultiPooler.sol#L60-L67) (`pool`), interacting with [`src/dispatchers/Uniboost.sol#L211-L255`](../../../lib/yield-claim-nft/src/dispatchers/Uniboost.sol#L211-L255) (`pool`)

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

---

## Carryover open findings

The findings below remain **open** in the ledger from prior runs and were
**re-confirmed still present** as of this run's commit (`4f80541`). They are
outside run-14's changed-file scope (except L-06, explicitly re-checked this run)
and are **not re-authored** here. Each links to its authoritative writeup and to
its carryover stub. Triage via `/ledger yield-claim-nft`.

| Label | Severity | One-line | Authoritative report | Stub |
|-------|----------|----------|----------------------|------|
| L-04 | Low | Privileged `mintFor()`/`burn()` ignore global `paused` + per-index disabled flags (`NFTMinterV2.sol#L206-L214`) | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](carryover/L-04-CARRYOVER.md) |
| L-05 | Low | No on-chain invariant couples `BalancerPoolerV2.batchDonationSize` and `Hook.ratio` (missing `batchDonationSize + ratio <= 100` guardrail) | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](carryover/L-05-CARRYOVER.md) |
| L-06 | Low | Single-sided sUSDS LP-add relies solely on off-chain keeper `minBPT` with no on-chain price reference (MEV sandwich). **Re-confirmed still-open this run**; story-042's `amountIn` parameterization is MEV-neutral-to-beneficial and does **not** escalate it. | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](carryover/L-06-CARRYOVER.md) |
| L-07 | Low | `replaceDispatcher()` carries stale per-index price to a new dispatcher whose `primeToken` may have different decimals (price re-denomination) | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](carryover/L-07-CARRYOVER.md) |
| L-09 | Low | `Uniboost` has no `hookTypeId` guard: an unwired/wrong dispatch hook silently accrues zero phUSD debt (M-04 fail-open class reborn on a third dispatcher) | [yield-claim-nft-13 qa-report](../../yield-claim-nft-13/submissions/qa-report.md) | [stub](carryover/L-09-CARRYOVER.md) |
| L-10 | Low | `UniboostMintDebtHook.scale` derived from the hook's own ctor `primeToken_` with no on-chain tie to dispatcher `primeToken()`; decimals mismatch mis-scales all debt | [yield-claim-nft-13 qa-report](../../yield-claim-nft-13/submissions/qa-report.md) | [stub](carryover/L-10-CARRYOVER.md) |
| Q-05 | QA | `nonReentrant` is not the first modifier on `pool()`/the hook-guarded entry (defense-in-depth) | [yield-claim-nft-10 qa-report](../../yield-claim-nft-10/submissions/qa-report.md) | [stub](carryover/Q-05-CARRYOVER.md) |
| Q-10 | QA | `setPool` repoints `_pairToken` without re-validating stored custom `_primeToPairPath` (stale path can route swap to wrong token) | [yield-claim-nft-13 qa-report](../../yield-claim-nft-13/submissions/qa-report.md) | [stub](carryover/Q-10-CARRYOVER.md) |

---

## Centralization Risks

None new this run. (The `MultiPooler` keeper/owner privileges — `onlyPooler`
batch gating, owner-settable `pooler`, and the requirement that `MultiPooler` be
registered as an authorized pooler on each target `Uniboost` — are trusted,
non-malicious operational roles under Law 3; the only non-obvious consequence is
captured as the L-11 footgun above.)

---

## Appendix — Automated QA/Gas Report (4naly3er)

**Status: NOT GENERATED — tooling gap.**

4naly3er (`tools/4naly3er`) was run against `lib/yield-claim-nft/src` but failed
to compile the scope. The submodule depends on a **mutable sibling interface**
(`pauser/interfaces/IPausable.sol`) that is resolved at build time via the
project's `foundry.toml` remappings into `lib/mutable/`; 4naly3er's standalone
compiler invocation does not apply those remappings, so the import is
unresolvable and `solc` aborts:

```
pauser/interfaces/IPausable.sol import not found
Make sure you can compile the contracts in the original repository.
TypeError: Cannot read properties of undefined (reading 'contents')
```

Per the agent runbook, the gap is noted and the manual QA bundle proceeds. The
deterministic SAST baseline for this run is still covered by the
static-analyzer's Slither / Aderyn / Semgrep dumps already present under
`reports/yield-claim-nft-14/` (`slither-output.json`, `aderyn-report.json`,
`semgrep-output.json`, normalized to `static-analysis-findings.json`); none of
their raw hits survived triage as new findings for the new files
(`src/MultiPooler.sol`, `src/dispatchers/Uniboost.sol`) — see
`deduplicated-findings.json` (`SLITHER-001/002/003`, `ADERYN-001`, `MR-001/002`
all dropped as noise or collapsed into L-06 / the bounded L-11 surface).

To regenerate 4naly3er for a future run, point it at a remapping-aware checkout
(e.g. run from a `workspace/` clone with `forge`-resolved deps, or pass an
explicit `scope`/remapping file) rather than the bare `lib/<submodule>/src`
directory.
