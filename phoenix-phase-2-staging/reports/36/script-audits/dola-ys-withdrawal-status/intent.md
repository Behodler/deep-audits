# Intent — dola-ys-withdrawal:status (run-36, delta 7ac6e70..91ed727)

Source `script/DolaStrategyWithdrawalStatus.s.sol` @ 91ed727, helpers in `DolaStrategyWithdrawalBase` (`script/InitiateDolaStrategyWithdrawal.s.sol`). npm L59. Stories 090, 092, **097** (auto-complete).

## Stated purpose — story 097 checklist
- [x] Phases: WAITING; "EXECUTABLE - cutover may START (>6h left)"; "EXECUTABLE but too late to START a cutover (<6h left): wait for expiry, then re-initiate"; expired. `_effectivePhase` mirrors the cutover's `_minterWithdrawalExecutable` exactly (same four conditions, strict `<` on the margin).
  - Anvil: WAITING right after initiate (attempt-1 fork-logs/04), START_OK after ageing 6h (fork-logs/04), "expired - rerun initiate" after lapsing (pending-path/P4), "none pending" after completion (fork-logs/11). In each case the cutover's own gate agreed (leg 1 started; the lapsed resume deferred).
- [x] Paused override "strategy PAUSED - execute will revert" on every pending phase; tested (sponsor harness + mocked fork test).
- [~] Override NOT applied to PHASE_NONE (story Decision 2, disclosed). Accepted: with nothing pending the only operator action is initiate, whose preflight `require(!strategy.paused())` (InitiateDolaStrategyWithdrawal.s.sol L267) refuses loudly, and the raw `strategy paused:` line still prints. No path to a bad initiate. Also correct post-cutover (retired 0x1760 is paused by design).
- [x] Start deadline and seconds-until lines printed.

## Declared pre/post-conditions
None (read-only `view` reporter).
