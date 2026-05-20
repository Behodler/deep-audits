<!--
C4 Submission Metadata
Title: [M-03] MigratorV1V2 does not enforce V1 drain before settlement, allowing legitimate V1 withdrawals to be double-credited via V2
Severity: Medium
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/MigratorV1V2.sol#L106-L142
PoC File: poc-M-03.t.sol
-->

## Finding description and impact

### Summary

`MigratorV1V2` settles V1 obligations by paying out USDC/phUSD rewards and re-staking V1 principal into `PhlimboV2` on each seeded user's behalf, but it has **zero on-chain coupling to the V1 `Phlimbo` contract**. The intended operational prerequisite — that V1 be drained via `Phlimbo.emergencyTransfer(...)` before the migrator is seeded — is neither documented in the migrator's NatSpec (which only enumerates the phUSD mint role and `PhlimboV2.setMigrator` as deployment-time wirings) nor enforced anywhere in code.

Because V1 remains a live, independent contract throughout the migration window, any V1 user who calls `Phlimbo.withdraw` (while V1 is unpaused) or `Phlimbo.pauseWithdraw` (while V1 is paused) between `seedObligations` and `migrateDeposits` retains their original V1 principal in their wallet **and** receives an owner-funded V2 position credited to the same address. Users with legitimate V1 withdrawal rights can therefore inadvertently double-credit themselves at the protocol's expense. This is a protocol design omission — a missing on-chain prerequisite check in the migrator — not an attack by a malicious user.

### Vulnerability details

`MigratorV1V2` is structured as a four-phase, owner-driven lifecycle:

1. **Seed** — `seedObligations(users, deposits, usdcOwed, phUSDOwed)` records the off-chain V1 snapshot verbatim and emits `Seeded`.
2. **Fund** — owner transfers `totalUSDC` USDC and `totalPHUSD_deposited` phUSD into the migrator. The contract verifies these balances on the strict-equality preconditions for `settleDebt`/`migrateDeposits`.
3. **Settle** — `settleDebt` transfers `usdcOwed[i]` USDC and mints `phUSDOwed[i]` phUSD to each seeded user.
4. **Migrate** — `migrateDeposits` calls `phlimboV2.stake(deposits[i], users[i])` using the owner-supplied phUSD float the migrator already holds.

None of these four phases ever reads or writes the V1 `Phlimbo` contract. The migrator's constructor only takes `(usdc, phUSD, phlimboV2)`; no V1 address is recorded or referenced. The "source" of the re-staked principal in step 4 is the owner's deposit into the migrator, not V1.

Meanwhile, V1's user-facing exits remain live regardless of V1's pause state:

- `Phlimbo.withdraw` is `whenNotPaused` — callable while V1 is unpaused.
- `Phlimbo.pauseWithdraw` is `whenPaused` — callable while V1 *is* paused.

So at least one of the two withdrawal paths is always available to a V1 user, unless V1's phUSD balance has been transferred out entirely (e.g. via `Phlimbo.emergencyTransfer`). The migrator does not invoke `emergencyTransfer`, does not require V1 to be paused, does not verify `phUSD.balanceOf(V1) == 0`, and does not check `Phlimbo.userInfo(user).amount == 0` per user. The implicit operational sequence "drain V1, then seed the migrator" exists only as tribal knowledge.

The user behavior that triggers the double-credit is not exploit-shaped. A V1 user calling `Phlimbo.withdraw` is invoking V1's documented public interface to recover their own deposit. They have no obligation to know that the owner has separately seeded a migrator contract; the `Seeded` event is on-chain but is not a notice to depositors that V1 is being decommissioned. The doubling is a consequence of the migrator crediting V2 stakes without verifying that V1 has released those users' positions.

### Impact

Each V1 user who recovers their V1 principal during the migration window is credited an equivalent V2 stake (funded by the owner) — an end-to-end 2x credit of their V1 principal, plus any pending USDC/phUSD rewards delivered by `settleDebt`. The aggregate value leak is bounded only by:

- the total V1 phUSD obligation pool (`totalPHUSD_deposited`), and
- V1's actual remaining phUSD balance at the time users withdraw.

There is no per-user or aggregate cap inside the migrator that would soften the loss. The migration cannot be safely run without operator-side V1-drain discipline that the contract neither documents in its prerequisites list nor enforces on chain. A single operator misorder (seed without first draining V1) silently exposes the entire V1 obligation pool to duplication, with no on-chain signal to detect or recover.

### Proof of Concept

The PoC at `reports/phlimbo-linear-02/audit/pocs/poc-M-03.t.sol` follows the documented migration flow exactly, with V1 left in its on-chain operating state, and demonstrates the issue across three tests:

1. `test_M03_UnpausedV1Withdrawal` — V1 is left unpaused. Between `seedObligations` and `migrateDeposits`, the user calls `Phlimbo.withdraw`. Final wallet balance asserts at `2 * ALICE_DEPOSIT`.
2. `test_M03_PausedV1NotDrained` — owner pauses V1 (a partial mitigation an operator might attempt) but does *not* call `emergencyTransfer`. The user calls `Phlimbo.pauseWithdraw`, which is `whenPaused`. Final wallet balance asserts at `2 * ALICE_DEPOSIT`. This shows pausing V1 alone is insufficient.
3. `test_M03_DrainedV1_NoLeak_Control` — **negative control**: owner calls `Phlimbo.emergencyTransfer` before seeding. Both V1 exit paths revert (`withdraw` because V1 is now paused; `pauseWithdraw` because V1 holds no phUSD). The user ends with exactly `ALICE_DEPOSIT`. This control demonstrates that the recommended mitigation closes the leak and confirms it is purely operational — `MigratorV1V2` itself contains no code that detects or requires the drain.

## Recommended mitigation steps

Adopt one of the following. The first is preferred because it provides the strongest on-chain assurance without modifying V1:

**(a) Enforce V1 drain in `seedObligations` (recommended).** Add the V1 contract address to the migrator's constructor and require V1 to be drained before seeding:

```solidity
// constructor gains a `_phlimboV1` address
phlimboV1 = IPhlimbo(_phlimboV1);

// in seedObligations, before any state writes:
require(phlimboV1.paused(), "V1 not paused");
require(IERC20(address(phUSD)).balanceOf(address(phlimboV1)) == 0, "V1 not drained");
```

This guarantees that V1 cannot service further `withdraw` or `pauseWithdraw` calls for the duration of the migration. Both V1 exit paths revert on the `safeTransfer` once V1 holds no phUSD, regardless of pause state. The check is O(1), runs once, and is impossible to bypass via operator misorder.

**(b) Have the migrator drain V1 itself in `seedObligations`.** If the migrator is granted V1 ownership/pauser roles, `seedObligations` can directly call `phlimboV1.emergencyTransfer(address(this))` (or another sink) before recording obligations. This eliminates any operator-sequencing window but requires V1 role wiring as part of deployment — a heavier integration than (a).

**(c) Document the prerequisite and add a deployment-runbook check.** Update the `MigratorV1V2` NatSpec lifecycle section to list V1-drain as an explicit pre-seed requirement and add an automated runbook assertion before `seedObligations` is called. This is the weakest option because the contract retains no ability to detect or recover from a misorder; it is acceptable only as a complement to (a) or (b), not as a standalone fix.

Option (a) is the most defensive: it requires no V1 modification, costs negligible gas, and turns the currently-undocumented operational prerequisite into a hard on-chain invariant.
