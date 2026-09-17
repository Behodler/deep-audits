# Intent — initiate-dola-ys-withdrawal (run-36, delta 7ac6e70..91ed727)

Source `script/InitiateDolaStrategyWithdrawal.s.sol` @ 91ed727 (also hosts `DolaStrategyWithdrawalBase`). npm L56–58.
Stories: **090** (origin, auto-complete) and **097** (commit 91ed727, auto-complete) — story 097 is the authoritative delta.

## Stated purpose — story 097 checklist
- [x] `WINDOW_SAFETY_MARGIN = 6 hours` added to the base (copied, not imported); non-fork drift-guard test `test_windowSafetyMargin_matches_cutover` passes (fork-logs/01). Story-rejected alternative (import) accepted: the test runs in CI's non-fork suite, so drift fails CI; the cutover constant itself is untouched.
- [x] Prints "start the cutover between executableAt and expiresAt - 6h (WINDOW_SAFETY_MARGIN)" and the start deadline (anvil fork-logs/03).
- [x] Timestamps and READBACK labelled LOCAL-PASS ESTIMATE, pointing to `npm run dola-ys-withdrawal:status`. Anvil (attempt 1): estimate initiatedAt 1789619459 vs mined 1789619475 — the label is accurate and status then printed the mined values.
- [x] package.json `//InitiateDolaStrategyWithdrawal` comment updated with the margin.
- [ ] Outside the repo: story 090's AC text still says "between executableAt and expiresAt" (PO task, disclosed in 097). Not a code finding.

## Declared pre-conditions (unchanged from run-35)
chainid 1; owner == OWNER; underlying DOLA; `!paused()`; on-chain 6h/72h; client == minter, != V1; principal > 0; status None/Expired or lapsed Initiated.

## Declared post-conditions
Local-pass readback: status Initiated, balance == principal, initiatedAt == block.timestamp (labelled estimate).
