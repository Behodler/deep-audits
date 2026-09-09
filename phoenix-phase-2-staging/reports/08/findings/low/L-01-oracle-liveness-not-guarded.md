# L-01 — Phase A DOLA/USDC drain depends on un-guarded third-party oracle freshness; a stale Tokemak/Chainlink feed aborts the atomic single-broadcast cutover

- **Severity:** Low
- **Status:** draft (new)
- **Entry point:** `migrate:ss-execute-mainnet`
- **Category:** cluster-interaction
- **Root cause class:** ExternalDependencyLivenessNotGuarded
- **Location:** `script/MigrateStableStakerMainnet.s.sol` — `_drainOne`
- **Fork-verified:** yes (empirical, fork block 25234535, HEAD `c08882b`)
- **Fingerprint:** `f8c4de0d44da48119ee8692ec25ff15e942b5fcd18fcae34b462c351083db852`

## Description

Story 055's cutover (`MigrateStableStakerMainnet`) runs all of Phase A–F under a single
broadcast. Phase A (`_drainOne`) re-calls `totalWithdrawal(token, minter)` on each of the
three OLD strategies to redeem the minter's principal. For the DOLA and USDC legs that
redeem path is transitively coupled to live third-party price oracles: the AutoDOLA and
AutoUSDC vaults are Tokemak `AutopoolETH` proxies whose `redeem` prices the underlying via
`CurveConvexDestinationVaultV2.getUnderlyerFloorPrice` → `CustomSetOracle.getPriceInEth`
and `RootPriceOracle` (Chainlink ETH/USD). If any of those feeds is stale at the moment
the script is broadcast, the redeem reverts (`CustomSetOracle.InvalidAge`, or Chainlink
staleness `0x8d54ba1f`), and because Phase A is the first phase of a single atomic
broadcast, the **entire** cutover reverts with no partial state written. The USDe leg
(sUSDe/Ethena) has no oracle dependency and redeems cleanly — confirming the coupling is
specific to the two oracle-priced legs.

The 24–72h execution window opened by story 054 does **not** guarantee oracle freshness at
any instant inside it; the script has no awareness of, pre-check for, or retry around the
third-party freshness its redeem transitively requires.

## Impact

Low. No asset risk and no partial/inconsistent state: the atomic broadcast either fully
applies or fully reverts. The realistic failure mode is **availability / operational**: a
stale feed at broadcast time aborts the migration, forcing a wait-and-retry inside the
remaining window — or, if the window lapses to Expired, a full re-run of story 054 to
re-open it. Re-runnable, no loss.

## Fork-verification note

Empirically established on a mainnet fork. The only observed revert was a fork **artifact**:
time-warping `block.timestamp` ~23h forward to open the windows froze the Tokemak/Chainlink
oracles at the fork block, making them stale under warp (`InvalidAge(89496)` on DOLA, the
Chainlink custom error on the tighter warp). The **live preview** (no warp) behaved
correctly — global pre-flight passed and the executability gate STOPped as designed because
the real windows had only just been initiated. The USDe leg drained cleanly end-to-end,
isolating the coupling to the oracle-priced legs. The liveness coupling is real even though
the specific revert seen was a warp artifact.

## Cluster / cross-entry-point note

This finding is the execute-leg (`migrate:ss-execute-mainnet`) counterpart of the
incomplete-migration risk recorded against the predecessor entry point
`migrate:ss-initiate-mainnet` (run-07 `L-03`, fingerprint
`198bb924faad2ceb9c446deb17c362cc941dfadf4f20ac04f45f55795bb4db87`): the same two-phase
054/055 window that defers the drain is what exposes both the stale-snapshot risk (initiate
leg) and this oracle-freshness risk (execute leg).

## Recommendation

Add a pre-broadcast oracle-freshness smoke check (e.g. `previewRedeem` per vault, or read
each feed's `updatedAt`) before Phase A mutates anything, and/or split the three drains so a
single stale leg does not abort the whole cutover. Treat the 24–72h window as necessary but
not sufficient for executability.
