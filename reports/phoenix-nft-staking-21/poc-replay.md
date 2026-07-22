# phoenix-nft-staking run-21 — Parked PoC suite repair + replay

**Workspace:** `/home/justin/code/audits/workspace/phoenix-nft-staking` @ `c881a42` (merge; tip of story-022 Stage 8 / story-023)
**Scope:** repair bit-rot in audit-authored PoCs, then replay. No `lib/**` touched. No upstream tracked test modified.
**Date:** 2026-07-21

---

## 1. Upstream baseline

Established with **all untracked audit-authored files parked out of `test/`** (only the 28 tracked upstream suites present):

```
Ran 28 test suites: 412 tests passed, 0 failed, 0 skipped (412 total tests)
```

**Actual: 412 passed / 0 failed. The claim was 396.**

This is *not* a defect. The delta is exactly **+16**, which is exactly the test count of
`test/MigratorRewardForwarding.t.sol` (16 tests), introduced by
`f3b92c0 [story-023] Version-agnostic migrator settlement-capture forwarding (pns20h1)`.
The 396 figure predates story-023. Suite is green; baseline is healthy.

Note `test/PoC_DepletionRateDrift.t.sol` is now **tracked upstream** (adopted from a prior audit run) and is
counted inside the 412.

---

## 2. Two independent bit-rot axes found

The task briefed one. There were two.

**Axis A — the multi-token split (`fba4991`, story-022 Stage 7).**
`src/BatchNFTMinter.sol` reverted to the frozen mainnet single-token version; the multi-token code these PoCs
were written against moved to the new `src/BatchNFTMinterMultiToken.sol`
(`batchMint(count, recipient, paymentAmount, address[] rewardTokens, uint256[] minRewards)`,
`BatchMint__RewardTokenIsPaymentToken(address)`, `BatchMint__RewardBelowMinimum(address,uint256,uint256)`,
`BatchMint__ArrayLengthMismatch`, `ReentrancyGuard`).

**Axis B — migrator constructor gained a 6th parameter (story-023).**
Both `NFTStakerMigrator` and `InPlaceNFTStakerMigrator` now take `IERC20 _rewardToken` immediately **before**
`address initialOwner`, with a constructor cross-check against the staker's own `rewardToken()` getter. Five
migration-lineage PoCs (not in the briefed candidate list) were broken by this and are repaired below.

---

## 3. What was changed, and why

All changes are **mechanical rename / signature adaptation only**. No assertion was weakened, no bound relaxed,
no attack parameter altered, no `expectRevert` selector loosened beyond the literal rename.

### Axis A — repointed to `BatchNFTMinterMultiToken` (11 files)

Applied as a word-boundary-anchored replacement `\bBatchNFTMinter\b` → `BatchNFTMinterMultiToken`, which by
construction leaves `RatchetBatchNFTMinter` and `MigrateBatchNFTMinter.s.sol` (comment references to live
mainnet deployments / deploy scripts) intact — verified afterwards with a residual grep. This rewrites, per
file: the `import`, the declared type, the `new` expression, error-selector qualifiers, and the
`src/BatchNFTMinter.sol:NNN` doc-comment source references.

| File | Lines changed | Nature |
|---|---|---|
| `test/PoC_NudgeLineage_H01.t.sol` | 7 | import + type + ctor + doc refs |
| `test/PoC_NudgeLineage_MevFrontrunNudge.t.sol` | 7 | + `BatchMint__RewardBelowMinimum` selector qualifier |
| `test/PoC_NudgeLineage_M01PriceInflation.t.sol` | 7 | import + type + ctor + doc refs |
| `test/PoC_NudgeLineage_NudgeDrain.t.sol` | 5 | import + type + ctor + doc refs |
| `test/PoC_BatchMinterCallbackAndAllowance.t.sol` | 7 | + reentrancy-probe type |
| `test/PoC_BatchMinterConfigDriftAndStaticcall.t.sol` | 3 | import + type + ctor |
| `test/PoC_DuplicateRewardWithDonations.t.sol` | 5 | import + type + ctor (x2 contracts) |
| `test/PoC_EconRatchetSweepAndDuplicates.t.sol` | 6 | + `BatchMint__RewardTokenIsPaymentToken` selector qualifier |
| `test/InvariantBatchNudge.t.sol` | 5 | import + type + handler cast + ctor |
| `test/MedusaNudge.sol` | 3 | import + type + ctor (Medusa harness) |
| `test/SymbolicNudgePayout.t.sol` | 2 | doc comments only (harness transcribes logic, does not import) |

### Axis B — inserted the `IERC20 _rewardToken` constructor argument (5 files)

In every case the staker's reward token in the fixture is the local `phUSD` mock, so the inserted argument is
`IERC20(address(phUSD))` — the only value that satisfies the new constructor's cross-check against
`staker.rewardToken()`.

| File | Sites |
|---|---|
| `test/PoC_EconMigrateReady.t.sol` | 8 × `InPlaceNFTStakerMigrator`, 1 × `NFTStakerMigrator` |
| `test/PoC_Drift01_DepositForPaysMigrator.t.sol` | 1 × `InPlaceNFTStakerMigrator`, 1 × `NFTStakerMigrator` |
| `test/PoC_Drift01_MigratorSidePatch.t.sol` | 1 × `NFTStakerMigrator` |
| `test/PoC_Local001_StakeGriefBlocksReset.t.sol` | 1 × `InPlaceNFTStakerMigrator` |
| `test/PoC_Local002_005_MigrationFootguns.t.sol` | 1 × `InPlaceNFTStakerMigrator` |

