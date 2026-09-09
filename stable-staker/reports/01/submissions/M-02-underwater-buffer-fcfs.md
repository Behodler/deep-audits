<!--
ID: ss1m2
C4 Submission Metadata
Title: [M-02] Underwater withdraw buffer is first-come-first-served at par, letting fast stakers capture a shared protocol reserve and exit loss-free
Severity: Medium
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L494-L502
PoC File: PoC_M02_BufferFCFS.t.sol (workspace/stable-staker/test/PoC_M02_BufferFCFS.t.sol)
-->

## Finding description and impact

### Summary

While a token's yield strategy is below par, `StableStaker.withdraw` satisfies exits from a shared, protocol-owned on-contract buffer **at par** on a strict first-come-first-served basis. Two stakers holding identical positions therefore receive materially different payouts based solely on withdraw ordering: the first staker is paid full principal at par out of the shared buffer, draining it, while later stakers hit a revert and are forced into `emergencyWithdraw`, where they absorb the strategy haircut. A finite reserve that backs every position equally is captured wholesale by whoever transacts first.

### Root cause

Withdrawals route through `_routeExit` ([`StableStaker.sol#L488-L507`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L488-L507)), called from `withdraw` ([`StableStaker.sol#L258`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L258)). When a token has a yield strategy and that strategy is below par (`totalBalanceOf < principalOf`), the underwater branch ([`StableStaker.sol#L494-L502`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L494-L502)) executes:

```solidity
if (guardUnderwater && _isUnderwater(token, strategy)) {
    // Underwater: try to satisfy the entire withdraw from the on-contract buffer.
    if (t.balanceOf(address(this)) >= amount) {
        emit BufferWithdrawn(token, msg.sender, amount);
        return amount;                                  // full amount, AT PAR
    }
    revert("StableStaker: strategy underwater");        // L502
}
```

The branch redeems **no** strategy shares. If the on-contract balance (the protocol-owned buffer) is at least the requested `amount`, the caller is paid the **full requested amount at par** and the buffer is debited by that full amount. As soon as the residual buffer drops below the next requested `amount`, the call reverts with `StableStaker: strategy underwater` ([`StableStaker.sol#L502`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L502)), and remaining stakers can only exit via `emergencyWithdraw`, which redeems strategy shares and forwards the proportionally reduced amount.

The buffer is a single shared reserve that backs all open positions. The code does not partition it across claimants nor apply the current par ratio to buffer payouts; it serves requests in arrival order until exhausted. Because `withdrawDisabled(token)` is a public view that returns true precisely while the strategy is underwater, the exploitable state is observable on-chain, making the ordering race MEV-extractable rather than merely accidental.

### On the existence of the buffer

The contract is explicitly architected around an on-contract buffer existing: the `_routeExit` buffer branch, the `BufferWithdrawn` event, and the `rescueERC20` "idle buffer" docstring all presuppose protocol-owned idle balance. Legitimate sources include strategy yield skim / `skimSurplus` proceeds returned to the StableStaker client, balances left behind when a strategy is replaced or only partially routed, and accounting dust. The buffer is therefore a real, expected protocol asset, not a contrived precondition. The PoC seeds it via `deal()` as a neutral stand-in for these documented mechanisms.

### Impact

The harm is the **unfair capture of a shared protocol reserve by whoever withdraws first**, producing unequal payouts for equal claims.

Consider two stakers, Alice and Bob, each with identical principal `P = 100e6` (USDC, 6 decimals). The strategy is forced to 50% value (`totalBalanceOf = P`, `principalOf = 2P`), so the system is underwater with total shortfall `S = P`. A protocol-owned buffer of `B = 100e6` sits on the contract (`P <= B < 2P`).

- Alice withdraws first: the buffer branch pays her the full `100e6` at par; no shares are redeemed; the buffer is drained.
- Bob withdraws: the residual buffer is below his requested amount, so the call reverts `StableStaker: strategy underwater`. Bob is forced into `emergencyWithdraw` and receives `50e6` (a 50% haircut on his own principal).

Identical positions, materially different outcomes (`100e6` vs `50e6`) determined purely by ordering. A fair design would distribute the recoverable value evenly: the total recoverable value `V = buffer + strategyValue = 2P` split across two equal stakers is `P` each; or, splitting just the buffer, `75e6` each. FCFS instead awards the entire shared subsidy to the fast actor.

