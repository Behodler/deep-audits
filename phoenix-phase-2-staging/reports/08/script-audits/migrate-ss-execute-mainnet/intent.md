# Intent — migrate:ss-execute-mainnet (Story 055, StableStaker migration SET 2/2)

Forge target: `script/MigrateStableStakerMainnet.s.sol:MigrateStableStakerMainnet::run()`
Signer: Ledger `0xCad1a7864a108DBFF67F4b8af71fAB0C7A86D0B6` (HD `m/44'/60'/46'/0/0`)
Predecessor (opens the window this consumes): `migrate:ss-initiate-mainnet` → `InitiateYieldStrategyWithdrawal.s.sol` (Story 054).

## Stated purpose (from NatSpec + intent comment + structure)
The script executes the whole DOLA/USDC/USDe yield-strategy cutover under one broadcast, in fixed phase order:

- [ ] **PHASE A — drain**: re-call `totalWithdrawal(token, minter)` on each of the 3 OLD strategies so it falls into the *Executable* branch and redeems the minter's principal to the deployer EOA. Capture the **actual received** via owner balance delta (not the story-054 snapshot).
- [ ] **PHASE B — deploy**: deploy 3 new `ERC4626YieldStrategy(deployer, token, vault)` reusing the SAME external vault + underlying each old strategy used (read on-chain & asserted in B), in fixed order DOLA → USDC → USDe.
- [ ] **PHASE C — minter cutover + re-deposit**: per token: `newYS.setClient(minter,true)` → `minter.registerStablecoin(token,newYS,PRESERVED rate,decimals)` → `minter.approveYS(token,newYS)` → deployer `approve(newYS,received)` → `newYS.depositAsOwner(token,received,minter)`.
- [ ] **PHASE D — SYA cutover**: add new (`addYieldStrategy(newYS,token)` + `newYS.setWithdrawer(SYA,true)`) for all 3 FIRST, THEN `removeYieldStrategy(oldYS)` for all 3 (never leaves SYA empty mid-run).
- [ ] **PHASE E — dependency verification**: verified NO-OP (no phlimbo re-wire required).
- [ ] **PHASE F — StableStaker**: deploy `StableStaker(phUSD, owner)`; `setPauser(PAUSER)` then `PAUSER.register(ss)`; `phUSD.setMinter(ss,true)`; per token `addToken` → `newYS.setClient(ss,true)` → `setYieldStrategy` → `newYS.setSetAsideBuffer(ss,10)` → `phUSDPerDay(token, rate)` (USDe 5 / USDC 4 / DOLA 1 e18/day).
- [ ] **POST (JS)**: `backup-mainnet-addresses.js` (pre) snapshots the addresses file; `patch-mainnet-addresses-stable-staker.js` (post) overwrites `YieldStrategy{Dola,USDC,USDe}` and zero-only-writes `StableStaker` in `server/deployments/mainnet-addresses.ts` from the broadcast log.

## Declared pre-conditions (require/assert BEFORE the broadcasted mutations)
Global pre-flight (`_globalPreflight`, runs before prank/broadcast):
- `OLD_YS_{DOLA,USDC,USDE}.owner() == OWNER_ADDRESS`
- `PHUSD_STABLE_MINTER.owner() == OWNER_ADDRESS`
- `SYA.owner() == OWNER_ADDRESS`
- `PHUSD/PAUSER/MINTER/SYA != address(0)`
- `DAILY_USDE==5e18 && DAILY_USDC==4e18 && DAILY_DOLA==1e18` (all > 0)
- `SETASIDE_BUFFER==10 && <=100`
- `setUp`: `block.chainid == 1`

Phase A executability gate (`_drainOne`, per strategy):
- `!oldYS.paused()`
- **window open**: derived from `withdrawalStates(token,minter)` (initiatedAt,status): executable iff `status==Executable && now<=initiatedAt+72h`, OR `status==Initiated && now in [initiatedAt+24h, initiatedAt+72h]`; else REVERT "Phase A STOP: withdrawal not Executable…". (Deliberately derives from `initiatedAt`, not the lazily-stored enum.)
- `received > 0` per token after the redeem.

Phase B (`_deployOne`, per strategy, before deploy):
- `oldYS.underlyingToken() == token`
- `oldYS.vault() == expectedVault` constant

Phase C (`_cutoverMinter`, per token, before mutate):
- `minter.stablecoinConfigs(token).exchangeRate == 1e18` (preserve check)
- `minter.stablecoinConfigs(token).decimals == expectedDecimals` (18/6/18)

Phase D (`_syaRemove`):
- `SYA.isRegisteredStrategy(oldYS) == true` before removing.

## Declared post-conditions (asserts AFTER the mutations)
The script does NOT add explicit post-condition asserts beyond the inline per-step requires above. Implicit "proof of end state" relies on:
- `received > 0` (Phase A) and `principalOf(new)` logged (not asserted) in Phase C.
- `isRegisteredStrategy(old)` checked only as a *pre*-condition of removal, not re-checked after.
- No assert that `minter.stablecoinConfigs(token).yieldStrategy == newYS` after re-point.
- No assert that StableStaker is a recognized phUSD minter / that a smoke `mint`/`stake` succeeds.

> **Gap (declared spec):** there is NO post-broadcast verification block. The script trusts each setter to have taken effect without re-reading end state — see findings `weak-postcondition`.

## NOT pre-flighted (owner gates the script relies on but never asserts)
- `PHUSD.owner() == OWNER_ADDRESS` (needed for `setMinter`) — **not** asserted. (On-chain: owner == OWNER ✓, but unguarded.)
- `PAUSER.owner()/authorization` to allow `register` — **not** asserted.
- StableStaker `migrator` is never set (only relevant to StableStakerMigrator flow, not the listed successors).