### Untouched, as instructed
- `test/*.t.sol.bak` (4 files) — left alone.
- `test/patched/` — run-20's own proposed migrator patch, left as reference (see §5).
- All tracked upstream suites and `test/mocks/**`.

**Result: `forge build` clean.** Full suite (upstream + audit) = **482 tests, 475 passed, 7 failed**, where
every one of the 7 "failures" is a deliberate audit assertion, classified below.

---

## 4. Replay verdicts

PoC convention here: these are *exploit-demonstrating* tests — **PASS = defect reproduced**. The invariant
harness is the inverse — **FAIL = invariant broken = defect reproduced**. Both are read as STILL-LIVE.

### 4.1 Ledger H-01 (`858e9e80`) — value-blind nudge gate — **STILL-LIVE** against `BatchNFTMinterMultiToken.sol`

`test/PoC_NudgeLineage_H01.t.sol` — 4/4 PASS.

| Test | Verdict | Numbers |
|---|---|---|
| `test_PoC_H01_AttackerDrainsFullNudgePool` | **STILL-LIVE** | attacker mints `nudgeSize=5`, spends **5,256.33 phUSD**, takes **50,000 USDC** (entire pot). Honest 50-NFT batch spends **110,294.59 phUSD** and receives **0**. Asserts `stolen == NUDGE_REFILL_AMOUNT` and `pot == 0`. |
| `test_PoC_H01_PotIsNotBoundedByMintCost` | **STILL-LIVE** | cost to qualify 5,256.33 phUSD vs pot captured 50,000 — payout is not bounded by outlay. |
| `test_PoC_H01_RecipientAsymmetry` | **STILL-LIVE** | payer pays 5,256.33 phUSD; `recipient != msg.sender` receives all 5 NFTs **and** the full 50,000 USDC nudge; payer receives 0. |
| `test_PoC_H01_ThresholdGamingAcrossRefills` | **STILL-LIVE** | 3 refill cycles, attacker spends 5,256 / 5,947 / 6,728 phUSD, takes 50,000 each — **150,000 USDC total**. |

The root cause is intact in the new file: the purely numeric `count >= nudgeSize` gate, the full pre-loop
`balanceOf` snapshot, and winner-take-all `_payRewards` → `recipient`. The multi-token split **moved** this
code; it did not fix it. story-022's `minRewards` addition does not close it (see M-01 below).

### 4.2 Ledger M-01 (`521c20ad`) — MEV front-run of the winner-take-all pot — **STILL-LIVE** against `BatchNFTMinterMultiToken.sol`

`test/PoC_NudgeLineage_MevFrontrunNudge.t.sol` — 2/2 PASS.

| Test | Verdict | Numbers |
|---|---|---|
| `test_M01_searcherFrontrunsHonestNudgeClaimant` | **STILL-LIVE** | pot 50,000e18. Searcher outlay **5,256.33e18** → gains **50,000e18** (whole pot, `NudgePaid` emitted to searcher). Honest user then genuinely qualifies (mints 5 NFTs, pays **5,947.05e18**) and receives **0**; asserts no `NudgePaid` log to the honest user. |
| `test_M01_minRewardsFloorDoesNotStopTheFrontRun` | **STILL-LIVE** | With a floor set, the honest tx reverts with `BatchMint__RewardBelowMinimum(nudgeToken, 50000e18, 0)` — the floor protects the loser's *capital* but does not change who wins the pot. Front-run outcome unchanged. |

**Both expired closures are confirmed still live.** Their code now lives in `src/BatchNFTMinterMultiToken.sol`
under a `contract:function` pair that mints a **new fingerprint dedup cannot match** against the `fixed`
ledger entries. These will not self-reconcile — they need an explicit reopen/re-file with disclosure of the
prior `fixed` status (per the "disclose when re-filing" rule), not a silent new finding.

### 4.3 Other nudge-lineage PoCs — all STILL-LIVE

