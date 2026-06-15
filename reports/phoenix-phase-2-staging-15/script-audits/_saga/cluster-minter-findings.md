# Cluster audit — DEPLOY + phUSD-MINTER sub-saga (steps 1/2/3/10)

**Project:** phoenix-phase-2-staging @ `0e190e8` | **Fork block:** 25313319 | **Mode:** fork-preview + in-process persistent-state fork test

**Verdict: NO new Medium+ findings.** All four hunt targets empirically refuted as correct/benign-by-design. 2 Lows + 1 cross-assignment cluster note recorded.

## Steps audited
- **Step 1** `migrate:ys-swap-deploy` — DeployTempStableStakerAndMigrators
- **Step 2** `migrate:phusd-minter-deploy` — DeployNewPhusdMinter
- **Step 3** `migrate:phusd-minter-cutover` — CutoverAndRevokeOldMinter
- **Step 10** `migrate:phusd-minter-evacuate` — EvacuateAndReseedMinter

## Hunt-target results (all empirically verified)

1. **Minter authority transitions — NO zero-minter gap.** The crux insight: the *staker reward mint path is a completely separate, independent phUSD minter* (StableStaker @0xbce8 is itself authorized on phUSD and calls `phUSD.mint()` directly at StableStaker.sol:329/346/540/734). None of the 4 scripts touches the staker's authorization. The PhusdStableMinter is the *user-facing collateral mint* path only. Old minter stays authorized through steps 1+2 (overlap with new minter — phUSD `authorizedMinters` is a plain per-address map, two can coexist), revoked only in step 3 *after* step 3's preflight asserts the new minter is live with `canMint`. Verified live: VER-1.

2. **Phase-4 prefund survives revocation.** Step 3 deauthorizes OLD_MINTER as a *client* on the old strategies but `withdrawAsOwner` is `onlyOwner`-gated, so step 5's Phase-4 drain still works after revocation. Verified: VER-2 (recovered 13815.459 of 13816.564 booked DOLA post-revocation). The mapper's design claim holds.

3. **4000/day cap cannot brick migration or rewards.** The cap is checked only inside `mint()` against `phUSDAmount` (user collateral path). Phase-4 prefund mints nothing (it's a `withdrawAsOwner` of pre-existing collateral). Staker rewards mint via the staker's own uncapped authorization. Verified: VER-3 (user >4000/day reverts; staker mints 100000 phUSD uncapped). 4000/token/day is a deliberate story-065 circuit-breaker, justified.

4. **Evacuate/reseed — no double-count, intended haircut.** Step 10 reads `principalOf(OLD_MINTER)` fresh, so even after step 5's partial Phase-4 drain it only moves the *remaining* residual. Step 5 caps `principalToWithdraw` at `minterBooked` and requires `minterRealizable >= shortfall`, so it never over-drains. Verified: VER-4 (reseeds 13814.467 DOLA onto V2 under new minter, old principal zeroed; round-trip shortfall 2.097 DOLA ≈ 0.015%, the intended minter shock-absorber). phUSD has NO redemption path, so the minter's V2 backing is protocol-owned yield, not a user redemption reserve — "backing < original obligations" creates no user-facing solvency claim.

5. **ys-swap-deployments.json completeness — OK.** Step 1 writes all 7 fields; downstream reads are a subset. Step 2/5 use the 3-arg `vm.writeJson(value,file,key)` merge form preserving step 1's fields.

6. **SYA choice (step 1) — CORRECT.** Verified: VER-5. Live SYA is 0x3C69 (mainnet-addresses.ts + progress.replace-sya.1.json {old:0x3bBE,new:0x3C69}); 0x3C69 holds the live old strategies, 0x3bBE is empty. Step 1's `SYA=0x3C69` is right.

## Superseded confirmations (not re-reported)
- **6fd3eddc / YS PhusdMinterRepoint → SUPERSEDED CONFIRMED.** Fresh deploy is the same PhusdStableMinter source with the 7-field config; old live minter is the 4-field build (confirmed on-chain — `stablecoinConfigs` getter returns 4 fields). Public ABI is a strict superset; no on-chain callers (mint() user-facing only; SYA/Phlimbo do not call it). No new ABI drift.
- **YS-20 minter-repoint ABI-drift** — already ledgered; no new instance here.

## Low findings
- **L (off-chain ref drift):** phoenix-ui `mainnet-addresses.ts` repoint is a manual out-of-worktree step (Q-REFS). If skipped after step 3 revokes the old minter, UI users hit `phUSD.mint: not authorized` revert until updated. Fail-loud, no fund loss.
- **L (non-idempotent deploy):** step 1's five `new` deployments are unconditional; a mid-saga re-run silently redeploys + overwrites the bus while live wiring still references the first set. Downstream preflights catch most mismatches and revert.

## Cluster note for the DEREGISTER+DECOMMISSION agent (step 11/12)
**SYA-MISMATCH-step11:** Step 11 `DeregisterOldStrategiesFromSYA.LIVE_SYA = 0x3bBE` targets the **decommissioned, empty** SYA. Its `removeYieldStrategy` calls no-op (idempotent skip), and the old strategies remain registered on the **live** 0x3C69 forever — likely a Medium intent-mismatch for whoever owns step 11. Flagged, not double-reported here (out of this sub-saga's assignment).

**PoC:** `workspace/phoenix-phase-2-staging/test/SagaMinterClusterAudit.t.sol` (4 passing fork tests).
