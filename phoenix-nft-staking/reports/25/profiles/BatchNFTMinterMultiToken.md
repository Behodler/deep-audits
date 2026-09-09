# Contract Profile — `BatchNFTMinterMultiToken.sol`

- **Path**: `lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol`
- **Commit**: `5015f1b` (submodule HEAD); baseline `d75229d`
- **Diff scope**: `git diff d75229d..5015f1b -- src/BatchNFTMinterMultiToken.sol` (364 lines changed, single source file)
- **Story**: story-029, delivered over 4 commits — `8f3b982` (RED), `0318089` (GREEN), `9bef5a6` (invariants), `5015f1b` (measured budget)
- **Solidity**: `pragma solidity ^0.8.20`; no `unchecked` blocks, no assembly, no `via_ir`
- **Inheritance**: `Ownable`, `Pausable`, `ReentrancyGuard`, `IPausable`; `using SafeERC20 for IERC20`
- **LOC**: 794 (was 630)

**Context contracts (verified byte-identical at `5015f1b` vs `d75229d`)**: `src/BatchNFTMinter.sol` (frozen twin), `src/NudgeStreamer.sol`, `src/INudgeStreamer.sol`. `git diff --stat d75229d..5015f1b` over those three paths is empty. The entire story-029 source delta is confined to `BatchNFTMinterMultiToken.sol`.

---

## 1. `batchMint` execution order as implemented

Signature: `batchMint(uint256 count, address recipient, uint256 paymentAmount, uint256[] calldata minRewards) external whenNotPaused nonReentrant returns (uint256 totalPaid)` — L461-465.

| Step | Lines | Operation | Changed by story-029? |
|---|---|---|---|
| 1 | L468-472 | Validate `count != 0`, `recipient != 0`, `_nudgeTokens.length == minRewards.length` | no |
| 2 | L476 | `_resolvePaymentPath()` → `(nftMinter, _dispatcherIndex, paymentToken)` | no |
| 3 | L507-511 | `qualifies = nudgeSize != 0 && count >= nudgeSize` | no |
| 3.5 | L525-533 | Streamer flush: for each `_nudgeTokens[i]`, `INudgeStreamer(_nudgeStreamer).pullPendingStream(token)` if `nudgeStreamer != 0` | **wrapped in a new `{ }` block** (stack pressure); logic unchanged |
| 4 | L535 | `snapshot = _snapshotRewards(minRewards, qualifies)` | **signature changed** — `paymentToken` param dropped |
| 5 | L575-581 | `budget` measured across the pull (see §2) | **rewritten** |
| 6+7 | L621-627 | Budget-tracked mint loop with per-iteration absolute approval (see §3) | **rewritten** |
| 8 | L631 | `paymentToken.forceApprove(address(nftMinter), 0)` | unchanged code, comment rewritten |
| 9 | L659-668 | **Refund of unspent budget** to `msg.sender`; sets `totalPaid` | **moved here from step 10; source changed** |
| 10 | L678 | `_payRewards(recipient, snapshot)` — pot payout | **moved here from step 9** |

### Verdict on the story's normative-order claim

The story (commit `0318089` §3.3 and `docs/multi-token-nudge.md` §3) claims: *snapshot → pull → budget-tracked mint loop → refund (step 9) → pot payout (step 10), with 9 and 10 SWAPPED relative to the old code.*

**CONFIRMED against source.** Concretely:

- Snapshot (L535) strictly precedes the pull (L578). ✅
- Old code (`d75229d`): `_payRewards(...)` at old-step-9, then the balance sweep at old-step-10 (diff lines 416-425: `_payRewards` followed by `uint256 remaining = paymentToken.balanceOf(...)`).
- New code: the refund block sits at L659-668, `_payRewards` at L678. The two are genuinely transposed. ✅
- The `_payRewards` NatSpec (L767-770) and `_snapshotRewards` NatSpec (L708) were renumbered consistently (step 9→10, step 4 retained).

**No contradictions found between the commit messages, `docs/multi-token-nudge.md` §3, and the implementation.** Every specific claim in `0318089` and `5015f1b` (§3.1 loop, §3.2 skip removal, §3.3 swap + dropped `>` guard, §5.1 whitelist check kept, block-scoping in two places, `via_ir` off) is literally present. Two nuances worth handing to the faithfulness agent are recorded in §9.

