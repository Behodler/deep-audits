# yield-claim-nft — QA Report

This report bundles Low-severity and Centralization findings identified during the audit of the yield-claim-nft V2 contracts at commit [`c67d3c9`](https://github.com/Behodler/yield-claim-nft/tree/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5). Scope was the V2 contract suite, with primary focus on `BalancerPoolerV2` and `BalancerPoolerMintDebtHook` executing against the real Balancer V3 mainnet Vault and the sUSDS / waUSDC pool. The items below are spec deviations, defensive-parameter omissions, pause-topology gaps, and centralization observations that do not rise to High or Medium severity but warrant attention before deployment.

| Severity | Count |
|----------|-------|
| Low / QA | 10 |

---

## [L-01] `BalancerPoolerV2.pool()` lacks a `deadline` parameter

**Location**: [`BalancerPoolerV2.sol#L191-L197`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/dispatchers/BalancerPoolerV2.sol#L191-L197)

`pool(uint256 minBPT, uint256 minUSDC)` accepts only first-order slippage thresholds; it does not take a `deadline` / expiry timestamp. The pooler bot quotes `minBPT` and `minUSDC` against pool state at signing time and must set them permissively enough to absorb normal market movement. If the transaction is held by a builder, delayed by mempool congestion, or intentionally censored for several blocks, the Balancer V3 sUSDS / waUSDC pool can drift well beyond the quoted state while still satisfying the now-stale thresholds.

**Impact**: Operator loses the ability to invalidate a signed but un-included transaction; protocol absorbs additional slippage purely due to delayed inclusion. Balancer's own Router entrypoints take a `deadline` for exactly this reason; routing through `Vault.unlock()` directly skips that check.

**Recommendation**: Add `uint256 deadline` to `pool()` and `require(block.timestamp <= deadline, ...)`. Pooler bot can set `deadline = block.timestamp + 30s` per standard DEX practice.

---

## [L-02] No absolute cap on `batchDonationSize`; large pool() swaps are predictable sandwich bait

**Location**: [`BalancerPoolerV2.sol#L143-L151`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/dispatchers/BalancerPoolerV2.sol#L143-L151), [`L207-L227`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/dispatchers/BalancerPoolerV2.sol#L207-L227)

`batchDonationSize` is a percentage applied to the dispatcher's full sUSDS balance at `pool()` time. The balance accumulates monotonically between calls and there is no per-tx absolute cap or auto-chunking. The donation swap size is fully derivable from public on-chain state (`sUSDS.balanceOf(dispatcher) * batchDonationSize / 100`), making the swap a deterministic, mempool-observable target. Against a shallow Balancer V3 pool, a single large donation can move spot meaningfully and is easy to sandwich.

**Impact**: Per-call value leak proportional to accumulated balance versus live pool depth. Worsens the slippage exposure already discussed in the Medium-severity donation-leg findings.

**Recommendation**: Cap donation size per `pool()` call as a small fraction of live pool reserves (read via `Vault.getPoolTokens`), or split a large donation across smaller swaps within the unlock callback. Pair this hardening with a `deadline` (L-01) and tighter per-leg slippage caps.

---

## [L-03] `BalancerPoolerMintDebtHook.setRatio` off-by-one against documented `< MAX_RATIO` invariant

**Location**: [`BalancerPoolerMintDebtHook.sol#L29-L33`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L29-L33), [`L92-L97`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L92-L97)

The contract documents `MAX_RATIO` (50) as an **exclusive** upper bound — comments explicitly state "Max settable ratio is `MAX_RATIO - 1`" and "Strictly < MAX_RATIO". However, `setRatio` checks `if (newRatio > MAX_RATIO) revert`, which permits `newRatio == 50`. Compounding the issue, the constructor sets `DEFAULT_RATIO = 50`, so the hook is born violating its own documented invariant.

**Impact**: Pure spec-vs-implementation mismatch. The boundary value (ratio = 50) is also the worst case for the broader debt-vs-realised-USDC divergence tracked separately.

**Recommendation**: Change the guard to `if (newRatio >= MAX_RATIO) revert RatioTooHigh();` and lower `DEFAULT_RATIO` below `MAX_RATIO`. Alternatively, update the docstrings to reflect that `MAX_RATIO` is inclusive.

---

## [L-04] Donation slice rounds down via integer division; tiny dispatches skip the donation entirely

**Location**: [`BalancerPoolerV2.sol#L207-L213`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/dispatchers/BalancerPoolerV2.sol#L207-L213)

`uint256 donationSUSDS = (sUSDSAmount * batchDonationSize) / 100;` rounds toward zero. For small `sUSDSAmount` values (e.g. dispatches following the previous `pool()`), the donation slice truncates to zero and `donationActive` evaluates false — the entire balance flows to the LP add. The `BalancerPoolerMintDebtHook` still accrues phUSD debt against the USDS notional received in `_dispatch`, regardless of whether downstream `pool()` actually routes any USDC through the donation path.

**Impact**: Sub-wei rounding bias favouring the LP leg over the batchMinter leg. Negligible per-call but is the on-chain mechanism by which the hook ↔ dispatcher invariant first diverges for small flows.

**Recommendation**: Either accumulate the rounded-down dust into a separate counter and trigger when it crosses a threshold, or — preferred — accrue `mintDebt` against realised USDC output rather than dispatched USDS notional.

---

## [L-05] Global Pauser cannot freeze `BalancerPoolerV2.pool()`

**Location**: [`BalancerPoolerV2.sol#L191-L276`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/dispatchers/BalancerPoolerV2.sol#L191-L276), [`NFTMinterV2.sol#L111-L122`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/NFTMinterV2.sol#L111-L122)

The Global Pauser role on `NFTMinterV2` gates only `_executeMint` via the contract's internal `paused` flag; it does **not** propagate to `ATokenDispatcherV2`'s separate `Pausable` (which is controlled by `setDispatcherActive`, an owner-only path). After an operator engages the global pause in response to an incident, `pool()` remains callable by any authorized pooler until the owner additionally calls `setDispatcherActive(dispatcher, false)`.

**Impact**: Pause-topology / operator mental-model gap. The dispatcher *can* be halted, but only via a slower owner-mediated control plane rather than the fast Pauser-role halt operators may assume covers everything. In a fast-moving incident (compromised pooler key, anomalous pool state) this is exactly the window where `pool()` is most dangerous to leave open.

**Recommendation**: Either propagate `NFTMinterV2.pause()` to registered dispatchers, add a second `whenNotPaused` check on `pool()` that consults `NFTMinterV2(minter).paused()`, or introduce a shared `PauseRegistry`. Whichever path is chosen, document the pause topology so operators know which switch freezes which surface.

---

## [L-06] `NFTMinterV2.mintFor()` bypasses the `paused` flag

**Location**: [`NFTMinterV2.sol#L206-L214`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/NFTMinterV2.sol#L206-L214)

The paid mint path `_executeMint` enforces `require(!paused)`, but `mintFor(uint256 index, address recipient)` — the authorized-minter entry point used by `NFTMigrator` and any other operationally registered minter — has no such check. While the Global Pause is engaged, authorized minters can continue to issue claim NFTs and the resulting tokens are immediately transferable.

**Impact**: Spec / coverage gap: an operator engaging the Global Pause expects new claim supply to halt, but `NFTMigrator` (and any other allow-listed minter) can keep issuing. Restricted to allow-listed addresses, so not directly attacker-reachable; could also plausibly be intentional (migration should arguably continue through a paid-flow incident).

**Recommendation**: Add `require(!paused, "Contract is paused")` to `mintFor` (and audit `burn()` for the same property). At minimum, document the asymmetry so operators understand the pause scope.

---

## [L-07] `NFTMigrator.setInitialized` invariant broken by post-init `setMapping` / `setMappings`

**Location**: [`NFTMigrator.sol#L33-L47`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/NFTMigrator.sol#L33-L47), [`L51-L58`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/NFTMigrator.sol#L51-L58), [`L62-L76`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/NFTMigrator.sol#L62-L76)

`setInitialized()` validates that every V1 dispatcher index has a non-zero V2 mapping, then flips `initialized = true`. The documented intent is that mappings are validated and frozen at this point. However, `setMapping` and `setMappings` remain callable by the owner after initialization, with no guard preventing the owner from re-pointing a mapping to a different V2 index or zeroing it back to 0. The validated invariant of `setInitialized` is therefore non-binding post-init.

**Impact**: Documented immutability guarantee is illusory. The compromised-owner attack vector is largely covered by the project's owner-trust known-issue assumption; the salvageable contribution is the spec-vs-implementation gap on `setInitialized`'s documented immutability claim, which may mislead external integrators.

**Recommendation**: Either make `setMapping`/`setMappings` revert when `initialized == true` (matches the documented frozen semantics), or keep mutation but require `migrate()` callers to pass an expected `v2Index` and revert on mismatch so users get a predictable result even if the table rotates mid-flight.

---

## [L-08] `NFTMigrator.migrate()` per-unit mint loop can strand large V1 holders

**Location**: [`NFTMigrator.sol#L62-L76`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/NFTMigrator.sol#L62-L76)

`migrate()` calls `v2.mintFor(v2Index, msg.sender)` once per held unit (`for (uint256 j = 0; j < balance; j++)`). Each `mintFor` is an external call performing the full authorized-minter check and an ERC1155 `_mint`, which is roughly 25k-50k gas. A holder of ~1000 V1 NFTs of a single index can hit the mainnet block gas limit (~30M) before the loop completes, and the design is single-tx (no partial migration).

**Impact**: UX / availability issue for power users — large V1 holders may be unable to migrate without first splitting their balances across fresh wallets. No assets at risk (revert rolls back the V1 burn), but a workaround that requires extra wallets and gas premiums is non-trivial.

**Recommendation**: Add a `mintForBatch(index, recipient, quantity)` variant on `NFTMinterV2` and call it once per V1 index from `migrate()`, reducing the cost to `O(numIndexes)`. Alternatively, allow `migrate()` to take a list of specific indexes so users can split the migration across multiple txs.

---

## [L-09] `BalancerPoolerV2.rescueERC20` is not pause-gated

**Location**: [`BalancerPoolerV2.sol#L305-L317`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/dispatchers/BalancerPoolerV2.sol#L305-L317)

`rescueERC20(address token, address to, uint256 amount)` is owner-only and accepts any ERC20, including BPT, USDC, sUSDS, and waUSDC dust. The dev comment claims it "does not expand the owner trust surface" because the owner already has `withdrawBPT` and `pool()` — but `rescueERC20` is strictly broader: (1) it covers every token the dispatcher may hold, not just BPT; and (2) it bypasses the `Pausable` guard, so the owner can still extract any token when the dispatcher has been paused in response to an incident.

**Impact**: Centralization observation. The compromised-owner branch is covered by the project's owner-trust known-issue assumption. The new insight is the pause-bypass — operators believing "pause = funds safe until investigation" are wrong on this surface, and the misleading dev comment understates the capability.

**Recommendation**: Pause-gate `rescueERC20`. If the rescue path must be available during a pause, restrict it to a hard-coded denylist of expected protocol tokens (BPT, sUSDS, waUSDC, USDC) or place it behind a short timelock so a compromised-owner rescue can be cancelled. At minimum, update the dev comment to reflect that the function can sweep any token, including protocol-owned BPT.

---

## [L-10] Donation skip silently drops caller's `minUSDC` slippage parameter

**Location**: [`BalancerPoolerV2.sol#L207-L243`](https://github.com/Behodler/yield-claim-nft/blob/c67d3c98adf1c1b25b4cfcf26c9c964cb92ca3d5/src/V2/dispatchers/BalancerPoolerV2.sol#L207-L243)

`donationActive` requires `donationSUSDS > 0 && batchMinter != address(0) && swapPool != address(0) && waUsdc != address(0) && usdc != address(0)`. If any of these are false, the donation phase is skipped silently — all sUSDS flows to the LP add and the caller-supplied `minUSDC` parameter is never checked. The race condition (owner reconfigures `batchMinter` or `swapPool` between the pooler's quote and the tx landing) is realistic on mainnet block timings; the rounding-to-zero branch is also reachable for tiny dispatches.

**Impact**: Caller-intent / spec violation. The pooler's slippage bound is silently downgraded, and only the absence of `BatchDonated` distinguishes "intentionally skipped" from "config disabled". The pooler is operator-controlled so this is not directly exploitable, but the contract's behaviour diverges from a natural reading of its interface.

**Recommendation**: If the caller passes a non-zero `minUSDC` and donation is configured off, revert with a clear error (e.g. `DonationDisabled()`). Alternatively, emit an explicit `DonationSkipped` event with a reason code so off-chain monitors can detect the silent downgrade, or add a `wantsDonation` boolean to `pool()` that must match the configured state.

---
