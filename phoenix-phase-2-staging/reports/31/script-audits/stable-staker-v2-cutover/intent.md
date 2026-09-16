# Intent — stable-staker-v2-cutover

Entry point: `stable-staker-v2-cutover` (`:preview` / `:broadcast`), source commit `1c1608c`.
Script: `script/CutoverStableStakerV2Mainnet.s.sol` + `script/helpers/StableStakerCutoverCore.sol`;
JS tail `scripts/patch-mainnet-addresses-stable-staker-v2.js`.

## Story authority (Law 2)
- **story-082** — `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md`
  - State folder: `auto-complete/` (machine-approved "not human-reviewed", Review Status ISSUES_FOUND, triage "non-blocking"). Glob of the whole `phStaging2` tree: exactly one `082-*` hit.
  - Commits `272f94b`, `7046127`, `1c1608c` (all `[story-082]`).
- Supporting: story-080 (DeployMocks rehearsal = ordering template), story-060 (DOLA/USDC principal surplus), story-062 (pause pattern), story-067 (realized >= booked floor), story-076 (two-sided minter delta, stragglers STOP AND REPORT), story-047 (buffer recipient).
- Owner intent memo (2026-08-28, `stable-staker-migration-intent-owner`): sweep yield+buffer into principal; relinquish over-credit to protocol; safe > precise; err toward the user where possible.

## Story acceptance criteria (authoritative) vs script
- [x] AC1 Deploy Antimatter (name "Antimatter", symbol "AM") owned by OWNER — Phase 2, asserted.
- [x] AC2 Deploy StableStakerV2; configure every token exactly as V1 today, read live — Phase 4 (token list live; strategy map HARD-CODED and asserted against V1 while Active, Decision 7).
- [x] AC3 `antimatterPerDay = 2.1 x C`, `C = V1.phusdPerSecond * 86400` floored — Phase 4 + Phase 8 invariant.
- [x] AC4 Grant V2 Antimatter mint + phUSD mint — Phase 5. **Scope addition**: `phUSD.setMinter(Antimatter, true)` (Decision 3; required by `Antimatter.annihilate`).
- [x] AC5 Migrate every V1 staker via CrossVersionMigrator, dust cannot grief — Phase 6 (dust predicate, straggler cap 1 cent, strict-progress guard).
- [x] AC6 Revoke V1 phUSD mint — Phase 7.
- [x] AC7 Fill `StableStakerV2` + `Antimatter` in `mainnet-addresses.ts` — patch script (broadcast tail).
- [x] preview + broadcast npm keys; broadcast chains `backup && forge && patch && :preview`.
- [~] Phase 6 post-condition "loss <= 0 bps + 2 wei on ERC4626" — RELAXED to 2 bps + 2 wei (ERC4626) and 61 bps (USDe market) (Decision 4, disclosed).
- [~] "realized >= booked principal (067)" — implemented as `principalOf(token,V2) >= V2.totalStaked` post-migration (both sides book the same `credited`), not against the pre-migration booked total that story-067 specified.
- [~] Phase 7 "restore V1 pauser to Pauser (V1 may stay paused — executor decides)" — V1 UNPAUSED (Decision 9).
- [x] Phase 8 "pausers registered" — asserted as registration only; loop health of `Pauser.pause()` not asserted.

## Stated purpose (package.json `//` comment + NatSpec)
- [ ] Phase 0 preconditions: owners (V1, phUSD, Pauser, PhusdStableMinter, strategies), strategies unpaused, V1 phUSD mint live while any pool Active, every V1 token registered on PhusdStableMinter (fail loudly), strategy map matches V1, phUSD minter-set baseline (mask 511 / mintVersion 0).
- [ ] Phase 1 pause V1 (`setPauser(OWNER)`, `pause()`), skipped once finalized (V2 pauser == Pauser).
- [ ] Phase 2 deploy Antimatter(OWNER); `setPhUSD(PHUSD)`, `setPhUSDMinter(PHUSD_STABLE_MINTER)`; read back.
- [ ] Phase 3 deploy StableStakerV2(antimatter, OWNER); `setPauser(OWNER)` + `pause()` BEFORE any addToken.
- [ ] Phase 4 per V1 token: `addToken`, `strategy.setClient(V2,true)`, idle-balance guard (rescue to OWNER), `setYieldStrategy`, `setSetAsideBuffer(V2, V1's %)` (10/10/25), `antimatterPerDay(C*21/10)`, `autoAnnihilateAvailable`.
- [ ] Phase 5 `antimatter.setApprovedMinter(V2)`, `phUSD.setMinter(V2)`, `phUSD.setMinter(Antimatter)`; two-sided minter delta (mask unchanged).
- [ ] Phase 6 deploy CrossVersionMigrator(V1, V2, OWNER); `setMigrator` on V1 and V2; per token: relinquish `principalOf(V1) - totalStaked` iff > 0 (DOLA 26.898455742910213445, USDC 27.043385), market exit pre-quote / ERC4626 maxRedeem guard, `initiateMigration`, plan (dust predicate), maxDeposit guard, batch `migrate` (25/call, strict progress), post-conditions.
- [ ] Phase 7 finalize: `setSetAsideBufferRecipient(V2)` on DOLA/USDC (USDe strategy has no recipient), revoke V1 phUSD mint, V1 pauser -> Pauser + unpause, V2 + Antimatter pauser -> Pauser + `register`, V2 `unpause`, `claimEnabled` stays false.
- [ ] Phase 8 wiring assertions (both modes).
- [ ] Preview-only smoke: Antimatter mint-revocation proof (throwaway + V2), 100-unit stake/withdraw on every V2 pool, 1000 DOLA stake + 10 min + `autoAnnihilate` pays phUSD.
- [ ] Broadcast tail: patch script FILLs 2 keys (completed-status gate, SAME idempotency, COLLIDE exit 4, key-set drift exit 3), then `:preview` as post-broadcast verification.

