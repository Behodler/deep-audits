# Tier-3 Invariant Verification — PromotionUniV2_Eth.sol (story-044)

- **Project:** yield-claim-nft (run-17)
- **Target:** `src/dispatchers/PromotionUniV2_Eth.sol` (story-044)
- **Baseline commit:** `8dd8963` (workspace source tree synced to it; PoC/test home = `workspace/yield-claim-nft/`)
- **Date:** 2026-07-18
- **Harness:** `workspace/yield-claim-nft/test/Tier3PromotionInvariants.t.sol`
- **Runner:** Foundry invariant runner on a **real mainnet fork** (Sky PSM + sUSDS ERC4626 + Balancer V3 vault + UniV2 router all LIVE). Fork pinned at `FORK_BLOCK = 25_550_000`, RPC = `RPC_MAINNET` (from repo-root `.envrc`, mapped to `MAINNET_RPC_URL`).

## Objective

Tier-2 (code / econ / faithfulness) found **no High/Medium** and concluded "value is conserved, no unauthorized egress." Tier-3's job was to **try to falsify** that conclusion under stateful fuzzing against real protocol state — not to re-bless it. Four invariants were targeted (INVARIANT-1..4 from the task).

## Anti-vacuous safeguards (heeding the vacuous-harness lesson)

This is **not** a mock-token `0==0` harness. Every leg calls live mainnet protocols; state is really seeded and `pool()` really executes and mutates protocol-owned LP. Two independent guarantees that a no-op run cannot pass silently:

1. **Guided deterministic test** (`test_guided_sequence_holdsAllInvariants`) lands **6 real pools** interleaved with real external ETH donations and asserts all four invariants after every step. It fails hard (`assertGe(pools, 6)`) if the fork ever stops producing real pools — the harness cannot pass without doing real work.
2. **Fuzz campaign final-run views** print `pool successes` per invariant campaign (observed 11 / 2 / 8 / 3), confirming the randomized sequences also land real pools (0 reverts across 160 calls each).

The pre-fork liveness gate passed: the repo's own `test_pool_endToEnd_...` executes the full two-leg zap against the fork in ~35 s, and `cast block 25550000` returns archive state.

## Invariants tested

| ID | Invariant | Encoding | Runner | Result |
|----|-----------|----------|--------|--------|
| INV-1a | **Conservation / no USDC egress** — `batchMinter` receives *exactly* the summed donation split, nothing more | `invariant_donationExact` (exact equality vs ghost) | real fork | **HELD** |
| INV-1b | **No latent egress vector** — every `forceApprove` in `pool()`/legs reset to 0 (USDC→router, phUSD→router, promo→router, USDC→PSM) | `invariant_noLingeringApprovals` | real fork | **HELD** |
| INV-1c | **Retained value lands as protocol-owned LP** — dispatcher LP strictly increases on each successful pool | in-handler `require(lp > ghost_lastLP)` on every real pool | real fork | **HELD** |
| INV-1d/4 | **No third-party egress** — designated never-touched EOAs (W1/W2) hold 0 USDC/phUSD/promo/LP | `invariant_noThirdPartyEgress` | real fork | **HELD** |
| INV-2 | **Split integrity** — `halfA + halfB == amountIn`, gap ≤ 1 wei, odd wei → Leg B | `SplitIntegrityTest` (fork-free fuzz + boundaries incl. `type(uint256).max`) | fork-free | **HELD** |
| INV-3 | **No stranded ETH** — after any successful `pool()`, `address(dispatcher).balance == 0` (leg-produced AND externally-donated ETH fully swept into the promotion buy → LP) | in-handler `require(balance == 0)` + guided `assertEq` | real fork | **HELD** |
| INV-4 | **Whole-balance ETH sweep bound** — dispatcher ETH never exceeds cumulative externally-donated ETH (+ 1 wei fork baseline); donated ETH can only route into protocol LP, never to a third party | `invariant_ethBoundedByDonations` + INV-3 + INV-1d | real fork | **HELD** |

## Call counts / run depth

