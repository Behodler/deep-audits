# MIGRATION-LEGS cluster audit — new findings (steps 4-8 + adjacent)

Scope: everything EXCEPT the YS-24/YS-25 gate-correctness fixes (owned by fix-verifier).
Head 0e190e8, fork block 25313222. Empirical via `test/AuditYsSwapBounceE2E.t.sol` + live cast.

## Live state context (load-bearing)
The saga has NOT been broadcast yet: ORIGINAL_STABLE_STAKER is unpaused, no migrator set,
still on the old strategies. Both old DOLA/USDC strategies are currently ABOVE par
(totalBalanceOf > principalOf for staker AND minter), so `_prefundShortfall` is a no-op today
(fork run: dola/usdcPrefunded == 0). The user-safety story therefore rests on the skim surplus
+ existing idle being folded into V2, plus the step-9 floor gate — analysed below.

## NEW Medium

### M (cluster-interaction): YS-swap SYA wiring split across two accumulators
`DeployTempStableStakerAndMigrators` (step 1) registers ysDolaV2/ysUsdcV2 on SYA **0x3C69**
(= current production `StableYieldAccumulator` in `mainnet-addresses.ts`), and
`PostMigrationCleanup` (step 9) asserts the V2 strategies are registered + the SYA is an
authorized withdrawer **on 0x3C69**. But `DeregisterOldStrategiesFromSYA` (step 11) hardcodes
`LIVE_SYA = 0x3bBE` — a DIFFERENT accumulator (the one in
`mainnet-addresses-post-phlimbo-upgrade.ts` / `RewireSYAToPhlimboV2.s.sol`), which is currently
**empty**. The deregister is therefore a silent no-op on the production accumulator.

Empirical (block 25313222):
- `0x3C69.getYieldStrategies()` = `[YS_DOLA_OLD, YS_USDE, YS_USDC_OLD]`, and 0x3C69 is an
  authorizedWithdrawer on both old DOLA/USDC strategies.
- `0x3bBE.getYieldStrategies()` = `[]`.
- both wired to phlimbo 0x6084, rewardToken USDC.

Consequences (non-malicious operator, documented runbook):
1. **claim() DoS.** 0x3C69 keeps the old strategies registered; step 12 `pause()`s them.
   `StableYieldAccumulator.claim()` calls `skimSurplus()` (whenNotPaused + onlyAuthorizedWithdrawer)
   on every registered strategy whose SYA-token is not paused (DOLA/USDC are not token-paused) →
   reverts on the paused old strategy → permissionless claim() reverts for everyone, unless each
   claimer passes the dead strategies in `exemptStrategies[]` (undocumented knowledge).
2. **Misconfig.** If 0x3bBE is the intended go-forward accumulator, V2 strategies were registered
   on the wrong (legacy) one and 0x3bBE ends with zero strategies, so the V2 set-aside buffers are
   never skimmed there.

Either way the accumulator the protocol serves ends the migration half-configured. This is the
unresolved INCONSISTENCY-SYA the manifest flagged for the script-auditor.

Fix: resolve Q-SYA-SEL, make step 1 register and step 11 deregister on the SAME verified SYA, add
a cross-script equality assertion on the SYA constant, and hard-require the live accumulator no
longer lists the olds before step 12 pauses them.

## Lows (terse — adjacent to known findings)
- **Floor gate measures wrong quantity.** story-067 gate compares buffer-inflated
  `principalOf` not user-withdrawable `totalStaked`; even on a clean run a real per-user haircut
  passes (fork: user staked 1018.3878 DOLA, received 1018.1447 on full withdraw, -0.024%; agg
  totalStaked ended 0.165 DOLA below preMigBooked while gate passed at principalOf=1061). Dust on
  ERC4626 → Low, but the blind spot would amplify on a MARKET strategy. Complementary to YS-25/26
  and ledger 5c9f1cee. Recommend gating on totalStaked.
- **Orphaned USDe idle.** Step 5 skims USDe surplus to the staker but USDe pool is never
  reset/swept → skimmed USDe stranded as idle (protocol-owned, owner-rescuable). Low.

## Cleared (no Medium+)
JSON-bus staleness (preflight count/totalStaked guards + loud post-asserts), userMigrate during
pause (by design, skipped by batchMigrate), Phase-4 over-delivery (capped at minterBooked,
hard-reverts on under-cover, no-op at current above-par state), setYieldStrategy empty-pool
precondition (satisfied by finalizeAndReset + the contract's totalStaked==0 require), idle-sweep
attribution (full balance swept to V2 principal, only ERC4626 rounding residual), sender/auth/chain
guards. YS-09 resume idempotency re-checked across steps 5/6/8 — re-run-safe. YS-01 fix present.
