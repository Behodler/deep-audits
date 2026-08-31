# Intent — promotion-ready suite (run-24, HEAD `b9391b1`, baseline `c4396b1`)

Entry points in scope: `promotion-ready:snapshot`, `:dry`, `:broadcast`, `:resume`, `:verify`.
The audited delta is **story 076** only (commit `f445e87`, merged at `b9391b1`).

## Authoritative source (Law 2)

- **Story 076** — `~/code/product-owner/stories/phStaging2/complete/phStaging2-promotion-ready/076-phlimbo-v3-cutover-migration-in-promotion-ready-script.md`
  (state: `complete/`, human-promoted 2026-08-04T00:50:10Z). Resolved by a project-wide glob;
  exactly one hit, no ambiguity.
- Supporting: story 072 (same dir, the cutover this extends), stories 074/075
  (`auto-complete/phStaging2-audit-fixes/`), and the `//`-doc keys above each npm key.

## Stated purpose — Phase 4e (story 076 "Proposed Phase 4e ordering", steps 1-14)

- [x] 1. Deploy `PhlimboV3(PHUSD, rewardToken, depletionDuration)` with the last two read **live** off V2 — `:1666-1676`
- [x] 2/3. `setDesiredAPY(bps)` ×2 (preview + commit) mirroring V2's live value — `:1684-1688`
- [x] 4. `setPauser(PAUSER)` + `Pauser.register(phlimboV3)` — `:1691-1696`
- [x] 5. **`phUSD.setMinter(phlimboV3, true)`** — the deliberate story-072 invariant break — `:1710-1714`
- [x] 6. Deploy `MigratorV2V3(PHLIMBO_V2, v3, PHUSD, rewardToken)`; no mint role for the migrator — `:1719-1729`
- [x] 7. `setMigrator(migrator)` on **both** V2 and V3, both read back — `:1732-1741`
- [x] 8/9. `seedUsers` from the snapshot, chunked `migrate(25)` to `migrateIterator == -1`, up to 3 reseed passes — `:1845-1874`
- [x] 10. Conservation against the **write-once** Phase 0 baseline — `:1887-1892`
- [x] 11. Wind V2 down `setDesiredAPY(0)` ×2 — **not** a pause — `:1757-1760`
- [x] 12. `phlimboV2.setMigrator(0)` — `:1763-1768`
- [x] 13. Hard gate `require(v2.totalStaked() == 0)` — `:1779-1782`
- [x] 14. **`phUSD.setMinter(PHLIMBO_V2, false)`** after 11 and 13 — `:1791-1795`
- [x] Phase 5 `:1974` repointed to `sya.setPhlimbo(newPhlimboV3)`, `approvePhlimbo` still after it
- [x] **No `pause()` on PhlimboV2 anywhere** — verified by exhaustive grep; the only `pause()` calls are Phase 4d's old batch minter (`:1596`) and Phase 6's V1 staker (`:2165`)
- [x] **No `startPromotion` anywhere** — verified by grep

## Declared pre-conditions (Phase 0, `_phase0_phlimboV3Preconditions` `:754-853`)

- `phUSD.owner() == OWNER` and `PHLIMBO_V2.owner() == OWNER`
- `V2.rewardToken() != 0`, `V2.depletionDuration() > 0`, `V2.phUSD() == PHUSD`
- Write-once monotonic `phlimboV2StakedAtCutover`, with a **RESUME ABORT** when
  `p4e_migrate` is configured but the baseline is absent (`:798-801`)
- Fresh leg: `phlimboV2StakedAtCutover > 0`
- V2 snapshot file: target == `PHLIMBO_V2`, `blockNumber > 0`, `unixTimestamp` within
  `MAX_V2_SNAPSHOT_AGE` (24 h), `users[]` non-empty (`:822-853`)
- Mid-phase (`:1748-1751`): `!v2.paused()` — inside the `p4e_migrate` gate, so **skipped on resume**
- Configuration Safety: `0 < MIGRATE_CHUNK <= 100`, `MAX_MIGRATE_CALLS > 0`,
  `0 < MAX_MIGRATION_PASSES <= 10`, `MAX_V2_SNAPSHOT_AGE > 0`

## Declared post-conditions (Phase 7 `_phase7_phlimboV3Assertions` `:2376-2455`; re-run live by `VerifyPromotionReady` via inheritance)

- V3: `owner == OWNER`, `pauser == PAUSER`, `Pauser.isRegistered`, `phUSD`/`rewardToken` match V2, `depletionDuration > 0`
- **Positive mint guard**: `authorizedMinters(v3).canMint && version == mintVersion()`
- No-promotion negative: `promoToken() == 0`, `promoPhase() == None`
- `v3.migrator() == migratorV2V3`, `v2.migrator() == 0`, `migrator.seeded()`, `migrateIterator == -1`, both migrator endpoints
- `v2.desiredAPYBps() == 0`, `v2.totalStaked() == 0`, V2 mint authority revoked
- Conservation `v3.totalStaked() >= phlimboV2StakedAtCutover` (relaxed from `==`; **human-accepted**, story 076 lines 896-901)
- `newSYA.phlimbo() == v3`, non-zero `rewardToken` allowance, `SYA.rewardToken() == V3.rewardToken()`
- **NOT asserted despite the docstring claim** (`:1643-1645`) and the Phase 7 banner + log (`:2418`, `:2454`): `!v2.paused()`
- **NOT asserted anywhere**: `v3.desiredAPYBps()` and `v3.apySetInProgress()`

## `VerifyPromotionReady` (story 075, reworked by 076)

- `_requireResolved` extended to `PhlimboV3` + `MigratorV2V3`; log count 14 → 16 (`:143-146`)
- `_verifyMintAuthorityInvariance` (`:228-299`) — three claims: two-sided mask delta
  `liveMask == baseline & ~(1<<19)`, positive V3 grant, `_requireNotPhusdMinter` over the
  other 15 (V3 the sole exclusion, `MigratorV2V3` retained)
- `_adoptPersistedPhlimboBaseline` (`:190-200`) aborts on an absent or zero baseline
- Candidate set closed by `require(i == 20)` (`:921`), `PHUSD_MINTER_BIT_PHLIMBO_V2 = 19` (`:928`),
  reorder guard `_requirePhlimboV2BitIndex()` (`:933-939`)

## npm-key delta (3 changed keys)

- `:snapshot` gains `&& node scripts/snapshot-phlimbo-v2-stakers.js`
- `:dry` / `:broadcast` / `:resume` gain the leading
  `node scripts/check-phlimbo-snapshot-age.js --variant v2 --fail-on-stale` gate
- `:broadcast`'s "patcher is the final state-mutating element" rule is intact — nothing was
  inserted between the patcher and the read-only `:verify` leg
