# Intent — migrate:saga2.3-rewire (MigrateSaga2Rewire.s.sol)

STEP 2.3 (FINAL) of "MIGRATE SAGA 2 — InPlaceMigrator route": 2.1 deploy → 2.2 migrate → 2.3 rewire.
Forge target: `script/MigrateSaga2Rewire.s.sol:MigrateSaga2Rewire`. HEAD `3d52474`.
Fork-verified by replaying 2.1→2.2→2.3 on one mainnet fork (block 25322425) via
`test/AuditSaga2_3Rewire.t.sol`.

## Stated purpose (from script header + npm `//` comment + plan-doc §5 Script 3)
- [x] Repoint `StableYieldAccumulator` (0x3C69…8270) from the OLD DOLA/USDC strategies to the NEW
      ones (ysDolaV2/ysUsdcV2), i.e. `addYieldStrategy(ysV2, token)` for DOLA + USDC.
- [x] Retire the OLD strategies (0x90ce DOLA, 0x90af USDC) as accumulator sources via
      `removeYieldStrategy(oldYS)`.
- [x] Leave the USDe market strategy (0xaC2e…) untouched.
- [x] Run the final verification gates (`_verify()`).
- [x] No address change: pure on-chain registry repoint; `mainnet-addresses.ts` untouched
      (entry-manifest `jsChain.pre == [] && jsChain.post == []` — CONFIRMED EMPTY).
- [x] Idempotent: add/remove guarded on `isRegisteredStrategy` so a re-run is a no-op.

## Ordered steps (as executed under owner prank / broadcast)
1. `_loadDeployments()` — read ysDolaV2/ysUsdcV2/minterV2 from `script/migration-inputs/saga2-deployments.json`
   (written by 2.1 broadcast). Reverts "deployments JSON incomplete" if any is zero / file missing.
2. Preflight gate A: `ACCUMULATOR.owner() == OWNER_ADDRESS`.
3. Preflight gate B: `STAKER.yieldStrategy(DOLA) == ysDolaV2` ("DOLA not rewired - run 2.2").
4. Preflight gate C: `STAKER.yieldStrategy(USDC) == ysUsdcV2` ("USDC not rewired - run 2.2").
5. `addYieldStrategy(ysDolaV2, DOLA)`  (guarded: only if not already registered).
6. `addYieldStrategy(ysUsdcV2, USDC)`  (guarded).
7. `removeYieldStrategy(OLD_DOLA_YS)`  (guarded: only if currently registered).
8. `removeYieldStrategy(OLD_USDC_YS)`  (guarded).
9. `_verify()` — 8 post-condition gates (below). View-only; reverts the whole tx on any failure.

## Declared pre-conditions (the 3 preflight `require`s before the mutation block)
- `ACCUMULATOR.owner() == OWNER_ADDRESS` (0xCad1…D0B6). Live: TRUE.
- `STAKER.yieldStrategy(DOLA) == ysDolaV2` — drift guard / proves 2.2 ran. Live (raw mainnet): FALSE
  (staker still on OLD 0x90ce) → raw 2.3 against live fork reverts here. After 2.1→2.2 replay: TRUE.
- `STAKER.yieldStrategy(USDC) == ysUsdcV2` — same; after replay: TRUE.

## Declared post-conditions (the 8 `_verify()` `require`s after the mutation block)
Accumulator registry (4):
- `isRegisteredStrategy(ysDolaV2) == true`
- `isRegisteredStrategy(ysUsdcV2) == true`
- `isRegisteredStrategy(OLD_DOLA_YS) == false`
- `isRegisteredStrategy(OLD_USDC_YS) == false`

Staker health on the new strategies (4):
- `!STAKER.withdrawDisabled(DOLA)` (not underwater — `totalBalanceOf >= principalOf` on ysDolaV2)
- `!STAKER.withdrawDisabled(USDC)`
- `ysDolaV2.principalOf(DOLA, STAKER) > 0` (stakers re-credited)
- `ysUsdcV2.principalOf(USDC, STAKER) > 0`

Set-aside buffer carried forward — 10% (2):
- `ysDolaV2.setAsideBufferSize(STAKER) == 10`  ← codifies 2.1 M-03's 10% (was 25% on old strats)
- `ysUsdcV2.setAsideBufferSize(STAKER) == 10`

Minter V1 drained from the OLD strategies (2):
- `OLD_DOLA_YS.principalOf(DOLA, MINTER_V1) == 0`
- `OLD_USDC_YS.principalOf(USDC, MINTER_V1) == 0`

(plus log-only: staker/minterV2 principals on the new strategies — not gated.)

## Mapping to plan-doc §5 Script 3 step 4 verification list
| Plan §5.4 gate | In 2.3 `_verify()`? | Notes |
|---|---|---|
| `migrator.totalParked(DOLA|USDC) == 0` | NO (asserted by 2.2 `_postAssert`, not 2.3) | Covered upstream; 2.3 re-asserts staker principal>0 instead. |
| `newDolaYS.principalOf(DOLA, staker) > 0`, USDC>0 | YES | gates 7,8 above. |
| `withdrawDisabled == false` (not underwater) | YES | gates 5,6 above. |
| `newDolaYS.principalOf(DOLA, minterV2) > 0`, USDC>0 | **NO — log-only** | plan says "may be 0 if minter had no position"; downgraded from gate to console.log. Acceptable per script comment. |
| USDe market YS client includes minterV2; minterV1 still authorized; USDe untouched | **NOT verified in 2.3** | Established in 2.1; 2.3 does not re-check. Gap is benign (USDe out of 2.3 scope) but undocumented. |
| `phUSD.setMinter(minterV1)==false`, `setMinter(minterV2)==true` | **NOT verified in 2.3** | Established in 2.1; 2.3 does not re-check. |
| (NOT in plan) `setAsideBufferSize==10` | YES (2.3-added) | codifies the 10% — see side-effects + findings. |

## Buffer / set-aside protocol-wide concept (owner clarification)
Owner states the strategy "set-aside" and the staker "buffer" are ONE protocol-wide concept, realized
via TWO cushions: (1) skimmed DOLA/USDC surplus transferred to the staker as idle balance in 2.2 step 8;
(2) strategy-level 10% withholding for the staker on the NEW strategies (2.1 step 5a). 2.3's `_verify()`
asserts ONLY cushion (2) (`setAsideBufferSize==10`). It does NOT assert that cushion (1) landed, nor
that `setAsideBufferRecipient == STAKER` on the new strategies. See candidate-findings (S23-01).
