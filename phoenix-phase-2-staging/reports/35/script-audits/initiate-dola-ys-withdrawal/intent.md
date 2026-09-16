# Intent — initiate-dola-ys-withdrawal

Source `script/InitiateDolaStrategyWithdrawal.s.sol` @ 7ac6e70. npm keys `:preview` (L57) and `:broadcast` (L58). Intent comment `//InitiateDolaStrategyWithdrawal` (L56).
Story: **story-090** `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/090-initiate-dola-strategy-minter-withdrawal.md`. One glob hit. The state folder is `auto-complete`, and the story was machine-approved, not human-reviewed. Runtime consumer: story-092 (the cutover's Phase 0 and Phase 6b).

## Stated purpose (story 090 ACs, authoritative; npm comment and NatSpec restate them)
- [x] Start the clock only. Make the FIRST `totalWithdrawal(DOLA, PhusdStableMinter)` call on YieldStrategyDola 0x1760E053…24e2. Nothing moves.
- [x] Refuse to make the second (executing) call. Revert while a withdrawal is pending, both in the waiting period and in the execution window.
- [x] Only the minter is withdrawn. V1 StableStaker is rejected by a require.
- [x] Assert the on-chain 6h / 72h constants rather than trusting the stale 24h/48h NatSpec.
- [x] Log executableAt / expiresAt in unix and readable form, plus "broadcast the cutover between executableAt and expiresAt".
- [~] That instruction ignores story 092's `WINDOW_SAFETY_MARGIN`. The cutover refuses to START in the last 6h. The printed timestamps also come from the forge local pass, not the mined block (see findings).

## Declared pre-conditions (`_preflight`, all before the write)
- `block.chainid == 1`
- `strategy.owner() == OWNER` (0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6)
- `underlyingToken() == DOLA`
- `!paused()`. `totalWithdrawal` is whenNotPaused.
- On-chain `WAITING_PERIOD == 6h` and `EXECUTION_WINDOW == 72h`
- client != V1, and client == PhusdStableMinter
- `principalOf(DOLA, minter) > 0`
- Status None/Expired → OK. Initiated/Executable with `now > initiatedAt + 78h` → OK (lazy expiry). Before +6h → revert (waiting). In [+6h, +78h] → revert (would EXECUTE). An unknown status → revert.

## Declared post-conditions (read-back)
- `withdrawalStates(DOLA, minter).status == Initiated`
- `balance == principal` captured before the call
- `initiatedAt == block.timestamp`. In broadcast mode this is checked only in forge's local pass. The mined `initiatedAt` differs (anvil: local 1789569551 vs mined 1789569586).

## Out-of-scope by design
- Execution (second call) belongs to the cutover's Phase 6b.
- No ETH preflight (single tx, 101,456 gas), no progress file, no JS chain.