---

## 2. The budget computation (step 5)

```solidity
575:        uint256 budget;
576:        {
577:            uint256 heldBeforePull = paymentToken.balanceOf(address(this));
578:            paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);
579:            uint256 credited = paymentToken.balanceOf(address(this)) - heldBeforePull;
580:            budget = credited < paymentAmount ? credited : paymentAmount;
581:        }
```

- **Expression**: `budget = min(balanceOf(this)_after − balanceOf(this)_before, paymentAmount)`.
- **Bracketed reads**: L577 and L579 (both `paymentToken.balanceOf(address(this))`).
- **Operations strictly between the two reads**: exactly one — the `safeTransferFrom` at L578. Nothing else. No streamer call, no minter call, no snapshot, no event, no storage write.
- **Bracket span verdict**: the bracket spans **ONLY the step-5 `transferFrom` pull**. **CONFIRMED.** The snapshot (L535) and the streamer flush (L525-533) are both above L577; the mint loop begins at L621, well below L581.
- **Cap**: `min(..., paymentAmount)` — a one-sided ceiling. Per the inline rationale L562-571 it defends against a payment token with a transfer callback letting a **third party push funds in during the pull window**, which would otherwise inflate `credited` above `paymentAmount` and be refunded to `msg.sender`. It also mechanically preserves `budget <= paymentAmount`, which is what makes `totalPaid = paymentAmount - refund` (L664) underflow-free.
- **Lower side** (the measurement itself) is stated to defend against a fee-on-transfer payment token crediting less than `paymentAmount`.
- `budget` is the only variable that survives the block (declared L575 outside it).

---

## 3. Allowance handling in the mint loop (steps 6+7)

```solidity
621:        for (uint256 i; i < count; ++i) {
622:            (, uint256 price,,) = INFTMinterV2(address(nftMinter)).configs(_dispatcherIndex);
623:            if (price > budget) revert BatchMint__PaymentBudgetExhausted(i, price, budget);
624:            paymentToken.forceApprove(address(nftMinter), price);
625:            budget -= price;
626:            nftMinter.mint(_dispatcherIndex, recipient);
627:        }
```

- **Absolute, not cumulative/max**: L624 sets the allowance to exactly `price` for *this* iteration. `forceApprove` (OZ SafeERC20) performs `approve(0)` then `approve(value)` on failure, so the write is an absolute target regardless of the token's decrement behaviour. **CONFIRMED absolute.**
- **Old behaviour (removed)**: `d75229d` did a single `paymentToken.forceApprove(address(nftMinter), type(uint256).max)` before the loop (diff line 272). That is gone.
- **Price source**: **re-read from the minter every iteration** at L622 — `INFTMinterV2(address(nftMinter)).configs(_dispatcherIndex)`, destructuring the 2nd tuple member (`(address dispatcher, uint256 price, uint256 growthBasisPoints, bool disabled)`, per `lib/mutable/yield-claim-nft/src/interfaces/INFTMinterV2.sol:86-89`). **Not extrapolated locally.** No local ramp arithmetic exists anywhere in the file. **CONFIRMED** against `0318089`'s claim that "the optimisation of computing the ramp locally was NOT taken".
- **Budget check precedes approval**: L623 reverts `BatchMint__PaymentBudgetExhausted(i, price, budget)` (new error, declared L230) before any approval is written, naming the failing index.
- **Decrement order**: `budget -= price` (L625) happens **before** `nftMinter.mint` (L626) — effects-before-interaction within the iteration.
- **Allowance zeroed after the loop**: **YES**, L631 `paymentToken.forceApprove(address(nftMinter), 0)`, unconditional, on every non-reverting path.
- The loop ignores `configs`' 4th member `disabled`; `_resolvePaymentPath` (L703-704) also only checks `dispatcher != address(0)`. Pre-existing, unchanged by story-029.

---

## 4. `_snapshotRewards`

- **Old**: `_snapshotRewards(uint256[] calldata minRewards, address paymentToken, bool qualifies)`.
- **New** (L749): `_snapshotRewards(uint256[] calldata minRewards, bool qualifies)` — the `paymentToken` parameter is dropped. Sole call site L535 updated.
- **Runtime skip removed**: the old body contained `if (rewardToken == paymentToken) continue;` (diff line 489). That line is **deleted**. The new body (L754-765) is:

