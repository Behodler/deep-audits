# QA Report for phoenix-nft-staking (run-18)

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| Centralization | 0 |
| **Total** | **3** |

All three Low findings are non-obvious owner/operational footguns (Law-3 in scope): a competent, non-malicious owner could be surprised by each consequence. None has an attacker path; none requires a coded PoC. Each was second-opinion confirmed as Low (downgraded from Medium) and is parked here visibly — recall-beats-tidiness — rather than dropped. An automated 4naly3er QA/gas report is attached as an appendix in `4naly3er-report.md`.

---

## Low Risk Findings

### [L-01] InPlaceNFTStakerMigrator missing stakedId/stakedToken consistency assertion <!-- id: pns18l1 -->

**Location**: [InPlaceNFTStakerMigrator.sol#L93-L109](../../../../lib/phoenix-nft-staking/src/InPlaceNFTStakerMigrator.sol#L93-L109) (constructor), with the `totalParked` floor at [InPlaceNFTStakerMigrator.sol#L281-L289](../../../../lib/phoenix-nft-staking/src/InPlaceNFTStakerMigrator.sol#L281-L289).

**Description**: The migrator constructor accepts `_stakedToken` and `_stakedId` as independent arguments and never cross-checks them against the immutable staker's own `stakedToken()` / `stakedId()`. The migrator parks ERC1155 stake under its own `stakedId`, but every exit path moves the staker's immutable id:
- `migrateIn` → `staker.depositFor(user, amount)` deposits against the staker's `stakedId`, and
- `claimTimedOut` / `rescueERC1155` operate on the migrator's `stakedId`.

If the owner deploys with a `_stakedId` that does not match the live staker's `stakedId()`, in-place migration parks stake under one id while every exit attempts to move a different id. Both exits revert, stranding parked principal. The `rescueERC1155` surplus path is no help: it is floor-blocked by `totalParked` (any amount dipping below the floor reverts), so the parked principal cannot be swept out either.

This is a deploy-time owner misconfiguration with no attacker path. It would surface in the first migration test run — but the code provides no wire-time guard, so a mismatched mainnet deployment strands principal silently until the first `migrateIn`.

**Root note**: An on-chain constructor `require` is *structurally impossible* today because the `INFTStakerMigratable` interface ([INFTStakerMigratable.sol](../../../../lib/phoenix-nft-staking/src/INFTStakerMigratable.sol)) does not expose `stakedId()` / `stakedToken()`. The cross-check cannot be written without first extending the ABI.

**Recommendation**: Add `stakedId()` and `stakedToken()` getters to `INFTStakerMigratable`, then add a constructor cross-check so a mismatch reverts at wire-time instead of stranding principal at migration time:

```solidity
require(
    staker.stakedId() == _stakedId && address(staker.stakedToken()) == address(_stakedToken),
    "InPlace: staker id/token mismatch"
);
```

Until the ABI is extended, treat the id/token match as a hard deploy-script invariant and assert it off-chain before broadcasting.

---

### [L-02] Un-try/catch'd dispatcherHook.pull() can DoS interactions and migration <!-- id: pns18l2 -->

**Location**: [NFTStakerDepletion.sol#L430](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L430) (bare `dispatcherHook.pull()` inside `_syncBudget`); recovery via `setDispatcherHook(address(0))` at [NFTStakerDepletion.sol#L328](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L328); escape via `emergencyWithdraw` at [NFTStakerDepletion.sol#L633](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L633).

**Description**: `_syncBudget` calls `dispatcherHook.pull()` directly, with no `try/catch`. `_syncBudget` runs at the head of `stake`, `unstake`, `claim`, and `initiateMigration`. If a wired hook is unauthorized to mint, mis-wired, or otherwise reverting, that revert propagates and bricks all of those core flows at once — including `initiateMigration`, blocking the very migration that would rotate the broken hook.

The damage is bounded and never traps principal:
- **Owner-recoverable in one transaction**: `setDispatcherHook(address(0))` (no empty-pool guard) makes `_syncBudget` short-circuit to a pure recompute (the `address(dispatcherHook) == address(0)` branch at L425), restoring stake/unstake/claim/migration.
- **Principal is never trapped**: `emergencyWithdraw` deliberately skips `_syncBudget` / `_updatePool` (L633), so users can always exit with principal even while the hook reverts.
- **Reward is frozen, not lost**: pending phUSD continues to accrue against the existing schedule and is paid once the hook is cleared or replaced.

The wiring precondition (hook must authorize this staker as recipient) is natspec-documented (~L105-108), and there is no attacker path. The residual risk is purely an availability footgun: a misbehaving hook degrades the contract to a hard revert on every interaction until the owner intervenes.

**Recommendation**: Wrap the `pull()` call in `try/catch` so a misbehaving hook degrades to a pure recompute (skip the inflow this round) instead of bricking core flows:

```solidity
uint256 pre = rewardToken.balanceOf(address(this));
try dispatcherHook.pull() {
    uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
    _recomputeSchedule();
    if (inflow > 0) emit Pulled(inflow, rewardBudget);
} catch {
    _recomputeSchedule(); // hook misbehaving: recompute without inflow, never brick
}
```

---

### [L-03] stake/unstake/claim not poolState-gated during Migrating; no auto-pause <!-- id: pns18l3 -->

**Location**: [NFTStakerDepletion.sol#L540](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L540) (`stake`), [#L568](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L568) (`unstake`), [#L588](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L588) (`claim`) — all `whenNotPaused` but **not** `poolState == Active` gated; contrast `depositFor` at [#L761](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L761) which **is** `Active`-gated; `initiateMigration` ([#L664](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L664)) does not auto-pause; `_updatePool` no-ops while `Migrating` at [#L454-L457](../../../../lib/phoenix-nft-staking/src/NFTStakerDepletion.sol#L454-L457).

**Description**: While the pool is in the `Migrating` state, `stake`, `unstake`, and `claim` remain callable as long as the contract is not paused — they check `whenNotPaused` but not `poolState == Active`. `depositFor` *is* `Active`-gated, and `initiateMigration` *is* `Active`-gated, so the staker already knows how to fence on pool state. The omission on the three user-facing functions is a genuine asymmetry.

This is **value-conserving** (verified — no exploit, no value leak): while `Migrating`, `_updatePool` no-ops (L454-457), so emissions are frozen and every user's pending phUSD is fixed at the `initiateMigration` snapshot and minted in full on their migration exit. Stake/unstake during the window do not corrupt the accounting. The concern is migration *hygiene*, not solvency: correct migration depends entirely on the operator remembering to pause the pool for the duration of the `migrateOut` → reset → rewire → `migrateIn` orchestration. If the operator forgets, a user can stake or unstake mid-migration, changing `totalStaked` underneath the parked-set worklist and complicating the migrator's batch reconciliation. Because the fence lives only in the runbook, not in code, this is a non-obvious snapshot-hygiene footgun.

**Recommendation**: Enforce the migration fence in code rather than relying on operator discipline. Either:
1. Gate `stake` / `unstake` / `claim` on `poolState == Active` (mirroring `depositFor`), so they revert cleanly during `Migrating`; or
2. Have `initiateMigration` auto-pause the pool (and `revivePool` / the migration-complete path unpause it), so the `whenNotPaused` guard already on these functions does double duty as the migration fence.

Option 1 is the tighter mirror of the existing `depositFor` gate.

---

## Centralization Risks

No centralization-risk findings were identified in this run. The two privileged migration surfaces (`InPlaceNFTStakerMigrator` and the staker's `onlyMigrator` / `onlyOwner` paths) are already structurally constrained — the migrator's `staker` target is immutable and the only parked-stake exits credit the original user (`migrateIn`) or return stake to the user (`claimTimedOut`), with a `totalParked` floor preventing owner sweep of parked principal. These are noted for context, not as findings.

---

## Appendix A — Automated QA / Gas Report (4naly3er)

The canonical C4-style automated QA/gas baseline was generated with **4naly3er** over the in-scope `src/` contracts (`NFTStaker.sol`, `NFTStakerPriceScaled.sol`, `NFTStakerDepletion.sol`, `NFTStakerMigrator.sol`, `InPlaceNFTStakerMigrator.sol`, `INFTStakerMigratable.sol`, `BatchNFTMinter.sol`, plus `INFTSupply.sol`).

The full machine-generated report is attached separately as [`4naly3er-report.md`](./4naly3er-report.md). It covers gas optimizations (GAS-1 … GAS-14) and non-critical / low-severity automated checks. These are bot-baseline observations and are intentionally kept separate from the manually-curated Low findings above; they are not promoted into the L-XX set because, per C4 convention, non-critical and pure gas items are reported only as the automated appendix.
