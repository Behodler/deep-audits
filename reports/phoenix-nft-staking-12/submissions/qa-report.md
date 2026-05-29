# QA Report for Phoenix NFT Staking

Run: `nft-staking-12` · Submodule: `phoenix-nft-staking` · Commit: [`ab07199`](https://github.com/Behodler/phoenix-nft-staking/tree/ab07199a658b58d0162c3914e4b32384d3a59a7b)

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| Centralization | 0 |
| **Total** | **3** |

All three Low findings concern `BatchNFTMinter.batchMint`. There are **no centralization (C-XX) findings** this run: owner/pauser privileges are documented as by-design in the project's known issues.

An automated QA/gas baseline produced by **4naly3er** over the in-scope contracts (`BatchNFTMinter.sol`, `NFTStaker.sol`) is attached as an appendix at `submissions/4naly3er-report.md`.

---

## Low Risk Findings

### [L-01] `batchMint` lacks `nonReentrant`; ERC1155 `onERC1155Received` fires mid-loop <!-- id: ns12l1 -->

**Location**: [`BatchNFTMinter.sol#L184`](https://github.com/Behodler/phoenix-nft-staking/blob/ab07199a658b58d0162c3914e4b32384d3a59a7b/src/BatchNFTMinter.sol#L184), [`#L205`](https://github.com/Behodler/phoenix-nft-staking/blob/ab07199a658b58d0162c3914e4b32384d3a59a7b/src/BatchNFTMinter.sol#L205), [`#L207-L211`](https://github.com/Behodler/phoenix-nft-staking/blob/ab07199a658b58d0162c3914e4b32384d3a59a7b/src/BatchNFTMinter.sol#L207-L211)

**Description**: `batchMint` has no reentrancy guard. Inside the loop, `nftMinter.mint` (L207-209) mints an ERC1155 to the caller-controlled `recipient` (L188), which invokes the receiver's `onERC1155Received` callback **mid-loop** — while the max payment-token approval granted at L205 is still live and before the nudge payout. A malicious `recipient` can therefore re-enter `batchMint`.

This was determined **not independently exploitable**:
- The nudge payout reads `balanceOf` live at L220, so it cannot be double-paid by stale state.
- The dangling max approval is held by `address(nftMinter)`, an owner-set trusted minter — not by the attacker — so it is not drainable.

The residual concern is robustness: the `remaining = balanceOf(...)` refund snapshot at L228 can be misattributed across nested same-token calls. Any over-/under-refund is bounded to the participating callers' own deposits within a single transaction; it does not touch the nudge pot or third-party funds.

**Impact**: No demonstrated cross-party value extraction. Defense-in-depth / accounting-robustness gap.

**Recommendation**: Add OpenZeppelin `ReentrancyGuard` (already an expected project dependency per the submodule's `CLAUDE.md`) and mark `batchMint` as `nonReentrant`, to harden the `totalPaid`/refund accounting against nested re-entry.

```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BatchNFTMinter is /* ... */ ReentrancyGuard {
    function batchMint(/* ... */) external nonReentrant {
        // ...
    }
}
```

---

### [L-02] Uncapped `count` loop in `batchMint` <!-- id: ns12l2 -->

**Location**: [`BatchNFTMinter.sol#L207-L209`](https://github.com/Behodler/phoenix-nft-staking/blob/ab07199a658b58d0162c3914e4b32384d3a59a7b/src/BatchNFTMinter.sol#L207-L209)

**Description**: `count` (L187) is caller-controlled with no upper bound. The loop at L207-209 runs `count` times, each iteration making an external `nftMinter.mint` call. Only `count == 0` is rejected (L191); no maximum is enforced.

**Impact**: Self-DoS only. A sufficiently large `count` exhausts the block gas limit and reverts the caller's own atomic transaction (including the upfront token pull), rolling everything back. No shared queue, per-block accumulator, or other user's funds/liveness depend on this call, so there is no protocol-wide or cross-user impact.

**Recommendation**: Add an owner-settable `maxBatchSize` and enforce it with a clear revert, mirroring the existing `count == 0` guard.

```solidity
uint256 public maxBatchSize;

function setMaxBatchSize(uint256 newMax) external onlyOwner {
    maxBatchSize = newMax;
}

// in batchMint:
if (count > maxBatchSize) revert BatchMint__CountTooLarge();
```

---

### [L-03] Nudge-token equality guard reverts even when the nudge is size-disabled <!-- id: ns12l3 -->

**Location**: [`BatchNFTMinter.sol#L199-L201`](https://github.com/Behodler/phoenix-nft-staking/blob/ab07199a658b58d0162c3914e4b32384d3a59a7b/src/BatchNFTMinter.sol#L199-L201)

**Description**: The up-front guard at L200-201 reverts when `nudgePaymentToken == paymentToken` even when `nudgeSize == 0` (nudge effectively disabled, so no payout is possible). The payout block at L215 separately requires `nudgeSize != 0`, so the up-front revert is over-broad relative to the actual payout condition.

**Impact**: Usability nit only — fail-closed and harmless. An owner who set `nudgePaymentToken` but left `nudgeSize == 0` blocks `batchMint` for that `paymentToken` even though no nudge would ever pay out. No security impact.

**Recommendation**: Optionally gate the up-front guard on `nudgeSize != 0` so a size-disabled nudge does not block `batchMint`, keeping the early check consistent with the payout condition.

```solidity
if (nudgeSize != 0 && _nudgeTokenEntry != address(0) && _nudgeTokenEntry == address(paymentToken)) {
    revert /* ... */;
}
```

---

## Centralization Risks

No centralization findings this run. Owner and pauser privileges in `BatchNFTMinter` and `NFTStaker` are documented as by-design in the project's known issues and are therefore not reported here.

---

## Appendix: Automated QA/Gas Report (4naly3er)

The canonical C4-style automated analyzer **4naly3er** was run over the in-scope contracts
(`src/BatchNFTMinter.sol`, `src/NFTStaker.sol`; `src/INFTSupply.sol` is an in-tree interface
pulled in by the scope directory). Compilation succeeded against the project's pinned
OpenZeppelin / yield-claim-nft / pauser dependencies, and the full markdown output is attached
alongside this report:

- [`submissions/4naly3er-report.md`](./4naly3er-report.md)

The automated pass surfaced 10 Gas optimization categories, 18 Non-Critical (NC) categories,
and 11 Low (L) categories. These are tool-generated baseline observations (style, indexed
events, address(0) setter checks, 2-step ownership, precision/rounding notes, PUSH0/chain
compatibility, etc.) and are provided as the bot-report baseline; they are not individually
triaged as manual findings above.
