# QA Report for yield-claim-nft (Report 08)

Scope: `lib/yield-claim-nft` @ `bc99ee3`

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| QA / Non-Critical | 4 |
| Centralization | 1 |
| **Total** | **8** |

All findings below are non-exploitable in scope: they are spec deviations, defense-in-depth hardening, code-hygiene notes, or owner-gated design considerations. None places user funds at direct risk.

---

## Low Risk Findings

### [L-01] NFTMinterV2._executeMint lacks ReentrancyGuard (cross-index re-entry not blocked) <!-- id: ycn8l1 -->

**Location**: [`src/V2/NFTMinterV2.sol#L170-L201`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L170)

**Description**: The `nonReentrant` guard lives on the dispatcher (`ATokenDispatcherV2.sol:118-126`), not on `NFTMinterV2` itself, so re-entry into `_executeMint` targeting a *different* dispatcher index is not blocked at the minter level. No in-scope dispatcher makes a re-entrant external call today (in-scope hooks make no external calls in `onDispatch`, and `BalancerPoolerV2._dispatch` only does `forceApprove` + `ERC4626.deposit`), so this is a latent defense-in-depth gap, not exploitable in the current code.

**Recommendation**: Add a `nonReentrant` modifier to `NFTMinterV2._executeMint` (or the public entrypoints that reach it) so cross-index re-entry is blocked at the minter level regardless of any future dispatcher that may be added.

---

### [L-02] setRatio accepts ratio == MAX_RATIO, contradicting documented strict-less-than invariant <!-- id: ycn8l2 -->