```solidity
756:        for (uint256 i; i < tokenCount; ++i) {
757:            address rewardToken = _nudgeTokens[i];
758:            uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;
759:            uint256 minReward = minRewards[i];
760:            if (available < minReward) {
761:                revert BatchMint__RewardBelowMinimum(rewardToken, minReward, available);
762:            }
763:            snapshot[i] = available;
764:        }
```

- **Any runtime payment-token skip remaining?** **NO.** Grep-confirmed: no `continue` and no `paymentToken` comparison survives in `_snapshotRewards`; `_payRewards` (L784-792) skips only on `amount == 0`. There is no other runtime special-casing of the payment token anywhere in the file.
- **Is the payment token's `minRewards` floor live?** **YES.** If the payment token is whitelisted, L758 reads its balance (pre-pull → the uncontaminated pot) and L760 enforces `minRewards[i]` against it identically to every other token. **CONFIRMED** against `0318089` §3.2.
- **Admin-time guard retained**: `setNudgeTokenWhitelist` still rejects the current derived payment token at L324-327 — explicitly re-labelled defence-in-depth (L318-323, and on the error at L188-200). So the collision is reachable **only** by the owner repointing `tokenMinter`/`dispatcherIndex` after whitelisting, not by a single whitelist call.

---

## 5. State-mutating external/public functions

| Function | Line | Access control | Pausable | Reentrancy | External calls, in order |
|---|---|---|---|---|---|
| `setTokenMinter(ITokenMinterV2)` | L249 | `onlyOwner` | callable while paused | none | none |
| `setDispatcherIndex(uint256)` | L258 | `onlyOwner` | callable while paused | none | none |
| `setNudgeSize(uint256)` | L265 | `onlyOwner` | callable while paused | none | none |
| `setNudgeStreamer(address)` | L290 | `onlyOwner` | callable while paused | none | none |
| `setNudgeTokenWhitelist(address,bool)` | L315 | `onlyOwner` | callable while paused | none | **add branch only**: `_resolvePaymentPath()` → `nftMinter.configs()` (L703) + `dispatcher.primeToken()` (L705). Remove branch performs **no** external call (deliberate — see L312-314). |
| `setPauser(address)` | L350 | `onlyOwner` | callable while paused | none | none |
| `pause()` / `unpause()` | L358 / L363 | `onlyPauser` (L241, `require(msg.sender == pauser)`) | — | none | none |
| `rescueERC20(IERC20,address,uint256)` | L383 | `onlyOwner` | callable while paused | none | `token.safeTransfer(to, amount)` (L385) — arbitrary token, arbitrary amount |
| `batchMint(...)` | L461 | **none** (permissionless) | `whenNotPaused` | `nonReentrant` | see below |

`batchMint` external calls, in execution order:
1. L703 `nftMinter.configs(_dispatcherIndex)` (view, via `_resolvePaymentPath`)
2. L705 `ITokenDispatcherV2(dispatcher).primeToken()` (view)
3. L530 `INudgeStreamer(nudgeStreamer).pullPendingStream(token)` — once per whitelisted token, **state-mutating on the streamer**, and it transfers token INTO this contract (`NudgeStreamer._settle` → `safeTransfer(recipient=this)`, `NudgeStreamer.sol:187`). The streamer is itself `nonReentrant` (`NudgeStreamer.sol:164`).
4. L758 `IERC20(rewardToken).balanceOf(address(this))` — once per whitelisted token, **only when `qualifies`**
5. L577 `paymentToken.balanceOf(address(this))`
6. L578 `paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount)`
7. L579 `paymentToken.balanceOf(address(this))`
8. L622 `nftMinter.configs(...)`, L624 `paymentToken.forceApprove(minter, price)`, L626 `nftMinter.mint(index, recipient)` — ×`count`
9. L631 `paymentToken.forceApprove(minter, 0)`
10. L660 `paymentToken.balanceOf(address(this))`; L663 `paymentToken.safeTransfer(msg.sender, refund)` (conditional)
11. L790 `IERC20(rewardToken).safeTransfer(recipient, amount)` — once per non-zero snapshot entry

