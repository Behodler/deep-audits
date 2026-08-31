# L-03 — Phase-2 drain uses principal snapshotted at initiation while deposits/withdrawals stay enabled — incomplete-migration risk

- **Severity:** Low
- **Status:** draft (new)
- **Entry point:** `migrate:ss-initiate-mainnet`
- **Category:** cluster-interaction
- **Root cause class:** StaleSnapshotAcrossTwoPhaseWindow
- **Location:** `lib/vault/src/AYieldStrategy.sol` — `_executeWithdrawal`
- **Fork-verified:** yes (fork block 25232738, HEAD `ddf7a41`)
- **Fingerprint:** `198bb924faad2ceb9c446deb17c362cc941dfadf4f20ac04f45f55795bb4db87`

## Description

`totalWithdrawal` in phase 1 (`_initiateWithdrawal`) snapshots the client's principal into
`withdrawalStates[token][minter].balance` and sets status `Initiated`. In phase 2 (story 055),
`AYieldStrategy._executeWithdrawal` drains the **cached snapshot `state.balance`**, not the
live principal, then resets status to `None`.

Crucially, withdrawal state does **not** gate the strategy's ongoing operation. Verified against
source: `withdrawalStates` is read by no function other than `totalWithdrawal`; `deposit`,
`withdraw`, `totalBalanceOf`, `principalOf`, and `skimSurplus` do not consult it. They check only
`whenNotPaused` / `onlyAuthorizedClient`. Initiation is a pure timer — phUSD mint/redeem (routed
through the minter's deposit/withdraw on the strategy) and yield accrual continue normally
throughout the 24–72h window between phase 1 and phase 2. Initiation does NOT freeze user funds
or halt the minter.

Consequently, principal can move between the two phases:
- A **net deposit** in the interim leaves residual undrained principal after phase 2 (the cached
  amount is now less than live principal) → **incomplete migration**.
- A **net withdrawal** makes the cached amount exceed available principal; phase-2 withdraw caps
  to available, so it under-drains gracefully (no revert, no overdraw).

The root cause lives in the external `vault` `AYieldStrategy` base, but it is admissible here
because it is surfaced operationally by the in-scope script's two-phase design (this entry point
opens the snapshot window).

## Impact

Low. No overdraw and no fund loss: phase-2 withdraw caps to available principal. The realistic
failure mode is an **incomplete migration** — residual principal left in the old strategy if
deposits land in the interim — which requires a follow-up sweep, not an exploit.

## Fork-verification note

Verified via source that `withdrawalStates` gates nothing but `totalWithdrawal`; fork preview
confirmed phase-1 initiation moves no tokens and does not pause the strategies, so deposits/
redemptions remain enabled across the window. The stale-snapshot drain behavior is established
from `AYieldStrategy` source (`_executeWithdrawal` drains cached `state.balance`).

## Recommendation

Pause the three strategies / freeze minter deposits+redemptions for the migration window, or have
phase-2 re-read live principal and reconcile any residual; confirm minter quiescence before
broadcasting set 1.
