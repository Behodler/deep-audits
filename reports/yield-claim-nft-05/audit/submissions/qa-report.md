# QA Report — yield-claim-nft (Round 05)

Commit: `2805a4d`

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 8 |
| **Total** | **8** |

| ID | Title |
|----|-------|
| L-01 | Decimals mismatch between USDS and phUSD is not validated, silently mispricing mint-debt accounting |
| L-02 | Immutable dispatcher binding strands accrued debt on dispatcher replacement |
| L-03 | `BalancerPoolerMintDebtHook.pull()` is not gated by NFTMinterV2 global pause |
| L-04 | `unlockCallback` trusts vault-reported `bptAmountOut` instead of dispatcher balance delta |
| L-05 | `NFTMigrator.migrate()` quadratic gas usage and mint-debt hook asymmetry vs. `mintFor` |
| L-06 | `pull()` redirects all historical mint-debt to whatever recipient is set at call time |
| L-07 | No debt writedown; `setRatio` reduction cannot shrink ledger, supply cap can freeze `pull()` permanently |
| L-08 | `IDispatchHook` NatSpec documents observational semantics but implementation mints protocol debt |

---

## [L-01] Decimals mismatch between USDS and phUSD is not validated, silently mispricing mint-debt accounting

**Location**: [`src/V2/hooks/BalancerPoolerMintDebtHook.sol#L85-L107`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L85-L107)

**Description**:
`BalancerPoolerMintDebtHook` accrues debt as `added = amount * ratio / 100`, where `amount` is the raw USDS wei value passed into `onDispatch` by `BalancerPoolerV2`. The same integer is later handed verbatim to `phUSD.mint(recipient, debt)` inside `pull()`. Nothing in the hook reads `decimals()` of either token or performs any unit conversion — the accounting implicitly assumes `1 USDS wei == 1 phUSD wei`.

USDS is 18 decimals on Ethereum, but the hook accepts `phUSD_` as a raw `IMintable` with no decimals check. If phUSD is deployed with a different decimals value (e.g. 6), each USDS wei dispatched would mint `1e12` phUSD per USDS wei — or symmetrically under-mint in the reverse case. The stated `ratio%`-of-USDS semantics are silently broken.

**Impact**:
Protocol-wide value mis-issuance on `pull()` if the deployment ever pairs USDS with a phUSD token whose decimals differ. An inflated phUSD balance can be dumped into the sUSDS/phUSD Balancer pool that backs NFT holders, draining the sUSDS side and destroying the BPT collateral behind NFT claims. Matching decimals are currently an undocumented trust assumption on the deployer.

**Recommendation**:
Take the USDS address in the constructor and enforce `IERC20Metadata(phUSD_).decimals() == IERC20Metadata(USDS).decimals()` at construction. Alternatively, scale inside `onDispatch` using each token's on-chain decimals. Any mismatch should revert at deploy time rather than produce wrong-scale debt.

---

## [L-02] Immutable dispatcher binding strands accrued debt on dispatcher replacement

**Location**: [`src/V2/hooks/BalancerPoolerMintDebtHook.sol#L26`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L26), [`L58-L65`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L58-L65), [`L89-L95`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L89-L95)

**Description**:
The hook's `dispatcher` is `immutable`, so the hook is permanently bound to a single `BalancerPoolerV2` instance. `NFTMinterV2.replaceDispatcher` (`src/V2/NFTMinterV2.sol#L227-L247`) and `ATokenDispatcherV2.setHook` allow the owner to rotate dispatchers and hooks independently. During a rotation (new dispatcher + new hook), accrued `mintDebt` lives on the old hook and must be drained via `pull()` before or after the swap; there is no on-chain migration path to move `mintDebt` between hook contracts.

A subtler variant: because the dispatcher's `hook` pointer is mutable but the hook's `dispatcher` is not, `setHook(newHook)` on the dispatcher while the old hook still has a non-zero ledger produces a permanent split between two hook contracts that look identical from the outside. The `pull()` capability on the old hook remains intact, but operators and off-chain tooling must know to drain both.

