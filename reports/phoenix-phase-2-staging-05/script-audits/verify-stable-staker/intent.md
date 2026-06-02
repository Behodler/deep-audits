# Intent — verify-stable-staker (npm test:stable-staker)

`./verify-stable-staker.sh` — Story 051 end-to-end StableStaker config/smoke check. NOT a unit test:
a clean, no-revert run IS the verification. Spins up its OWN anvil, runs deploy:local, stakes 1000 DOLA,
advances the live chain clock 1 day, then claims+withdraws and asserts reward/principal/baseline.

## Stated purpose (from script header + the two interaction scripts)
- [ ] Bring up a fresh anvil + deploy the full mock stack (deploy:local, incl. Phase 3.7 StableStaker).
- [ ] STEP 1 (StakeStableStaker): stake 1000 DOLA into the DOLA pool as the deployer.
- [ ] STEP 2: `cast rpc evm_increaseTime 86400` + `evm_mine` — advance the LIVE clock one day (vm.warp
      inside a `--broadcast` script does NOT move the live chain clock; reward accrues off block.timestamp).
- [ ] STEP 3 (ClaimWithdrawStableStaker): claim phUSD, withdraw full principal, assert the 3 invariants.

## Declared pre-conditions
- Env: `ANVIL_PRIVATE_KEY` must be set — both interaction scripts read it via `vm.envUint("ANVIL_PRIVATE_KEY")`.
  The shell exports `PRIVATE_KEY` (same hardcoded anvil acct0 key) but does **not** export `ANVIL_PRIVATE_KEY`;
  it is supplied only by the repo-root `.envrc` (direnv). If unset, STEP 1 reverts before any staking.
- Tools: anvil/cast/forge/npm on PATH.
- STEP 1 `require`: DOLA pool `phusdPerSecond == 10 ether / 86400` (drift guard on the deploy-set rate);
  deployer holds >= 1000 DOLA (minted 1,000,000 at deploy).

## Declared post-conditions (Solidity `require` — a revert aborts the shell via `set -e`)
STEP 1:
- `userInfo.amount == STAKE_AMOUNT` (1000e18)
- `totalStakedAfter == totalStakedBefore + STAKE_AMOUNT`
- `dolaBefore - dolaAfter == STAKE_AMOUNT`

STEP 3:
- `pending > 0` ("did time advance?")
- `rewardCredited ∈ [9.9e18, 10.1e18]` (EXPECTED_DAILY_PHUSD = 10e18, ±1%)
- `userInfo.amount == 0` (principal fully withdrawn)
- `returned <= STAKE_AMOUNT` (strategy never over-pays)
- `STAKE_AMOUNT - returned <= 10` wei (ERC4626 rounding dust kept protocol-side)
- `totalStakedFinal == baseline` (baseline = totalStakedNow - STAKE_AMOUNT)

## Notes on the assertion bands (verified against realized values below in side-effects.json)
- 10 phUSD/day at the floored rate 115740740740740 wei/s = 115740740740740 * 86400 = 9999999999999936000
  (64000 wei short of 10e18 from per-second flooring) — the lower band 9.9e18 absorbs this trivially.
- The 1% upper band absorbs any extra elapsed seconds from block mining between stake and claim.
