# QA Report for Phoenix NFT Staking

Run: `phoenix-nft-staking-14` · Submodule: `phoenix-nft-staking` · Commit: [`9be4a87`](https://github.com/Behodler/phoenix-nft-staking/tree/9be4a87a62e5ed1d25a013c4f8a033eaa41de2f6)

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 4 |
| Centralization | 0 |
| **Total** | **4** |

All four Low findings concern `BatchNFTMinter.batchMint`. There are **no centralization (C-XX) findings** this run: owner/pauser privileges are documented as by-design in the project's known issues (and 4naly3er's automated centralization flags are folded into the appendix as tool baseline, not triaged as manual findings).

This run re-examined the carryover reentrancy gap (**L-01**) with a decisive validated Tier-3 PoC and added one new Low (**L-05**) tracking an integration footgun in the story-015 slippage mitigation. **L-02** and **L-03** are carried over unchanged from run-13 and are summarized here as stubs.

An **informational note** at the end records the residual status of **M-01 / `pns13m1`** (the winner-take-all MEV nudge-pot capture): story-015's `minReward` slippage guard is correctly implemented and closes the loser-overpay leg, but the underlying winner-take-all MEV root cause persists as an acknowledged Medium residual. M-01 itself is **not** part of this QA bundle — it carries its own individual submission.

An automated QA/gas baseline produced by **4naly3er** over the in-scope contracts (`BatchNFTMinter.sol`, `NFTStaker.sol`, `INFTSupply.sol`) is attached as an appendix at `submissions/4naly3er-report.md`.

---

## Low Risk Findings

### [L-01] `batchMint` lacks `nonReentrant`; ERC1155 `onERC1155Received` fires mid-loop <!-- id: pns14l1 -->

