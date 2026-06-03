# L-03 — Incomplete owner pre-flight: PHUSD.owner / PAUSER.owner are not asserted, so an ownership mismatch reverts only at Phase F, leaving a half-migrated non-idempotent state

- **Severity:** Low
- **Status:** draft (new)
- **Entry point:** `migrate:ss-execute-mainnet`
- **Category:** access-control
- **Root cause class:** IncompleteAccessControlPreflight
- **Location:** `script/MigrateStableStakerMainnet.s.sol` — `_globalPreflight`
- **Fork-verified:** yes (empirical, owners read on fork, block 25234535, HEAD `c08882b`)
- **Fingerprint:** `2399fff2208807f42b1b22528cf258d316eac59ec0ea245005b11e94c94826da`

## Description

`_globalPreflight` runs before any prank/broadcast and asserts the owner gates the script
depends on — but only 5 of the 7. It checks `OLD_YS_{DOLA,USDC,USDE}.owner()`,
`PHUSD_STABLE_MINTER.owner()`, and `SYA.owner()` all equal `OWNER_ADDRESS`, but it does
**not** assert the two owner gates that Phase F relies on:

- `PHUSD.owner() == OWNER_ADDRESS` (needed for `phUSD.setMinter(stableStaker, true)`).
- `PAUSER.owner()` / authorization to allow `PAUSER.register(stableStaker)`.

Because the whole cutover is a single broadcast in fixed phase order A → F, an ownership
mismatch on either of these would not be caught up-front. Phases A–D (and the StableStaker
deploy in F) would mutate live state first, and only the late `setMinter` / `register` calls
in Phase F would revert — leaving the migration in a half-applied, **non-idempotent** state
(old strategies drained, new strategies deployed and registered, minter re-pointed, SYA
swapped) that cannot simply be re-run.

## Impact

Low. No live failure today: on the fork both `PHUSD.owner()` and `PAUSER.owner()` already
equal `OWNER_ADDRESS`, so the unguarded gates currently hold. The risk is purely the missing
fail-fast guarantee — if either owner ever differs at broadcast time (e.g. an ownership
handoff between staging and execution), the atomic-or-fail-fast property the rest of the
pre-flight provides is lost for these two gates.

## Fork-verification note

Empirically established: both owners were read on the fork via `cast call` and both equal
`OWNER_ADDRESS` — present but **unguarded** (`preconditionResults`: "NOT asserted by script
— present but unguarded"). The other 5 owner gates are asserted by the script and also pass.

## Recommendation

Add `require(PHUSD.owner() == OWNER_ADDRESS)` and the PAUSER owner/authorization assertion
to `_globalPreflight`, so all 7 owner gates fail fast before any state is mutated and the
cutover preserves its all-or-nothing property.
