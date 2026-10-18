# Run 40, Tier 3: symbolic checks (Halmos), phoenix-phase-2-staging

- **Workspace:** `work/` at a4f9f3c. Halmos 0.3.3, default solver yices, `--solver-timeout-assertion 60000`. Targets were run one at a time (WSL2).
- **Build isolation:** the tests were compiled with `FOUNDRY_SRC/TEST/SCRIPT=test/audit-run40/symbolic` into a throwaway out dir, so the shared `work/out` used by the fork tests was not touched. The throwaway dir was deleted afterwards.
- **Test files (audit-authored, AUDIT-LOCAL):**
  - `work/test/audit-run40/symbolic/CutoverMinAmountsSymbolic.t.sol`: Halmos, target 1.
  - `work/test/audit-run40/symbolic/CutoverMinAmountsFallback.t.sol`: forge fuzz fallback, target 1. **Not a proof.**
  - `work/test/audit-run40/symbolic/UniswapHelperPsmSymbolic.t.sol`: Halmos, targets 2 and 3.
  - `work/test/audit-run40/symbolic/UniswapHelperPsmFallback.t.sol`: forge fuzz fallback, targets 2 and 3. **Not a proof.**
- **Raw logs:** `symbolic-logs/` in this directory (one per run). The Python exhaustive checkers sit beside their logs there.
- **Scope:** CODE-001/003/004/005 were **not** redone; the fork tests in `invariants.md` already cover them.

## Headline

**No finding results.** Nothing failed against the real code. Every FAIL in the logs is an intended tripwire.

The core arithmetic claims could **not** be proved with Halmos. Every property whose truth depends on the value of a division timed out. That held even with a single division by a constant (the PSM case) and at a 2^64 bound. The memory rule ("2+ symbolic divisions intractable") is therefore conservative for Halmos 0.3.3 + yices on this code: in practice, *one* division is often enough to cause a timeout. Those properties are **INCONCLUSIVE** as proofs. They are backed only by:

- 100k-run forge fuzz over the real code;
- exhaustive checks on small or scaled-down domains (a proof only over those domains);
- a hand proof, given below.

**What Halmos did prove (PASS, all with a non-vacuity tripwire that FAILed as intended):**

1. Step 0 rejects any exit or seed tolerance above 100 bps, with the exact reason `"UniPoolerCutoverCore: tolerance too wide"`. The cap is inclusive at 100. Domain: unbounded.
2. `swapPhUSDToETH` split and residue: on every successful path, the helper ends with 0 phUSD, 0 sUSDS, 0 USDS, 0 USDC, 0 WETH and 0 ETH. The recipient's ETH equals the returned `ethOut`, which is ≥ `minEthOut`. USDS is conserved (refund + PSM pull = redeemed USDS). `ethOut == 0` exactly when the PSM output floors to 0. Domain: all amounts < 2^128, `tout = 0`, venues axiomatised.
3. `_usdsToUsdc` conservation and no residue *on success*. Domain: amount < 2^128, `tout = 0`.
4. `swapPhUSDToETH` with a zero PSM output and `minEthOut > 0` always reverts. The revert *reason* was not decided by Halmos (TIMEOUT); fuzz shows it is `InsufficientOutput(0, minEth)`.
5. The `_checkMinAmountsOut` window properties hold at one concrete snapshot (supply = 2^120−1, bptIn = 1), with raw, min and tol symbolic. This is narrow.

## Target 1: `UniPoolerCutoverCore._checkMinAmountsOut` (SLITHER-010) and the step-0 tolerance cap

Code: `script/helpers/UniPoolerCutoverCore.sol` L396-408 (`share = raw*bptIn/supply`; accept `min ∈ [floor(share*(1e4−tol)/1e4), share]`). The cap is at L273-276. `_runCutover` (L242-250) always runs step 0 before step 5, so `exitToleranceBps ≤ 100` holds whenever L404 executes. The only consumers are `_runCutover` callers: the mainnet script and `DeployMocks`.

Harness: the real internal code runs through `CoreHarness is UniPoolerCutoverCore`. The Balancer vault and pool are mocks that return `(raw0, raw1)` and `totalSupply`. Token 1 is held at raw = 0 and min = 0; the loop body is identical per index.

