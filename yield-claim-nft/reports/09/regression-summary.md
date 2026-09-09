# yield-claim-nft — Regression Audit (run yield-claim-nft-09)

**Mode:** REGRESSION
**Baseline (prior `lastAuditedCommit`):** `bc99ee3`
**Audited HEAD:** `cf75ec9520fd16b19e20c4b77ada2be28d7d4382`
**Commits in scope:** `843953e`, `cf75ec9` — both `[story-034]`
**Date:** 2026-06-04

## Scope of change

`[story-034]` rebuilt the BalancerPoolerV2 batch-donation route. Files changed:

| File | Change |
|---|---|
| `src/V2/interfaces/ISkyPSM.sol` | **NEW** — minimal `ISkyPSM` interface |
| `src/V2/dispatchers/BalancerPoolerV2.sol` | Donation moved into `_dispatch` via Sky PSM `buyGem`; `pool()` becomes a pure LP add (its `minUSDC` arg removed); added `psm`/`maxTout`/`batchMinter`/`batchDonationSize` + setters |
| `src/V2/hooks/BalancerPoolerMintDebtHook.sol` | `dispatcher` made mutable storage + owner-gated `setDispatcher` |
| `test/**`, `test/mocks/MockSkyPSM.sol` | Tests + faithful PSM mock (out of scope) |

## Verdict

**No new High/Medium findings. No regressions. story-034 is sound and actually closes a prior Low (L-03).**

The two specific concerns raised for this run were both investigated directly against ground truth and **clear**:

---

### Concern 1 — "Is the shape of the Sky dependencies correct, not hallucinated?" → ✅ FAITHFUL

The `ISkyPSM` interface and the `_psmDonate` fee/decimal math were cross-checked against the **live canonical source** — Sky `UsdsPsmWrapper.sol` (`sky-ecosystem/usds-wrappers`, `dev` branch), which proxies the Maker `DssLitePsm`.

Live source:
```solidity
function buyGem(address usr, uint256 gemAmt) external returns (uint256 usdsInWad) {
    uint256 gemAmt18 = gemAmt * to18ConversionFactor;
    usdsInWad = gemAmt18 + gemAmt18 * psm.tout() / WAD;
    usds.transferFrom(msg.sender, address(this), usdsInWad);
    usdsJoin.join(address(this), usdsInWad);
    legacyDaiJoin.exit(address(this), usdsInWad);
    psm.buyGem(usr, gemAmt);
}
```

Correspondence verified:

| Property | Live `UsdsPsmWrapper` | Audited code | Result |
|---|---|---|---|
| `buyGem(address usr, uint256 gemAmt) → uint256 usdsInWad` | ✓ | `ISkyPSM.buyGem` identical | ✅ |
| Pulls **USDS** (not DAI) from `msg.sender` | `usds.transferFrom(msg.sender,…)` | `forceApprove(psm,usdsSpent)` then `buyGem` | ✅ |
| Gem (USDC) delivered to the `usr` arg | `psm.buyGem(usr, gemAmt)` | passes `batchMinter` as `usr` | ✅ |
| `gemAmt` in gem decimals (USDC, 6dp) | ✓ | sized in 6dp | ✅ |
| `to18ConversionFactor = 1e12` (USDC) | immutable | used as `conv` | ✅ |
| `tout()/tin()` WAD fee getters | present | declared identically | ✅ |
| Fee math `usdsIn = gemAmt·conv + gemAmt·conv·tout/WAD` | ✓ | `usdsSpent = gemAmt·conv·(WAD+tout)/WAD` | ✅ **arithmetically identical** |

The fee algebra is provably exact (`A·WAD` divides `WAD`, so both forms equal `A + ⌊A·tout/WAD⌋`). Consequences:
- `usdsSpent` equals the PSM's `transferFrom` pull **to the wei** ⇒ the `forceApprove(psm, usdsSpent)` is exactly sized, never short (no allowance revert), never over-approved (`forceApprove(psm,0)` tidies after).
- `gemAmt = ⌊usdsAmount·WAD / (conv·(WAD+tout))⌋` guarantees `usdsSpent ≤ usdsAmount`, so the swept balance always covers the swap and the remainder floors to protocol-held dust (re-swept next dispatch).

