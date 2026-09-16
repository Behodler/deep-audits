# Intent — dola-ys-withdrawal:status

Source `script/DolaStrategyWithdrawalStatus.s.sol` @ 7ac6e70. The npm key is `dola-ys-withdrawal:status` (L59). It has no dedicated `//` comment; the `//InitiateDolaStrategyWithdrawal` comment calls it "read-only and safe anytime".
Stories:
- **story-090** created the status script.
- **story-092** made the post-retirement annotation. Its runbook step 2 reads: "wait at least 6 hours, then `dola-ys-withdrawal:status` must say EXECUTABLE".

Both stories sit in `auto-complete`.

## Stated purpose
- [x] Read-only. `run()` is `view`: no prank, no broadcast.
- [x] Print the stored status, principal now vs the snapshot balance, and seconds until executable and until expiry (or "expired (lazy)").
- [x] Print whether the minter's DOLA registration still points at 0x1760.
- [x] Story 092: after the cutover, print "withdrawal completed / strategy retired". Fork-confirmed.
- [~] Serve as the operator's go signal for the cutover broadcast (story-092 runbook step 2). Two gaps:
  - It prints "EXECUTABLE - cutover may broadcast now" through the whole [+6h, +78h] window. The cutover's Phase 0 refuses to start in the last 6h (`WINDOW_SAFETY_MARGIN`), confirmed on the fork.
  - It prints "EXECUTABLE" even while the strategy is paused. It does print `strategy paused: true` on a separate line.

## Declared pre-conditions
- None. There is no `block.chainid` guard (OBS-35-S1). Against a non-mainnet RPC, calls to the codeless hard-coded addresses revert rather than misreport. An anvil fork of mainnet (chainid 1) is read faithfully.

## Declared post-conditions
- None (reporter).

## Effective-phase logic vs contract (`AYieldStrategy._updateWithdrawalStatus`)
- The status script's EXECUTABLE range `[initiatedAt+6h, initiatedAt+78h]` (`nowTs <= expiresAt`) matches the contract's inclusive `<= initiatedAt + TOTAL_DURATION`.
- The stored `Expired (3)` branch is unreachable: a lazy update only happens inside a `totalWithdrawal` call, which re-initiates in the same call. This is harmless.