To be precise about the boundary of this finding: the buffer does not make Bob absolutely worse off than a no-buffer world. With no buffer, both stakers would `emergencyWithdraw` for `50e6` each, so Bob's `50e6` outcome is unchanged. The buffer makes **Alice better** (loss-free exit) while Bob is unchanged. The grievance is not incremental loss inflicted on Bob beyond his own strategy haircut; it is that a shared protocol asset meant to back all positions is captured by whoever moves first.

This is Medium per C4: a value-leak / unfair-distribution issue contingent on an external precondition (the strategy being below par — a market or negative-yield event, not attacker-induced). The subsidizing buffer is protocol-owned and no attacker steals another staker's accounted principal, so it does not reach High. But stakers with equal claims receive unequal payouts based solely on transaction ordering, and the shared reserve is allocated arbitrarily — a clear protocol-fairness defect with an external trigger.

### Distinction from the documented known issue

The project documents that, while a strategy is underwater, `withdraw` **reverts** so that non-migrating users are not forced to realise a loss (they wait for the strategy to recover, while `emergencyWithdraw`/`migrateOut` remain available as loss-realising escape hatches). This finding is **not** that documented revert behaviour. The documented design concerns the *revert path* once the buffer cannot satisfy a request; the issue reported here is the **buffer-satisfied path that executes *before* that revert** — the branch at [`L494-L498`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L494-L502) that pays the *full requested amount at par* out of the shared reserve, first-come-first-served, with no par-ratio haircut and no partitioning across claimants. The documented "withdraw reverts underwater" invariant is precisely what the buffer branch *violates* for the lucky first movers: they do not wait and do not realise any loss, while the shared reserve that funded their par exit is consumed at the expense of an even distribution. The novel, undocumented element is the FCFS capture of the shared buffer and the resulting equal-claim/unequal-payout outcome — not the revert itself.

## Recommended mitigation steps

Make underwater exits treat the shared buffer as a shared resource rather than a first-come prize. Either:

(a) **Block the solvent buffer branch entirely while underwater**, so every exit routes through the proportional `emergencyWithdraw` haircut and no staker is paid at par from the shared reserve:

```solidity
if (guardUnderwater && _isUnderwater(token, strategy)) {
    revert("StableStaker: strategy underwater");
}
```

or (b) **Apply the current par ratio to buffer payouts**, so every withdrawer takes the same proportional reduction and the buffer is distributed pro rata:

```solidity
if (guardUnderwater && _isUnderwater(token, strategy)) {
    uint256 totalBal = strategy.totalBalanceOf(token);
    uint256 principal = strategy.principalOf(token);
    uint256 fairAmount = Math.mulDiv(amount, totalBal, principal); // floor, protocol-favoured
    if (t.balanceOf(address(this)) >= fairAmount) {
        emit BufferWithdrawn(token, msg.sender, fairAmount);
        return fairAmount;
    }
    revert("StableStaker: strategy underwater");
}
```

Option (a) is the simplest and aligns with the documented design intent that non-migrating users are not forced to realise a loss (they simply wait), while removing the ordering advantage. Option (b) preserves the buffer's utility but guarantees that no staker can exit loss-free at the expense of slower stakers.

## Proof of Concept

A standalone Foundry test reproduces the inequality and the exact revert. It lives at `workspace/stable-staker/test/PoC_M02_BufferFCFS.t.sol` and passes.

Run:

```bash
forge test --match-path test/PoC_M02_BufferFCFS.t.sol -vvv
```

Setup and observed result:

- Alice and Bob each stake `P = 100e6` (USDC, 6 decimals); the strategy holds `2P`; a protocol-owned buffer `B = 100e6` is seeded on the contract via `deal()` (`P <= B < 2P`).
- The strategy is forced to 50% value (`totalBalanceOf = P < principalOf = 2P`), so `withdrawDisabled(token) == true` and total shortfall `S = P = 100e6`.
- Alice withdraws first: the buffer branch pays the full `100e6` at par (no shares redeemed; `BufferWithdrawn` emitted); the buffer is drained.
- Bob withdraws: the call reverts with `StableStaker: strategy underwater` (buffer exhausted); Bob is forced into `emergencyWithdraw` and receives `50e6` (50% haircut on his own principal).
- The test asserts `assertGt(alicePayout, bobPayout)` — `alicePayout = 100e6 > bobPayout = 50e6` for identical positions. The inequality is baseline-independent: it follows purely from withdraw ordering.