**Conclusion:** the Sky interface was *not* guessed. Shape, direction of transfer, recipient, decimals, and fee math all match the deployed contract. The header NatSpec address (`0xA188EEC8F81263234dA3622A406892F3D630f98c`) should still be confirmed against the live registry at deploy time, but the *shape* is correct.

---

### Concern 2 — "minterDebt hook should allow owner-gated `setDispatcher`" → ✅ PRESENT & CORRECT

`BalancerPoolerMintDebtHook.setDispatcher` (lines 98–103):
```solidity
function setDispatcher(address newDispatcher) external onlyOwner {
    require(newDispatcher != address(0), "dispatcher=0");
    address old = dispatcher;
    dispatcher = newDispatcher;
    emit DispatcherUpdated(old, newDispatcher);
}
```
- `onlyOwner` gated ✓
- non-zero check ✓
- `dispatcher` is now mutable storage (was implicitly fixed), and `onDispatch` is gated `if (msg.sender != dispatcher) revert OnlyDispatcher()` ✓ — so only the current pooler can accrue debt.
- Test coverage confirms it: `test_setDispatcher_revertsForNonOwner`, `test_setDispatcher_revertsOnZeroAddress`, `test_setDispatcher_updatesOnDispatchGate`, `test_setDispatcher_debtAccruesOnGrossAmount`, `test_setDispatcher_updatesStorageAndEmits` — all pass.

Trust model is unchanged: the owner is already fully trusted (holds `setHook`, `setRecipient`, `setRatio`). A repointable dispatcher adds no new attacker surface. Operational note (already in NatSpec): `pull()` outstanding `mintDebt` before repointing so the ledger is clean across a pooler swap — failing to do so mints accrued debt to the *current* recipient, but that is owner operational hygiene, not a vulnerability.

---

## Ledger reconciliation

| Label | Title | Prior status | This run |
|---|---|---|---|
| L-03 | Donation swap `limitRaw=0` / no oracle reference | qa-bundled | **FIXED** — story-034 removed the Balancer donation swap; fixed-rate PSM has no price curve/slippage |
| L-02 | `setRatio` accepts `ratio == MAX_RATIO` (contradicts strict-`<` doc) | qa-bundled | **still live** (line-drifted to 77–82; check remains `> MAX_RATIO`, so `50` is accepted) |
| Q-02 | Unchecked ERC4626 `deposit()` return in `_dispatch` | qa-bundled | **still live** (line-drifted to ~218) |
| M-01, M-02 | NFTMigrator gas-DoS / index-0 brick | submitted | untouched (file unchanged) |
| L-01, Q-01, Q-03, Q-04, C-01 | (NFTMinterV2 / NFTMigrator / ATokenDispatcherV2) | qa-bundled | untouched |

## Informational (QA, owner-trust — not a formal finding)

`mintDebt` accrues on the **gross** dispatched USDS (`amount·ratio/100`), while up to `batchDonationSize%` of that USDS permanently leaves the protocol as USDC to `batchMinter` and only `(100−donationSize)%` is pooled as sUSDS backing. phUSD backing is therefore governed by the *product* of two **independently** owner-set, mutually-unguarded parameters living in two different contracts (`ratio` in the hook, `batchDonationSize` in the pooler). A coordinated misconfiguration (e.g. `donationSize=100`, `ratio=49`) silently under-backs phUSD. This is explicitly documented as intended (`BalancerPoolerV2.sol:196–200`) and requires no non-owner action, so under the stated owner-trust model it is **QA at most**, not Medium+. Flagged for the owner's awareness.

## Tooling

- `forge build`: clean (lint-only suggestions).
- `forge test` story-034 suites: `BalancerPoolerV2.t.sol` 81/81 pass · `BalancerPoolerMintDebtHook.t.sol` 33/33 pass.
- Slither on `BalancerPoolerV2.sol`: only naming-convention / solc-version noise (the ignored `buyGem` return is intentional — `usdsSpent` is pre-sized exactly and USDC ships directly to `batchMinter`).
- econ-scanner (independent pass): no Medium+ value-flow finding in scope.

## Sources

- Live Sky PSM wrapper: https://github.com/sky-ecosystem/usds-wrappers/blob/dev/src/UsdsPsmWrapper.sol
- Underlying Maker LitePSM math: `makerdao/dss-lite-psm` `DssLitePsm._buyGem`
- Sky LitePSM docs: https://developers.sky.money/guides/psm/litepsm/
