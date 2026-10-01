# Carryover QA Report — originating audit 08 (carried into yield-claim-nft-20)

> **Carryover QA report — audit 08** (cut down from `yield-claim-nft/reports/08/submissions/qa-report.md`).
> Retained below (still open / untriaged as of audit 20): **L-01, L-02, Q-01 (surviving portion only — see note), Q-02, Q-03, Q-04, C-01**.
> Removed as no longer live: L-03 (fixed at `cf75ec9`). The NFTMigrator portion of Q-01 is moot (contract deleted in story-039, `7f5cac1`; ledger Q-01 `98c9fc45…` is `fixed`), but the section is retained because its BurnerV2/GatherV2 portion is still live as ledger **Q-09** (`3a5c5221…`, qa-bundled).
> Structural sections not copied (they carry no live findings of their own): title block + Summary (counts superseded by this header), Appendix A (4naly3er tool output, regenerated each run).
> Retained counts: Low 2 · QA 4 (Q-01 live only as Q-09) · Centralization 1.
> Labels are the originals — gaps in the sequence are the removals above, not omissions.
> Re-observed in run 20: L-01, Q-02, Q-03, Q-04 (re-flagged by run-20 static analysis; `lastSeenRun` → yield-claim-nft-20). Q-02 additionally gains a second location at `UniPoolerV2._dispatch` L290/L306. L-02, C-01, Q-09 were not re-observed and are carried for recall only.
> Line numbers and links were accurate at the originating commit, and relative links reflect the repository
> layout of that run (`reports/yield-claim-nft/NN/`, `lib/yield-claim-nft/src/...`); the source now lives at
> `yield-claim-nft/src/src/...`. Re-verify every location against current HEAD `2bfa090`.
>
> ⚠ **Label-collision warning:** run-19's run-scoped C4 labels `L-01`/`L-02`/`Q-01` are different findings (ledger `L-16`/`L-17`/`Q-18`). The labels below are the **ledger** entries `a25137b1…` (L-01), `5425119c…` (L-02), `98c9fc45…`→`3a5c5221…` (Q-01→Q-09).
>
> Triage any of these with `/ledger yield-claim-nft`.
>
> *The text below is a verbatim copy of the retained sections of the original report.*

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