**Impact**:
Operational risk during dispatcher/hook rotation. A distracted rotation can strand accrued debt on an orphaned hook whose existence is not advertised anywhere at the NFTMinter level. No fund loss — owner/recipient can always still call `pull()` — but accounting gets split across contracts that look interchangeable.

**Recommendation**:
Either (a) add a one-shot, `onlyOwner` `transferDebt(address newHook)` that forwards `mintDebt` state to a successor hook; or (b) document a hard runbook requiring `pull()` on the old hook before calling `setHook` on the dispatcher; or (c) replace the `immutable dispatcher` with an `onlyOwner setDispatcher` flow that emits an event, keeping the `msg.sender == dispatcher` check enforced against the current stored value.

---

## [L-03] `BalancerPoolerMintDebtHook.pull()` is not gated by NFTMinterV2 global pause

**Location**: [`src/V2/hooks/BalancerPoolerMintDebtHook.sol#L100-L107`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L100-L107)

**Description**:
`NFTMinterV2` has a pauser-controlled global pause (`src/V2/NFTMinterV2.sol#L111-L115`) that blocks `_executeMint`. Dispatch flow through `BalancerPoolerV2` is also blocked while paused, which correctly halts new debt accrual in the hook. However, the hook itself has no link to the pauser role and no emergency-stop control surface — `pull()` remains fully callable during a protocol pause by `owner || recipient`, and freshly mints phUSD against the already-accrued ledger.

If the pause is triggered in response to a dispatcher-level issue (e.g. an sUSDS deposit accounting bug), the ability to still realise historical debt as circulating phUSD directly undermines the freeze.

**Impact**:
Global pause is incomplete: phUSD can continue to be minted via `pull()` while the rest of the protocol is stopped. The attack surface is bounded by the owner/recipient trust assumption, but the gap is specifically relevant for the pauser role — a lower-trust emergency-response actor whose action is meant to stop all value-issuing operations.

**Recommendation**:
Either (a) inherit the same pauser pattern as `NFTMinterV2` and gate `pull()` on a local paused flag; (b) pass `NFTMinterV2` into the constructor and have `pull()` read `NFTMinterV2.paused()` as a live circuit-breaker; or (c) document explicitly that hook-resident mint-debt is decoupled from protocol pause so integrators build their runbooks accordingly.

---

## [L-04] `unlockCallback` trusts vault-reported `bptAmountOut` instead of dispatcher balance delta

