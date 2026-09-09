<!--
ID: ss7m5
C4 Submission Metadata
Title: [M-05] `emergencyWithdraw` under an underwater strategy socializes the entire pool shortfall onto the last caller (first-come-first-served value transfer between users)
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L304-L319
PoC File: workspace/stable-staker/test/PoC_M05_EmergencyFCFSSocialization.t.sol
Severity: Medium
Status: NEW
Ledger Fingerprint: 0dca43f3
Wont-fix coverage: DISTINCT from the buffer-scoped wont-fix 69c7666 — NOT blessed by known issue #6. Flag for explicit wont-fix-coverage re-triage.
-->

## Finding description and impact

### Summary

When a token's yield strategy is underwater (`totalBalanceOf < principalOf`), normal `withdraw` is blocked, funneling every staker into the permissionless `emergencyWithdraw` escape hatch. That path calls `_routeExit(token, amount, false)` with the underwater guard **off** ([`StableStaker.sol#L316`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L316)), which redeems the caller's full requested principal directly from the strategy at the *depressed* share price. The result is a first-come-first-served (FCFS) race: the **first** exiter redeems an outsized slice of shares and walks away with (near) full principal, while the **last** exiter can only redeem the residual shares and absorbs the **entire** pre-existing pool shortfall. This is an inter-user value transfer — early exiters are made whole at the direct expense of late exiters, who lose far more than their pro-rata share of the strategy loss.

### Wont-fix-coverage distinction (read first)

This finding is a **distinct, strictly-larger** variant of the already-`wont-fix`'d, buffer-scoped finding `69c7666` (keyed on `_routeExit`), and it is **NOT covered by it**:

- **Different root-cause key.** `69c7666` is scoped to `_routeExit`'s buffer branch; this finding (`0dca43f3`) is keyed on `emergencyWithdraw` and is **bufferless** — the socialization occurs through `strategy.withdraw` at the depressed price even when no on-contract buffer exists.
- **Strictly-larger loss bound.** The buffer-scoped variant caps the misallocation at the buffer size. Here the socialized loss is bounded by the **full pool shortfall**, independent of any buffer.
- **Known issue #6 does not bless it.** Known issue #6 states that `emergencyWithdraw` and migrations "accept *the* haircut" — that is a **self-inflicted** haircut on the exiting user. It does **not** authorize transferring one user's loss onto **another** user. Inter-user loss socialization is a different, unblessed harm.

This finding is surfaced for **explicit human wont-fix-coverage re-triage**; it must not be auto-closed as a duplicate of `69c7666`.

### Vulnerability details

While a strategy is below par, non-migrating `withdraw` is intentionally blocked so a passive user is not forced to realize a loss ([`StableStaker.sol#L282`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L282), guard at [`#L679-L687`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L679-L687)). The only remaining exit is `emergencyWithdraw` ([`#L304-L319`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L304-L319)):

```solidity
function emergencyWithdraw(address token) external nonReentrant {
    require(!migrationInfo[token].active, "StableStaker: migrating");
    UserInfo storage user = userInfo[token][msg.sender];
    uint256 amount = user.amount;
    require(amount > 0, "StableStaker: nothing staked");
    user.amount = 0;
    user.rewardDebt = 0;
    poolInfo[token].totalStaked -= amount;
    _stakers[token].remove(msg.sender);
    // No underwater guard: the escape hatch must always work, accepting a haircut if below par.
    uint256 payout = _routeExit(token, amount, false);   // <-- guardUnderwater = FALSE
    IERC20(token).safeTransfer(msg.sender, payout);
    emit EmergencyWithdrawn(token, msg.sender, amount);
}
```

With `guardUnderwater = false`, `_routeExit` skips the buffer branch entirely and redeems the requested principal straight from the strategy ([`#L673-L692`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L673-L692)):

```solidity
uint256 balanceBefore = t.balanceOf(address(this));
strategy.withdraw(token, amount, address(this));   // amount = requested PRINCIPAL, not shares
return t.balanceOf(address(this)) - balanceBefore;
```

