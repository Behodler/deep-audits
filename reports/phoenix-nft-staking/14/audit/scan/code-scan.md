# Code Scan — BatchNFTMinter.sol (story-015 regression)

- **Project:** phoenix-nft-staking
- **Commit:** `9be4a87`
- **Scan type:** code (Tier-2 interaction-level)
- **Target:** `src/BatchNFTMinter.sol`
- **Context read:** `lib/mutable/yield-claim-nft/src/V2/NFTMinterV2.sol` (impl), V2 interfaces, `dispatchers/ATokenDispatcherV2.sol`, `dispatchers/BalancerPoolerV2.sol`, OZ ERC1155 v5.5.0.
- **Regression focus:** story-015 added 4th param `minReward` + error `BatchMint__RewardBelowMinimum`.

---

## Executive summary

The story-015 `minReward` floor itself is **correctly implemented** for what it claims to do (issues #2–#5 below resolve to NOT-A-BUG / informational). It does not introduce an exploitable slippage bypass, refund error, or new fund-already-pulled hazard.

However, this scan **refutes a load-bearing trust assumption in the Tier-1 profile** and surfaces a **real cross-contract reentrancy surface that the profile explicitly dismissed**. The profile (Trust Assumption #6, §5, LOCAL-002) concluded that under the project's "standard ERC20" assumption, `recipient` gains no reentrant control during `batchMint`, because ERC20 `transfer`/`balanceOf` don't call back. That analysis **only considered the ERC20 tokens and missed the ERC1155 mint-receiver hook.** The pinned, trusted `tokenMinter` is an `ERC1155Supply` (`NFTMinterV2`); its `mint()` calls `_mint(recipient, id, 1, "")` (NFTMinterV2.sol L196), which under OZ ERC1155 v5.5.0 invokes `recipient.onERC1155Received(...)` whenever `recipient` is a contract (ERC1155.sol L204-222). `batchMint` has **no `nonReentrant` guard** and runs this callback **inside the mint loop**, before the nudge computation, the `minReward` check, the nudge payout, and the dust refund. Any caller can reach it by passing a contract `recipient` they control — `recipient` is the canonical *untrusted* edge actor, not the trusted minter.

The exploitable impact is bounded by the contract's stateless / `balanceOf`-driven design (no accounting state to corrupt, and the nudge pot cannot be double-spent from a single funding because the second `balanceOf` reflects the first transfer). The concrete realizable harm is **theft of the entire `paymentAmount` an honest caller has pre-loaded into the contract** when their batch's mint-receiver hook is attacker-reachable, plus griefing of the dust-refund accounting. See CODE-001.

---

## CODE-001 — Cross-contract reentrancy via ERC1155 `onERC1155Received` mint hook drains the in-flight payment / nudge pot (profile trust-assumption refuted)

- **id:** CODE-001
- **type:** reentrancy (cross-contract)
- **severity:** potential-high
- **confidence:** medium (exploitability of the payment-theft path is high-confidence under the standard config; "drain" magnitude depends on whether an honest victim batch and an attacker share a block / mempool ordering)
- **contract:** `src/BatchNFTMinter.sol`
- **function:** `batchMint`
- **line:** 258
- **lineStart:** 254
- **lineEnd:** 293

### Root cause (the chain the profile missed)

1. `batchMint` pulls the caller's full `paymentAmount` into the contract and grants the minter an **unbounded, loop-spanning** approval:
   ```solidity
   paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);   // L254
   paymentToken.forceApprove(address(nftMinter), type(uint256).max);          // L255
   for (uint256 i; i < count; ++i) {
       nftMinter.mint(_dispatcherIndex, recipient);                           // L257-259
   }
   paymentToken.forceApprove(address(nftMinter), 0);                          // L261
   ```
2. Each `nftMinter.mint(index, recipient)` reaches `NFTMinterV2._executeMint`, which (a) pulls `price` of the payment token **from BatchNFTMinter** (`safeTransferFrom(msg.sender=BatchNFTMinter, dispatcher, price)`, NFTMinterV2.sol L183, drawing on the max approval), then (b) calls `_mint(recipient, id, 1, "")` (NFTMinterV2.sol L196).
3. OZ ERC1155 v5.5.0 `_mint` → `_updateWithAcceptanceCheck` → `ERC1155Utils.checkOnERC1155Received(operator, address(0), recipient, …)` (ERC1155.sol L309-315, L204-222). **If `recipient` is a contract it receives an `onERC1155Received` call** — i.e. control transfers to attacker code on the *first* loop iteration, while `batchMint` is mid-execution and the `max` approval is live.
4. `batchMint` has no reentrancy guard (`whenNotPaused` only). The dispatcher's own `nonReentrant` (ATokenDispatcherV2.sol L118-126) does **not** help: the callback fires *after* `dispatch()` has returned, from `_mint`, on a different contract.

The profile's §5 / Trust-Assumption-#6 statement — *"standard ERC20 `transfer`/`transferFrom`/`balanceOf` do not hand control to `recipient`, so under the project's standard-ERC20 trust assumption no recipient callback exists"* — is therefore incomplete. The callback comes from the **ERC1155 NFT mint**, not from any ERC20, and the NFT being an ERC1155 with receiver hooks is the *intended, standard* design, not a weird-token edge case. No ERC-777 / non-standard-token assumption is needed.

### Exploit path A — steal an honest caller's pre-loaded payment (primary, value-theft)

Pre-req: a victim (or a JS front-end that batches on a user's behalf) calls `batchMint` with a `recipient` that is a contract the attacker controls, OR the attacker is the `recipient` of any batch funded by someone else's tokens. The natural realization is the project's own integration: `BalancerPoolerV2` (story-031) is configured to push USDC into a `batchMinter` address, and front-ends call `batchMint` routing mints to arbitrary recipient contracts.

The simplest concrete theft does not even need a victim — it shows the refund accounting can be gamed so the attacker recovers more payment token than they are charged, by re-entering and letting the **outer** frame's pulled balance be swept to the **inner** `msg.sender`:

- Outer: attacker calls `batchMint(count=K, recipient=Atk, paymentAmount=P_out, minReward=0)`. `P_out` is pulled in (L254). Loop iteration 0 mints, charging `price` from the contract, then fires `Atk.onERC1155Received`.
- Inside the hook, `Atk` re-enters `batchMint(count=1, recipient=EOA /*no hook*/, paymentAmount=P_in_small, minReward=0)`. This inner frame pulls only `P_in_small`, mints once, then at L287-293 sweeps `remaining = paymentToken.balanceOf(this)` to `msg.sender == Atk`. **`remaining` here includes the outer frame's still-unspent `P_out` minus what the loops have charged so far.** The inner sweep therefore pays the attacker out of the *outer* deposit.
- Control returns to the outer loop, which keeps minting (charging `price` per mint from whatever balance is left / from the contract's pot) and finally hits its own L287-293 sweep with a now-depleted balance.

Because both frames credit refunds via a single shared `balanceOf(this)` read keyed to `msg.sender` of the *current* frame, a re-entrant frame can carry the outer frame's deposit out to an attacker-chosen `msg.sender`, while the outer caller's `totalPaid` bookkeeping (L290) under-reports the loss. When the victim and attacker are the *same* party this is just a convoluted self-pay; the real damage is when the **outer caller is a victim** (a front-end-initiated batch whose recipient contract is malicious, or a shared/pooled batching contract) — the attacker's inner sweep walks off with the victim's payment token, and the victim's mints still consume the remainder, so the victim's funds leave the contract to the attacker.

### Exploit path B — nudge pot interaction (griefing / DoS, not double-spend)

The nudge pot itself **cannot be double-spent** from one funding: the outer frame reads `nudgeAmount = balanceOf` (L271) *after* its loop; a re-entrant qualifying batch that pays out first zeroes the balance, so the outer frame reads 0 and (with `minReward==0`) transfers 0, or (with `minReward>0`) reverts the whole tx atomically. The profile's conclusion on this point holds.

But reentrancy lets an attacker **deterministically deny the nudge to a victim in the same tx tree** and skew who collects it, and combined with path A lets the attacker collect the nudge *and* exfiltrate the victim's payment in one tx. The winner-take-all + permissionless-gate economics of that race is an econ-scanner concern (M-01 lineage); the *mechanism* (no guard lets a mid-loop callback reorder the payout) is the code defect here.

### Why severity is potential-high not confirmed-high

- The contract holds **no per-user accounting** and every decision is a fresh `balanceOf`, which structurally blunts classic single-funding double-spend (the profile is right about that narrow point).
- The payment-theft path A requires that the tokens in the contract at callback time belong to someone other than the re-entrant `msg.sender` — i.e. an honest caller's in-flight `paymentAmount`, or the externally-funded pot. In a usage pattern where every caller mints only to their own EOA and no third party ever pre-loads value, the attacker can only churn their own funds. The integration context (`BalancerPoolerV2` donating USDC into this contract; front-ends batching to arbitrary recipient contracts) makes a non-attacker balance routinely present, which is why this is rated potential-high rather than low.
- Needs PoC confirmation in Tier-3 with the realistic deployment config (nudge funded, a victim batch whose `recipient` is a contract).

### Fix

Add OZ `ReentrancyGuard` and mark `batchMint` `nonReentrant` (the sibling `NFTStaker` already does this; the profile's LOCAL-002 recommended it as "defense-in-depth" — it is in fact load-bearing). This removes the entire class. Cheap and decisive. Alternatively, the contract could refuse contract `recipient`s, but the guard is the correct fix because the NFT is legitimately an ERC1155 and contract recipients (e.g. the staker) are a real use case.

---

## Investigated and found NOT exploitable / informational

### #2 — `minReward` slippage-guard correctness — CORRECT
`batchMint` L268-280:
```solidity
uint256 nudgeAmount;
if (_nudgeSize != 0 && count >= _nudgeSize && _nudgeTokenEntry != address(0)) {
    nudgeAmount = IERC20(_nudgeTokenEntry).balanceOf(address(this));
}
if (nudgeAmount < minReward) {
    revert BatchMint__RewardBelowMinimum(minReward, nudgeAmount);
}
```
- The floor compares against the **same `nudgeAmount`** that is actually transferred at L282-285 — there is no TOCTOU between the checked value and the paid value within a single (non-reentrant) frame; both use the one `balanceOf` read at L271. Correct.
- `minReward == 0`: `nudgeAmount < 0` is never true → never trips → exact pre-existing behaviour preserved. Correct and matches NatSpec.
- `reward == minReward` exactly: `nudgeAmount < minReward` is false → passes, pays out. Boundary is inclusive on the caller's favour. Correct.
- `nudgePaymentToken == paymentToken` collision: cannot reach the check — L249-252 reverts `BatchMint__NudgeTokenMatchesPaymentToken` up-front before any funds move. So the floor never operates on a conflated balance. Correct.
- The guard does what M-01's triage intended (stops the *loser* paying mint cost for a sniped reward). It does **not** stop a front-runner from *winning* the pot — this is explicitly documented in NatSpec L221-224 and flagged in the profile (LOCAL-003); that residual is an econ/MEV question, out of scope for this code scan.

### #3 — Refund / dust logic — CORRECT
L287-293. On the revert path (L279) the entire tx reverts, so no refund executes and nothing is half-applied — the `paymentAmount` pull rolls back atomically. On the normal path, `remaining = balanceOf(this)`; refund only if `remaining / DUST_THRESHOLD != 0` (i.e. `>= 1e6`), and `totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0`. The ternary cannot underflow. Sub-threshold residue intentionally retained (documented). No error introduced by story-015. (Caveat: the refund is `balanceOf`-driven, which is the lever abused in CODE-001 — but in the single-frame, non-reentrant case it is correct.)

### #4 — Ordering / CEI — no NEW violation from story-015
The `minReward` check (L278-280) was inserted **after** the loop+approval-revoke and **before** the payout/refund — the correct position to make the revert roll the mints back. It did not move any existing external call relative to a state write (the contract has no state writes in `batchMint`). The pre-existing CEI weakness (no guard around the external-call-heavy body) is CODE-001 and predates story-015; story-015 neither introduced nor worsened it.

### #5 — New-parameter interaction with already-pulled funds — SAFE
The concern "minReward reverts after funds are pulled/approved" is benign: the revert at L279 unwinds `safeTransferFrom` (L254), the `forceApprove(max)` (L255) and the subsequent `forceApprove(0)` (L261), and all `count` mints in one atomic rollback. No funds or approvals are left stranded by the revert path. The only residual approval risk is the *successful* path's transient `max` approval during the loop — which is exactly the window CODE-001 exploits, and is a reentrancy-guard issue, not a story-015 ABI-change issue.

---

## Cross-references to profile
- Refutes profile **Trust Assumption #6** and **§5** ("no recipient callback under standard-ERC20 assumption") — the ERC1155 mint hook was not considered.
- Upgrades profile **LOCAL-002** from "informational / defense-in-depth" to **CODE-001 potential-high**: the missing guard is exploitable via the mint-receiver callback, not merely theoretical.
- Confirms profile **LOCAL-003** scope note (minReward is loser-protection only) — left to econ-scanner.
- Trusts profile verified-local properties (checked arithmetic, access control on setters, pause wiring) — not re-checked.