**Location**: [`BatchNFTMinter.sol#L238-L257`](https://github.com/Behodler/phoenix-nft-staking/blob/9be4a87a62e5ed1d25a013c4f8a033eaa41de2f6/src/BatchNFTMinter.sol#L238-L257), nested reset at [`#L261`](https://github.com/Behodler/phoenix-nft-staking/blob/9be4a87a62e5ed1d25a013c4f8a033eaa41de2f6/src/BatchNFTMinter.sol#L261)

**Description**: `BatchNFTMinter` does not inherit `ReentrancyGuard`, and `batchMint` is unguarded — unlike the sibling `NFTStaker`, which marks every state-changing entrypoint `nonReentrant`. Inside the mint loop, the ERC1155 mint invokes the caller-chosen `recipient`'s `onERC1155Received` callback **mid-loop**, before the per-iteration `forceApprove(minter, 0)` reset and the nudge payout run — while the max payment-token approval is live, `paymentAmount` is held, and the nudge pot is intact. A malicious `recipient` can therefore re-enter `batchMint`.

This was re-examined this run with a decisive, validated Tier-3 PoC (`workspace/phoenix-nft-staking/test/poc-L01-reentrancy.t.sol`, 4 cases, all passing against the real source @ `9be4a87`). The **High escalation (third-party fund theft) is refuted**:

- The clean third-party theft path **atomically reverts**: the nested re-entrant frame's `forceApprove(minter, 0)` at L261 revokes the outer loop's live approval, so the outer continuation cannot draw against the honest caller's held budget and the whole transaction rolls back.
- The only value-moving reentrancy paths require **honest-caller misconfiguration** (over-fund the call AND designate the attacker as `recipient`) — a known-invalid user mistake.
- The donated-`paymentToken` sweep is **documented intended behavior**, with an owner `rescueERC20` hatch.

**Impact**: Defensive gap / parity issue only. No demonstrated cross-party value extraction on the current code. Would become High only under speculative future changes (e.g. a fixed-amount payout or a retained per-caller balance).

**Recommendation**: Add OpenZeppelin `ReentrancyGuard` and mark `batchMint` as `nonReentrant`, for parity with `NFTStaker` and defense-in-depth against future payout changes. Additionally, make the dust/refund credit a recorded/tracked amount rather than `balanceOf(this)`, so future payout-shape changes cannot reopen a reentrancy value-extraction path.

```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BatchNFTMinter is /* ... */ ReentrancyGuard {
    function batchMint(/* ... */) external nonReentrant {
        // ...
    }
}
```

---

### [L-02] Uncapped `count` loop in `batchMint` <!-- id: pns14l2 -->

> **Carryover (unchanged) from run `phoenix-nft-staking-13`** — see [`reports/phoenix-nft-staking-13/submissions/qa-report.md`](../../phoenix-nft-staking-13/submissions/qa-report.md) (`pns13l2`). Not re-flagged by the run-14 scan; reproduced here as a stub for completeness.

**Location**: [`BatchNFTMinter.sol#L238-L240`](https://github.com/Behodler/phoenix-nft-staking/blob/9be4a87a62e5ed1d25a013c4f8a033eaa41de2f6/src/BatchNFTMinter.sol#L238-L240)

**Description**: `count` is a fully caller-supplied `uint256` with no `MAX_COUNT` ceiling; the loop runs `count` times, each iteration making an external mint call.

**Impact**: Self-griefing only, and bounded. An oversized `count` exceeds the block gas limit and reverts the caller's own atomic transaction (rolling back the upfront token pull). No shared queue or other user's funds/liveness depend on this call, so there is no third-party or protocol-wide impact.

**Recommendation**: Introduce a sane (owner-settable or constant) `MAX_COUNT` cap and revert early with a clear error for oversized batches, mirroring the existing `count == 0` rejection.

---

### [L-03] Nudge-token equality guard reverts even when the nudge is size-disabled <!-- id: pns14l3 -->

> **Carryover (unchanged) from run `phoenix-nft-staking-13`** — see [`reports/phoenix-nft-staking-13/submissions/qa-report.md`](../../phoenix-nft-staking-13/submissions/qa-report.md) (`pns13l3`). Not re-flagged by the run-14 scan; reproduced here as a stub for completeness.

**Location**: [`BatchNFTMinter.sol#L250`](https://github.com/Behodler/phoenix-nft-staking/blob/9be4a87a62e5ed1d25a013c4f8a033eaa41de2f6/src/BatchNFTMinter.sol#L250)

**Description**: The up-front nudge-token equality guard (`BatchMint__NudgeTokenMatchesPaymentToken`) reverts whenever `nudgePaymentToken != address(0) && nudgePaymentToken == paymentToken`, **unconditionally on `nudgeSize`** — i.e. before the `nudgeSize != 0` payout gate. So even when the nudge is disabled via `nudgeSize == 0` (no payout could ever occur), a configured-but-equal nudge token bricks every `batchMint` for that `paymentToken`.

**Impact**: Usability nit only — fail-closed and harmless. Spec-vs-behavior mismatch; no asset risk and no availability impact in any intended operating mode.

**Recommendation**: Gate the up-front guard on `nudgeSize != 0`, so the early check only fires when a nudge payout can actually occur, keeping it consistent with the payout condition.

```solidity
uint256 _nudgeSize = nudgeSize;
if (_nudgeSize != 0 && _nudgeTokenEntry != address(0) && _nudgeTokenEntry == address(paymentToken)) {
    revert BatchMint__NudgeTokenMatchesPaymentToken();
}
```

---

### [L-05] `minReward == 0` default silently opts out of the slippage guard <!-- id: pns14l5 -->

**Location**: [`BatchNFTMinter.sol#L246-L256`](https://github.com/Behodler/phoenix-nft-staking/blob/9be4a87a62e5ed1d25a013c4f8a033eaa41de2f6/src/BatchNFTMinter.sol#L246-L256)

**Description**: `batchMint`'s `minReward` parameter — added by story-015 as a slippage guard against the M-01 MEV front-run — defaults to `0` for backward compatibility. A `minReward` of `0` disables the guard entirely (`nudgeAmount >= 0` always holds, so any payout, including zero, satisfies it). An integrating front-end that omits or zeroes the parameter **re-exposes M-01 in full**: the honest minter is no longer protected and mints into an already-drained pot.

**Attack path**:
1. An integrator calls `batchMint` without supplying `minReward` (or supplies `0`), relying on the backward-compatible default.
2. The slippage guard is inert (`nudgeAmount >= 0` always holds).
3. A searcher front-runs and captures the pot (M-01); the honest call still succeeds and mints into an empty pot instead of reverting.
4. The user pays mint cost + gas and receives no nudge — exactly the M-01 outcome story-015 intended to prevent.

**Impact**: Integration footgun. The slippage protection story-015 introduced is opt-in by value: callers who do not set a non-zero `minReward` get no protection. No direct fund-at-risk in the contract itself; severity Low (integration / spec-deviation footgun). It does, however, mean the M-01 mitigation can be silently nullified at the integration layer.

**Recommendation**: Make the slippage guard safe-by-default — either require an explicit `minReward` (no zero-default opt-out), or document prominently that `minReward` MUST be set to the caller's expected pot value and have integrating front-ends compute and pass it. Consider emitting an event or reverting when a qualifying `batchMint` is submitted with `minReward == 0` against a non-empty configured nudge pot.

---

## Centralization Risks

No centralization findings this run. Owner and pauser privileges in `BatchNFTMinter` and `NFTStaker` are documented as by-design in the project's known issues and are therefore not reported here. (4naly3er's automated "Centralization Risk for trusted owners" baseline — 18 instances — is retained in the appendix as tool-generated noise, not as a manual C-XX finding.)

---

## Informational Note: M-01 / `pns13m1` Residual Status

> This is an informational status note, **not** a Low finding. M-01 carries its own individual Medium submission and is **not** part of this QA bundle.

**Subject**: Winner-take-all MEV capture of the nudge pot (`BatchNFTMinter.batchMint`), tracked as M-01 / `pns13m1`.

story-015 introduced a `minReward` slippage parameter to `batchMint`. That fix is **correctly implemented** and **closes the loser-overpay leg** of M-01: an honest caller who passes a non-zero `minReward` equal to their expected pot value will now **revert** (rather than mint into a drained pot and silently overpay) when a front-runner has already swept the bonus.

However, the **winner-take-all MEV capture root cause persists**. The pot is still allocated atomically and in full to whoever's qualifying `batchMint` lands first in the block; `recipient` remains unbound from the actual payer, and there is no pro-rata accounting, commit-reveal, or payer-relative cap. A searcher can still front-run an honest qualifier and scoop the entire bonus — the honest caller is now protected from *overpaying* (they revert) but is still *denied the incentive they intended to earn*.

**Status**: **Medium, acknowledged residual.** The slippage fix mitigates the worst user-facing harm (silent overpay) but does not remove the underlying first-come, winner-take-all allocation. See L-05 above for the related integration footgun (the `minReward == 0` default that can silently disable even this partial protection), and the M-01 individual submission for the full root-cause analysis and recommended mitigations (payer-bound pro-rata accounting, per-payer accrual, commit-reveal, or a payer-relative payout cap).

---

## Appendix: Automated QA/Gas Report (4naly3er)

The canonical C4-style automated analyzer **4naly3er** was run over the in-scope contracts (`src/BatchNFTMinter.sol`, `src/NFTStaker.sol`, `src/INFTSupply.sol`) at commit `9be4a87`. The full markdown output is attached alongside this report:

- [`submissions/4naly3er-report.md`](./4naly3er-report.md)

The automated pass surfaced **10 Gas-optimization categories, 18 Non-Critical (NC) categories, 11 Low (L) categories, and 2 Medium (M) categories**. These are tool-generated baseline observations (style, indexed events, `address(0)` setter checks, 2-step ownership, precision/rounding notes, PUSH0/chain compatibility, etc.) provided as the bot-report baseline; they are **not** individually triaged as manual findings above. In particular, the two 4naly3er "Medium" categories are out of scope / by-design under this project's validity rules and are **not** manual findings:

- **4naly3er M-1 (fee-on-transfer accounting)** — fee-on-transfer tokens are a **known-invalid** finding class per the project's rules unless explicitly in scope.
- **4naly3er M-2 (centralization risk for trusted owners, 18 instances)** — owner/pauser privileges are **documented by-design** in the project's known issues (see Centralization Risks section).

*Tooling note*: 4naly3er writes its markdown to `tools/4naly3er/report.md`; that artifact was copied verbatim into `submissions/4naly3er-report.md`. The local 4naly3er install was previously patched (local-only, in the gitignored `tools/4naly3er`; the read-only submodule was not touched) to apply only the single longest-prefix matching remapping per import, restoring a clean compile against the in-tree `immutable/` / `mutable/` short-remappings.
