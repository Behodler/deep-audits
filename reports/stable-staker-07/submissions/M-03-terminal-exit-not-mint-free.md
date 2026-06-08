<!--
ID: ss7m3
C4 Submission Metadata
Title: [M-03] Terminal-migration escape hatch is not mint-free — a revoked phUSD minter right traps user principal during migration
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L495-L504
PoC File: workspace/stable-staker/test/PoC_M03_TerminalExitNotMintFree.t.sol

SEVERITY NOTE (read first): This is a PROPOSED re-weigh from Low to Medium. The authoritative
ledger status remains OPEN / LOW under fingerprint e4567dc3 (basis
src/StableStaker.sol:userMigrate:availability-dependency-on-mint). The elevation is a proposal
only and is NOT effective until confirmed via `/ledger stable-staker` triage. This submission
re-confirms the existing open Low with a passing PoC and adds a Law-2 (faithfulness) dimension.
-->

## Finding description and impact

> Severity: PROPOSED Medium (re-weighed from ledger Low). The authoritative ledger record
> remains **open / Low** under fingerprint `e4567dc3`. The Low→Medium elevation is a proposal
> pending `/ledger stable-staker` triage and is not authoritative until then. Cross-reference:
> the spec-conformance / faithfulness report (this finding carries `faithfulness=true`).

### Summary

