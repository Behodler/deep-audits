# Run 40, Tier 3: stateful and fork tests (phoenix-phase-2-staging)

- **Workspace:** `work/` at a4f9f3c, with `lib/yield-claim-nft` at 0fd6bdf.
- **Fork:** mainnet block **26181500**, pinned. Mainnet head at run time was 26181543. The RPC came from `.envrc` `RPC_MAINNET`, and the liveness probe passed.
- **Test files (audit-authored, AUDIT-LOCAL):**
  - `work/test/audit-run40/UniPoolerCutoverCoreRun40.fork.t.sol`
  - `work/test/audit-run40/UniswapHelperInvariantsRun40.fork.t.sol`
- **Raw logs (this directory):**
  - `core-fork-tests.log`: full core suite, `-vvv`.
  - `core-code001-fuzz-fresh.log`: fresh fuzz campaign with seed 40 and a clean failure-persist dir.
  - `helper-invariants.log`: final honest campaign.
  - `helper-invariants.attempt1-harness-overreach.log`: first campaign, which failed because of a harness defect (see below).
  - `helper-tripwires.log`

**Engines.** Only forge was used: the invariant runner and the fuzzer, with `--threads 2`. **Medusa was not run.** Every target here depends on live mainnet venues (Balancer V3 pool, Sky PSM, Curve, Uniswap V3, NFTMinterV2/hook). The rigor rules forbid non-fork, constant-price doubles. A crytic-compile build of this via_ir repo is also a full rebuild, which risks the WSL2 crash noted in memory. Echidna was not run for the same reason. Nothing timed out.

**Honesty rule.** A passing helper invariant means "no counterexample found in 16 runs x depth 15 = 240 calls per invariant". It is not a proof.

## 1. UniPoolerCutoverCore (fork)

### How broadcast was modelled (CODE-001)
The core's steps are `internal`, so the test contract inherits `UniPoolerCutoverCore` and exposes each step as an external wrapper that does `startPrank(OWNER)` at the core's call depth. Under `forge script --broadcast`, each state-changing call becomes its own OWNER transaction. Its calldata is fixed in simulation, and the core's `require`s only run in simulation. The test models this in three stages:

1. **Simulate.** Snapshot the state, run steps 0..6 through the real core, and record the baked values: `bptIn`, `minAmountsOut`, `sAmt`/`pAmt` (the step-5 deltas), and the new pooler's address.
2. **Revert** to the snapshot.
3. **Replay.** Run steps 0..4 through the core. The test asserts that the replay deploys the same `newPooler` address. Then an **interfering Balancer V3 swap** (Router `swapSingleTokenExactIn` via Permit2) runs. After that, step 5 runs as the raw baked txs (`approve` + `removeLiquidityProportional`), and step 6 runs as the raw baked txs (2x `approve` + Router02 `addLiquidity(sAmt, pAmt, sMin, pMin, newPooler, deadline)`). No core `require` is evaluated for steps 5 and 6 during the replay.

Tolerances are `exitToleranceBps = seedToleranceBps = 10`, the same as the dev rehearsal and run-39. Story 103's mainnet values are not yet set, and the core allows up to 100 bps.

### Results

