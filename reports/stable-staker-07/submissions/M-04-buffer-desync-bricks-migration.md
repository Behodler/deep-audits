<!--
ID: ss7m4
C4 Submission Metadata
Title: [M-04] Underwater buffer-path withdrawals desync totalStaked below strategy.principalOf, making initiateMigration's incomplete-exit check unsatisfiable and permanently bricking terminal migration
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L679-L688
PoC File: workspace/stable-staker/test/PoC_M04_BufferDesyncBricksMigration.t.sol
Status: NEW
Ledger fingerprint: dc361b7d
Related (distinct root cause, same symptom): 3d61c955 (acknowledged underwater-migration-bricked)
-->

## Finding description and impact

### Summary

When a token's yield strategy is underwater, the `_routeExit` buffer branch pays a withdrawer out of the contract's idle balance and returns **without touching strategy principal**, yet the surrounding `withdraw` still decrements `totalStaked` (and `user.amount`). This breaks the invariant the migration path relies on — `totalStaked == strategy.principalOf(this)` — leaving `strategy.principalOf(this) > totalStaked`.

`initiateMigration` later snapshots `P = totalStaked`, withdraws exactly `P` from the strategy, and then asserts `strategy.principalOf(this) == 0`. Because the strategy held more principal than `P`, that post-check can never be satisfied and the call reverts. Terminal migration is **permanently bricked** for that token: `active` never flips to true, and there is no retry path in terminal mode.

### Vulnerability details

