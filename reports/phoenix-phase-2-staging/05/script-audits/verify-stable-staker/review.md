# Script Review — `verify-stable-staker` (`npm run test:stable-staker`)

**Project:** phoenix-phase-2-staging (run 05)
**Entry point:** `verify-stable-staker` (`./verify-stable-staker.sh`, npm key `test:stable-staker`)
**Scope:** the StableStaker introduction (Story 051) — the end-to-end config/smoke check
**Mode:** local Anvil (chain-id 31337), mock contracts, no mainnet fork applicable
**Sibling review:** [`../dev/review.md`](../dev/review.md) — the `dev` flow that deploys and wires the same Phase 3.7 StableStaker this script exercises.

## Scope and method

`verify-stable-staker.sh` is the Story-051 end-to-end StableStaker verification. It is **not a unit test**: a clean, no-revert run *is* the verification. The script spins up its own ephemeral Anvil, runs `deploy:local` (the same `DeployMocks` Phase 3.7 reviewed in the sibling `dev` review), and then:

- **STEP 1** (`StakeStableStaker.s.sol`) — stake 1,000 DOLA into the DOLA pool as the deployer.
- **STEP 2** — `cast rpc evm_increaseTime 86400` + `evm_mine` to advance the **live** chain clock one day (a `vm.warp` inside a `--broadcast` script does not move the live clock; reward accrues off `block.timestamp`).
- **STEP 3** (`ClaimWithdrawStableStaker.s.sol`) — claim phUSD, withdraw full principal, and assert the three Story-051 invariants.

All assertions are Solidity `require()` statements; a revert produces a non-zero exit and `set -e` aborts the shell. There are no shell-level numeric assertions.

This review is structured around the three audit-script questions, and shares the Phase 3.7 wiring with the `dev` review (cross-referenced above).

---

## 1. Does it do what it intends?

**Yes — the full end-to-end flow runs GREEN with all assertions passing.** The realized values land squarely inside the asserted bands.

Pre-conditions (with `.envrc` sourced):

| Pre-condition | Result |
|---|---|
| `ANVIL_PRIVATE_KEY` present in env | yes (via `.envrc`) |
| DOLA pool `phusdPerSecond == 10 ether / 86400` | `115740740740740 == floor(10e18/86400)` |
| deployer DOLA balance ≥ 1000e18 | `995000e18` |

Realized end-state:

| Invariant | Asserted | Realized |
|---|---|---|
| STEP 1: `userInfo.amount == 1000e18` | exact | pass |
| STEP 1: `totalStaked += 1000e18` | exact | pass |
| STEP 1: DOLA debit == 1000e18 | exact | pass |
| STEP 3: `pending > 0` (did time advance?) | > 0 | pass |
| STEP 3: reward credited ∈ [9.9e18, 10.1e18] | ±1% band | **9999999999999936000** (64000 wei under 10e18) |
| STEP 3: `userInfo.amount == 0` | exact | pass (principal fully withdrawn) |
| STEP 3: `returned <= STAKE_AMOUNT` | strategy never over-pays | pass |
| STEP 3: principal dust ≤ 10 wei | ≤ 10 | **1 wei** |
| STEP 3: `totalStakedFinal == baseline` | exact | **0** (baseline restored) |

The realized reward (`9999999999999936000`) is 64000 wei short of the 10e18 ideal — exactly the per-second flooring loss (`phusdPerSecond = floor(10e18/86400)` loses 64000 wei/day). It sits trivially inside the lower band. Principal returned with 1 wei of ERC4626 share-rounding dust (kept protocol-side by design), and the pool's `totalStaked` returned to its pre-stake baseline. The `Claimed(DOLA, deployer, 9999999999999936000)` event corroborates the reward.

The script does what it intends: it confirms the Phase 3.7 deploy-set DOLA rate produces ~10 phUSD/day, that principal round-trips cleanly through the ERC4626 strategy, and that pool accounting returns to baseline.

---

## 2. Does it introduce unintended side effects?

**No side effects beyond its stated purpose.** Every state write was enumerated and is intended: `userInfo`/`poolInfo` updates on the DOLA pool, the MockDola transfers in (stake) and out (withdraw), the MockPhUSD mint on claim, and the ERC4626 deposit/withdraw round-trip through `YieldStrategyDola`/`MockAutoDOLA`. Both external calls (`MockPhUSD.mint`, strategy `deposit`/`withdraw`) succeeded with no revert — StableStaker is an authorized minter and the two-sided client auth is present, and the strategy was not underwater. The script tears down its own Anvil on exit via a cleanup trap, leaving no residual node.

**The concerns here are harness defects, not on-chain side effects** — they affect the *reliability* and *strength* of the verification itself, not the contract state it produces. They are discussed next.

