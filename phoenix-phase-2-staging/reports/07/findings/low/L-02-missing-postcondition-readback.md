# L-02 — Script encodes no post-condition: never reads back withdrawalStates to confirm the window opened

- **Severity:** Low
- **Status:** draft (new)
- **Entry point:** `migrate:ss-initiate-mainnet`
- **Category:** intent-mismatch
- **Root cause class:** MissingPostConditionAssert
- **Location:** `script/InitiateYieldStrategyWithdrawal.s.sol` — `_initiate`
- **Fork-verified:** yes (fork block 25232738, HEAD `ddf7a41`)
- **Fingerprint:** `3f4ce2fd6ae3399112fe1d1c787545062d84275ecd27dc9967aed46a2caa0ca3`

## Description

The script asserts only **pre-conditions** before each `totalWithdrawal` call
(`owner() == OWNER_ADDRESS`, `underlyingToken() == token`, `!paused()`,
`principalOf(token, minter) > 0`, `withdrawalStates.status == None || Expired`). It performs
**no post-condition assert** that the window actually opened after the call. Specifically,
after `totalWithdrawal(token, minter)` it does not read `withdrawalStates(token, minter)`
back to confirm `status == Initiated(1)` and that the snapshotted `balance` equals the
expected principal.

The `executableAt` value the script logs is **recomputed in the script** as
`block.timestamp + WAITING_PERIOD`, not read back from the contract — so any contract-side
anomaly (a divergent state transition, a different snapshot balance, a clock/version skew)
would not be caught by the script. The script trusts the call succeeded rather than proving
the resulting state.

## Impact

Low. This is a defense-in-depth / operational-confidence gap, not a fund-loss path. On the
fork the end state IS `Initiated` for all three strategies, so under current code the missing
assert masks nothing today — but a broadcast operator relying on the script's own output would
have no on-chain confirmation that the window opened with the expected balance.

## Fork-verification note

Fork preview confirmed the end state is `Initiated` for all three strategies with the expected
snapshot balances, and that the `postconditionResults` check "script asserts status == Initiated
after totalWithdrawal" is NOT encoded (`passed: false` — the script does not prove it). No token
transfers occur in phase 1 (empirically zero transfer/withdrawal-executed events).

## Recommendation

After `totalWithdrawal`, read `withdrawalStates(token, minter)` back; require
`status == Initiated(1)` and `balance == principal`; and log the **contract's** `executableAt`
rather than a script-recomputed value.