| File | Test | Verdict | Evidence |
|---|---|---|---|
| `PoC_NudgeLineage_NudgeDrain.t.sol` | `test_NudgeDrain_modestPrice_stillNetProfitable` | STILL-LIVE | PASS |
| | `test_PayoutIsIndependentOfWhatTheCallerPaid` | STILL-LIVE | PASS |
| | `test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED` | (negative control) | PASS — variant A remains correctly closed |
| `PoC_NudgeLineage_M01PriceInflation.t.sol` | `test_M01_NudgeInflatesPriceShortensRunway` | STILL-LIVE | PASS |
| | `test_M01_NudgeMintedNFTsAreImmediatelyRealizable` | STILL-LIVE | PASS |
| `PoC_BatchMinterCallbackAndAllowance.t.sol` | `test_ReceiveHookRunsMidLoop_WithLiveMaxAllowance` | STILL-LIVE | PASS — hook still reenters mid-loop despite the new `ReentrancyGuard` (guard covers `batchMint` re-entry, not the mid-loop callback surface) |
| | `test_MaxAllowance_UnderfundedBatchEatsContractsOwnPaymentBalance` | STILL-LIVE | PASS |
| `PoC_BatchMinterConfigDriftAndStaticcall.t.sol` | `test_ConfigsTupleAppend_IsTolerated` | STILL-LIVE | PASS |
| | `test_ConfigsTupleReorder_FailsClosed` | (negative control) | PASS |
| | `test_SnapshotBalanceOfIsStaticcall` | STILL-LIVE | PASS |
| `PoC_DuplicateRewardWithDonations.t.sol` | `test_DuplicateDoesNotFailClosedWhenDispatcherDonates` | STILL-LIVE | PASS |
| | `test_ManyDuplicatesDrainOwnDonationsEntirely` | STILL-LIVE | PASS |
| `PoC_EconRatchetSweepAndDuplicates.t.sol` (`PoC_RatchetPrimeTokenSweep`) | `test_CountOneCallerSweepsEntireRatchetPot` | STILL-LIVE | PASS |
| | `test_RatchetBatchMintIsFree` | STILL-LIVE | PASS |
| | `test_QualifyingBatcherCannotListThePotAsset` | (negative control) | PASS — §4.1 exclusion reverts with `BatchMint__RewardTokenIsPaymentToken(usdc)`; error now correctly resolved on the MultiToken type |
| `PoC_EconRatchetSweepAndDuplicates.t.sol` (`PoC_DuplicateMagnitudeMainnetShape`) | `test_AtObservedShape_DuplicateStillFailsClosed` | (negative control) | PASS |
| | `test_BackToBackSteadyState_DonateForwardNullified` | STILL-LIVE | PASS |
| | `test_LargeBatchRecapturesItsOwnDonation` | STILL-LIVE | PASS |
| `PoC_DuplicateRewardWithDonations.t.sol` (payment-token sweep) | `test_AnyoneSweepsPaymentTokenBalanceWithoutQualifying` | STILL-LIVE | PASS |

### 4.4 `InvariantBatchNudge.t.sol` — 4 invariants BROKEN against real `BatchNFTMinterMultiToken`

Stateful fuzz, non-vacuous (handler call counts in the thousands). Each failure is a **STILL-LIVE** defect.

| Invariant | Verdict | Shrunk counterexample |
|---|---|---|
| `invariant_nudgeSolvency` — a single `batchMint` must never pay more of a reward token than the pre-loop snapshot held | **STILL-LIVE** | `paid=36,000,000` vs `prePot=18,000,000` (**2×** over-pay), `count=6`, `listLen=3`, token `0xc718…0bB1` — duplicate-token listing double-spends the snapshot |
| `invariant_nudgeNoSelfFund` — a caller cannot be paid out of their own batch's donations (spec §4.2) | **STILL-LIVE** | `excess=18,000,000` |
| `invariant_sweep` — the sweep must never leave a caller net-positive | **STILL-LIVE** | caller **net gain = 18,969.39e18** — this is the H-01 value-blind class expressed as a stateful invariant |
| `invariant_fotFloor` — is `minRewards[i]` a floor on what `recipient` actually RECEIVES? | **STILL-LIVE (see caveat)** | `delivered=95.000…e18` vs `declared floor=100.000…e18` — a 5 % fee-on-transfer token delivers below the caller's declared floor |

**Caveat on `invariant_fotFloor` — triage, not a suppression.** Fee-on-transfer tokens are a C4 known-invalid
class per `CLAUDE.md`, and this counterexample is driven purely by the `MockFeeOnTransferERC20` handler token.
The *finding* is arguably still real in a narrow framing (`minRewards` is documented as a floor on receipt but
is enforced pre-transfer, so the guarantee is nominal rather than actual), but it should be raised on that
framing, not as an FoT-support finding. **Flagging for human triage — deliberately not suppressed here**
(recall beats tidiness).

### 4.5 Symbolic harness — `test/SymbolicNudgePayout.t.sol` (Halmos)

Not runnable under `forge` (uses `check_` entry points); executed via `halmos`.

| Contract | Result |
|---|---|
| `SymbolicNudgePayout` | 3 passed, **2 failed** — `check_noOverPay_twoTokens_withDonation` and `check_noOverPay_threeTokens_withDonation` produce counterexamples where `t0 == t1` (duplicate listing) over-pays by exactly the donation |
| `SymbolicNudgeBound` | 2 passed, 0 failed — `check_overPayBoundedByOwnDonation` and `check_distinctTokens_donationStaysBehind` **PROVEN** |

**Weight caveat:** `NudgeHarness` is a hand **transcription** of the snapshot→payout pass, not an import of
`src/BatchNFTMinterMultiToken.sol`. Under this repo's rigor rule a mock-inlined harness proves a property of
the mock, not of the code under audit — so these counterexamples are **corroborating, not authoritative**.
The authoritative proof of the same duplicate-token defect is the real-source `PoC_DuplicateRewardWithDonations`
(§4.3) and `invariant_nudgeSolvency` (§4.4), both of which reproduce it against the actual contract.
One `check_noOverPay_threeTokens_withDonation` path was additionally truncated by Halmos's loop-unrolling
bound of 2 — that path is **unexplored, not proven**.

### 4.6 Migration-lineage PoCs — regression-clean

`PoC_EconMigrateReady.t.sol` 10/10 PASS, `PoC_Local001_StakeGriefBlocksReset.t.sol` 2/2 PASS,
`PoC_Local002_005_MigrationFootguns.t.sol` 3/3 PASS, `PoC_DepletionRateDrift.t.sol` (now upstream) 3/3 PASS.
No change in verdict from the constructor-arg repair.

---