**Location**: [`src/V2/dispatchers/BalancerPoolerV2.sol#L129-L165`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/dispatchers/BalancerPoolerV2.sol#L129-L165)

**Description**:
`unlockCallback` applies a balance-before/after check around the sUSDS going into the vault (`vaultBefore`, `actualInVault`) as a defensive measure against FOT-style or hook-mutating token behaviour. The symmetric pattern is NOT applied to the BPT flowing back to the dispatcher. The emitted `Pooled(pooler, actualInVault, bptAmountOut, minBPT)` event and the `minBPT` slippage comparison both use the vault's self-reported return value.

For a vanilla Balancer V3 pool these values are equivalent. Balancer V3 supports pool hooks that can legitimately settle a different credited amount than the value returned from `addLiquidity`. Treating the return value as authoritative for event reporting is inconsistent with the rest of the function, and any off-chain treasury accounting that trusts `Pooled` could diverge from the on-chain BPT balance if the target pool ever uses such hooks.

**Impact**:
Integrity gap between the `Pooled` event and real BPT holdings when the target sUSDS/phUSD pool is backed by a Balancer V3 pool hook that alters crediting. No present-day exploit path against a vanilla pool; the finding is about robustness and accounting consistency for future pool migrations.

**Recommendation**:
Apply the same balance-before/after pattern for BPT as for sUSDS:

```solidity
uint256 bptBefore = IERC20(_pool).balanceOf(address(this));
// ... addLiquidity call ...
uint256 actualBpt = IERC20(_pool).balanceOf(address(this)) - bptBefore;
if (actualBpt < minBPT) revert SlippageExceeded();
emit Pooled(pooler, actualInVault, actualBpt, minBPT);
```

This eliminates any possible event/state divergence and makes slippage enforcement track the actual dispatcher receipt.

---

## [L-05] `NFTMigrator.migrate()` quadratic gas usage and mint-debt hook asymmetry vs. `mintFor`

**Location**: [`src/V2/NFTMigrator.sol#L65-L75`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/NFTMigrator.sol#L65-L75), [`src/V2/NFTMinterV2.sol#L206-L214`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/NFTMinterV2.sol#L206-L214)

**Description**:
`NFTMigrator.migrate()` iterates over every V1 index in `[1, v1.nextIndex())` and, for each index with `balance > 0`, calls `v2.mintFor(v2Index, msg.sender)` once per unit held via an inner `for j in balance` loop. Each `mintFor` writes an ERC-1155 storage slot, emits `TransferSingle` + `ClaimMintedFor`, and invokes any receiver callback. A user holding 1000 NFTs at a single index pays gas for 1000 separate single-unit mints in one transaction.

In addition, `mintFor` bypasses the dispatcher entirely — no `ATokenDispatcherV2.dispatch`, no `IDispatchHook.onDispatch` — so `BalancerPoolerMintDebtHook` does not accrue any `mintDebt` on migrated NFTs. This is defensible as an intentional design choice (migration is not a new economic event), but the advertised `ratio%` tax is therefore a tax on new mints only, and the phUSD-debt beneficiary is systematically under-compensated for migrated supply that ends up backed by the same BPT.

**Impact**:
Two independent issues:
- Operational: users with large V1 balances can hit the block gas limit and be forced to split migration across multiple EOAs or multiple transactions. Friction only, no fund loss.
- Economic: the mint-debt mechanism is not applied to migrated NFTs despite their equivalent backing. If migration represents significant supply, the hook's recipient receives proportionally less phUSD than the protocol's stated ratio would imply across all outstanding NFTs.

**Recommendation**:
Add `mintForBatch(uint256 index, address recipient, uint256 quantity)` to `NFTMinterV2` that calls `_mint(recipient, index, quantity, "")` once, and collapse the inner loop in `migrate()` to a single call. ERC-1155 natively handles quantities > 1, so this is a pure gas win with no semantic change. Separately, document explicitly whether the mint-debt hook is intended to apply to migrated NFTs; if yes, wire a hook path through `mintFor` (or `mintForBatch`); if no, document the asymmetry.

---

## [L-06] `pull()` redirects all historical mint-debt to whatever recipient is set at call time

**Location**: [`src/V2/hooks/BalancerPoolerMintDebtHook.sol#L76-L107`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L76-L107)

**Description**:
`pull()` mints the full `mintDebt` ledger to the address currently stored in `recipient`. `setRecipient` is `onlyOwner` with no timelock, no cap, and no snapshot of the pre-existing debt. The practical semantics are therefore "whoever is `recipient` at the moment `pull()` fires collects 100% of the historical ledger", regardless of who was beneficiary while that debt accrued.

Because `pull()` is callable by either owner or recipient, any rotation of the recipient can be front-run or back-run by the outgoing or incoming party, and the entire historical balance is unilaterally claimed by whichever side acts first. There is no mechanism to carve off pre-existing debt.

**Impact**:
Accrued phUSD mint-debt can be redirected wholesale from the intended beneficiary to a successor (or vice versa) by a single owner call, with no way to split the ledger. Any operational timing error or race between outgoing and incoming recipients causes material amounts of phUSD to materialise at the wrong address. Because recipients are likely treasury or multisig accounts, the ordering risk is an operational attack surface rather than a pure owner-trust concern.

**Recommendation**:
Pick one of:
- Require `mintDebt == 0` as a precondition of `setRecipient`, forcing the owner to call `pull()` for the outgoing recipient first.
- Have `setRecipient(newRecipient)` atomically settle the outstanding debt to the old recipient before updating the pointer.
- Maintain per-recipient debt ledgers keyed by address so each recipient is only ever paid what was accrued under their tenure.

---

## [L-07] No debt writedown; `setRatio` reduction cannot shrink ledger, supply cap can freeze `pull()` permanently

**Location**: [`src/V2/hooks/BalancerPoolerMintDebtHook.sol#L67-L74`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L67-L74), [`L97-L107`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L97-L107)

**Description**:
`setRatio(newRatio)` only changes the rate at which NEW dispatches accrue debt — it does not modify `mintDebt`. There is no `writeDown(uint256)`, no `setMintDebt`, no partial-cancellation path, and no admin clawback. Once debt has accrued under an unintended ratio, the only way to clear it is to call `pull()`, which mints the entire (possibly inflated) amount to `recipient`.

Compounding this: if phUSD has a supply cap (common for algorithmic stablecoins or wrapped USD designs) and `mintDebt` exceeds remaining headroom, `pull()` reverts inside `phUSD.mint`. With no partial-pull, no cap-awareness, and no writedown, the ledger becomes permanently stuck while new dispatches keep growing it. `setRatio(0)` stops new accrual but does not unfreeze the stuck ledger.

**Impact**:
Structural mechanism-design flaw: any `setRatio` error is irrevocable except by printing the mistake into circulating phUSD supply. In combination with a phUSD supply cap, the hook's only settlement path can be bricked, leaving an unredeemable ledger that continues to grow on every subsequent dispatch.

**Recommendation**:
Add an `onlyOwner` `writeDown(uint256 amount)` that decrements `mintDebt` without minting, and/or make `pull(uint256 amount)` accept a partial value so the ledger can be drained incrementally under a cap. Consider adding an explicit `maxDebt` parameter so `onDispatch` caps accrual once the outstanding obligation exceeds a protocol-configured ceiling.

---

## [L-08] `IDispatchHook` NatSpec documents observational semantics but implementation mints protocol debt

**Location**: [`src/V2/interfaces/IDispatchHook.sol#L4-L12`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/interfaces/IDispatchHook.sol#L4-L12), [`src/V2/hooks/BalancerPoolerMintDebtHook.sol#L85-L107`](https://github.com/Behodler/yield-claim-nft/blob/2805a4d/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L85-L107)

**Description**:
The `IDispatchHook` NatSpec describes an "observation hook invoked by V2 dispatchers after `_dispatch` completes" and instructs implementers to treat calls as side-effect-free telemetry. `BalancerPoolerMintDebtHook` violates that contract in three substantive ways:

1. It mutates authoritative protocol state (`mintDebt += added`) on every dispatch.
2. `pull()` mints unbacked phUSD to a recipient — a direct value-issuing side-effect.
3. The hook effectively acts as a pseudo-treasury: it is the sole system-of-record for how much phUSD is owed, yet the interface gives hooks no such status.

A related implementation subtlety: `onDispatch` early-returns silently when `added == 0` (e.g. when `amount * ratio < 100`), so any dispatch below the rounding floor accrues no debt and emits no event. Combined with the observational-by-spec framing, future hook authors and integrators copying this pattern will make wrong assumptions about when a dispatch has triggered a value-issuing side-effect.

**Impact**:
Interface semantics do not describe real behaviour, producing two concrete risks: (a) the `added == 0` silent early-return means dispatches under the rounding floor succeed with zero debt, with no event and no visible signal — a below-floor minter gets a different protocol-state outcome than an above-floor minter; (b) legitimately-observational telemetry hooks and value-issuing hooks share the same interface with no type-level distinction, so `ATokenDispatcherV2.setHook` silently changes the economic contract of the dispatcher when rotated between the two.

**Recommendation**:
Two complementary fixes:
1. Rewrite the `IDispatchHook` NatSpec to reflect actual permitted semantics: hooks MAY mutate state, MAY issue tokens, MAY revert, and MUST NOT be treated as side-effect-free. Add explicit guidance that `setHook` can change the value-issuing behaviour of the dispatcher and should therefore be gated by protocol-level governance.
2. Remove the silent `if (added == 0) return;` branch in `BalancerPoolerMintDebtHook.onDispatch`. Either revert when the dispatched amount is too small to accrue, or emit a `DebtSkipped` event so the dust-rounding surface is visible in the event log.