**No inbound ERC721/ERC1155 receive-hook surface on this contract.** `nftMinter.mint(index, recipient)` routes the minted ERC1155 unit to the caller-supplied `recipient`, never to `address(this)`; this contract implements no `onERC1155Received`/`onERC721Received` and inherits no holder. The reachable-code callback surface is therefore confined to the ERC20 token contracts and the owner-configured minter/dispatcher/streamer.

---

## 6. Trust boundaries

**Caller-supplied (untrusted)** — `count`, `recipient`, `paymentAmount`, `minRewards[]`, `msg.sender`.

**Owner-configured (trusted per Law 3)** — `tokenMinter` (L150), `dispatcherIndex` (L157), `nudgeSize` (L162), `pauser` (L166), `_nudgeTokens[]` (L172), `nudgeStreamer` (L182).

**Read from an external contract** — `dispatcher` and `price` from `nftMinter.configs()` (L622, L703); `paymentToken` from `dispatcher.primeToken()` (L705); token balances from `IERC20.balanceOf` (L577, L579, L660, L758).

### TRUSTED (taken as given, never cross-checked)

| Value | Site | Note |
|---|---|---|
| `price` from `configs()` | L622 | Taken as the exact charge for the next `mint`. Never reconciled against an observed balance delta — that reconciliation is explicitly prohibited by the L600-605 comment. |
| `dispatcher` / `paymentToken` derivation | L703-705 | Assumed to be the asset `mint()` will actually charge in. |
| `paymentAmount` as an upper bound on the caller's credit | L580 | Used as the `min` ceiling. |
| `snapshot[i]` at payout time | L678 → L787 | Deliberately stale; the pre-loop reading is paid out unconditionally after the loop. |
| `nftMinter.mint` charging ≤ `price` | L626 | Bounded structurally by the L624 allowance, not by a check. |
| Streamer honesty / solvency | L530 | Return value ignored (function returns nothing); the flush's effect is only observed indirectly via the L758 balance read. |
| `disabled` flag from `configs()` | L622, L703 | Read and discarded. |

### MEASURED (derived from observation)

| Value | Site | Measurement |
|---|---|---|
| `credited` | L579 | `balanceOf` delta across the single L578 transfer |
| `budget` | L580 | `min(credited, paymentAmount)` |
| `available` (refund cap) | L660 | absolute `balanceOf` — a ceiling only |
| `snapshot[i]` | L758 | absolute `balanceOf` taken **pre-pull** |

---

## 7. Arithmetic inventory (new/changed code)

Solidity `^0.8.20`, all arithmetic **checked**; no `unchecked` block and no assembly anywhere in the file.

| Line | Expression | Kind | Underflow / rounding path |
|---|---|---|---|
| L579 | `paymentToken.balanceOf(address(this)) - heldBeforePull` | subtraction | Reverts if the contract's payment-token balance is **lower** after L578 than before it. Reachable only for a token whose `transferFrom` can decrease this contract's balance (callback-driven outbound transfer, negative rebase, or a hook-bearing token). Failure mode is a revert, not a wrong value. |
| L580 | `credited < paymentAmount ? credited : paymentAmount` | min | no arithmetic |
| L623 | `price > budget` | comparison | guard for L625 |
| L625 | `budget -= price` | subtraction | Cannot underflow — L623 reverts first on `price > budget`. |
| L661 | `budget > available ? available : budget` | min | no arithmetic |
| L662 | `refund / DUST_THRESHOLD != 0` | **division** | Integer floor division by the constant `DUST_THRESHOLD = 1e6` (L146). Equivalent to `refund >= 1e6`. No division-before-multiplication. Sub-threshold `refund` is **not** transferred and stays in the contract (becomes pot). |
| L664 | `paymentAmount - refund` | subtraction | Cannot underflow: `refund <= available` and `refund <= budget <= paymentAmount` (L580 min). This is the guard `0318089` §3.3 says it deliberately removed — the old code was `paymentAmount > remaining ? paymentAmount - remaining : 0`. **CONFIRMED removed**, and its absence is safe only because of the L580 `min`. |
| L666 | `totalPaid = paymentAmount` | assignment | dust branch |