| Property | Test | Domain | Result | Time |
|---|---|---|---|---|
| P1: accepted min ≤ true share (`min*supply ≤ raw*bptIn`) | `check_acceptedMinLeqTrueShare` | raw, supply < 2^120, bptIn ≤ supply, tol ≤ 100 | **TIMEOUT: INCONCLUSIVE** | 60 s |
| P2: accepted min ≥ floor(exact multiply-first bound) − 1 | `check_acceptedMinWithinOneWeiOfExactFloor` | same | **TIMEOUT: INCONCLUSIVE** | 60 s |
| P3: completeness, so no legitimate min in [exact bound, true share] is rejected | `check_legitMinNeverRejected` | same | **TIMEOUT: INCONCLUSIVE** | 60 s |
| P1–P3, retried | `check_b64_*` | bound 2^64 | **TIMEOUT ×4: INCONCLUSIVE** | 4×60 s |
| P1–P3, retried with solver bitwuzla | (same) | 2^120 | **ERROR**: bitwuzla is not installed and the download was refused. Not a run. | 1 s |
| P1+P2, concrete (supply, bptIn); raw, min, tol symbolic | `check_snap_S0_live` (live mainnet supply 32438774213867981521320, bptIn 20401809116957261204353) | raw < 2^120 | **TIMEOUT: INCONCLUSIVE** | 80 s |
| | `check_snap_S1_fullExit`, `_S3_smallCoprime`, `_S4_oddLarge`, `_S0_live_complete`, `_S3_smallCoprime_complete` | raw < 2^120 | **TIMEOUT ×5: INCONCLUSIVE** | 5×60 s |
| | `check_snap_S2_oneWeiExit` (supply 2^120−1, bptIn 1) | raw < 2^120 | **PASS** (that snapshot only) | 2.9 s |
| P4: step 0 rejects tol > 100 (either field), with the exact reason string | `check_step0RejectsWideTolerance` | **unbounded** | **PASS** | 0.02 s |
| P5: step 0 never rejects tol ≤ 100 for the tolerance reason | `check_step0AcceptsInCapTolerance` | unbounded | **PASS** | 0.02 s |

Even with the divisor made concrete, the snapshots stay nonlinear because `share*(1e4−tol)` multiplies two symbolic values. That is why only S2 (where share ≤ 0 or 1 effectively) closed.

**Tripwires (all intended to FAIL):**

| Tripwire | Purpose | Result |
|---|---|---|
| `check_TRIPWIRE_ceilShareExceedsTrueShare` (2^120) | P1 is non-vacuous against a ceil-share variant | **FAIL** as intended: bptIn=1, min=1, raw=0x7fff…ff000…0, supply=0xffff…fd000…01, tol=0 |
| `check_snap_TRIPWIRE_S0_ceilShare` (live snapshot) | same, at live magnitudes | **FAIL** as intended: raw=2^119, min=0x5080deb926becd8833a24c078ebedb, tol=0 |
| `check_TRIPWIRE_step0RejectsAt100` | P4 is boundary-sensitive (the cap is inclusive) | **FAIL** as intended: (tolExit=100, tolSeed=0) and (0, 100) are accepted |
| `check_TRIPWIRE_errorIsZero` (2^120, 2^64, live snapshot) | the error bound is tight, not zero | **TIMEOUT ×3**. Tightness was instead shown concretely (below). |

**Fallback evidence (not proof):**

- `CutoverMinAmountsFallback.testFuzz_window`: 100,000 runs over the 2^120 domain and the real `_checkMinAmountsOut`. Checked each run:
  - upper edge ≤ true share;
  - `floor(exact) − 1 ≤ computed lower edge ≤ floor(exact)`;
  - the real check accepts both edges;
  - the real check rejects `c−1` with "below tolerance" and `share+1` with "above share".
  - Result: **PASS** (`symbolic-logs/target1-fallback-fuzz.log`).
- Exhaustive small domain (`target1-exhaustive-small-domain.py`): supply 1..40, bptIn 0..supply, raw 0..40, tol 0..100, which is 3,561,260 cases. **0 violations.** This is a proof over that domain only, against a Python mirror of L400-405.
- **Live tightness witness** (`test_liveTightnessWitness`, PASS): at the live supply and bptIn, with raw = 29500000000000000000001 and tol = 10, the computed floor is 18534964102442762052700 and the exact multiply-first floor is …701. The real check accepts the …700 floor. The 1-wei slack is real at mainnet magnitudes; for tol = 0 the slack is always 0.

**Hand proof of the bound.** Let x = raw·bptIn/supply (real), q = ⌊x⌋, k = 1e4 − tol, c = ⌊q·k/1e4⌋, and e = ⌊x·k/1e4⌋.

