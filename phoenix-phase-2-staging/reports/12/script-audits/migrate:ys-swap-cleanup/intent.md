# Intent — migrate:ys-swap-cleanup (PostMigrationCleanup, story-060 step 5/5)

Forge target: `script/PostMigrationCleanup.s.sol:PostMigrationCleanup` — `run()`
Commit: b27c6ac. Intent doc: `docs/stable-staker-migrations/yield-strategy-swap-June-12-2026.md` (Step 6 + Set-Aside Buffer + Post-Migration Options).
package.json doc-key: `//ys-swap-migration`.

## Stated purpose (from NatSpec + doc Step 6)
- [ ] Verify the YS-swap migration left a consistent end-state (12 on-chain checks, all REVERT on failure).
- [ ] Revoke the temp staker's phUSD minter authorization — the sole state-changing call.
- [ ] Declare the YS-swap migration COMPLETE.

This is a **verify-then-revoke** finalizer. Its only mutation is `phUSD.setMinter(tempStaker, false)`;
the 12 verifications are read-only `require`s that gate that revocation.

## Declared pre-conditions
- `setUp()`: `block.chainid == 1` (mainnet only).
- `script/migration-inputs/ys-swap-deployments.json` exists & parses: `.ysDolaV2`, `.ysUsdcV2`, `.tempStaker` (required); `.usdeSkimmed`, `.dolaSkimmed`, `.usdcSkimmed` (optional, try/catch).
- `script/migration-inputs/leg2-stakers.json` exists & parses: `.tokens.DOLA.count`, `.tokens.USDC.count`.
- `phUSD.owner() == OWNER_ADDRESS (0xCad1…D0B6)` — asserted just before the mutation.

## Declared post-conditions (the 12 verify requires, in order)
- [ ] **V1a/1b** `tempStaker.stakerCount(DOLA)==0` && `stakerCount(USDC)==0` (temp fully drained).
- [ ] **V2** `original.stakerCount(DOLA) == leg2 .tokens.DOLA.count`.
- [ ] **V3** `original.stakerCount(USDC) == leg2 .tokens.USDC.count`.
- [ ] **V4** `ysDolaV2.principalOf(DOLA, original) > 0`.
- [ ] **V5** `ysUsdcV2.principalOf(USDC, original) > 0`.
- [ ] **V4b** (hard solvency) `ysDolaV2.principalOf >= original.poolInfo(DOLA).totalStaked`.
- [ ] **V5b** (hard solvency) `ysUsdcV2.principalOf >= original.poolInfo(USDC).totalStaked`.
- [ ] **V4b-band** *(only if `dolaSkimmed>0`)* `dolaBuffer ∈ [dolaSkimmed/2, dolaSkimmed*2]`.
- [ ] **V5b-band** *(only if `usdcSkimmed>0`)* `usdcBuffer ∈ [usdcSkimmed/2, usdcSkimmed*2]`.
      where `buffer = principalOf(token,original) - poolInfo(token).totalStaked`.
- [ ] **V6/V7** `original.withdrawDisabled(DOLA)==false` && `withdrawDisabled(USDC)==false`.
- [ ] **V8/V9** `ysDolaV2.setAsideBufferSize(original)==10` && `setAsideBufferRecipient()==original`.
- [ ] **V10/V11** `ysUsdcV2.setAsideBufferSize(original)==10` && `setAsideBufferRecipient()==original`.
- [ ] **V12** *(only if `usdeSkimmed>0`)* `IERC20(USDe).balanceOf(original) >= usdeSkimmed`.

## Declared mutation (post-verify)
- [ ] `phUSD.setMinter(tempStaker, false)` — under `vm.startPrank(OWNER)` (preview) or `vm.startBroadcast()` (Ledger).

## Intent the doc declares but this script does NOT do
- Step-6 item "Update `mainnet-addresses.ts`" — handled by a sibling (`migrate:ys-swap-reset`'s patch JS), not here. (No finding — correctly delegated.)
- Doc "Post-Migration Options" presumes migrator permissions are *eventually revoked* ("do it before revoking migrator permissions"). **No story-060 script revokes the migrator** from the original or temp staker, and cleanup neither performs nor verifies it. → skipped-step (a).
- SYA re-wiring to V2 strategies — never referenced by any story-060 script; cleanup does not verify SYA wiring. → skipped-step (b), root cause = deploy-entry F3.