Unchanged arithmetic elsewhere: `_nudgeTokens.length - 1` (L338, guarded by `oneBasedIndex != length` at L337), `oneBasedIndex - 1` (L339, guarded by the `!= 0` check at L335).

---

## 8. Every path by which `paymentToken` balance can leave the contract

| # | Path | Line | Amount | Conditions |
|---|---|---|---|---|
| 1 | Minter pull under the per-iteration allowance | L624 → L626 | ≤ `price` per iteration; ≤ `budget` in aggregate | Inside `batchMint`. The allowance is written to exactly `price` immediately before each `mint` and zeroed at L631, so no standing allowance survives the call. |
| 2 | Budget refund to `msg.sender` | L663 | `min(budget, balanceOf(this))`, only if `>= 1e6` | Inside `batchMint`, step 9. Source is the tracked counter; the `balanceOf` at L660 acts only as a ceiling. |
| 3 | Nudge payout to `recipient` | L790 (via L678) | `snapshot[i]`, the **full pre-pull balance** | Only if `paymentToken` is on `_nudgeTokens` **and** `qualifies` (`nudgeSize != 0 && count >= nudgeSize`) **and** the snapshot entry is non-zero. This is the path story-029 newly opened by deleting the skip. |
| 4 | Owner rescue | L385 | arbitrary `amount` | `onlyOwner`, any token, callable while paused. |
| 5 | *(closed)* residual minter allowance | — | — | L631 zeroes it unconditionally; no post-call allowance path exists. |

No `receive()`/`fallback()`, no ETH handling, no `selfdestruct`, no delegatecall, no upgradeability/initializer.

---

## 9. Notes for the faithfulness / interaction agents

Two places where the prose is *narrower* than the code. Neither is a contradiction of a commit-message claim — both are acknowledged in-code — but they are worth carrying forward:

1. **"the pot is invisible to the refund"** (header L116-118) is true of the refund's *source* but not of its *ceiling*: L660 reads the absolute `balanceOf`, which does include `P` and `D`. The code comment at L647-655 states this explicitly and calls the cap "non-binding on every path we can construct". A downstream agent evaluating the refund must treat `available` as a ceiling that can only *lower* the refund.
2. **The header's `min` rationale** (L86-89, L562-571) attributes the cap to a donation-during-pull scenario. The cap is *also* what keeps `budget <= paymentAmount` and therefore keeps L664 from underflowing. Both roles are load-bearing; only the first is named in the prose.

Also carried forward, factual, not adjudicated:
- The mint loop's cost per iteration rose materially (project gas snapshot: `batchMintN_25` 520,111 → 1,170,867; `batchMintN_10` 312,809 → 559,003, per `0318089`), because each iteration writes an allowance slot. `count` is caller-supplied and unbounded in the contract; the ceiling is the block gas limit.
- The whitelist-driven loops (L529, L756, L786) are unbounded in `_nudgeTokens.length`, which is owner-controlled.
- `configs().disabled` is read and discarded at L622 and L703.

---

## 10. Verified properties

| Property | Status | Evidence |
|---|---|---|
| Checked arithmetic | **verified** | `^0.8.20` (L2), zero `unchecked`, zero assembly |
| Reentrancy guarded | **verified** | `batchMint` `nonReentrant` (L464). Sole state-mutating permissionless entry point. |
| Access control on setters | **verified** | all 6 setters `onlyOwner`; `pause`/`unpause` `onlyPauser` (L241); `rescueERC20` `onlyOwner` |
| Initializer protection | **n/a** | non-upgradeable, plain `constructor` (L141) |
| Pause mechanism | **verified** | `whenNotPaused` on `batchMint` only; setters and `rescueERC20` intentionally live while paused |
| Weak randomness | **verified absent** | no `block.timestamp` / `prevrandao` / `blockhash` / `block.number` in this file |
| Unbounded loops | **present, by design** | L529 & L756 & L786 (owner-sized whitelist); L621 (caller-supplied `count`) |
| Inbound ERC721/1155 hook surface | **verified absent** | no holder inherited, mints routed to `recipient` |
| Storage collision / uninitialized storage | **n/a** | no proxy, no transient storage, no `delegatecall` |
| Post-call token allowance to minter | **verified zero** | L631, unconditional |