## Declared pre-conditions (require before any mutation / before each step)
- `block.chainid == 1`; RATE 21/10; `MIGRATE_CHUNK in 1..50`; `STRAGGLER_CAP_CENTS in (0,1]`.
- Progress file: every recorded non-zero address has code (else abort with trim instruction); baselines write-once.
- `owner() == OWNER` for V1, phUSD, Pauser, PhusdStableMinter, each strategy; strategy not paused.
- V1 pauser in {Pauser, OWNER}; V1 token list non-empty; token in hard-coded strategy map; if Active, `V1.yieldStrategy(t) == map`.
- PhusdStableMinter registration non-zero and decimals == token decimals.
- If any V1 pool Active: V1 can mint phUSD (at current mintVersion).
- Phase 4: V2 pool `totalStaked == 0` and V2 idle balance == 0 immediately before `setYieldStrategy`; `C > 0`.
- Phase 6: `migrator.oldStaker == V1`, `newStaker == V2`, owner OWNER; `versionOf(V1)==1`, `versionOf(V2)==2`; market exit quote >= strategy minOut / ERC4626 `maxRedeem >= shares`; stragglers' summed principal < cap; ERC4626 `maxDeposit >= migrating credit`; V1 phUSD mint live while migratable stakers remain.
- Phase 7: every V1 pool Migrating and zero migratable stakers remain.

## Declared post-conditions (assert after each step / Phase 8)
- Read-backs: Antimatter phUSD/minter; V2 STAKER_VERSION/antimatter/owner; V2 paused before setup; client/strategy/buffer/rate per pool; approved minter; phUSDMintAvailable; Antimatter phUSD mint; setMigrator both sides.
- `initiateMigration`: pool Migrating, `principalOf(V1) == 0`.
- Per batch: V1 stakerCount drops by exactly the batch length.
- Per pool: V1 stakerCount == stragglers; V1 totalStaked == straggler principal; per migrated user `0 < post <= pre`, `pre - post <= pre*maxLossBps/1e4 + 2 wei` (ERC4626 2 bps, USDe 2*30+1 = 61 bps); zero-credit users hold 0 on V1; `V2.totalStaked == sum(V2 userInfo)`; `principalOf(V2) >= V2.totalStaked` ("067 floor").
- Phase 7: recipient == V2 where it exists; V1 phUSD mint revoked; V1 pauser Pauser and unpaused; V2 unpaused; claimEnabled false.
- Phase 8: Antimatter owner/name/symbol/phUSD/minter; approved-minter set exactly {V2}; V1 and migrator not Antimatter minters; V2 phUSD mint; V1 revoked; Antimatter phUSD mint; minter mask == baseline minus V1 bit; mintVersion unchanged; migrator and SYA hold no phUSD mint; V2 token set == V1 token set; per pool strategy, client, buffer %, recipient, rate, V2 Active, autoAnnihilateAvailable, V1 Migrating, `principalOf(V1)==0`, V1 totalStaked < cap; V2/Antimatter/V1 pauser == Pauser; V1 unpaused; V2 + Antimatter registered; V2 unpaused; claimEnabled false.

## NOT declared (gaps relevant to the audit)
- No assertion on the migrator role after finalize (V1.migrator / V2.migrator left = transient CrossVersionMigrator).
- No read of V1's prior migrator (0x17DC492A…b342) before overwrite.
- No check that `Pauser.pause()` actually succeeds over the registered set V2 and Antimatter are handed to.
- Post-broadcast `:preview` does not assert "nothing left to do": each phase re-performs outstanding work under prank, and the per-user loss bound is evaluated only for users migrated in the same leg.
- Smoke `autoAnnihilate` exercised on DOLA only (USDC/USDe reward path not smoke-tested by the script).