| test | result | what it proves |
|---|---|---|
| `test_P_cleanRunEndState` | PASS | Steps 0..12 run as separate calls with no interference. Afterwards the pair's reserves are exactly the seeded amounts (18,571.887281957274477649 sUSDS / 22,558.708306572739389505 phUSD), the LP sits on the new pooler, and the old pooler is `paused()`. The old pooler's `_minter` storage slot reads **OWNER**: it was located by its pre-cutover value, NFTMinterV2. Index 4 points to the new pooler, and the OWNER's sUSDS and phUSD are unchanged. |
| `test_P_cleanRunEndState_orchestrator` | PASS | `_runCutover` in one call gives the same end state. |
| `test_CODE001_control_noSwap` | PASS | Control. With no interference, the baked exit and baked seed txs both land, and the OWNER keeps 0 sUSDS. |
| `test_CODE001_dustSwap_phUSDIn_seedReverts` | PASS | A swap of **0.001 phUSD in** lets the baked exit **land**, but the baked seed **reverts**. Revert data is `Error("TransferHelper: TRANSFER_FROM_FAILED")` (`0x08c379a0…5472616e7366657248656c7065723a205452414e534645525f46524f4d5f4641494c4544`), raised in `SUsds.transferFrom` inside `UniswapV2Router02.addLiquidity`. Afterwards the OWNER holds 0 BPT (it was burned), **18,571.886765729696524411 sUSDS** and **22,560.181609305761341301 phUSD**. The pair is still empty (0/0) and public. The sUSDS shortfall against the baked `sAmt` is 516,227,577,953,238 wei. Re-running the core then reverts `"UniPoolerCutoverCore: owner holds no BPT"`, so it cannot be resumed. |
| `test_CODE001_dustSwap_sUSDSIn_observe` | PASS (observational) | A swap of 0.001 sUSDS in lets the seed land, but it pulls 0.00076 of the OWNER's **own** phUSD into the pair. 0.000628 sUSDS of protocol value is left unseeded on the EOA. |
| `test_CODE001_organicSwap_{phUSDIn,sUSDSIn}` | PASS (observational) | A 2,000-token swap in either direction makes the **exit itself revert**: `AmountOutBelowMin(address,uint256,uint256)` `0x2f785e46` from the V3 Vault (for example token = sUSDS, out 17,593.8, min 18,553.3). All **20,401.809 BPT stay on the OWNER EOA**, since step 4 already moved them there. |
| `test_CODE001_sweep` | PASS (observational) | See the size sweep below. |
| `testFuzz_CODE001_exitImpliesSeed` | **FAIL (expected)** | This is the property "if the step-5 exit lands, the step-6 seed lands". It is **falsified**. Counterexamples: **26,181,500 wei** phUSD-in (from the first campaign) and **135,600,680,029 wei** phUSD-in (the fresh campaign with `--fuzz-seed 40` and a clean persist dir, which failed on run 2 of 24). |
| `test_CODE003_mintRevertsBetweenStep8And10` | PASS | A control mint before step 8 succeeds. After step 8, and still after step 9, `NFTMinterV2.mint(4, user)` reverts with exactly **`0xee5fc5a8` = `OnlyDispatcher()`**, unwrapped and bubbled from `BalancerPoolerMintDebtHook.onDispatch`. After step 10, mints work again. If the run halts after step 8, re-running the core reverts `"UniPoolerCutoverCore: hook not on old pooler"`. |
| `test_CODE004_recoveryBranchRevertsOnLivePool` | PASS | The live pool reports `isPoolInRecoveryMode=false` and `isPoolPaused=false`. Step 5 in RECOVERY mode reverts with exactly **`0xef029adf…642bb6860b4776cc10b26b8f361fd139e7f0db04` = `PoolNotInRecoveryMode(0x642BB6…db04)`** from the real V3 Vault. `Vault.enableRecoveryMode(pool)` reverts **`0x23dada53` = `SenderNotAllowed()`** for both a stranger and OWNER while the pool is live. |
| `test_CODE005_helperFirstLPBricksCoreStep2AndEscrow` | PASS | The pair is created at core step 1. An ordinary user then calls `UniswapHelper.addLiquidityUSDS(1e18, 1e18, 0, 0, …)`, which succeeds and makes them the first LP: 0.948 LP, and 1000 wei MINIMUM_LIQUIDITY locked at address(0). Core step 2 then reverts `"UniPoolerCutoverCore: pair reserves not empty"`. UniPoolerV2 still deploys, because the canonical-pair check does not test emptiness. `UniPoolerCutoverEscrow.exitAndSeed` reverts with the exact **`UniPoolerCutoverEscrow__PairNotEmpty(r0, r1, b0, b1)`** (selector `0x247b45ec`, args 0.8988e18 / 1e18 / 0.8988e18 / 1e18) before it touches BPT. |
| `test_CODE005_prePairCreated_helperAddSUSDS` | PASS | A stranger pre-creates the pair (createPair is permissionless), and a user adds via `addLiquiditySUSDS`. Core step 2 then reverts `"pair reserves not empty"`. |