`StableStaker` documents `emergencyWithdraw` as a mint-free escape hatch whose explicit purpose
is that "a broken mint path can never trap principal" ([StableStaker.sol#L299-L307](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L299-L307)).
However, once a token enters terminal migration (`migrationInfo[token].active == true`),
`emergencyWithdraw` is **blocked**, and its only permissionless replacement, `userMigrate`
([StableStaker.sol#L495-L504](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L495-L504)),
is **not** mint-free: it routes through `_exitPosition`, which mints the frozen pending phUSD
**before** transferring principal. If the farm's phUSD minter right is revoked during the
decommissioning of the old staker, that mint reverts, so the only available exit reverts for any
user with `pending > 0`, and user principal is trapped until the minter right is restored.

### Vulnerability details

The escape-hatch invariant is stated directly in the `emergencyWithdraw` NatSpec
([StableStaker.sol#L299-L307](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L299-L307)):

```solidity
/**
 * @notice Escape hatch: withdraw the caller's full principal for `token`, forfeiting any
 *         pending reward. Works while paused and never touches reward accounting, so a
 *         broken mint path can never trap principal.
 */
function emergencyWithdraw(address token) external nonReentrant {
    // Frozen once terminal migration is engaged: the escape hatch becomes {userMigrate} ...
    require(!migrationInfo[token].active, "StableStaker: migrating");   // L307: blocked while active
    ...
}
```

So `emergencyWithdraw` deliberately stops working while migrating, and the design re-points the
escape hatch to `userMigrate` ([StableStaker.sol#L489-L504](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L489-L504)):

```solidity
function userMigrate(address token) external nonReentrant {
    require(migrationInfo[token].active, "StableStaker: not migrating");
    require(userInfo[token][msg.sender].amount > 0, "StableStaker: nothing staked");

    uint256 credit = _exitPosition(token, msg.sender);   // mints pending FIRST (see below)
    IERC20(token).safeTransfer(msg.sender, credit);
    emit UserMigrated(token, msg.sender, credit);
}
```

`_exitPosition` mints the frozen pending phUSD **before** the position is paid out
([StableStaker.sol#L479-L481](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L479-L481)):

```solidity
if (pending > 0) {
    phUSD.mint(account, pending);   // L479-L481: reverts if minter right revoked
}
```

`StableStaker` is an authorized phUSD minter; it holds no pre-funded reward balance and mints on
demand. Revoking the old staker's mint right (`phUSD.setMinter(oldStaker, false)`) is a plausible,
non-obvious step when retiring the old staker after a migration — the operator reasonably assumes
the migration is "done" and that removing the obsolete minter is safe hygiene. But any migrant who
still has accrued, frozen pending phUSD (`pending > 0`) can only exit via `userMigrate`, which now
reverts inside the mint with `"phUSD: caller is not authorized to mint"`. Because
`emergencyWithdraw`, `withdraw`, and the old staker's `depositFor` are all blocked while
`active`, there is **no mint-free exit path** while migrating. The principal sits in the contract,
unpayable, until the minter right is restored.

This is both:

- A **footgun** (CLAUDE.md Law 3): a competent, non-malicious owner would be surprised that
  revoking an obsolete minter right traps user principal — the consequence is non-obvious and
  the action looks like routine decommissioning.
- A **Law-2 faithfulness gap**: `emergencyWithdraw`'s stated invariant — "a broken mint path can
  never trap principal" — is not preserved by its own documented terminal-mode replacement,
  `userMigrate`. The replacement reintroduces exactly the mint dependency the original was
  designed to avoid.

### Impact

Availability of the permissionless escape hatch is broken under a plausible operational
precondition (the old staker's phUSD minter right revoked while a token is mid-migration). Affected
users cannot withdraw their staked principal until an owner action restores the minter right.

Severity is assessed as **Medium, not High**: the principal is **recoverable** — re-granting the
mint right immediately unblocks `userMigrate` and returns full principal plus the frozen pending
phUSD (demonstrated in the PoC). This is temporary denial of the escape hatch / availability of
funds, not permanent loss. It nonetheless exceeds QA/Low because (a) it defeats the contract's
central "principal can never be trapped" safety guarantee, (b) the triggering condition is a
realistic non-obvious operator action, and (c) recovery requires a privileged owner intervention
that locked-out users cannot perform themselves.

### Proof of Concept

A passing standalone Foundry PoC is provided at
`workspace/stable-staker/test/PoC_M03_TerminalExitNotMintFree.t.sol`.

Run:

```bash
cd workspace/stable-staker
forge test --match-contract M03PoCTest -vv
```

The test (`test_M03_revokedMinterTrapsPrincipalDuringMigration`) does the following:

1. User stakes 100 principal; emission set so pending phUSD accrues over a 1h skip.
2. `initiateMigration` engages terminal mode and freezes a non-zero pending balance
   (`assertGt(frozenPending, 0)`).
3. `phUSD.setMinter(staker, false)` revokes the farm's mint right (the decommissioning step).
4. `userMigrate` reverts with exactly `"phUSD: caller is not authorized to mint"` — the revert
   originates inside the pending-mint at `_exitPosition` L479-481, before any principal transfer.
5. The two other exits are confirmed blocked: `emergencyWithdraw` and `withdraw` both revert
   `"StableStaker: migrating"`. Principal is trapped: the position is still live
   (`amt == STAKE`) and the tokens still sit in the contract.
6. Recoverability: re-granting the mint right lets `userMigrate` succeed, returning the full 100
   principal and minting the frozen pending phUSD — confirming temporary unavailability rather
   than permanent loss.

Result: `1 passed; 0 failed`.

## Recommended mitigation steps

Restore the design invariant that a broken mint path can never trap principal during terminal
migration by providing a **mint-free exit** while `active`. Options, with their trade-offs:

1. **Allow `emergencyWithdraw` while migrating** (forfeiting or deferring pending phUSD). Remove or
   relax the `require(!migrationInfo[token].active, ...)` guard at
   [StableStaker.sol#L307](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L307)
   so that during migration `emergencyWithdraw` pays the fixed snapshot credit `p_i·min(R,P)/P`
   from the realized idle pile (rather than a live exit that would change `P`), with no phUSD mint.
   This keeps the snapshot intact while guaranteeing a principal exit.

2. **Make the pending mint non-blocking in `_exitPosition`.** Wrap the mint at
   [StableStaker.sol#L479-L481](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L479-L481)
   in `try/catch` (or skip it when the farm is no longer an authorized minter) and let users claim
   their frozen pending separately once the minter right is restored. The principal transfer then
   never depends on mint authorization.

Trade-off to state explicitly: option (1) may forfeit (or require a separate later claim of) the
pending phUSD in exchange for guaranteeing principal recovery; option (2) preserves the pending
claim but adds a second user step. Either is preferable to trapping principal. Whichever path is
chosen, the `emergencyWithdraw` NatSpec invariant — "a broken mint path can never trap principal"
— should be re-stated to cover the terminal-migration mode so the guarantee and the code agree.