- Because q ≤ x, c ≤ e.
- Because q > x − 1, q·k/1e4 > x·k/1e4 − k/1e4 ≥ x·k/1e4 − 1. Hence c ≥ e − 1.
- Any accepted min also satisfies min ≤ q ≤ x.

**Bound for target 1:** the divide-before-multiply floor (SLITHER-010) is never above the exact floor and at most **1 wei** below it. The bound is tight, and it is **not proven by Halmos**. Every accepted min is ≤ the true proportional share. Overflow of `raw*bptIn` needs raw·bptIn ≥ 2^256, which is far outside realistic balances (~2^75), and it reverts (fail-loud) in any case.

**Finding: none.** SLITHER-010 is benign. The looseness is ≤ 1 wei on a window that is ≥ 0 bps wide, and it never lets min exceed the payout bound.

## Target 2: UniswapHelper PSM conversion (`psmGemForUsds`, `_usdsToUsdc`)

Code: `src/periphery/UniswapHelper.sol` L411-415 and L472-481. Harness: `HelperHarness is UniswapHelper` exposes `_usdsToUsdc`.

The PSM is **axiomatised**, not proved: `cost(g) = g·conv + ⌊g·conv·tout/WAD⌋`, pulled via `transferFrom`, with conv = 1e12. This matches the formula documented in the repo's ISkyPSM.sol for DssLitePsm / UsdsPsmWrapper. The fork invariants exercise the real PSM.

| Property | Test | Domain | Result | Time |
|---|---|---|---|---|
| (a)–(e) together: no revert, no residue, no dangling approval, conservation, maximality, zero-gem refund | `check_usdsToUsdc_symbolicTout` | amount < 2^128, tout ∈ [0, WAD] | **TIMEOUT: INCONCLUSIVE** | 62 s |
| same, concrete tout snapshots | `_tout0`, `_tout1bp`, `_tout30bp`, `_tout1pct`, `_tout100pct` | amount < 2^128 | **TIMEOUT ×5: INCONCLUSIVE** | 5×61 s |
| (a) alone: never asks the PSM for more than it holds (no revert) | `check_split_tout0_noRevert` | amount < 2^128, tout = 0 | **TIMEOUT: INCONCLUSIVE** | 120 s |
| (d) alone: floor is maximal and `g·conv ≤ amount` | `check_split_tout0_maximal` | same | **TIMEOUT: INCONCLUSIVE** | 87 s |
| (b)+(c) on success: helper USDS = 0, allowance = 0, PSM pull + refund = amount, usdcTo gets g | `check_split_tout0_conservation` | same | **PASS** | 0.5 s |

**Tripwires:**

| Tripwire | Result |
|---|---|
| `check_TRIPWIRE_noDustEver` (claims dust is never refunded) | **FAIL** as intended: amount = 0xe1bfffffff and amount = 2^127. The refund path is live. |
| `check_TRIPWIRE_psmCeilFee` (a ceil-fee PSM must make the helper over-request) | **TIMEOUT** (inconclusive). The fuzz version FAILed as intended: Panic 0x11 on the over-pull, k=8825890849527428 (`target2-fallback-tripwire.log`). |
| `check_TRIPWIRE_formulaWithoutMinusOne` | **TIMEOUT** (inconclusive) |

**Fallback evidence (not proof):**

- `UniswapHelperPsmFallback.testFuzz_usdsToUsdc`: 100,000 runs, amount < 2^128, tout ∈ [0, WAD]. Half the runs are biased to the exact cost of k gems ±0..3 wei, where floor errors live. All of (a)–(e) held: **PASS**.
- Exhaustive scaled-down model (`target2-exhaustive-scaled.py`): WAD ∈ {100, 1000}, conv 1..12, tout over [0, WAD], budget 0..300, which is 881,328 cases. The closed form `⌊((b+1)·WAD−1)/(conv·(WAD+tout))⌋` equals the brute-force maximum g with cost(g) ≤ b in every case. **0 mismatches.** This is a proof over that model only.

**Hand proof.** g·conv is an integer, so cost(g) = ⌊g·conv·(WAD+tout)/WAD⌋. Then cost(g) ≤ b ⇔ g·conv·(WAD+tout) < (b+1)·WAD ⇔ g·conv·(WAD+tout) ≤ (b+1)·WAD − 1. The code's g is the largest such integer. The NatSpec at L408-410 is correct.

**Bound for target 2:**

- The helper never requests more USDS than it holds.
- Dust is strictly less than cost(1 gem) ≈ conv·(1 + tout/WAD) + 1, which is about 1e12 wei (≈ 1e-6 USDS) at tout = 0.
- All dust goes to `dustTo`, and the helper keeps 0 (the on-success part is Halmos-PASS; the rest is fuzz plus hand proof).
- When g = 0 there is no PSM call and the whole amount is refunded.