#### CODE-001 swap-size sweep (exit tx / seed tx)
| swap in | phUSD-in | sUSDS-in |
|---|---|---|
| 1e7 wei | exit OK, **seed REVERTS** | exit OK, seed OK |
| 1e12 wei | exit OK, **seed REVERTS** | exit OK, seed OK |
| 0.001 | exit OK, **seed REVERTS** | exit OK, seed OK (OWNER's own phUSD pulled in) |
| 1 | exit OK, **seed REVERTS** | exit OK, seed OK (0.76 of OWNER's 1.47 phUSD pulled in) |
| 10 | exit OK, **seed REVERTS** | exit OK, **seed REVERTS** (shortfall > 1.47 phUSD) |
| 100 / 500 / 1000 | exit REVERTS `AmountOutBelowMin`; BPT on OWNER EOA | exit REVERTS `AmountOutBelowMin`; BPT on OWNER EOA |

Every tested interfering swap leaves the cutover stuck mid-way with value on the OWNER EOA:
- **Split brain (pool tokens on the EOA):** any phUSD-in swap from 1e7 wei (the Balancer minimum trade) up to at least 10 phUSD, and an sUSDS-in swap of about 10.
- **Clean exit revert (BPT on the EOA):** swaps of 100 or more in either direction.

Two cases do not strand value this way. With no interference, everything succeeds. Small sUSDS-in swaps (≤1 tested) also succeed, but they consume the OWNER's own phUSD.

### Verdicts
- **CODE-001: CONFIRMED, and stronger than claimed for the trigger.** The scanner said "a dust swap". On the fork, *any* phUSD-in swap down to the 1e7-wei Balancer minimum lets the exit land and makes the seed revert. That happens because the OWNER holds 0 spare sUSDS, so even a 1-wei shortfall fails. The impact is as described: about 18.57k sUSDS and 22.56k phUSD on the OWNER EOA, an empty public pair, and no resume. One addition the scanner missed: at 10 bps, an organic swap of 100 or more reverts the exit cleanly but leaves **all 20,401.8 BPT on the EOA**, again with no resume, because step 4 already ran.
  - The "without --slow, steps 7-12 cut index 4 over to an unseeded pooler" sub-claim was **not exercised**.
- **CODE-003: CONFIRMED.** The exact revert is `OnlyDispatcher()` `0xee5fc5a8` between step 8 and step 10. The no-resume claim is also confirmed (step-0 revert `"hook not on old pooler"`).
- **CODE-004: CONFIRMED,** with exact error `PoolNotInRecoveryMode(pool)` `0xef029adf`. **Nuance against the suggested fix:** `Vault.enableRecoveryMode(pool)` reverts `SenderNotAllowed()` for anyone, OWNER included, while the pool is live. Calling it from the RECOVERY branch only works once the pool or vault is actually paused, which is the scenario after 30 Oct. The paused-pool path was **not tested**, because the pool's pause state could not be produced faithfully on the fork.
- **CODE-005 / FAITH-001: CONFIRMED.** An honest helper add into the existing empty pair bricks core step 2 (`"pair reserves not empty"`) and the escrow (`PairNotEmpty`, exact args). The MINIMUM_LIQUIDITY lock means the reserves can never return to 0.

## 2. UniswapHelper stateful invariants (fork, real venues)

**Setup.** The helper is deployed with the mainnet constructor inputs. The phUSD/sUSDS V2 pair, which does not exist at this block, is created and seeded with **exactly** the amounts the core fork test measured the cutover would seed. That gives the post-cutover pair at its real depth. The handler covers all 8 entry points:
- `swapToPhUSD` and `swapFromPhUSD`, over sUSDS, USDS, USDC, DOLA and USDe
- `swapETHToPhUSD` and `swapPhUSDToETH`
- `addLiquiditySUSDS`, `addLiquidityUSDS`, `removeLiquiditySUSDS` and `removeLiquidityUSDS`

Every route goes through the real Sky PSM, sUSDS, Curve DOLA-3CRV, Curve USDe/USDC, Uniswap V3 0.05% and Router02. Amounts range from 1 to 2,000 tokens and from 0.001 to 1 ETH. `minOut` takes one of four forms: 0, the live quote minus 1 bp, the quote +1% (which must revert), or a random value in [0, 2·quote]. Two priming calls seed real state before the campaign starts.

| invariant | result (runs x depth = calls) |
|---|---|
| I1: helper holds 0 of phUSD, sUSDS, USDS, USDC, DOLA, USDe, WETH, LP, and 0 ETH, checked after every call and by the runner | PASS (16 x 15 = 240) |
| I2: every helper allowance to {V2 router, sUSDS, PSM, Curve DOLA, Curve USDe, V3 router} is 0 for all 8 tokens | PASS (240) |
| I3: on success, delivered ≥ minOut, and each `used ≥ min` for adds when min ≤ desired | PASS (240) |
| I4: on success, the returned amounts equal the recipient's measured deltas (LP, refunds, outputs) | PASS (240) |

**Coverage.** Every entry point produced successes and `InsufficientOutput` reverts across the campaign. Sampled final-run counters show 2 to 7 `InsufficientOutput` reverts per 17-call run, and each route has both outcomes (see `helper-invariants.log`). The selector table shows 22 to 42 calls per selector per invariant.

**Harness defect, disclosed.** The first campaign "failed" I3: `addLiquiditySUSDS` reported `used < min`, with `sMin = 1.01·desired + 1`. Router02 only checks the min on the optimal side, so it accepts `amountXMin > amountXDesired` for the side it uses in full. That is a caller-input error that mirrors Router02, not a helper defect. The invariant was narrowed to `min ≤ desired`, and the case is now counted as an observation (`minAboveDesiredAccepted`). The first log is kept as `helper-invariants.attempt1-harness-overreach.log`. **No finding.**

**Tripwires.** These were armed after the priming calls, so each one fires inside the fuzzed campaign rather than in setUp.

| tripwire | expected | result |
|---|---|---|
| 1 wei phUSD leaked into the helper after each success | I1 fails | **FAIL as expected:** `I1 helper token balance: 1 != 0`, shrunk to 1 call (`swapPhUSDToETH`) |
| a 1-wei helper→PSM USDC allowance left after each success | I2 fails | **FAIL as expected:** `I2 allowance USDC -> PSM: 1 != 0`, shrunk to 1 call |
| minOut = exact quote, with the measured delivery reduced by 1 wei | I3 and I4 fail | **FAIL as expected:** I3 on `swapPhUSDToETH`, I4 on `swapETHToPhUSD`, each shrunk to 1 call |

In every tripwire contract the untouched invariants still passed. This shows each assertion can fail independently.

**Verdict.** No helper invariant violation was found in 240 calls per invariant on real venues. This is not a proof. CODE-006 (the shallow DOLA pool) is consistent with this result: quote-derived minimums protected every DOLA call.