**Location**: [`src/V2/hooks/BalancerPoolerMintDebtHook.sol#L93`](../../../lib/yield-claim-nft/src/V2/hooks/BalancerPoolerMintDebtHook.sol#L93)

**Description**: `setRatio` guards with `if (newRatio > MAX_RATIO) revert` while the NatSpec/invariant (lines 29, 47, 91) states the ratio must be *strictly less than* `MAX_RATIO` (= 50). The value `ratio == 50` is therefore accepted in contradiction of the documented bound. No asset impact: the downstream `added = amount * ratio / 100` truncation rounds in the harmless direction.

**Recommendation**: Change the guard to `if (newRatio >= MAX_RATIO) revert` to match the documented strictly-less-than invariant, or update the NatSpec to permit equality if equality is actually intended.

```solidity
if (newRatio >= MAX_RATIO) revert RatioTooHigh();
```

---

### [L-03] Donation swap uses limitRaw=0, relying solely on a pooler-supplied minUSDC floor (no on-chain oracle/TWAP reference) <!-- id: ycn8l3 -->

**Location**: [`src/V2/dispatchers/BalancerPoolerV2.sol#L214-L243`](../../../lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L214)

**Description**: `pool()` performs the donation swap with `limitRaw=0`, with the only slippage protection being the `minUSDC` floor supplied by the caller; there is no independent on-chain price reference (oracle/TWAP). `pool()` is `onlyAuthorizedPooler + whenNotPaused + nonReentrant`, and a pooler passing a weak/zero `minUSDC` is itself a role mistake. Downgraded from Medium: protection is delegated to an off-chain-chosen floor from a semi-trusted role, and the value at risk is the owner-configured donation slice destined for the `batchMinter` flow, not user deposits.

**Recommendation**: Add an independent on-chain price reference (oracle or TWAP) to derive or sanity-check the swap floor, and/or enforce a non-zero minimum on `minUSDC` so a pooler cannot pass an unprotected (zero) floor.

---

## QA / Non-Critical Findings

### [Q-01] Missing zero-address validation in constructors (NFTMigrator, BurnerV2, GatherV2) <!-- id: ycn8l4 -->

**Location**: [`src/V2/NFTMigrator.sol`](../../../lib/yield-claim-nft/src/V2/NFTMigrator.sol), [`src/V2/dispatchers/BurnerV2.sol`](../../../lib/yield-claim-nft/src/V2/dispatchers/BurnerV2.sol), [`src/V2/dispatchers/GatherV2.sol`](../../../lib/yield-claim-nft/src/V2/dispatchers/GatherV2.sol)

**Description**: The constructors of `NFTMigrator`, `BurnerV2`, and `GatherV2` accept critical addresses without zero-address checks. A zero address would brick the flow at use time (downstream calls revert). Deployment-misconfiguration hardening only.

**Recommendation**: Add `require(addr != address(0))` validation for each critical constructor argument.

---

### [Q-02] Unchecked ERC4626 deposit return value in BalancerPoolerV2._dispatch <!-- id: ycn8l5 -->

**Location**: [`src/V2/dispatchers/BalancerPoolerV2.sol#L183`](../../../lib/yield-claim-nft/src/V2/dispatchers/BalancerPoolerV2.sol#L183)

**Description**: The `IERC4626(sUSDS).deposit` return value (shares minted) is ignored at line 183. The gap is bounded and harmless because `pool()` re-reads `balanceOf(address(this))` (line 192) rather than the deposit return, so accounting uses the actual held sUSDS.

**Recommendation**: Capture and assert the ERC4626 `deposit` return value for accounting hygiene, even though the current `balanceOf` re-read makes the gap harmless.

---

### [Q-03] abi.encodePacked used to build dynamic-string metadata in uri() (cosmetic) <!-- id: ycn8l6 -->

**Location**: [`src/V2/NFTMinterV2.sol#L262-L273`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L262)

**Description**: `uri()` builds dynamic-string metadata via `abi.encodePacked`. The packed output is returned as a metadata JSON string and is never hashed, so the classic `encodePacked` collision concern does not apply (no `keccak256` on this output). Cosmetic/style note only.

**Recommendation**: Prefer `abi.encode` or `string.concat` for dynamic-string concatenation clarity.

---

### [Q-04] setMinter emits no event (and V2 uses single-step Ownable) <!-- id: ycn8l7 -->

**Location**: [`src/V2/dispatchers/ATokenDispatcherV2.sol#L85`](../../../lib/yield-claim-nft/src/V2/dispatchers/ATokenDispatcherV2.sol#L85)

**Description**: `setMinter` changes a privileged role without emitting an event, hindering off-chain detection/monitoring. Separately, V2 `Ownable` is single-step (`Ownable2Step` would guard a transfer mistake, but reckless-admin transfer mistakes are otherwise treated as known-invalid). Monitorability/operational-hygiene only.

**Recommendation**: Emit an event (e.g. `MinterUpdated(oldMinter, newMinter)`) in `setMinter`. Optionally adopt `Ownable2Step` for ownership transfers (minor note).

---

## Centralization Risks

### [C-01] Owner can replaceDispatcher at an existing index, re-pointing token/metadata under existing holders <!-- id: ycn8c1 -->

**Location**: [`src/V2/NFTMinterV2.sol#L227-L247`](../../../lib/yield-claim-nft/src/V2/NFTMinterV2.sol#L227)

**Description**: `replaceDispatcher` is `onlyOwner` and changes the dispatcher/token/metadata mapping for an index that may already have holders. Existing holders' `tokenId` then maps to a different dispatcher/token underneath them. Any "redemption honored against the new token" impact lives in an external redemption layer that is out of scope; no in-scope on-chain redemption keys off this mapping, so no in-scope value impact is demonstrable.

**Impact**: None demonstrable in scope (assumes a trusted owner per the project trust model). A real impact would require an external redemption layer that depends on the mapping.

**Recommendation**: Consider restricting `replaceDispatcher` to indexes with no existing holders, or document and time-lock the power, so holders cannot have their token/metadata re-pointed underneath them.

---

## Appendix A — Automated QA/Gas Report (4naly3er)

**Status: NOT GENERATED — toolchain incompatibility (gap noted).**

4naly3er was run against the project (`tools/4naly3er`, via the writable workspace clone at the audited commit `bc99ee3`). Import resolution was set up correctly (`remappings.txt` for `@openzeppelin/contracts/` and `pauser/`, scope restricted to `src/`), and all in-scope imports resolved successfully.

However, the analysis could not complete because of a hard limitation in 4naly3er's bundled compiler:

- 4naly3er's vendored `solc` tops out at **0.8.23**.
- The vendored OpenZeppelin contracts in this repo use the **`mcopy`** opcode (EIP-5656, Cancun) in inline assembly and pragma `^0.8.24`–`^0.8.27`, which requires **solc >= 0.8.25**.
- solc-0.8.23 fails every in-scope file with `DeclarationError: Function "mcopy" not found.` (all 29 in-scope sources fail AST generation), so no report is produced.

Lowering dependency pragmas alone does not help — the `mcopy` opcode is genuinely unavailable in solc-0.8.23, and patching it out would alter dependency semantics, which was deliberately not done (source/deps left read-only/unmodified). Any temporary workspace edits used to diagnose this were reverted; the workspace and submodule trees were restored clean.

To restore the automated baseline, 4naly3er would need a bundled `solc-0.8.25`+ (Cancun). The manual QA findings above stand independently of this gap.
