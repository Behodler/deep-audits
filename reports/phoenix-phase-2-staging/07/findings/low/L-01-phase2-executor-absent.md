# L-01 — Phase-1 "initiate" has no committed phase-2 executor — story-055 drain script absent, half-configured migration

- **Severity:** Low
- **Status:** draft (new)
- **Entry point:** `migrate:ss-initiate-mainnet`
- **Category:** cluster-interaction
- **Root cause class:** MissingPostStepConfiguration
- **Location:** `script/InitiateYieldStrategyWithdrawal.s.sol` — `run`
- **Fork-verified:** yes (fork block 25232738, HEAD `ddf7a41`)
- **Fingerprint:** `54a00d2b397820e1a28b4a3a0baed258d0f8b9a208fab27bfad474e79cd823c7`

## Description

Story 054 mainnet StableStaker migration is an explicit two-set operation. Set 1
(this script, `migrate:ss-initiate-mainnet`) opens the 24h total-withdrawal window
on the three live mainnet yield strategies — DOLA (`0xE7aEC2…`), USDC (`0x8b4A75…`),
USDe (`0xFc629b…`) — by calling `totalWithdrawal(token, client)` once per strategy
with `client = PHUSD_STABLE_MINTER 0x435B0A…`. Set 2 (story 055) is supposed to
re-call the same function inside `[executableAt, executableAt + 48h]` to execute the
drain and complete the migration.

A repository-wide search for the phase-2 executor turned up nothing: no script, JSON,
or TS matching `story 055` / `ExecuteYieldStrategyWithdrawal` / `ss-execute`. The only
`totalWithdrawal` callers committed in the repo are this Initiate script plus
`RebalanceUSDe{Initiate,Execute}` (story 038, different strategies/flow),
`PartialMigration{Initiate,Execute}` (story 034), and `AutoUSDC FullMigration{Initiate,Execute}`
— none of which target the three story-054 strategies for the execute leg. The migration
is therefore committed in a half-configured state: the broadcastable phase-1 step exists,
its phase-2 counterpart does not.

## Impact

Low. Funds are not at direct risk and not permanently stuck: the withdrawal window state
machine is `None → Initiated (0–24h) → Executable (24–72h) → Expired (>72h)`, and the
script's own status guard accepts `Expired(3)`, so re-initiation is permitted from a lapsed
window. If story 055 does not re-call `totalWithdrawal` within `[executableAt, executableAt+48h]`
(i.e. 24h–72h after this run), the three windows simply lapse to `Expired`, the migration
silently stalls, and it must be restarted — re-snapshotting principal. The operational risk
is a stalled / restarted migration, not loss.

## Fork-verification note

Preview run on a mainnet fork (impersonating owner `0xCad1a78…`, no broadcast) confirmed all
three strategies transition `None → Initiated` and emit `WithdrawalInitiated` with
`executableAt = initiatedAt + 24h`. The absence of the phase-2 executor is established by
source/grep evidence over the committed repo at HEAD `ddf7a41`, not by fork state.

## Recommendation

Do not broadcast set 1 until the story-055 execute script is authored, fork-verified, and
staged; treat the two as an atomic operational pair.