**Finding: none.**

**Observations (informational, not filed):**

- `tout == type(uint256).max` is DssLitePsm's HALTED sentinel. When it is set, `WAD + tout` overflows, and `psmGemForUsds` (and so every USDC/DOLA/USDe/ETH exit and quote) reverts with Panic 0x11 rather than a named error. The behaviour is fail-loud and matches the PSM, since `buyGem` would be disabled anyway. The same applies to `tin` HALTED in `_quoteToSusds`, which is quote-only.
- `(usdsBudget+1)*WAD` overflows for budgets ≥ ~1.16e59, which is unreachable.

## Target 3: `swapPhUSDToETH` ethOut and refund split

Code: L247-267. Venues are axiomatised as mocks: V2, sUSDS redeem, V3 (exact-input full fill) and WETH9. tout = 0, which is the live value.

| Property | Test | Domain | Result | Time |
|---|---|---|---|---|
| P7: on success the helper holds 0 of every token and 0 ETH; recipient ETH == returned ethOut ≥ minEthOut; USDS refund + PSM pull == redeemed USDS; ethOut == 0 iff the PSM gem output is 0, else == the V3 output | `check_swapPhUSDToETH_split` | phusdIn, sOut, usdsOut, ethOut < 2^128; minEth unbounded | **PASS** | 0.9 s |
| P8: zero gem output and minEthOut > 0 ⇒ revert | `check_swapPhUSDToETH_zeroGemReverts` (first version, any reason) | usdsOut < 1e12 | **PASS** (`target3-helper-eth.log`) | 0.2 s |
| P8 with the reason pinned to `InsufficientOutput` | same test, revised | same | **TIMEOUT: INCONCLUSIVE**. Fuzz `testFuzz_zeroGemRevertReason` (100k runs) shows the exact `InsufficientOutput(0, minEth)`: PASS (not a proof). | 61 s |

**Tripwires:**

| Tripwire | Result |
|---|---|
| `check_TRIPWIRE_v3PartialFillResidue` (V3 leaves 1 wei USDC unpulled) | **FAIL** as intended: the residue assertion trips (4 counterexamples, e.g. phusdIn=2^127, usdsOut=0x4cf41b1660f68e0020a42b9328975000) |
| `check_TRIPWIRE_ethSuccessReachable` (claims no success with a non-zero gem output) | **FAIL** as intended. Success paths are reachable, so P7's PASS is not vacuous. |

**Bound for target 3:** the ETH path leaves no residue in the helper and splits exactly. The split is ETH = V3 output, plus a USDS refund of redeemed − PSM cost. This rests on Halmos PASS for amounts < 2^128, tout = 0, and the axiomatised venues. The PASS does not cover the PSM-cost maximality (that is target 2's INCONCLUSIVE part), real V3 partial-fill behaviour (axiom: full fill or revert), or tout > 0.

When the gem output is zero and `minEthOut = 0`, the call succeeds with ethOut = 0 and the user receives only the USDS refund. This is documented behaviour ("USDS dust … refunded to recipient"). It is self-protected by any non-zero `minEthOut`, so it is a user-input matter and not a finding.

**Finding: none.**

## Run time (Halmos wall clock, sequential)

| Target | Time | Note |
|---|---|---|
| 1 | ≈ 15.8 min (254 s + 243 s + 450 s, plus a 1 s bitwuzla ERROR) | Slightly **over** the 15-min cap. The snapshot sweep was the overrun; nothing further was attempted after it. |
| 2 | ≈ 11.7 min (495 s + 208 s) | |
| 3 | ≈ 1.2 min (6 s + 66 s) | |
| Forge fuzz fallbacks | ≈ 30 s total | |

## Honest-reporting ledger

- **proofs[] (citable as evidence of safety):** P4 and P5 (unbounded); P7, P8-any-reason, and `_usdsToUsdc` conservation-on-success (< 2^128, tout = 0, axiomatised venues); `check_snap_S2_oneWeiExit` (that snapshot only).
- **unverified[] (NOT citable):** P1–P3 at every bound and snapshot; `_usdsToUsdc` no-revert and maximality at every tout; P8 revert reason; the three TIMEOUT tripwires. These rest on fuzz plus small-domain exhaustive checks plus the hand proofs above. Reviewers should treat them as *manually reasoned, not machine-proved*.