## 5. Item 6 — run-20 H-01 `NFTStakerDepletion.depositFor` (migrator pays itself): **INVERTED — LIKELY-FIXED**

This is the one place where a PoC *failing* is the good news. Three tests now fail **because the bug is gone**,
and their assertion messages are literally asserting the presence of the bug.

| Test | Old (buggy) expectation | Observed at `c881a42` | Verdict |
|---|---|---|---|
| `PoC_Drift01_DepositForPaysMigrator::testC_InPlaceMigrateInCapturesReward_RecoverableViaRescue` | `assertEq(aliceGain, 0, "BUG: alice got nothing")` | alice received **8,219.178082191780691200e18** | **LIKELY-FIXED** |
| `PoC_Drift01_DepositForPaysMigrator::testD_CrossStakerMigrateStrandsRewardPermanently` | migrator holds **82,191.78e18** captured | migrator holds **0** — fully forwarded | **LIKELY-FIXED** |
| `PoC_Drift01_MigratorSidePatch::testA_Control_UnpatchedMigratorStrandsReward` | control: unpatched migrator strands 82,191.78e18 | migrator holds **0** | **LIKELY-FIXED** (the "unpatched" control is no longer unpatched) |

**Code change that closed it:** `f3b92c0 [story-023] Version-agnostic migrator settlement-capture forwarding
(pns20h1)` — `NFTStakerMigrator` / `InPlaceNFTStakerMigrator` gained an immutable `rewardToken` (the new 6th
constructor arg, cross-checked against the staker's own getter), a settlement-capture measure-and-forward leg,
a `require(captured <= owed)` tripwire ("Migrator: capture exceeds owed"), and a per-user `unforwarded`
escrow + `claimForwarded()` with a `totalUnforwarded` floor that `rescueERC20` cannot cross.

`PoC_Drift01_DepositForPaysMigrator::testA_DepositForPaysMigratorNotUser` and `testB_BatchMigratePaysUserCorrectly`
still PASS — they characterise `depositFor`'s raw behaviour, which is unchanged; the fix is on the migrator side,
which is what run-20's own patch proposal recommended.

### Confirming the upstream inversion claim (`MigratorRewardForwarding.t.sol`)

Verified directly in source, and both pass in the 412-test baseline:

- `testE2_MispointedHookRecipientRevertsInsteadOfOverCrediting` — the file's own comment states it is the
  inversion of `testE2_HOLE_HookRecipientPointedAtMigratorOverCreditsUser`, whose baseline at `0d1a0b2` was
  `assertGt(aGain, owed, "HOLE CONFIRMED")`, i.e. a **50,000e18** unrecoverable over-credit. With the tripwire
  the batch reverts wholesale (`vm.expectRevert("Migrator: capture exceeds owed")`), alice's balance is
  unchanged, and nothing is half-applied (`stillOnOld == 10`). **Claim confirmed.**
- `testG_RevertingRecipientDoesNotBrickTheBatch` — inversion of `testG_HOLE_RevertingRecipientBricksWholeBatch`.
  A blocklisted migrator→bob edge no longer bricks the batch; the reward escrows. `testG2_FalseReturningTransferEscrowsRatherThanReverting`
  covers the silent-false-return variant. **Claim confirmed.**

**Important scoping note on `PoC_Drift01_MigratorSidePatch.t.sol`.** Its `testE2_HOLE_…` and `testG_HOLE_…`
still **PASS** — but they construct `PatchedNFTStakerMigrator` from `test/patched/`, i.e. **run-20's own
proposed patch**, not shipped `src/`. They demonstrate holes in a *superseded audit proposal* and say nothing
about HEAD. Upstream shipped a different (and stronger) design that closes both. These two tests are now
**moot / reference-only** and must not be read as live findings against `c881a42`.

---

## 6. INCONCLUSIVE — explicit list

Only one item, and it is scoped narrowly:

1. **`SymbolicNudgePayout::check_noOverPay_threeTokens_withDonation` — path coverage INCONCLUSIVE.**
   Halmos reports `paths have not been fully explored due to the loop unrolling bound: 2`. The counterexample
   it *did* find is real for the transcribed harness, but the unexplored region is neither proven safe nor
   proven unsafe. Zero weight either direction on the unexplored paths. (The underlying defect is independently
   proven against real source in §4.3/§4.4, so this does not leave the finding unsupported.)

**Nothing else is inconclusive.** Every repointed PoC compiles and runs against real project source; there is
no remaining bit-rot, and no PoC was "made to pass" by weakening it.

---

## 7. Actions owed to the ledger (proposals only — not applied)

1. **Reopen H-01 (`858e9e80`)** and **M-01 (`521c20ad`)**, re-filed against `src/BatchNFTMinterMultiToken.sol`.
   Both are expired closures (fixed-status rationale invalidated by relocation, not by regression — the patch
   was never there to restore). Dedup **will not** catch these: the new `contract:function` mints a fresh
   fingerprint. The re-file must name the prior entries and quote their `fixed` disposition.
2. **Propose `fixed` for run-20 H-01 / `pns20h1` / DRIFT-01** (`depositFor` pays migrator), with story-023
   `f3b92c0` as the closing change and the three inverted PoCs as evidence. Human applies.
3. **Triage `invariant_fotFloor`** on the "declared floor is nominal, not actual" framing — do not close it as
   an FoT-support request, and do not suppress it silently.
4. **Retire or relabel** `PoC_Drift01_MigratorSidePatch::testE2_HOLE_*` / `testG_HOLE_*` as reference-only
   against the superseded run-20 patch, so a future run does not misread them as live.

---

# 8. ECON-001 — dedicated PoC: `paymentAmount = 0` free-mint + whole-balance sweep

**File:** `workspace/phoenix-nft-staking/test/PoC_EconZeroPaymentSweep.t.sol` (new, audit-authored)
**Commit:** `c881a42` · **Date:** 2026-07-21
**Result:** `11 passed / 0 failed` (7 against the FROZEN deployed file, 4 against the multi-token twin).

```
Ran 7 tests for PoC_ZeroPaymentSweep_DeployedBatchNFTMinter  — 7 passed
Ran 4 tests for PoC_ZeroPaymentSweep_MultiToken              — 4 passed
```

Regression check: the full non-invariant suite runs `472 passed / 3 failed / 475 total`. The 3 failures are
the pre-existing `PoC_Drift01_DepositForPaysMigrator::testC/testD` and
`PoC_Drift01_MigratorSidePatch::testA_Control_UnpatchedMigratorStrandsReward` already classified
**LIKELY-FIXED** in §5 above (story-023 `f3b92c0`). They are untouched by this PoC and are not
`BatchNFTMinter`-related.

## 8.1 Verdict

**The claim is CONFIRMED on both files, including the frozen, mainnet-deployed
`src/BatchNFTMinter.sol`.** Every leg of the described mechanic executes exactly as stated. Nothing was
weakened to make a test green; two boundary/control tests exist specifically to falsify.

Sites re-verified in source at `c881a42`:

| Step | `src/BatchNFTMinter.sol` (DEPLOYED) | `src/BatchNFTMinterMultiToken.sol` |
|---|---|---|
| pull `paymentAmount` | `:283` | `:357` |
| `forceApprove(minter, type(uint256).max)` | `:284` | `:360` |
| `remaining = balanceOf(this)` | `:305` | `:381` |
| `safeTransfer(msg.sender, remaining)` | `:307` | `:383` |
| `totalPaid = paymentAmount > remaining ? … : 0` | `:308` | `:384` |

## 8.2 Per-test results — deployed file (`PoC_ZeroPaymentSweep_DeployedBatchNFTMinter`)

Fixture models the live ratchet wiring: 6-decimal payment token, `dispatcherIndex = 7`,
`PRICE = 10.000000` (growth 0), third-party residual `R = 500.000000`. `DUST_THRESHOLD = 1e6 = 1.000000`.

| Test | Verdict | Numbers |
|---|---|---|
| `testA1_…ZeroPaymentMintsFreeAndSweepsThirdPartyBalance` | **CONFIRMED** | attacker pre-balance `0`, pre-allowance `0`. After `batchMint(count=1, recipient=attacker, paymentAmount=0, minReward=0)`: attacker `+490.000000` payment token, `+1` NFT; contract `500.000000 → 0`; `totalPaid == 0`; allowance still `0`. Outlay: **0 payment token, gas only.** |
| `testA2_…ZeroPaymentBuysMaximumFreeMints` | **CONFIRMED** | `count = R/PRICE = 50`. Attacker `+50` NFTs (face value `500.000000`), cash leg `0`, contract `→ 0`, `totalPaid == 0`. Free-mint leg stands alone — no dust gate involved. |
| `testA3_…VictimCannotRecoverTheSweptResidual` | **CONFIRMED (victim-side harm)** | Control: pre-attack `rescueERC20(usdc, owner, 500.000000)` succeeds. Post-attack the same call reverts `ERC20InsufficientBalance(0x…batch, 0, 500000000)`; owner recovers `0`. Second victim: the next honest batcher pays full freight (`totalPaid == 10.000000`, final balance `0`) — the refund they would have received is gone. |
| `testA4_…NudgeGateDoesNotGateTheSweep` | **CONFIRMED** | With `nudgeSize = 40`, `nudgePaymentToken` set: a `count = 1` (non-qualifying), `paymentAmount = 0` caller still takes `490.000000`. The **gated** nudge pot (`123e18`) is correctly withheld — proving the gate works and simply does not cover step 10. |
| `testA5_…ControlEmptyContractRevertsAtTheFundingBoundary` | **CONTROL (bounds the finding)** | On an empty contract the attack reverts inside the mint loop with the exact error `ERC20InsufficientBalance(0x…batch, 0, 10000000)`. Precondition is exactly `R >= C`; the mints are demonstrably funded from the **contract's** balance. |
| `testA6_…RatchetForwardingMakesFreeMintsUnbounded` | **CONFIRMED (amplifier)** | With the dispatcher forwarding 100% of each mint price back into the batch minter (the live `NudgeRatchet` wiring), marginal mint cost is **zero**: `count = 100` yields `+100` NFTs **and** the full `500.000000` residual, undiminished. `count` is bounded only by gas. |
| `testA7_…DustGateIsTheOnlyLowerBoundOnTheCashLeg` | **CONFIRMED (boundary)** | `remaining = 999_999` → no sweep, residue retained, `totalPaid == 0`, NFT still free. `remaining = 1_000_000` → whole balance swept. The dust gate is the only lower bound on the cash leg and is worth `1.00` unit at 6dp. |

## 8.3 Per-test results — multi-token twin (`PoC_ZeroPaymentSweep_MultiToken`)

| Test | Verdict | Numbers |
|---|---|---|
| `testB1_…ZeroPaymentMintsFreeAndSweepsThirdPartyBalance` | **CONFIRMED** | Identical outcome: `+490.000000` + `1` NFT for a zero contribution; contract `→ 0`; `totalPaid == 0`; no allowance required. |
| `testB2_…VictimCannotRecoverTheSweptResidual` | **CONFIRMED** | `rescueERC20` reverts `ERC20InsufficientBalance(batch, 0, 500000000)`; next honest batcher pays full freight. |
| `testB3_…PaymentTokenExclusionDoesNotCoverStep10` | **CONFIRMED** | A *qualifying* 40-batcher listing the payment token is reverted `BatchMint__RewardTokenIsPaymentToken(usdc)` — while the zero-payment `count = 1` caller takes `490.000000` anyway. The §4.1 hardening protects the reward path only; step 10 is untouched by it. |
| `testB4_…ControlEmptyContractRevertsAtTheFundingBoundary` | **CONTROL** | Same exact `ERC20InsufficientBalance(batch, 0, 10000000)`. |

## 8.4 Explicit statement on the DEPLOYED contract

**`src/BatchNFTMinter.sol` — the frozen, mainnet-deployed file — is exploitable as described.**
There is no lower bound on `paymentAmount`, `forceApprove` grants `type(uint256).max` irrespective of it,
step 10 sweeps the whole payment-token balance to `msg.sender` with no qualification check, and `totalPaid`
floors at `0`. No owner action, no privileged role, no unusual token behaviour and no allowance are required.
The attacker's total outlay is **gas only**.

The single precondition is `R > 0` — the contract holding payment token that did not come from the current
caller — and `R >= C` for the free-mint leg. The contract's own NatSpec (`:63-68`) documents two mechanisms
that produce `R` by design ("intentionally left … picked up by the next batch's sweep"; a donator "simply
donates to the next caller"), and the live `NudgeRatchet` wiring forwards 100% of every mint price into it.

**Run-20's severity bound (D-22 / R-7) — *"incremental extraction is capped by the caller's OWN donation"* —
is REFUTED by `testA1`, `testA2` and `testA6`: the caller's donation is `0` and the extraction is `R`.**

## 8.5 What this PoC does NOT establish

- **Present exposure is not measured here.** No mainnet reads were performed in this PoC. The magnitude
  of `R` on `0x81896F48…` / `0x86866e01…` at a current block remains **UNVERIFIED** (see ECON-001
  `presentExposure`). The mechanic is proven; the funds-at-risk-today figure is not, and must not be
  inferred from the `500.000000` fixture number, which is illustrative.
- **`testA6`'s 100% forward-back** is modelled via `MockITokenMinterV2.setPerMintDonation`, matching the
  existing suite's own `PoC_EconRatchetSweepAndDuplicates` fixture. It reproduces `NudgeRatchet`'s
  documented behaviour but is a mock, not a fork.
- **No fix is proposed or validated here.** ECON-001's recommendation remains REASONED, NOT VALIDATED
  (run-20 D-35).

---

# 9. DEDUP-21-002 — reentrancy on the frozen, mainnet-DEPLOYED `BatchNFTMinter`

**Artefacts**
- `workspace/phoenix-nft-staking/test/PoC_DeployedMinterReentrancy.t.sol` — **10/10 PASS**, default suite config (solc 0.8.20).
- `workspace/phoenix-nft-staking/test/poc/FaithfulNFTMinterV2.sol` — harness (`PoCDispatcher`, `FaithfulNFTMinterV2`).
- `workspace/phoenix-nft-staking/pocs/PoC_DeployedMinterReentrancy_RealMinter.t.sol` — **5/5 PASS**, same attack against the **real, unmodified `NFTMinterV2`**.

Commands:

```
cd workspace/phoenix-nft-staking
forge test --match-path test/PoC_DeployedMinterReentrancy.t.sol -vv
FOUNDRY_TEST=pocs FOUNDRY_SOLC_VERSION=0.8.26 FOUNDRY_EVM_VERSION=cancun \
  forge test --match-path pocs/PoC_DeployedMinterReentrancy_RealMinter.t.sol -vv
```

## 9.1 Which minter was driven, and why it faithfully reaches `onERC1155Received`

The existing `MockITokenMinterV2` + `MockERC1155` stack **cannot** reach the mechanism:
`test/mocks/MockERC1155.mint()` writes the balance, emits `TransferSingle`, and returns — it
never performs `_checkOnERC1155Received`. A reentrancy verdict reached on that stack would be a
**vacuous witness**. This is ledger **Q-01**, and it is now pinned as an executable fact by
`test_Q01_MockERC1155_IsVacuous_NeverFiresTheHook`, which asserts the probe recipient's hook
counter is **exactly 0** after a `MockERC1155.mint()`.

Two harnesses were therefore driven, and **both** were run:

1. **The real `NFTMinterV2`** (`lib/mutable/yield-claim-nft/src/NFTMinterV2.sol`, unmodified,
   imported via the project's own `yield-claim-nft/` remapping) wired to a real
   `ATokenDispatcherV2` subclass. Its `_executeMint` ends at `:196` in
   `_mint(recipient, resolvedTokenId, 1, "")` → OZ `ERC1155._updateWithAcceptanceCheck` →
   `ERC1155Utils.checkOnERC1155Received` → `recipient.onERC1155Received`. Nothing is simulated.
   `test_Real_HookFiresOncePerMint` measures **3 hook invocations for a 3-mint batch**.
   *This variant lives in `pocs/` and not `test/` for one reason only:* `foundry.toml` pins
   `solc = "0.8.20"` while OZ `ERC1155.sol` requires `^0.8.24` (and `Bytes.sol` needs cancun
   `mcopy`), so importing it into `test/` would break compilation of the whole 508-test suite.
   `FOUNDRY_TEST=pocs` keeps the default `forge test` byte-for-byte unaffected.

2. **`FaithfulNFTMinterV2`** (`test/poc/FaithfulNFTMinterV2.sol`) for the in-suite deliverable —
   a statement-for-statement port of `NFTMinterV2._executeMint` (paused/config/disabled requires
   in the same order → authoritative `primeToken()` read → balance-before/after
   `safeTransferFrom(msg.sender, dispatcher, price)` → price growth **before** dispatch (CEI) →
   the real non-virtual `ATokenDispatcherV2.dispatch` with its `nonReentrant`/`onlyMinter`/
   `whenNotPaused` chain → `_mint`). Its `_mint` writes the balance and then calls the
   **genuine OpenZeppelin `ERC1155Utils.checkOnERC1155Received` library** — the exact function
   the real `ERC1155` calls, with the same `operator = msg.sender`, `from = address(0)`
   arguments, imported from `lib/immutable/openzeppelin-contracts` and not re-implemented
   (`ERC1155Utils.sol` is `^0.8.20`, so the security-relevant half of the path compiles in-suite).

**Equivalence check:** the two harnesses produce **identical literals** on every shared assertion
(13_590_000 swept, 4 NFTs, 46_410_000 to the dispatcher, 25_000_000 NDG double-paid, and the same
`ERC20InsufficientAllowance(minter, 0, 12_100_000)` on the early-fire control). The port is doing
none of the work.

The `paymentToken`/dispatcher/`primeToken` wiring is the production one: the batcher **derives**
the payment token from `INFTMinterV2.configs(idx).dispatcher.primeToken()` — no override was used.

## 9.2 Fixture

6-decimal, USDC-shaped, matching the live `RatchetBatchNFTMinter` wiring.
`PRICE = 10_000_000` (10.000000), `growthBasisPoints = 1000` (+10%/mint), `DUST_THRESHOLD = 1e6`.
Alice is an honest integrator/relayer who names `Mallory` as `recipient` and **over-funds**, which
`src/BatchNFTMinter.sol:217-220` explicitly instructs callers to do because the per-mint price ramps.

## 9.3 Per-test verdicts (`test/PoC_DeployedMinterReentrancy.t.sol`, 10/10 PASS)

| Test | Verdict | Numbers |
|---|---|---|
| `test_Q01_MockERC1155_IsVacuous_NeverFiresTheHook` | PASS | `MockERC1155.mint()` → balance credited **1**, acceptance-hook invocations **0**. Vacuity proven. |
| `test_Fidelity_FaithfulMinter_FiresHookOncePerMint` | PASS | 3-mint batch → **3** hook invocations, inside `batchMint`'s loop. |
| `test_Exploit_LastIterationReentry_StealsSurplus_AliceTxSucceeds` | **PASS — EXPLOIT CONFIRMED** | see 9.4 |
| `test_Baseline_PassiveRecipient_AliceIsRefunded` | PASS | Same call, passive recipient: Alice refunded **26_900_000**, `totalPaid = 33_100_000`. |
| `test_Control_EarlyIterationReentry_RevertsWholeTx_ExactSelector` | PASS | Fire on hook #1 → whole tx reverts `ERC20InsufficientAllowance(minter, 0, 12_100_000)`. Alice keeps **60_000_000**; Mallory gains **0 USDC / 0 NFTs**; dispatcher receives **0**. |
| `test_Control_MiddleIterationReentry_AlsoReverts` | PASS | Fire on hook #2 → `ERC20InsufficientAllowance(minter, 0, 13_310_000)`. Alice intact. |
| `test_Control_MultiTokenTwin_GuardBlocksTheSameAttack` | PASS | Identical attack on `BatchNFTMinterMultiToken` → `ReentrancyGuardReentrantCall()` (`0x3ee5aeb5`). Alice keeps **60_000_000**, Mallory **0**. |
| `test_Control_MultiTokenTwin_PassiveRecipientSucceeds` | PASS | Twin, honest recipient: `totalPaid = 33_100_000`, surplus **26_900_000** refunded — so the revert above is the guard, not a fixture defect. |
| `test_Exploit_NudgeSnapshotPaidTwice` | **PASS — ECON-005 VALUE LEG CONFIRMED** | see 9.5 |
| `test_Baseline_Nudge_SingleFrame_PaysPriorPotOnly` | PASS | Honest 3-mint batch: recipient gets the prior pot **5_000_000 NDG**; the batch's own **15_000_000 NDG** of donations stay behind ("donate forward"). |

`pocs/…_RealMinter.t.sol` (5/5 PASS) reproduces items 2, 3, 5, 7 and 9 against the real `NFTMinterV2`.

## 9.4 The exploit — exact numbers

Call: Alice → `frozen.batchMint(count = 3, recipient = Mallory, paymentAmount = 60_000_000, minReward = 0)`.

| Quantity | Value |
|---|---|
| Cumulative honest dispatcher charge (10 + 11 + 12.1) | **33_100_000** |
| Contract payment balance before Alice's call | **0** |
| Price after the 3rd outer mint | **13_310_000** |
| Inner frame (fired on hook #3 = last iteration): `batchMint(1, Mallory, 0, 0)` | **succeeded** |
| — free mint charged to the contract (= Alice's money) | **13_310_000** |
| — swept to the INNER `msg.sender` at `:305-307` | **13_590_000** |
| Contract payment balance after Alice's call | **0** → `remaining / DUST_THRESHOLD == 0` → refund branch **skipped** |
| **Alice's loss** (unrefunded surplus) | **26_900_000** (26.900000 USDC) |
| **Mallory's gain** | **13_590_000 USDC** + **4 NFTs** (3 Alice paid for + **1 free**) |
| Dispatcher received | **46_410_000** |
| **`totalPaid` returned to Alice** | **60_000_000** |
| **Alice's transaction** | **SUCCEEDED — no revert, no loss-indicating event** |

`totalPaid == paymentAmount` is the contract reporting a clean, fully-spent batch. The honest
counterfactual for the identical call is `totalPaid = 33_100_000` with 26_900_000 refunded
(`test_Baseline_PassiveRecipient_AliceIsRefunded`). The entire surplus moved to Mallory:
`13_590_000 (cash) + 13_310_000 (free mint) = 26_900_000`.

## 9.5 Nudge double-pay (ECON-005 leg)

Config: `nudgeSize = 3`, `nudgePaymentToken = NDG`, dispatcher donates **5_000_000 NDG** per mint,
prior pot **5_000_000 NDG**. Alice: `batchMint(3, Mallory, 100_000_000, 0)`; inner frame
`batchMint(3, Mallory, 0, 0)` on hook #3.

- Outer snapshot at `:280` = **5_000_000**.
- Inner snapshot = 5_000_000 + 3 outer donations = **20_000_000**, paid to Mallory at `:301`.
- Inner's own 3 donations refill the pot, so the outer `:301` transfer of **5_000_000** still clears.
- **Mallory received 25_000_000 NDG**; honest single-frame payout is **5_000_000**.
- **Excess captured: 20_000_000 NDG.** Residual pot **10_000_000** instead of the honest **15_000_000**.

## 9.6 Why the timing is load-bearing (not hand-waving)

Firing early is **self-defeating, not merely weaker**. The inner frame's
`forceApprove(nftMinter, 0)` at `:290` runs on the unwind **before** the outer loop resumes, so the
outer's next `mint` pulls against a zero allowance and the entire transaction reverts:

- fire on hook #1 → `ERC20InsufficientAllowance(minter, 0, 12_100_000)`
- fire on hook #2 → `ERC20InsufficientAllowance(minter, 0, 13_310_000)`

(The `needed` figure is one growth step past the outer walk because the inner frame's own mint
also advanced `config.price`.) In both cases Alice keeps all 60_000_000, Mallory gains nothing, and
the dispatcher receives nothing — the attacker simply does not fire early. `count` is public
calldata, so targeting the last iteration is trivial.

## 9.7 Fork-drift asymmetry, measured

Same attacker, same minter, same hook, same call shape — only the guard differs:

| Target | `ReentrancyGuard`? | Result |
|---|---|---|
| `src/BatchNFTMinter.sol` (**DEPLOYED**, frozen, `:62` / `:243`) | **no** | attack **succeeds silently**; Alice −26_900_000, Mallory +13_590_000 + 1 free NFT |
| `src/BatchNFTMinterMultiToken.sol` (**not deployed**, `:82` / `:300`, NatSpec `:78-81` "required rather than optional") | yes, `nonReentrant` | reverts `ReentrancyGuardReentrantCall()` `0x3ee5aeb5`; Alice intact |

## 9.8 Explicit statement on the DEPLOYED contract

> **The frozen, mainnet-deployed `src/BatchNFTMinter.sol` IS exploitable this way.**
> Against the real, unmodified `NFTMinterV2` acceptance path, a caller-named hostile `recipient`
> re-entering `batchMint` on the final mint's `onERC1155Received` steals the caller's entire
> unrefunded surplus (13_590_000 in cash plus a 13_310_000 free mint, on a 60_000_000 budget),
> and **the victim's transaction succeeds** with `totalPaid` reporting a clean batch. The
> guarded twin blocks the identical call. This is realised fork drift on the file that is
> actually deployed, not a theoretical gap.

## 9.9 What this PoC does NOT establish

- **No present-exposure claim.** §8's mainnet reads at block 25577241 apply here too: both live
  frozen instances hold **0** of their payment token. The theft ceiling is the *caller's own
  in-flight surplus*, so unlike ECON-001 this path does **not** require the contract to be
  pre-funded — it only requires a real batch call with a hostile `recipient`. No such integration
  was found in scope; whether a third-party-recipient batching flow is operationally real is a
  severity question for the severity-auditor, and this PoC does not answer it.
- **Not a fix proposal.** The file is DEPLOYED and declared FROZEN (`:14-19`); there is no in-place
  patch. The documented mitigation (pause, route through the twin) remains **confirmed blocked** —
  `pauser() == address(0)` on both live instances (§8, ledger L-01).
- **Does not collapse into M-01 or M-07.** Those are the sweep leg and the max-approval leg
  individually; this is their reentrancy composition with a *distinct victim* (the outer caller).
- **Q-01 is discharged as an audit-harness concern only.** The project's own mocks are still
  vacuous; nothing in the shipped suite was changed.