---

## 3. Have other problems surfaced (cluster / knock-on)?

Two harness-quality findings surfaced. No High or Medium emerged.

### L-02 — `ANVIL_PRIVATE_KEY` is read but never exported: the smoke check fails on a fresh clone / CI

[`verify-stable-staker.sh#L20-L57`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/verify-stable-staker.sh#L20-L57) — shell STEP 1 / `vm.envUint`. (`pps5l2`)

`verify-stable-staker.sh` hardcodes and exports `PRIVATE_KEY` (anvil acct 0), but the interaction scripts `StakeStableStaker.s.sol` and `ClaimWithdrawStableStaker.s.sol` read `vm.envUint("ANVIL_PRIVATE_KEY")` — a **different** variable the shell never exports. The flow only works because the repo-root `.envrc` (direnv) sets `ANVIL_PRIVATE_KEY` in the ambient shell.

This was confirmed empirically. With `.envrc` sourced the full flow passes green; with `ANVIL_PRIVATE_KEY` unset (`env -u ANVIL_PRIVATE_KEY`, keeping `PRIVATE_KEY` set as the shell would) STEP 1 reverts immediately:

```
vm.envUint: environment variable "ANVIL_PRIVATE_KEY" not found
```

So the advertised one-command verification is **not self-contained**: any fresh clone or CI runner that does not load the repo-root `.envrc` gets an immediate revert in STEP 1 before any staking, and the `PRIVATE_KEY` the script does export is silently never consumed. This is classified **Low** — a real, empirically-reproduced tooling/portability bug, but with zero on-chain or asset impact; it affects only the availability of a developer verification convenience, not the protocol.

**Recommendation:** align the variable names — either `export ANVIL_PRIVATE_KEY="$PRIVATE_KEY"` in `verify-stable-staker.sh`, or have the interaction scripts read `PRIVATE_KEY`. Either removes the hidden `.envrc` dependency and makes the smoke check runnable from a clean checkout / CI.

### Q-02 — Reward band (±1%) is too loose to catch ~1% rate drift

[`script/interactions/ClaimWithdrawStableStaker.s.sol#L80-L84`](https://github.com/Behodler/phoenix-phase-2-staging/blob/master/script/interactions/ClaimWithdrawStableStaker.s.sol#L80-L84) — `run`. (`pps5q2`)

STEP 3 asserts `rewardCredited ∈ [9.9e18, 10.1e18]` (`EXPECTED_DAILY_PHUSD` ±1%). The realized reward is only 64000 wei short of 10e18 — the actual flooring dust is ~9 orders of magnitude smaller than the 1e17 (1%) band. The band is therefore a smoke-only tolerance: it would still pass if the deploy-set rate were off by up to ~1% (e.g. a config typo setting 9.95e18/day, or an off-by-one in the per-second conversion). For a script whose stated purpose is to verify the 10-vs-5 phUSD/day config split, a ±1% band on the rate it is verifying is weaker than the data supports.

This is the weakest-impact finding (**QA**), and it is **partially mitigated by the script itself**: STEP 1 already exact-asserts `phusdPerSecond == 10 ether / 86400`, which is the real config guard against rate drift. The loose reward band is therefore redundant rather than the sole line of defense — it adds little beyond "time advanced". No funds impact.

**Recommendation:** tighten the reward band toward the actual dust — e.g. assert `rewardCredited` within a few thousand wei of `86400 * phusdPerSecond` using the on-chain `phusdPerSecond`, rather than a hardcoded `10e18 ± 1%`.

### Known issues checked and NOT re-reported

- **Phlimbo / StableYieldAccumulator circular-reference ordering hazard (known issue #7).** StableStaker is **not** part of the Phlimbo/SYA cycle — it only consumes phUSD and the DOLA ERC4626 strategy — so the circular-ref hazard does not reach the path this script exercises. Not re-reported (pre-existing known issue, StableStaker confirmed outside the loop).
- **StableStaker dual-unpause (known issue #5).** A documented design property; not re-reported as a new finding. This script never pauses, so the property is not exercised here.

---

## Verdict

The verification does what it intends: the deploy → stake 1000 DOLA → warp 1 day → claim/withdraw → assert round-trip runs GREEN, with the realized reward (`9999999999999936000`), 1 wei principal dust, and restored baseline all inside the asserted bands — independently confirming that the sibling `dev`/Phase-3.7 wiring is functional, not merely present. It introduces no on-chain side effects beyond its purpose. The two findings are both harness defects: the `ANVIL_PRIVATE_KEY` export mismatch that breaks fresh-clone/CI runs (L-02, Low) and the overly loose reward band, mitigated by STEP 1's exact rate assert (Q-02, QA). **No High or Medium severity issue emerged.**
