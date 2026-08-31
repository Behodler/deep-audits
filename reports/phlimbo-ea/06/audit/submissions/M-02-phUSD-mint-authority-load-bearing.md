<!--
ID: pe6m2
C4 Submission Metadata
Title: [M-02] phUSD mint authority is load-bearing for solvency: revocation, pause, or supply cap bricks claim/stake/withdraw with no graceful degradation
Root Cause Link: https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV2.sol#L486-L507
PoC File: workspace/phlimbo-ea/test/poc-2006-V2-M-02-phusd-mint-authority-brick.t.sol
Ledger: V2-M-02 (inherited from V1 M-03, amplified in V2 by MigratorV1V2)
Severity: Medium
-->

## Finding description and impact

### Summary

`PhlimboV2._claimRewards` ([`src/PhlimboV2.sol#L486-L507`](https://github.com/Behodler/phlimbo-ea/blob/master/src/PhlimboV2.sol#L486-L507)) mints accrued phUSD rewards by calling `phUSD.mint(beneficiary, pendingPhUSDAmount)` at **L495** with no `try/catch` and no fallback path. PhlimboV2 holds the `canMint` role on the phUSD (Flax) token, and that authority is load-bearing: if it is removed, every value-bearing user path that routes through `_claimRewards` reverts at the mint site. Users can then neither claim their accrued rewards nor recover their principal through the normal exit.

This carries the V1 finding (ledger M-03) forward unchanged, and V2 amplifies it: `MigratorV1V2.settleDebt` ([`src/MigratorV1V2.sol#L181`](https://github.com/Behodler/phlimbo-ea/blob/master/src/MigratorV1V2.sol#L181)) also mints phUSD, so a revocation that lands mid-migration bricks debt settlement and strands users between V1 and V2.

### Vulnerability details

The mint call has no degraded mode:

```solidity
// src/PhlimboV2.sol#L486-L507  (_claimRewards)
uint256 pendingPhUSDAmount = (userDetails.amount * accPhUSDPerShare) / PRECISION - userDetails.phUSDDebt;
if (pendingPhUSDAmount > 0) {
    phUSD.mint(beneficiary, pendingPhUSDAmount);   // L495 — no try/catch, no skip-and-continue
}

uint256 pendingRewardAmount = (userDetails.amount * accStablePerShare) / PRECISION - userDetails.stableDebt;
if (pendingRewardAmount > 0) {
    rewardToken.safeTransfer(beneficiary, pendingRewardAmount);
}
```

`_claimRewards` is reached from all three normal user-facing entry points whenever a user has a non-zero position and accrued time under a non-zero APY (so `pendingPhUSDAmount > 0`):

- `claim(user)` → `_claimRewards` at **L424**
- `withdraw(amount, user)` → `_claimRewards` at **L373** (auto-claim runs *before* principal is returned)
- `stake(amount, user)` → `_claimRewards` at **L337** (auto-claim of the existing position)

Because the auto-claim in `withdraw` executes before the principal transfer, a revert at L495 blocks the user from exiting with their stake, not merely from collecting rewards. The only contract-internal escape, `pauseWithdraw` (L280-291), is reachable solely while the contract is paused and does not claim rewards — so under normal (unpaused) operation there is no path to recover principal while mint authority is missing.

The mint can fail for several routine, non-malicious reasons on the phUSD token side:

1. The phUSD-token owner revokes PhlimboV2's `canMint` role (e.g. during an unrelated token-side reconfiguration or minter rotation).
2. The phUSD token is paused.
3. The phUSD token hits a configured supply cap.

### Three-law framing

This is a non-obvious owner/operator **footgun** (Law 3), not a malicious-owner vector. The actor with the surprising power here is the **phUSD-token owner**, who is generally administered separately from PhlimboV2. A competent, non-malicious operator toggling phUSD mint roles for an unrelated reason would reasonably not expect that action to brick *every* reward and withdrawal path on PhlimboV2 — including users' ability to recover principal. The consequence is surprising, so it is in scope as an operational hazard, surfaced with safe-config guidance rather than suppressed.

### Impact

While phUSD mint authority is absent, paused, or capped:

- `claim`, `withdraw`, and `stake` all revert for every staker with accrued phUSD.
- Users cannot recover principal through the normal path; the position is frozen until mint authority is restored.
- Mid-migration, `MigratorV1V2.settleDebt` (L181) reverts, halting migration and stranding users between V1 and V2.

This is availability/recoverability impact contingent on an external (phUSD-token-side) precondition, with principal recoverable once authority is restored — Medium, not High.

### Proof of concept

PoC (passing): `workspace/phlimbo-ea/test/poc-2006-V2-M-02-phusd-mint-authority-brick.t.sol`

Run:

```
forge test --match-path test/poc-2006-V2-M-02-phusd-mint-authority-brick.t.sol -vvv
```

The test deploys PhlimboV2 against a phUSD mock whose `mint()` can be toggled to revert with `"Flax: caller not authorized to mint"` — the precise condition produced when the token owner revokes the `canMint` role. With `desiredAPYBps = 1000` (10% APY, which must be non-zero so L495 is reached) and a 1000e18 stake over a 30-day window, the test proves:

- Before revocation, the user has `pendingPhUSD = 8.219178e18` (`8219178082190592000`) of claimable, accrued phUSD.
- After `setMintEnabled(false)` (revocation), the reward remains owed but unpayable; `claim(user)`, `withdraw(amount, user)`, and `stake(amount, user)` each revert with `"Flax: caller not authorized to mint"` at the L495 mint site.
- After restoring mint authority, `withdraw` succeeds and returns `1008.219178e18` (`1008219178082190592000`) — principal (1000e18) plus the accrued phUSD — confirming the funds were never lost, only frozen, and that mint authority is the sole remedy.

## Recommended mitigation steps

Add graceful degradation so a missing phUSD mint authority cannot freeze principal or stable rewards. Two complementary options:

1. **Wrap the phUSD mint in `try/catch`** so a failure skips the phUSD portion (optionally crediting it as still-owed) while the stable-reward transfer and the principal return in `withdraw` still complete:

   ```solidity
   if (pendingPhUSDAmount > 0) {
       try phUSD.mint(beneficiary, pendingPhUSDAmount) {
           // minted
       } catch {
           // record as still-owed phUSD for later claim; do NOT revert the whole path
           owedPhUSD[user] += pendingPhUSDAmount;
       }
   }
   ```

   This guarantees `withdraw` always returns principal and that stable rewards remain payable regardless of phUSD-token state, while preserving the user's claim on the un-minted phUSD.

2. **Apply the same treatment to `MigratorV1V2.settleDebt` (L181)** so a mid-migration mint failure does not halt settlement — either skip-and-record the phUSD leg, or surface a clear precondition check before iterating.

Operationally, until a degradation path exists, document and enforce the safe-config rule explicitly: **do not revoke / pause / cap phUSD minting while PhlimboV2 holds open positions or while a migration is in progress.** PhlimboV2's `canMint` role and the migrator's `canMint` role must be treated as live infrastructure for the lifetime of the deployment.
