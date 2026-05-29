# QA Report — phoenix-nft-staking (nft-staking-08)

This QA report bundles all Low-severity findings identified in the nft-staking-08 audit run. No Centralization-risk findings were raised in this run (the project's owner-trust model is documented in prior known-issue submissions and was not amplified by the new code paths under review).

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 6 |
| Centralization | 0 |
| **Total** | **6** |

Scope of new code reviewed: `BatchNFTMinter.sol` (newly introduced), `NFTStaker._recomputeSchedule` (M-03 fix from prior audit). All findings are concentrated in these two surfaces.

---

## Low Risk Findings

### [L-01] `batchMint` has no per-mint or cumulative price ceiling; front-runner can gas-grief the entire batch

**Location**: [`BatchNFTMinter.sol#L60-L78`](https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/BatchNFTMinter.sol#L60-L78)

**Description**: `batchMint` does not accept a `maxStartingPrice` or `maxCumulativePrice` argument. Because the dispatcher's `price` compounds by `growthBasisPoints` per mint, any concurrent mint inserted between an honest user's submission and inclusion can push the cumulative cost above the prepaid `paymentAmount`. The whole batch then unwinds atomically (per the contract's documented rollback behavior on L26-L27).

**Impact**: No principal loss — atomic rollback returns the prepayment. The damage is repeated denial of the batch entrypoint on a contested mempool, plus the wasted gas for each reverted attempt. Front-runners secure the cheaper slot the honest user was targeting.

**Recommendation**: Add a `maxStartingPrice` (or `maxCumulativePrice`) parameter and revert at the top of the call if `nftMinter.configs(dispatcherIndex).price > maxStartingPrice`. A coarser `maxPaymentPerMint` ceiling would also bound the user's downside.

---

### [L-02] `batchMint` pre-approves `nftMinter` for `type(uint256).max` across the entire loop

**Location**: [`BatchNFTMinter.sol#L70-L76`](https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/BatchNFTMinter.sol#L70-L76)

**Description**: Allowance is granted as `type(uint256).max` before the mint loop and reset to zero only after the loop completes. For the duration of the loop the dispatcher (and any callback path it can trigger) is authorised to pull the contract's full prepaid `paymentAmount` rather than only the metered per-mint `price`. The contract also explicitly omits `ReentrancyGuard`, widening the surface for any future dispatcher with a callback hook.

**Impact**: Latent. The post-loop `forceApprove(nftMinter, 0)` ensures no allowance survives the call, and the current `BalancerPoolerV2` dispatcher does not exhibit pull-too-much behavior. Risk materialises only if an owner-registered dispatcher later turns hostile or gains a callback bug.

**Recommendation**: Replace the max approval with `paymentToken.forceApprove(address(nftMinter), paymentAmount)` so dispatcher authority is bounded by what the user already authorised. Optionally re-approve per iteration with `nftMinter.getPrice(dispatcherIndex)` for a tighter window, and update the L29 NatSpec note about the omitted reentrancy guard accordingly.

---

### [L-03] `batchMint` collapses multi-tx mint cadence into a single tx, amplifying prior-audit L-04 runway depletion and concentrating the early-minter premium

**Location**: [`BatchNFTMinter.sol#L65-L78`](https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/BatchNFTMinter.sol#L65-L78)

**Description**: A single `batchMint(count=N)` produces `latestPrice * (1+g)^N` and accumulates `mintDebt` for N mints atomically. This (a) accelerates `NFTStaker` runway depletion via the next `_recomputeSchedule` (the prior-audit Low previously framed as a multi-tx concern collapses to a single tx), and (b) lets a single first-batch caller capture the entire geometric early-minter premium pool (`r^N + r^(N-1) + … + r^1`) before any organic minter can compete for early slots.

**Impact**: No principal loss to honest stakers — the geometric APY-as-floor behavior is documented intentional design and later stakers still receive `targetAPY`. The novel risk is that batched first-mover capture removes the arrival-order competition the original cadence implicitly assumed, and the runway-shortening angle is achievable in one tx instead of a coordinated campaign.

**Recommendation**: Cap `count` per `batchMint` invocation (e.g. `MAX_BATCH = 10` or `32`) so wholesale early-minter capture requires multiple separate transactions. Stronger fix: per-block / per-tx mint-rate limit at the `NFTMinterV2` dispatcher layer that batched calls cannot bypass. Document the runway-stability implication in `BatchNFTMinter` NatSpec so operators size top-up buffers accordingly.

---

### [L-04] `_recomputeSchedule` computes `totalStaked * latestPrice` with bare multiplication, unprotected against future high-supply / high-price configs

**Location**: [`NFTStaker.sol#L401`](https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/NFTStaker.sol#L401)

**Description**: `_recomputeSchedule` computes the staked-subset notional as `S = totalStaked * latestPrice` with no overflow guard. NatSpec bounds the product at ~1e27 under current parameters, but `totalStaked` is not enforced on-chain. A future `stakedId` rotation to a higher-supply token combined with sustained `growthBasisPoints` mints can push the product past `2^256`, at which point Solidity 0.8 checked arithmetic reverts.

**Impact**: No exploitable loss today. If parameters drift outside the documented envelope, `_recomputeSchedule` reverts and DoS-es every user-facing function (`stake` / `unstake` / `claim` / `topUp` / `setTargetAPY` / `setDispatcherIndex` / `setNFTMinter` / `pullAndRefresh`) except `emergencyWithdraw`. Solvency is preserved — principal remains recoverable via `emergencyWithdraw` (forfeiting pending reward).

**Recommendation**: Add a defensive precheck `require(latestPrice == 0 || totalStaked <= type(uint256).max / latestPrice, NFTStaker__SOverflow())` before the bare multiplication, with a typed error so monitoring can react before total-interaction DoS sets in. Alternatively switch to `Math.mulDiv` and bound the result at a documented safe ceiling.

---

### [L-05] `totalPaid` returns 0 when caller actually paid `paymentAmount` and received an unrelated donation refund as a windfall

**Location**: [`BatchNFTMinter.sol#L78-L84`](https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/BatchNFTMinter.sol#L78-L84)

**Description**: When a third-party donation pre-loads the `BatchNFTMinter` contract balance, `remaining > paymentAmount` after the loop. The clamp `paymentAmount > remaining ? paymentAmount - remaining : 0` returns `totalPaid = 0` even though the dispatcher pulled real cost from the contract. Off-chain integrators that record call cost from the return value will treat a paid mint as free.

**Impact**: No on-chain asset loss — the caller's net wallet position is correct (paid the dispatcher the real cost, received a donor-funded refund as windfall). The defect is confined to the helper's return value, which is misleading to any off-chain accounting consumer.

**Recommendation**: Snapshot the pre-call contract balance and compute `totalPaid = (paymentAmount + preBal) > remaining ? (paymentAmount + preBal) - remaining : 0` so the return value reflects the actual contract balance delta. Alternatively, document in NatSpec that `totalPaid == 0` does not imply a zero-cost mint when donations are present.

---

### [L-06] `batchMint` forfeits dispatcher-side slippage protection by passing empty `extraData` on every iteration

**Location**: [`BatchNFTMinter.sol#L65-L78`](https://github.com/Behodler/phoenix-nft-staking/blob/b9272e483a04a82060b37dd722b818b2b7aa3a40/src/BatchNFTMinter.sol#L65-L78)

**Description**: `BatchNFTMinter` calls the no-`extraData` overload of `ITokenMinter.mint`. The interface NatSpec documents `extraData` as the channel for dispatcher-specific slippage parameters. The `BalancerPooler` family of dispatchers routes payment through a Balancer pool swap; a single-mint caller can choose the `extraData` overload and pass slippage bounds, but a batch caller cannot reach it. Every iteration of the loop therefore performs an unprotected pool swap on the price-routing leg.

**Note on severity**: This finding was originally classified as a Medium candidate (DEDUP-003 / CLASS-003) on the basis that loss of slippage protection extracts real value rather than just gas. It was demoted to Low during PoC validation for two reasons: (1) the attack path is gated by M-01 (`BatchNFTMinter` is DOA against the production V2 dispatcher today, so the loss path is unreachable until M-01 is fixed); and (2) on the realistic M-01 fix (retarget to V2), the V2 `BalancerPoolerV2._dispatch` ignores `extraData` entirely — slippage protection is enforced via a separate owner-only `pool(minBPT)` function, so there is no per-mint slippage surface for `batchMint` to forward to. The recommendation is retained as forward-looking interface hygiene rather than a Medium submission.

**Impact**: Conditional. Today: unreachable (M-01 gates execution). Post-M-01-fix: structurally absent at the V2 dispatcher level. The residual concern is interface-contract drift — if a future dispatcher version reintroduces per-mint slippage params via `extraData`, the batch path will silently bypass them.

**Recommendation**: Add an `extraData` (single shared) or `bytes[] calldata extraDatas` (per-iteration) parameter to `batchMint` and forward it to the slippage-aware mint overload. When the M-01 retargeting to V2 lands, route through `ITokenMinterV2.mint(uint256,address,bytes)` so any future per-mint slippage hook on the V2 dispatcher remains reachable from the batch path.

---
