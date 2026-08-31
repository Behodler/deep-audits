<!--
ID: ss1m1
C4 Submission Metadata
Title: [M-01] Underwater-pool migration is bricked by a requested-vs-received accounting mismatch
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L301-L337
PoC File: workspace/stable-staker/test/PoC_M01_MigrationBrick.t.sol
-->

## Finding description and impact

### Summary

`StableStakerMigrator` is the protocol's zero-user-action incident-migration mechanism: a permissioned migrator atomically moves a batch of stakers from an old `StableStaker` to a new one via the `migrateOut` / `depositFor` hook pair. By design this path is intended to remain callable while a token's yield strategy is **below par** — `migrateOut` redeems through `_routeExit(token, totalPrincipal, false)` with `guardUnderwater = false`, explicitly accepting the haircut so funds can be evacuated during an incident.

However, the migration reverts atomically in exactly that below-par condition. `migrateOut` returns each user's **requested** principal as the amount to re-credit, but only transfers the strategy's **actually-received** (haircut) balance delta to the migrator. The migrator then attempts to redeposit the full requested sum, which exceeds the funds it holds, so a later `depositFor` reverts on insufficient balance and the entire `migrate()` call unwinds.

### Vulnerability details

In `StableStaker.migrateOut` ([src/StableStaker.sol#L301-L337](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L301-L337)), for each migrated user the returned `amounts[i]` is set to the user's *requested* principal and accumulated into `totalPrincipal`:

```solidity
amounts[i] = amt;          // L324 — requested principal
totalPrincipal += amt;
```

It then redeems the aggregate principal and forwards only the measured amount actually received:

```solidity
// L334-L335
uint256 payout = _routeExit(token, totalPrincipal, false);
IERC20(token).safeTransfer(msg.sender, payout);
```

`_routeExit` ([src/StableStaker.sol#L488-L507](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L488-L507)) returns the **balance delta actually received** from redeeming strategy shares:

```solidity
uint256 balanceBefore = t.balanceOf(address(this));
strategy.withdraw(token, amount, address(this));
return t.balanceOf(address(this)) - balanceBefore;
```

When the strategy is below par, `payout < Σ requested`. The returned `amounts[]` (requested) and the transferred `payout` (received) therefore disagree.

The migrator consumes the returned `amounts[]` as gospel ([src/StableStakerMigrator.sol#L46-L65](https://github.com/Behodler/stable-staker/blob/master/src/StableStakerMigrator.sol#L46-L65)). It sums the *requested* amounts, approves that total, and loops `depositFor` with the per-user *requested* amount:

```solidity
IERC20(token).forceApprove(address(newStaker), total);   // L57 — total = Σ requested
...
newStaker.depositFor(token, users[i], amounts[i]);       // L60 — pulls requested amounts[i]
```

Each `depositFor` pulls `amounts[i]` from the migrator via `safeTransferFrom`. Cumulative pulls equal `Σ requested`, but the migrator only holds `payout`. Because `Σ requested > payout`, a later `depositFor` pulls more than the migrator's remaining balance and reverts on `ERC20InsufficientBalance`, unwinding the whole atomic `migrate()`.

### Impact

The zero-user-action incident migration is the protocol's marquee availability mechanism, and is explicitly designed (`guardUnderwater = false`) to remain callable below par. Yet it reverts atomically in precisely that below-par condition — the one scenario it exists to handle.

Severity is **Medium**:

- Protocol function / availability is impaired (a core feature is unusable in its target condition), gated by an external requirement (the strategy being below par).
- No funds are lost and no state is corrupted — the revert is atomic.
- The only workaround is to drain or rebalance the strategy back to par before migrating, which requires privileged admin action and defeats the zero-user-action purpose of the mechanism.

This is not High (no asset theft, no fund loss) and not Low (a core feature is unavailable in exactly the condition it is built for).

## Proof of Concept

A runnable Foundry PoC built on the project's own test suite lives at `workspace/stable-staker/test/PoC_M01_MigrationBrick.t.sol`. Run it with:

```
forge test --match-path test/PoC_M01_MigrationBrick.t.sol -vvv
```

Setup: two users (alice `100e6`, bob `300e6` USDC, 6 decimals) staked into the old `StableStaker`, whose USDC principal is routed through a yield strategy that faithfully mirrors the `ERC4626YieldStrategy` accounting `StableStaker` depends on (principal decremented by the *requested* amount on withdraw, value paid out at `requested * valueFactorBps / 10000`).

Primary case — strategy forced to a 10% loss (`9000` bps):

- `Σ requested` (the `amounts[]` returned by `migrateOut`) = `400_000_000`
- `payout` received by the migrator = `360_000_000`
- shortfall = `40_000_000`

`migrate()` reverts with the exact OpenZeppelin v5 custom error:

```
ERC20InsufficientBalance(
  sender  = <migrator>,
  balance = 260_000_000,   // after alice's 100e6 pull leaves 260e6
  needed  = 300_000_000    // bob's depositFor requires 300e6
)
```

The test asserts this error precisely via `vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", address(migrator), 260_000_000, 300_000_000))`, so it demonstrates the exact revert, not merely that a revert occurs.

Positive control — at par (`10000` bps), `payout == Σ requested == 400_000_000`, and the identical `migrate()` call **succeeds**: both users are credited their full principal on the new staker, the new staker holds the full principal, and no dust is stranded in the migrator. This isolates the failure specifically to the underwater haircut and rules out unrelated wiring issues.

Both tests pass as written.

## Recommended mitigation steps

The root cause is that `migrateOut` credits users on the **requested** basis while it can only fund the migrator on the **received** basis. Reconcile the two so that what is re-credited never exceeds what is delivered. Any of the following resolves it:

1. **Return actually-delivered per-user amounts.** Have `migrateOut` return `amounts[i] = amt * payout / totalPrincipal` (pro-rata of the realized payout), with division dust rounding down to the protocol. The migrator then redeposits exactly what it received and `Σ amounts[i] <= payout` always holds.

2. **Redeposit pro-rata against realized balance in the migrator.** Have `StableStakerMigrator.migrate` scale each `depositFor` by the migrator's actual post-`migrateOut` balance rather than trusting the requested `amounts[]`, so cumulative pulls cannot exceed the funds on hand.

3. **Redeem each user individually.** Route each user's exit through its own `_routeExit` so the per-user `received` equals the per-user `credited` by construction, eliminating the aggregate mismatch entirely.

Option 1 is the smallest change and keeps the single-call aggregate redemption; whichever is chosen, the post-condition `Σ (re-credited per user) <= (token received by the migrator)` must hold for the underwater path.