The underwater buffer branch in `_routeExit` ([StableStaker.sol#L679-L688](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L679-L688)) deliberately bypasses the strategy and pays from the on-contract buffer:

```solidity
if (guardUnderwater && _isUnderwater(token, strategy)) {
    // Underwater: try to satisfy the entire withdraw from the on-contract buffer.
    // Caller forwards the returned amount via safeTransfer, so we just signal
    // "use the buffer" by returning `amount` without touching the strategy.
    if (t.balanceOf(address(this)) >= amount) {
        emit BufferWithdrawn(token, msg.sender, amount);
        return amount;
    }
    revert("StableStaker: strategy underwater");
}
```

Meanwhile the caller, `withdraw`, unconditionally decrements both `user.amount` and `pool.totalStaked` ([StableStaker.sol#L270-L271](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L270-L271)) before routing the exit:

```solidity
user.amount   -= amount;
pool.totalStaked -= amount;
```

After a buffer-path withdrawal of `amount`, the strategy's booked principal is unchanged but `totalStaked` has dropped by `amount`. The accounting that the rest of the contract treats as held "in lockstep" with the strategy (see the source comment at L376-L377) is now desynced by exactly `amount`:

```
strategy.principalOf(token, this) > poolInfo[token].totalStaked
```

`initiateMigration` is built on the assumption that these two are equal. It snapshots `P = totalStaked` ([StableStaker.sol#L378](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L378)), realizes the position by withdrawing `P` from the strategy, and then enforces a full-drain post-check ([StableStaker.sol#L392-L395](https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L392-L395)):

```solidity
require(
    address(strategy) == address(0) || strategy.principalOf(token, address(this)) == 0,
    "StableStaker: incomplete exit"
);
```

`strategy.withdraw` caps the request to available principal and can draw the booked principal down to at most `principalOf - P`. Since `principalOf > P`, the residual is `principalOf - P > 0`, so `principalOf` can never reach `0` and the `require` always reverts. The whole `initiateMigration` transaction rolls back, so `active` stays `false` and the (intended one-shot, no-retry) terminal migration can never be engaged for that token. Each further buffer-path withdrawal only widens the desync.

This is the same observable symptom as the acknowledged finding `3d61c955` (terminal migration bricked while underwater), but a **distinct upstream root cause**: `3d61c955` concerns the underwater haircut itself, whereas this finding is the story-002 idle-buffer exit path (introduced to let underwater users still withdraw against the buffer) tripping the *new* `initiateMigration` post-check by mutating `totalStaked` without a matching strategy-principal decrement.

### Impact

Permanent loss of the ability to ever migrate the affected token — the availability of the entire terminal-migration mechanism is destroyed for that pool. Because `withdraw`, `stake`, and the normal exit paths remain blocked or unsafe while the strategy is underwater, and the migration escape hatch is exactly the mechanism intended to rescue users in that situation, this removes the protocol's designed recovery path precisely when it is needed.

No funds are directly stolen (principal remains custodied in the strategy and in the buffer), so this is not High. It is a Medium: protocol function/availability is impaired, conditional on (a) the strategy being underwater and (b) at least one buffer-path withdrawal having occurred — a realistic combined state given the idle buffer is a designed, intentionally-reachable mechanism and underwater is the exact condition under which that branch executes.

## Recommended mitigation steps

The root issue is that the buffer branch and the migration post-check disagree on what `totalStaked` and `strategy.principalOf` mean after an underwater buffer payment. Either side can be reconciled; the cleanest fix addresses the desync at its source.

**Option A — reconcile strategy principal on the buffer path (preferred).** When `withdraw` is satisfied from the buffer, the strategy's booked principal should be decremented to match the `totalStaked` decrement, so the lockstep invariant (`totalStaked == principalOf`) is preserved. Concretely, route the buffer payment through a strategy-side bookkeeping reduction (e.g. a principal write-down that recognizes the buffer was funded from set-aside strategy returns), rather than returning from `_routeExit` while leaving `principalOf` untouched. This keeps conservation honest: the value paid out of the buffer is matched by an equal reduction in the strategy's claim, and `initiateMigration` continues to draw down to exactly zero.

**Option B — make `initiateMigration` tolerant of residual principal.** Have `initiateMigration` realize the *strategy's* booked amount rather than the (possibly-smaller) `totalStaked`, i.e. request `P_strategy = strategy.principalOf(token, address(this))` from `strategy.withdraw`, or relax the post-check from strict equality to a dust tolerance (`require(strategy.principalOf(...) <= dust)`). This guarantees the strategy is fully drained regardless of any prior buffer desync.

Note the conservation trade-off between the options. Option A keeps `totalStaked` and `principalOf` equal at all times but requires the buffer to be a *recognized* drawdown of strategy principal (otherwise paying from the buffer double-counts value — once in the buffer, once still booked in the strategy). Option B tolerates the desync but means `R` (realized) can exceed `P` (the `totalStaked` snapshot used as the migration denominator); the existing `min(R, P)` cap at L406-L408 already guards user credits against an above-par `R`, so the surplus simply stays protocol-owned, consistent with the "yield stays protocol-owned" invariant. If the buffer can be funded from sources unrelated to strategy returns, Option B (or A combined with an explicit accounting of buffer provenance) is the safer choice, since it does not assume the buffer corresponds to a strategy drawdown.

### Proof of Concept

A passing Foundry PoC is provided at `workspace/stable-staker/test/PoC_M04_BufferDesyncBricksMigration.t.sol`.

Run:

```bash
cd workspace/stable-staker
forge test --match-path test/PoC_M04_BufferDesyncBricksMigration.t.sol -vv
```

Result:

```
[PASS] test_M04_bufferDesync_bricksInitiateMigration()
```

The test:

1. Wires a `MockYieldStrategy`, stakes `100`, and confirms the strategy custodies `100` principal.
2. Seeds an on-contract idle buffer of `30` and drives the strategy underwater (90% of par), confirming `withdrawDisabled(token) == true`.
3. Calls `withdraw(token, 30)`, which is funneled into the underwater buffer branch. Key assertions afterward:
   - `totalStaked == 70` (decremented), but `strategy.principalOf(this) == 100` (untouched).
   - `strategy.principalOf(this) > totalStaked` — the desync of `30`.
4. Calls `initiateMigration(token)` and asserts it reverts with exactly `"StableStaker: incomplete exit"`.
5. Confirms `migrationInfo[token].active == false` (migration never engaged) and that the residual desync equals `30`.

Note: the PoC seeds the idle buffer via a direct `mint` to the contract as a faithful stand-in for a set-aside buffer return. The bug mechanics — `totalStaked` decremented while `principalOf` is left untouched, then the post-check made unsatisfiable — are independent of how the buffer was funded.