The real `ERC4626YieldStrategy._withdrawInternal` converts that *principal* request into shares at the **current (depressed)** price (`convertToShares(requestedPrincipal)`) and redeems them. Because each caller requests full principal but the share price is below par, the first caller over-redeems: they pull more than their fair fraction of the surviving share pool. Concretely, for two equal stakers `A` and `B` in a pool that has lost a fraction `f`:

1. `A` calls `emergencyWithdraw` first. The request for `100` principal is converted to shares at the depressed price and redeemed, paying `A` (near) the full `100` and burning a disproportionate share slice.
2. `B` calls last. Only the residual shares remain; redeeming them yields only `~60`. `B` has absorbed the **entire** `40` shortfall instead of a fair `20`.

The fair outcome is a pro-rata split (`80 / 80` net of a 20% loss). The actual outcome is `~100 / ~60`: the loss is dumped FCFS onto whoever exits last. The precondition (strategy underwater) is an external market condition, not an owner action — and it is precisely the condition that blocks `withdraw` and forces everyone into this path, turning the exit into a bank run.

Notably, the protocol's own **terminal-migration** path already solves exactly this loss-allocation problem: it snapshots `(R, P)` once and credits every user a fixed, order-independent `p_i * min(R, P) / P` ([`#L340`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L340)), with a conservation proof that "the last claimer is never starved" ([`#L352-L354`](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L352-L354)). The emergency exit path is left exposed to the very FCFS unfairness the migration path was designed to avoid.

### Impact

Inter-user value transfer under an underwater strategy: early exiters are made whole at the direct expense of late exiters, who lose far more than their pro-rata share of the strategy loss. The misallocated amount is bounded by the **full pool shortfall** (not a buffer). This is not protocol theft and requires an external precondition (the strategy being below par), so it does not rise to High; but it is a genuine, design-avoidable unfair loss allocation between users — a value leak/redistribution with a stated external assumption — which is squarely **Medium**.

## Recommended mitigation steps

Apply the same pro-rata loss-sharing the terminal-migration path already uses, so the emergency exit cannot make one user whole at another's expense. Two viable approaches:

1. **Mirror the migration credit formula.** Credit the caller `requestedPrincipal * min(realizable, principal) / principal` rather than redeeming full principal at the depressed price — i.e. realize the position against a fixed `(R, P)` snapshot (or compute `min(R, P)/P` from the current strategy par ratio at first emergency exit) so every exiter, regardless of order, bears the same fractional haircut.

2. **Socialize the shortfall pro-rata across all stakers** for the emergency path: cap each emergency payout at the caller's pro-rata share of the strategy's *current* realizable value (`payout = principal_i * totalBalanceOf / Σprincipal`), instead of letting the first caller redeem an outsized share slice.

Trade-off to weigh: the escape hatch's "must always work" property must be preserved — the fix must still let every staker exit (it only changes *how much* each receives, not *whether* they can exit). A snapshot-based credit (approach 1) preserves both the always-exitable guarantee and the conservation property the migration path already proves.

### Proof of concept

A passing Foundry PoC using the **production** `ERC4626YieldStrategy` over a standard OpenZeppelin ERC4626 mock vault (`MockMigVault`, where `totalAssets() == asset.balanceOf(this)`) with a genuine 20% (40-underlying) vault loss is provided at:

```
workspace/stable-staker/test/PoC_M05_EmergencyFCFSSocialization.t.sol
```

Run:

```bash
cd workspace/stable-staker
forge test --match-path test/PoC_M05_EmergencyFCFSSocialization.t.sol -vv
```

Scenario and result (PASSING):
- `A` and `B` each stake `100` (pool `200`); strategy then suffers a real `40` (20%) vault loss → underwater, normal `withdraw` blocked.
- `A` calls `emergencyWithdraw` **first** → receives `99.999999999999999999`.
- `B` calls `emergencyWithdraw` **last** → receives `60.000000000000000001`.
- `B` absorbs `~40` (the entire shortfall) instead of a fair `20` (i.e. fair net `80 / 80`); the `A − B` gap is `39.999999999999999999`.
- Conservation asserted: total paid out ≤ post-loss vault value.

This uses the real production strategy and a genuine ERC4626 loss — not a hand-waved haircut — so the over-redemption arises from `convertToShares` at the depressed price exactly as on-chain.