- **Fuzz campaign:** `FOUNDRY_INVARIANT_RUNS=8`, `FOUNDRY_INVARIANT_DEPTH=20`, `fail_on_revert=false`. Each of the 4 fork invariants evaluated across **8 runs × 20 depth = 160 handler calls**, **0 reverts** — 640 fuzzed handler operations total (`dispatchPrime` / `doPool` / `donateEth`, ~50 each per campaign). Confirmed real pools per final-run view: 11, 2, 8, 3.
- **Guided sequence:** 6 real pools + 3 external ETH donations + 6 dispatches; 4 invariants asserted inline ~15 times.
- **INV-2 (fork-free):** 20,000 fuzz runs + 5 boundary cases (0,1,2,3,`type(uint256).max`).

## Falsification result

**No invariant falsified. No counterexample found.** The Tier-2 "value conserved / no unauthorized egress" conclusion is **corroborated** under real-fork stateful fuzzing:
- Donation egress is exact (INV-1a); no dangling allowances (INV-1b); retained USDC lands as protocol-owned LP (INV-1c); no third-party receives value (INV-1d).
- The whole-balance ETH sweep (the genuinely new Leg-B surface, econ-scan ECON-002 / faithfulness F-01-044) behaved **protocol-positively**: externally-donated ETH was swept into promotion → LP on the next pool, leaving zero stranded ETH (INV-3) and never exceeding what was donated (INV-4). This directly exercises the L-1/ECON-002 "stray ETH folds into next pooler's buy" behavior and confirms it routes to LP, not to a third party — consistent with the Low/QA classification, no escalation.
- 50/50 split is exactly conserving (INV-2).

## Honesty / coverage caveats

- **This is bug-finding, not proof.** A passing campaign means **"no counterexample found in 8×20 sequences (160 calls/invariant) + a 6-pool guided sequence + 20,000 split-math runs"** — absence of evidence, not proof of safety. Only Halmos `[PASS]` would be a proof; these are fuzz/stateful results.
- **Fuzzer run-reset nuance:** Foundry reverts to the setUp snapshot between invariant runs, so `afterInvariant` sees only the final run's ghost counters (why the anti-vacuous guarantee was moved to the deterministic guided test rather than an `afterInvariant` `require`).
- **Fork baseline artifact:** the freshly-created dispatcher carries 1 wei on the fork (CREATE-address artifact); INV-4 is bounded relative to it. The 1 wei is itself swept to 0 by the first pool, so INV-3 is unaffected.
- **Medusa / Echidna: NOT RUN for this target.** The harness is built on Foundry fork cheatcodes (`vm.createSelectFork`, `deal` for USDC storage seeding, live-protocol calls in `setUp`); porting to Medusa/Echidna fork mode requires a separate rewrite of the fork/seed model. Because the Foundry invariant runner already provides real-fork stateful coverage with an anti-vacuous guarantee (acceptable outcome (a) per the task), a parallel Medusa fork harness was not built in this pass. This is a coverage note, not a clean bill from those tools.
- **Scope of the phUSD/promo and WETH/promo pools is test-seeded** (100k/100k and 100 ETH/300k); USDC/WETH and the Balancer phUSD/sUSDS pool and Sky PSM are real live mainnet state. Slippage/price behavior on the promo legs reflects the seeded depth, not a specific partner's real pool.

## Reproduce

```bash
cd workspace/yield-claim-nft
set -a; source ../../.envrc; set +a
export MAINNET_RPC_URL="$RPC_MAINNET"
# INV-2 (fork-free):
forge test --match-contract SplitIntegrityTest --fuzz-runs 20000 -vv
# Real-fork guided + fuzz invariants:
FOUNDRY_INVARIANT_RUNS=8 FOUNDRY_INVARIANT_DEPTH=20 FOUNDRY_INVARIANT_FAIL_ON_REVERT=false \
  forge test --match-contract Tier3PromotionInvariants -vv
```

## Files

- Harness: `workspace/yield-claim-nft/test/Tier3PromotionInvariants.t.sol`
- This summary: `reports/yield-claim-nft/17/tier3/invariants.md`
