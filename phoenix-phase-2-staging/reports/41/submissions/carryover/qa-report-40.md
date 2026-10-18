# Carryover QA report: audit 40 (full-audit contract scan), carried at audit 41

> **Carryover QA report: audit 40** (cut down from `phoenix-phase-2-staging/reports/40/submissions/qa-report.md`).
> Carried by audit 41 (`phoenix-phase-2-staging-41`, `/audit-script unipooler-cutover`, src commit
> `e75ee0776efcf20918b7db71d717eafb61bbd1a6`, branch `master`). This is a full copy, not a stub.
> **Retained below (ledger status `open` as of audit 41): L-01, L-02, L-03, L-04, L-05, Q-01, Q-02. That is 7 entries.**
> **Removed as no longer live: none.** No run-40 QA entry has been disposed of in the ledger.
> Labels are the originals. Run 41 has its own, unrelated `L-01`..`L-04` and `Q-01`..`Q-03`, so select by issueId or fingerprint.
> Line numbers were accurate at run 40's commit `a4f9f3c`. Re-verify them against `e75ee07`, because story 103 has since landed in `UniPoolerCutoverCore.sol`.
> Source of the verbatim body: [`../../../40/submissions/qa-report.md`](../../../40/submissions/qa-report.md).

## Audit-41 reconciliation of the retained entries (statuses unchanged; only a human applies a status)

| Original label | issueId | Fingerprint | Ledger status | Audit-41 (`unipooler-cutover`) verdict |
|---|---|---|---|---|
| L-01 | `pps40l1` | `7d5a26570be9` | `open` | **PROPOSED `fixed`, not applied.** The escrow makes exit+seed one atomic tx, and no funds transit OWNER. See `reports/41/script-audits/unipooler-cutover/proposed-transitions.json`. |
| L-02 | `pps40l2` | `1d7e436f7dad` | `open` | **Still live** if the deploy order allows it (the helper is not on mainnet). It shows up again in this entry point as run-41 L-04 `pps41l4` (`a6764bb1edf1`). |
| L-03 | `pps40l3` | `85095591a60a` | `open` | **Still live.** The OnlyDispatcher window is txs 8..19 and there is no resume. It shows up again as run-41 L-01 `pps41l1` (`8142ab6d393c`). |
| L-04 | `pps40l4` | `5dce56307136` | `open` | **PROPOSED `fixed`, not applied.** The RECOVERY path is fork-proven against real Balancer. One runbook nit remains. |
| L-05 | `pps40l5` | `b7ff538a654c` | `open` | Not exercised by this entry point. It is neither reconfirmed nor closed, and absence from a scan is not evidence of a fix. |
| Q-01 | `pps40q1` | `c8fb41a168e1` | `open` | **Still live.** It shows up again as run-41 Q-01 `pps41q1` (`c62a58a1a8f8`). |
| Q-02 | `pps40q2` | `6d49f9353148` | `open` | **PROPOSED `fixed`, not applied.** A 1-wei unsynced pair donation now passes. |

Not in this file: F-01 `pps40f1` (`48d88a589ca4`) and F-02 `pps40f2` (`91aa9008aaca`) are faithfulness findings. They live in run 40's `spec-conformance.md`. Both are still live as story-document defects and show up again as run-41 F-01 `pps41f1` / F-02 `pps41f2`.

*The text below is a verbatim copy of the original report. Line numbers and links were accurate at the originating commit. Re-verify against current HEAD before acting.*

---

# QA Report for phoenix-phase-2-staging, run 40 (full-audit contract scan)

- **Project**: `phoenix-phase-2-staging` @ [`a4f9f3c`](https://github.com/Behodler/phoenix-phase-2-staging/tree/a4f9f3c66ee133a7cacb79f4d24300bba5945966) (`a4f9f3c66ee133a7cacb79f4d24300bba5945966`), branch `master`, read-only
- **Run**: `phoenix-phase-2-staging-40`. This is a full-audit **regression** contract scan (`entryPoint: ""`).
- **Range**: `0e190e8..a4f9f3c` (baseline `branchBaselines.master` = `0e190e8`)
- **Nested source**: `lib/yield-claim-nft` pinned at `0fd6bdf` by `a4f9f3c`. That pin contains `src/migration/UniPoolerCutoverEscrow.sol`.
- **Focus**: the UniPooler cutover (`script/helpers/UniPoolerCutoverCore.sol`, stories 100 / 103) and `UniswapHelper` (`src/periphery/UniswapHelper.sol` with `script/DeployUniswapHelperMainnet.s.sol`, stories 109 / 111)
- **Fork evidence**: mainnet block **26181500** (pinned). Test files are `work/test/audit-run40/UniPoolerCutoverCoreRun40.fork.t.sol` and `work/test/audit-run40/UniswapHelperInvariantsRun40.fork.t.sol`. Both are audit-authored, live in the writable `work/` clone, and are not part of the upstream repo. Raw logs are in `reports/40/tier3/`.
- **User directive: Sepolia excluded.** Every Sepolia leg (address books, scripts, story clauses) was excluded from this run by explicit user directive. Nothing here grades Sepolia, and silence on Sepolia is **not** a clean result. See [`spec-conformance.md` → "Sepolia excluded by user directive"](./spec-conformance.md#sepolia-excluded-by-user-directive).
- **Inputs**: `reports/40/findings/low/L-01..L-05*.json`, `reports/40/findings/qa/Q-01*.json`, `reports/40/findings/qa/Q-02*.json`

> **Faithfulness is not in this file.** This run's Law-2 findings, **F-01** (`pps40f1`) and **F-02** (`pps40f2`),
> and the **OBLIGATIONS** section (fixes story 103 owes yield-claim-nft) are in [`spec-conformance.md`](./spec-conformance.md).
> L-02, L-04 and Q-02 carry a faithfulness facet. The full text is here, and spec-conformance cross-references them.
>
> **Labels are run-scoped.** This run's `L-01` (`pps40l1`) is **not** run-39 `dev` L-01 (`9a694ae01fe1…`) and
> **not** run-38 `balancer-holding` L-01 (`59527bfa8478…`). Carried entries are cited **by fingerprint** throughout.
>
> **Carryover QA is not merged here.** Entries reconfirmed by this run are in
> [`carryover/qa-report-39.md`](./carryover/qa-report-39.md) and [`carryover/qa-report-38.md`](./carryover/qa-report-38.md).
> Both are full verbatim copies with a run-40 header (see [Carryover](#carryover-reconfirmed-in-run-40)).

---

## Borderline: owner decision needed

Three findings are **flagged for human review**. Each is rated Low, but a credible case for Medium exists, and a
specific event would make Medium correct. The triggers are listed so the re-weigh happens when the event occurs,
not after a broadcast.

| Finding | Question for the owner | Severity-raise trigger (raise to Medium if...) |
|---|---|---|
| **L-01** `pps40l1` · `7d5a26570be9093ad8a0704ee939953879a0a01a7201a88e8c182a97630bf505` | **Low vs Medium.** Fork-proven split cutover leaves about $41.3k of protocol POL on the OWNER EOA with no resume path. The trigger is organic (about 5 swaps a week) or costs about $0.03. **Overlaps the story-103 obligation** ([spec-conformance.md → OBLIGATIONS](./spec-conformance.md#obligations-cross-project-fixes-owed-by-story-103-not-landed)). **Re-check when story 103 lands. Do NOT pre-close.** | ...any story-103 mainnet entry point runs steps 4–6 as separate transactions in PROPORTIONAL mode before 30 Oct 2026 **without** escrow or skip-if-done gates. (The trigger closes itself at the 30 Oct pool pause: Balancer swaps are then blocked.) |
| **L-02** `pps40l2` · `1d7e436f7dad8616b42dd5e2616dd93ac83c8f7a23e82f60fb599675de405f91` | **Low vs Medium**, and **re-raises an owner wont-fix**: yield-claim-nft L-26 `b2a29359fde5` (wont-fix 2026-10-07; disclosure in the finding). The owner may also want to re-weigh L-26 itself given the 30 Oct and 30 Nov deadlines. | ...the protocol UI exposes the helper's add-liquidity form before Stage 4, **or** story 103 keeps step 1 (`createPair`) in a separate tx from the seed while the helper is live. Disclose ycn L-26 `b2a29359fde5` on any re-weigh. |
| **L-04** `pps40l4` · `5dce56307136849d1db9375216b87b0f95b6ab1e26a63675705db9062c2c3f0d` | **Is the deadline fallback reachable?** On the live, unpaused pool `enableRecoveryMode` reverts `SenderNotAllowed`. **Final review:** after `pausePool`, an arbitrary address can call `enableRecoveryMode` and the recovery exit seeds the new pooler (ycn `test_fork_case2_pausedPoolRecoveryExitSeedsNewPooler`, block 26136000, PASS). The **Vault-paused-only** case (after 30 Nov) is still untested. | ...a fork that forces a pause shows `enableRecoveryMode` still reverts `SenderNotAllowed` for OWNER and anyone else after the pause, which would make the documented fallback unreachable. Raise higher if the BPT exit becomes impossible. |

---

## Summary

| Severity | Count |
|----------|------:|
| High | 0 |
| Medium | 0 |
| Low Risk | 5 |
| QA | 2 |
| Centralization | 0 |
| **Total (this bundle)** | **7** |

**No Centralization findings.** The owner is trusted for knowing actions (Law 3), so no "a malicious owner could…"
vector is reported. Owner **footguns** (non-obvious consequences) are in scope and appear as Lows. L-01, L-03 and L-05
are tagged as footguns.

No finding moves value out of protocol custody or lets a third party extract it. ECON-001 showed zero extractable
value on the cutover path. The Lows are liveness and custody hazards on the Balancexit migration path, which is
under a hard deadline: the Balancer pool goes withdrawals-only on 30 Oct 2026, and the V3 Vault pauses on 30 Nov 2026.

| Label | issueId | Fingerprint | Area | Human review |
|---|---|---|---|---|
| L-01 | `pps40l1` | `7d5a26570be9093ad8a0704ee939953879a0a01a7201a88e8c182a97630bf505` | Cutover core, steps 4-6 | **Yes** |
| L-02 | `pps40l2` | `1d7e436f7dad8616b42dd5e2616dd93ac83c8f7a23e82f60fb599675de405f91` | UniswapHelper add-liquidity guard | **Yes** (re-raises a wont-fix) |
| L-03 | `pps40l3` | `85095591a60a255bbf6aea9f34526957ce4c921c2c5ef74c2e7c8111b58bd2fa` | Cutover core, steps 8-10 | No |
| L-04 | `pps40l4` | `5dce56307136849d1db9375216b87b0f95b6ab1e26a63675705db9062c2c3f0d` | Cutover core, RECOVERY exit | **Yes** |
| L-05 | `pps40l5` | `b7ff538a654ccbb3df5eab02005208a0379f8d111a859e0b4a1273c95a1cabe4` | UniswapHelper DOLA venue | No |
| Q-01 | `pps40q1` | `c8fb41a168e1ed1098cb04eb88f045c722d43597e243550968b621a56df6d86a` | Cutover core, simulation-only post-conditions | No |
| Q-02 | `pps40q2` | `6d49f9353148dcfaa9791a68b5b4eed6513ed728e0f9f78f2a8ed642af73a201` | Story-103 respec of step 2 / `_assertRetired` | No |

---

## Low Risk Findings

### [L-01] UniPoolerCutoverCore routes the whole protocol LP through the OWNER EOA across separate broadcast txs with simulation-baked amounts and no resume path; any Balancer swap between simulation and the exit strands the liquidity on the EOA <!-- id: pps40l1 -->

- **Severity**: Low. **HUMAN REVIEW FLAG: Low vs Medium** (footgun, borderline)
- **issueId**: `pps40l1`
- **Fingerprint**: `7d5a26570be9093ad8a0704ee939953879a0a01a7201a88e8c182a97630bf505`
- **Fingerprint input**: `script/helpers/UniPoolerCutoverCore.sol:_step4WithdrawBPT / _step5ExitBalancer / _checkMinAmountsOut / _step6SeedPair:multi-tx-eoa-custody-no-resume`
- **Root cause class**: `multi-tx-eoa-custody-no-resume`
- **Story**: 103 (`incomplete`), 100 (`auto-complete`)
- **Location**: [script/helpers/UniPoolerCutoverCore.sol#L359-L439](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/script/helpers/UniPoolerCutoverCore.sol#L359-L439) (`_step4WithdrawBPT` L359, `_step5ExitBalancer` L369, `_checkMinAmountsOut` L396, `_step6SeedPair` L417)

```solidity
    function _step4WithdrawBPT(CutoverParams memory p, CutoverLive memory l) internal returns (uint256 bal) {
        bal = ICutoverERC20(l.bPool).balanceOf(p.oldPooler);
        if (bal > 0) {
            ICutoverBalancerPooler(p.oldPooler).withdrawBPT(p.owner, bal);   // tx: all BPT -> OWNER EOA
        }
        ...
    }
    function _step5ExitBalancer(...) internal returns (uint256 bptIn, uint256 sOut, uint256 pOut) {
        bptIn = ICutoverERC20(l.bPool).balanceOf(p.owner);
        require(bptIn > 0, "UniPoolerCutoverCore: owner holds no BPT");   // re-run after a split fails here
        _checkMinAmountsOut(p, l, bptIn);
        ...
            IBalancerV3RouterExit(p.balancerRouter)
                .removeLiquidityProportional(l.bPool, bptIn, p.minAmountsOut, false, "");   // tx: bptIn baked
    }
    function _step6SeedPair(..., uint256 sAmt, uint256 pAmt) internal returns (uint256 liquidity) {
        ...
        (a, b, liquidity) = ICutoverUniV2Router(p.uniV2Router)
            .addLiquidity(l.sUSDS, l.phUSD, sAmt, pAmt, sMin, pMin, l.newPooler, p.seedDeadline);   // tx: sAmt/pAmt = simulation deltas
```

**Description**: Under `forge script --broadcast`, steps 4, 5 and 6 are separate OWNER transactions. Their amounts (`bal`, `bptIn`, `sAmt`, `pAmt`) are fixed in simulation, and every `require` between them runs only in simulation. If a Balancer swap is mined between simulation and the step-5 exit, one of two things happens:

- **(A) Split-brain.** The swap shifts the per-BPT composition but stays inside the `_checkMinAmountsOut` window. The exit lands, and then the baked step-6 `addLiquidity` tries to pull more of the short leg than OWNER holds. OWNER has 0 spare sUSDS and 1.47 phUSD.
- **(B) Clean exit revert after custody moved.** A larger swap pushes the exit past its floor, so step 5 reverts. Step 4 has already moved all 20,401.8 BPT to OWNER.

Either way, about $41.3k of protocol POL is left on the OWNER EOA. Story 103's 2026-10-07 requirement says "no protocol funds transit the owner EOA", and this violates it. The canonical pair is left empty and public, which **extends the open pair-poisoning window of carried entry `9a694ae01fe1`**. Index 4 and the hook stay on the old pooler. There is no resume entry point: re-running `_runCutover` fails at step 5 (`bptIn == 0`, L374) or at step 0. The fix is the escrow (`UniPoolerCutoverEscrow.exitAndSeed`, atomic, whole-balance seed). It is present in the `0fd6bdf` pin but **not wired into the core** at `a4f9f3c`.

**Failure scenario**:
1. The operator simulates `UniPoolerCutoverCore` in PROPORTIONAL mode. `bptIn`, `sAmt` and `pAmt` are baked into calldata.
2. A Balancer phUSD/sUSDS swap lands before the step-5 exit. It can be organic (about 5 a week) or a front-run of the step-4/5 txs costing about $0.03.
3. **(A)** Exit lands inside the floors, and step-6 `addLiquidity` reverts `TransferHelper: TRANSFER_FROM_FAILED` with a sUSDS shortfall of 516,227,577,953,238 wei. **(B)** A swap of 100 tokens or more at 10 bps tolerance makes step 5 revert `AmountOutBelowMin`, after step 4 has already moved all BPT to OWNER.
4. Re-running the core reverts at step 5 (`"UniPoolerCutoverCore: owner holds no BPT"`) or at step 0. Recovery means a hand-written owner transaction.

**Fork evidence (mainnet block 26181500, tolerances 10/10 bps)**, in `work/test/audit-run40/UniPoolerCutoverCoreRun40.fork.t.sol`:
- `test_CODE001_dustSwap_phUSDIn_seedReverts`: **PASS.** A swap of 0.001 phUSD in lets the exit land, and the seed then reverts `Error("TransferHelper: TRANSFER_FROM_FAILED")` (selector `0x08c379a0`) inside `UniswapV2Router02.addLiquidity`. OWNER then holds 18,571.886765729696524411 sUSDS and 22,560.181609305761341301 phUSD. The pair is still 0/0, and a re-run reverts `"UniPoolerCutoverCore: owner holds no BPT"`.
- `test_CODE001_organicSwap_phUSDIn` / `test_CODE001_organicSwap_sUSDSIn`: **PASS.** A 2,000-token swap makes the exit revert `AmountOutBelowMin(address,uint256,uint256)`, selector **`0x2f785e46`** (sUSDS out 17,593.8 < min 18,553.3). All 20,401.809 BPT remain on OWNER.
- `test_CODE001_sweep`: **PASS.** This size sweep covers both regimes. `test_CODE001_control_noSwap` is the **PASS** control in which both baked txs land.
- `testFuzz_CODE001_exitImpliesSeed`: **FAIL, property falsified.** Counterexamples are 26,181,500 wei and 135,600,680,029 wei of phUSD in. Logs: `tier3/core-fork-tests.log`, `tier3/core-code001-fuzz-fresh.log`.
- **Independent reproduction (final review):** the validity-checker re-ran `test_CODE001_dustSwap_phUSDIn_seedReverts` at block 26181500: **PASS**, with the `TRANSFER_FROM_FAILED` revert asserted byte-exact and the 516,227,577,953,238 wei shortfall matching.
- Not exercised on fork: the sub-claim that without `--slow`, steps 7-12 would still land after a failed seed and cut index 4 over to an unseeded pooler.

**Impact**: Liveness and custody. No third-party theft path exists: the owner controls the EOA (Law 3), and ECON-001 found zero extractable value. The seed either lands at the simulated price or reverts. The 1% tolerance bounds when the tx reverts. It does not bound a loss.

**Severity rationale (human review)**: *Case for Medium:* the failure is fork-confirmed in both regimes and falsified by fuzz. The trigger is organic or costs under $0.20. About $41.3k lands on an EOA with no resume path, which violates story 103's 2026-10-07 requirement. It also opens the `9a694ae01fe1` window, and the 30 Oct / 30 Nov deadlines compress recovery time. *Case for Low (chosen):*
- Nothing is lost or extractable.
- The trusted owner custodian can recover by hand (`BalancerWinddownPlan.md` L414 anticipates "recovered sUSDS and phUSD sit on OWNER … operator re-runs from step 6").
- Index-4 minting survives 30 Oct, because `BalancerPoolerV2._dispatch` never calls Balancer (plan L9), and a proportional recovery exit stays open after 30 Nov (plan L22/L38).
- Decisively, **no mainnet entry point calls the core at `a4f9f3c`**: only the DeployMocks rehearsal does.
- The trigger closes itself at the 30 Oct pool pause, because Balancer swaps are then blocked, so the hazard exists only in the PROPORTIONAL window before that date.

**Severity-raise trigger**: Raise to Medium if any story-103 mainnet entry point runs steps 4–6 as separate transactions in PROPORTIONAL mode before 30 Oct 2026 without escrow or skip-if-done gates. The trigger closes itself at the 30 Oct pool pause, because Balancer swaps are then blocked, so the hazard exists only in the PROPORTIONAL window before that date.

**Story-103 obligation overlap: re-check, do not pre-close.** This finding overlaps the story-103 fix obligation (DEDUP-009; yield-claim-nft L-27 `2268ead7cb…` / F-02-052 `5a7732a4ea…`, both fix-pending) tracked in [spec-conformance.md → OBLIGATIONS](./spec-conformance.md#obligations-cross-project-fixes-owed-by-story-103-not-landed). If story 103 lands the escrow rewire, the root cause should dissolve. **It must be re-checked against the landed code when story 103 lands. It must not be pre-closed on the strength of the story text.** The same applies to L-03 and Q-01, which live in the same core.

**Recommendation**: Wire story 103 onto `UniPoolerCutoverEscrow.exitAndSeed` (atomic, whole-balance seed), as the OBLIGATIONS checklist specifies. Until then, **do not broadcast the core in PROPORTIONAL mode**. If the core is kept, seed with the on-chain-guaranteed `minAmountsOut` floors as the desired amounts rather than the simulation deltas, sweep the remainder later, and add per-step skip-if-done gates. Also note that the runbook's 1% `exitAndSeed` tolerance (`docs/UniPoolerCutoverRunbookNotes.md`) is safe only in the escrow flow. Applied to this EOA core, it widens the split-brain window.

**Related ledger entries (not duplicates)**: `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add` (carried; the poisoning window this leaves open); yield-claim-nft L-28 `d77a482de757…` (same trigger against the escrow, where it is a clean revert; fix-pending); yield-claim-nft L-27 `2268ead7cb…` / F-02-052 `5a7732a4ea…` (fixes routed to story 103).

---

### [L-02] UniswapHelper's add-liquidity guard checks only that the pair exists, so an honest user can become first LP of the empty canonical sUSDS/phUSD pair and permanently brick both the cutover core (step 2) and UniPoolerCutoverEscrow (PairNotEmpty) <!-- id: pps40l2 -->

- **Severity**: Low. **HUMAN REVIEW FLAG: Low vs Medium**, and it **re-raises an owner wont-fix** (see Disclosure)
- **issueId**: `pps40l2`
- **Fingerprint**: `1d7e436f7dad8616b42dd5e2616dd93ac83c8f7a23e82f60fb599675de405f91`
- **Fingerprint input**: `src/periphery/UniswapHelper.sol:_requirePair / addLiquiditySUSDS / addLiquidityUSDS:first-lp-empty-pair-via-helper`
- **Root cause class**: `first-lp-empty-pair-via-helper`
- **Story**: 109 (`auto-complete`), 111 runbook. Law 1 overrides story 109 (story-unsafe).
- **Location**:
  - [src/periphery/UniswapHelper.sol#L428-L431](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/src/periphery/UniswapHelper.sol#L428-L431) (`_requirePair`)
  - [src/periphery/UniswapHelper.sol#L273-L291](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/src/periphery/UniswapHelper.sol#L273-L291) (`addLiquiditySUSDS`), [#L300](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/src/periphery/UniswapHelper.sol#L300) (`addLiquidityUSDS`)
  - [script/DeployUniswapHelperMainnet.s.sol#L43-L46](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/script/DeployUniswapHelperMainnet.s.sol#L43-L46) (the runbook premise)

```solidity
    // UniswapHelper.sol
    function _requirePair() internal view returns (address p) {
        p = pair();
        if (p == address(0)) revert PairNotFound();   // existence only; (0,0) reserves pass
    }

    function addLiquiditySUSDS(...) external checkDeadline(deadline) returns (...) {
        if (recipient == address(0)) revert ZeroAddress();
        address lp = _requirePair();
        ...
        (susdsUsed, phusdUsed, liquidity) =
            _addLiquidity(susdsDesired, phusdDesired, susdsMin, phusdMin, recipient, deadline);
```

```solidity
 // DeployUniswapHelperMainnet.s.sol NatSpec
 *         THE phUSD/sUSDS PAIR IS NOT AN INPUT. `PhusdSusdsPair` stays a zero placeholder until story 103's cutover
 *         (broadcast at Stage 4) creates the pair. The helper resolves it at call time via `factory.getPair`, so it
 *         can be deployed first; until the pair exists every swap and liquidity call reverts (`PairNotFound`, ...
```

**Description**: The helper gates liquidity on the canonical pair *existing*, not on it having reserves. Story 111 deploys the helper **before** the cutover. The pair exists from cutover step 1 onward (its own tx), or earlier if anyone calls the permissionless `factory.createPair`. Any `addLiquidity*` through the helper while the pair is still empty makes the caller the first LP and gives the pair non-zero reserves. Three things then hold permanently. Core step 2 fails (L339/L344). The escrow's `PairNotEmpty` gate fails. And `MINIMUM_LIQUIDITY` is locked, so reserves can never return to zero. `UniPoolerV2`'s canonical-pair constructor check rules out using any other pair. Story 109's letter is satisfied: the helper cannot create the pair. Its stated purpose, preventing seeding before story 103's cutover, is not achieved, because an existing pair is not an empty pair.

**Failure scenario**:
1. `UniswapHelper` is deployed via `uniswap-helper:broadcast` (story 111) before Stage 4.
2. The canonical sUSDS/phUSD pair comes to exist, either at cutover step 1 or through anyone's `createPair`.
3. An honest user, or a UI that shows the add form once `getPair` resolves, calls `addLiquiditySUSDS` or `addLiquidityUSDS`. `_requirePair` passes.
4. Pair reserves become non-zero for good. Core step 2 reverts `"UniPoolerCutoverCore: pair reserves not empty"`, and `exitAndSeed` reverts `UniPoolerCutoverEscrow__PairNotEmpty`.

**Fork evidence (mainnet block 26181500)**, in `work/test/audit-run40/UniPoolerCutoverCoreRun40.fork.t.sol`:
- `test_CODE005_helperFirstLPBricksCoreStep2AndEscrow`: **PASS.** The pair is created at core step 1, and a user's `addLiquidityUSDS(1e18, 1e18, 0, 0, …)` succeeds, giving 0.948 LP plus 1000 wei locked at `address(0)`. Core step 2 then reverts `"UniPoolerCutoverCore: pair reserves not empty"`. `UniPoolerCutoverEscrow.exitAndSeed` reverts `UniPoolerCutoverEscrow__PairNotEmpty(r0, r1, b0, b1)`, selector **`0x247b45ec`** (args 0.8988e18 / 1e18 / 0.8988e18 / 1e18), before touching BPT.
- `test_CODE005_prePairCreated_helperAddSUSDS`: **PASS.** A stranger pre-creates the pair, and a user's `addLiquiditySUSDS` then makes core step 2 revert `"pair reserves not empty"`.

**Impact**: Permanently bricks the current seeding contracts (core step 2 and escrow `PairNotEmpty`); finishing needs new re-price-then-mint code, with the recovery exit as the backstop. Nothing is stolen, and live protocol functions are unaffected (index-4 minting does not touch Balancer). The first LP sets the price.

**Re-price math (severity audit)**: an honest 1e18 sUSDS / 1e18 phUSD first LP overprices phUSD by about 21% against the live fair ratio (~0.82 sUSDS per phUSD). A swap of a few cents re-prices the ~$2 pool, and the protocol can be the arbitrageur. Minting in afterwards is pro-rata, so protocol dilution is about $2 against ~$41k. No protocol asset is at risk.

> **DISCLOSURE: re-raise of an owner wont-fix.** This finding re-raises **yield-claim-nft L-26
> `b2a29359fde54466776d650fd0a1097730653f4ed0fc21d380a3b9b00c0742f7`** (`ycn22l26`), which the owner triaged
> **wont-fix on 2026-10-07**. Quoted `triageReason` (verbatim from the yield-claim-nft ledger):
>
> > "Owner triage 2026-10-07: wont-fix. Owner: \"I guess, it should just panic and then I'll have to figure out what to do if there is a pair. I think it's safe to mark as won't fix.\" Basis: the escrow's strict empty-pair gate is fail-loud by design — a synced donation or dust first-mint only reverts exitAndSeed; no value moves and abort() fully restores the old pooler (fork-proven run-22). Recovery from a poisoned pair is an attended, manual operator decision, consistent with L-24 (ycn20l24, wont-fix 2026-10-01). Safe-recovery guidance retained (footgun): if the pair is poisoned, abort(); for a synced 1-wei donation seed via a separate contract using direct transfer + pair.mint(newPooler) (fork-proven to absorb the dust); for a dust-minted pair, arbitrage to the target ratio first, then transfer + mint with a reserve-ratio assertion. Never relax the empty-pair precondition and never router-addLiquidity with zero mins into a skewed pair. Re-weigh if a hard deadline would expose value, or if no replacement seeder is permissible under the story-052 tax constraint."
>
> **Why it is kept rather than suppressed.** L-26 judged the **escrow's** fail-loud gate against an
> **adversarial** 1-wei grief. This finding differs on every axis:
> - **Contract**: a different and newer first-party contract (`UniswapHelper`, story 109).
> - **Root cause**: the helper's existence-only guard.
> - **Trigger**: an **honest user** acting through a protocol-shipped helper and UI surface.
> - **Fix location**: the helper, not the escrow.
>
> L-26's own re-weigh condition now **partly** holds. A hard deadline exists: `BalancerWinddownPlan.md` L7 sets
> withdrawals-only from 30 Oct 2026, and the V3 Vault pauses 30 Nov 2026. Value is still not exposed, because a
> proportional recovery exit stays open after 30 Nov (plan L22/L38).

**Severity rationale (human review)**: *Case for Medium:* fork-proven, and Law 1 overrides story 109. The protocol ships an honest-user path to a permanent brick of its current seeding contracts, under a deadline. *Case for Low (chosen):*
- No asset is at risk, and live functions are unaffected.
- The adversarial-trigger outcome is already accepted: `9a694ae01fe1` is open Low, and ycn L-26 is wont-fix. This adds a new trigger, not a new outcome.
- The brick hits one seeding design, not the protocol. A dust first position can be re-priced and minted into with new code (plan L414).
- L-26's re-weigh condition is only partly met.

**Severity-raise trigger**: Raise to Medium if the protocol UI exposes the helper's add-liquidity form before Stage 4, or if story 103 keeps step 1 (`createPair`) in a separate tx from the seed while the helper is live. Disclose ycn L-26 `b2a29359fde5` on any re-weigh.

**Recommendation**: In the helper's add paths, revert when either reserve is 0, so the helper can never be the first LP. Correct the runbook and story-111 wording: the pair may exist before Stage 4. This must land **before story 111 broadcasts**, since the helper is immutable once deployed. Illustrative sketch:

```solidity
    function _requireSeededPair() internal view returns (address p) {
        p = pair();
        if (p == address(0)) revert PairNotFound();
        (uint112 r0, uint112 r1,) = IUniswapV2Pair(p).getReserves();
        if (r0 == 0 || r1 == 0) revert EmptyPair();   // helper may never be first LP
    }
```

**Related ledger entries (not duplicates; do not collapse)**: `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add` (carried; adversarial donate+sync trigger, fix in the core); yield-claim-nft L-26 `b2a29359fde5…` (wont-fix, disclosed above).

---

### [L-03] Index-4 mints revert OnlyDispatcher for the ~11-tx window between cutover step 8 and step 10, and the core has no resume gates, so a halt inside the window leaves index 4 bricked <!-- id: pps40l3 -->

- **Severity**: Low (footgun)
- **issueId**: `pps40l3`
- **Fingerprint**: `85095591a60a255bbf6aea9f34526957ce4c921c2c5ef74c2e7c8111b58bd2fa`
- **Fingerprint input**: `script/helpers/UniPoolerCutoverCore.sol:_step8RepointHook / _step9ConfigurePooler / _step10ReplaceDispatcher:rewire-window-no-resume`
- **Root cause class**: `rewire-window-no-resume`
- **Story**: 103 ("resume from receipts")
- **Location**: [script/helpers/UniPoolerCutoverCore.sol#L448-L499](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/script/helpers/UniPoolerCutoverCore.sol#L448-L499), plus the step-0 gate at [#L297](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/script/helpers/UniPoolerCutoverCore.sol#L297)

```solidity
    function _step8RepointHook(CutoverParams memory p, CutoverLive memory l) internal {
        ICutoverMintDebtHook(p.mintDebtHook).setDispatcher(l.newPooler);   // old pooler now fails onlyDispatcher
        UniPoolerV2(l.newPooler).setHook(IDispatchHook(p.mintDebtHook));
        ...
    }
    function _step9ConfigurePooler(...) internal {   // ~11 owner txs touching ONLY the new pooler
        np.setMinter(p.nftMinter);
        ... np.setPSM / setMaxTout / setBatchMinter / setBatchDonationSize / setAuthorizedPooler x4 / setNudgeStreamer
    }
    function _step10ReplaceDispatcher(...) internal {
        m.replaceDispatcher(p.dispatcherIndex, l.newPooler);   // index 4 works again only from here
    }
    // step 0:
        require(hook.dispatcher() == p.oldPooler, "UniPoolerCutoverCore: hook not on old pooler");   // blocks a re-run
```

**Description**: Once step 8's `setDispatcher` lands, `BalancerPoolerMintDebtHook.onDispatch` reverts `OnlyDispatcher` for the old pooler. `ATokenDispatcherV2.dispatch` calls the hook unconditionally, so every index-4 mint reverts until step 10 is mined. In between sit `setHook` and the step-9 setters, about 11 Ledger-signed `--slow` transactions. The window itself is inherent to having three independent owner contracts. The real hazard is that the core cannot resume. A broadcast halt inside steps 8-10 (Ledger timeout, gas, nonce) leaves index 4 bricked, and a re-run fails the step-0 gate at L297. Story 103 promises "resume from receipts", but the core has no skip-if-done gates.

**Failure scenario**:
1. Step 8 `hook.setDispatcher(newPooler)` is mined.
2. The step-9 setters (about 11 txs) are pending.
3. `NFTMinterV2.mint(4, user)` reverts `OnlyDispatcher()`.
4. If the run halts in the window, a re-run fails `"UniPoolerCutoverCore: hook not on old pooler"`.

**Fork evidence (mainnet block 26181500)**: `work/test/audit-run40/UniPoolerCutoverCoreRun40.fork.t.sol::test_CODE003_mintRevertsBetweenStep8And10`: **PASS.** A control mint before step 8 succeeds. After step 8, and still after step 9, `NFTMinterV2.mint(4, user)` reverts exactly **`0xee5fc5a8` = `OnlyDispatcher()`**, bubbled from `BalancerPoolerMintDebtHook.onDispatch`. Mints work again after step 10. A re-run after a halt reverts `"UniPoolerCutoverCore: hook not on old pooler"`.

**Impact**: Index-4 mints revert for the window. Users keep their USDS and lose gas. If the run halts inside the window, this lasts until the owner finishes by hand. Fail-closed; no value at risk.

**Recommendation**: Move step 9's configuration ahead of step 8. It touches only the new pooler, so steps 8-10 become three consecutive transactions. Give story 103 per-step idempotent gates, following the precedent of `StableStakerCutoverCore` after L-02 `2c82d65e65e1…` (fixed). Alternatively, disable index 4 in `NFTMinterV2` across the window.

**Related ledger entries (not duplicates)**: `19e2e0c2d6a3…` (dev rehearsal assertion, deleted code); `c358427cf96b…` and `2f8e1ff5e1ae…` (same class, uniboost-cutover, different contract); `2c82d65e65e1…` (fixed precedent, different contract, not a regression).

---

### [L-04] The RECOVERY exit branch never enables Balancer V3 Recovery Mode, and MockBalancerVault treats "paused" as "recovery allowed", so test_cutover_recovery proves a property that is false on mainnet <!-- id: pps40l4 -->

- **Severity**: Low. **HUMAN REVIEW FLAG** (the paused-pool path is unverified)
- **issueId**: `pps40l4`
- **Fingerprint**: `5dce56307136849d1db9375216b87b0f95b6ab1e26a63675705db9062c2c3f0d`
- **Fingerprint input**: `script/helpers/UniPoolerCutoverCore.sol:_step5ExitBalancer (RECOVERY branch):recovery-mode-conflation`
- **Root cause class**: `recovery-mode-conflation`
- **Story**: 100 (`auto-complete`, spec), 103 (`incomplete`), `BalancerWinddownPlan.md`. Law-2 facet; see [spec-conformance.md](./spec-conformance.md).
- **Location**:
  - [script/helpers/UniPoolerCutoverCore.sol#L381-L386](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/script/helpers/UniPoolerCutoverCore.sol#L381-L386) (`_step5ExitBalancer`, RECOVERY branch)
  - [src/mocks/MockBalancerVault.sol#L243](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/src/mocks/MockBalancerVault.sol#L243)
  - [test/UniPoolerCutoverCore.t.sol#L312-L317](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/test/UniPoolerCutoverCore.t.sol#L312-L317)

```solidity
    // UniPoolerCutoverCore._step5ExitBalancer
        if (p.exitMode == ExitMode.PROPORTIONAL) {
            ...
        } else {
            IBalancerV3RouterExit(p.balancerRouter).removeLiquidityRecovery(l.bPool, bptIn, p.minAmountsOut);   // no enableRecoveryMode
        }

    // MockBalancerVault.removeLiquidityRecovery
        require(poolPaused, "MockBalancerVault: pool not in recovery mode");   // paused == recovery (not true on mainnet)

    // test/UniPoolerCutoverCore.t.sol
    function test_cutover_recovery() public {
        bVault.setPoolPaused(true); // after 30 Oct: proportional reverts, recovery works
```

**Description**: On mainnet, a paused Balancer V3 pool is **not** in Recovery Mode. Someone must first call `Vault.enableRecoveryMode(pool)`. Today the live pool reports `isPoolInRecoveryMode = false`. The core's RECOVERY branch never makes that call. `MockBalancerVault` treats the two states as one (`poolPaused` ⇒ recovery allowed), so `test_cutover_recovery` proves a property that does not hold on mainnet. The DeployMocks rehearsal runs PROPORTIONAL only and never exercises this branch. For comparison, the yield-claim-nft escrow fork test does call `enableRecoveryMode` explicitly (`UniPoolerCutoverEscrow.fork.t.sol` L216).

**Failure scenario**:
1. After 30 Oct (pool paused), the operator sets `RECOVERY_EXIT=true`.
2. The core never calls `Vault.enableRecoveryMode`, and the pool is not yet in recovery.
3. Simulation reverts at step 5 with `PoolNotInRecoveryMode`. Nothing broadcasts, because the state is deterministic in simulation.

**Fork evidence (mainnet block 26181500)**: `work/test/audit-run40/UniPoolerCutoverCoreRun40.fork.t.sol::test_CODE004_recoveryBranchRevertsOnLivePool`: **PASS.** The live pool reports `isPoolInRecoveryMode=false` and `isPoolPaused=false`. Step 5 in RECOVERY mode reverts exactly **`PoolNotInRecoveryMode(0x642BB6…db04)`, selector `0xef029adf`**, from the real V3 Vault. `Vault.enableRecoveryMode(pool)` reverts **`SenderNotAllowed()`, selector `0x23dada53`**, for both a stranger and OWNER **while the pool is live**.

**Why the fork result is not decisive (human review)**: `SenderNotAllowed` on the live pool is the expected authorized-only behaviour before a pause. The **paused-pool path was not tested.** Plan L38 says `enableRecoveryMode` becomes permissionless once the pool or Vault is paused, and plan L21/L34 say Balancer enables Recovery Mode where needed. If that holds, the remedy is one permissionless call before re-running. The failure is fail-closed: it reverts in forge simulation before step 4's `withdrawBPT` is broadcast, so nothing is stranded. That is why this stays Low.

**Paused-pool path verified (final review)**: `yield-claim-nft/work/test/UniPoolerCutoverEscrow.fork.t.sol::test_fork_case2_pausedPoolRecoveryExitSeedsNewPooler` at fork block 26136000: after `V3_GOVERNANCE` calls `pausePool(BPT)`, an arbitrary address (`0xA11CE`) calls `enableRecoveryMode(BPT)` successfully, and the RECOVERY exit of 20,401.8 BPT seeds the new pooler. **PASS.** Plan L38 holds for the pool-paused case. **Still untested:** the Vault-paused-only case (after 30 Nov). Story 103's forced-pause fork test should cover both.

**Severity-raise trigger**: Raise to Medium if a fork that forces a pause (vault or authorizer prank) shows `enableRecoveryMode` still reverts `SenderNotAllowed` for OWNER and anyone else after the pause, i.e. the documented fallback cannot be reached. Raise higher if the BPT exit becomes impossible.

**Recommendation**: Add a permissionless `enableRecoveryMode` call to the RECOVERY branch (when `!vault.isPoolInRecoveryMode(pool)`, before `removeLiquidityRecovery`). Make `MockBalancerVault` model Recovery Mode as a separate state from paused. Story 103's fork case 2 must force a pause (pool **and** Vault) and call the **real** `enableRecoveryMode`, not a mocked pause query. This item is also listed in spec-conformance OBLIGATIONS (item 9). Illustrative sketch (interface names indicative):

```solidity
        } else {
            if (!IBalancerV3VaultViews(l.bVault).isPoolInRecoveryMode(l.bPool)) {
                IBalancerV3VaultAdmin(l.bVault).enableRecoveryMode(l.bPool);   // permissionless once paused
            }
            IBalancerV3RouterExit(p.balancerRouter).removeLiquidityRecovery(l.bPool, bptIn, p.minAmountsOut);
        }
```

---

### [L-05] UniswapHelper's hardcoded DOLA venue (Curve DOLA-3CRV) is near-empty; the DOLA route caps at about $1.5k USDC out, and story 109's fork depth check covered USDe but not DOLA <!-- id: pps40l5 -->

- **Severity**: Low (footgun: the venue is immutable once deployed)
- **issueId**: `pps40l5`
- **Fingerprint**: `b7ff538a654ccbb3df5eab02005208a0379f8d111a859e0b4a1273c95a1cabe4`
- **Fingerprint input**: `script/DeployUniswapHelperMainnet.s.sol:CURVE_DOLA_3CRV constant -> UniswapHelper._toSusds/_fromSusds:thin-hardcoded-venue`
- **Root cause class**: `thin-hardcoded-venue`
- **Story**: 109 / 111 (a spec gap, not a deviation; no F label). Story 111 L39 itself names the venue.
- **Location**:
  - [script/DeployUniswapHelperMainnet.s.sol#L74](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/script/DeployUniswapHelperMainnet.s.sol#L74)
  - [src/periphery/UniswapHelper.sol#L440](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/src/periphery/UniswapHelper.sol#L440) (`_toSusds`), [#L462](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/src/periphery/UniswapHelper.sol#L462) (`_fromSusds`)

```solidity
    // DeployUniswapHelperMainnet.s.sol
    address public constant CURVE_DOLA_3CRV = 0xAA5A67c256e27A5d80712c51971408db3370927D;

    // UniswapHelper._toSusds / _fromSusds: intermediate leg has a 0 minimum
            usdc = ICurveMetaPool(curveDolaPool).exchange_underlying(CURVE_META_DOLA, CURVE_META_USDC, amount, 0);
            amountOut = ICurveMetaPool(curveDolaPool).exchange_underlying(CURVE_META_USDC, CURVE_META_DOLA, usdc, 0);
```

**Description**: The address and indices are correct (`coins(0)` = DOLA, and USDC is underlying index 2). But at block 26181407 the pool holds only about 1,889 DOLA and 1,488 3CRV. Every DOLA leg crosses it with a 0 intermediate minimum, so only the caller's final `minOut` protects the user. `get_dy_underlying` depth curve (ECON-003):

| Direction | In | Out | Shortfall |
|---|---|---|---|
| DOLA→USDC | 100 | 99.62 | |
| DOLA→USDC | 1,000 | 984.95 | -1.5% |
| DOLA→USDC | 2,000 | 1,519 | -24% |
| DOLA→USDC | 5,000 | 1,543 | -69% |
| USDC→DOLA | 2,000 | 1,818 | -9% |
| USDC→DOLA | 10,000 | 1,888.7 | -81% |

The quote path uses the same pool, so a quote-derived `minOut` protects users. The trap is a UI that shows the output without the price impact. Story 109 L168 asks for a USDe depth check only.

**Failure scenario**:
1. A user swaps DOLA↔phUSD via the helper.
2. The leg crosses Curve DOLA-3CRV.
3. The output collapses, and only the caller's `minOut` stands between the user and the slippage.

**Evidence**: Chain reads of `get_dy_underlying` at blocks 26181407 and 26181448. The fork invariant suite `work/test/audit-run40/UniswapHelperInvariantsRun40.fork.t.sol` ran against real venues pinned at block 26181500. `invariant_I3_deliveredAtLeastMinOut` **PASSED** (16 runs × 240 calls, no counterexample; not a proof), so a quote-derived `minOut` protected every DOLA call. Log: `tier3/helper-invariants.log`. There is no revert selector, because this is a depth/slippage finding.

**Impact**: The route on an immutable helper is unusable above ~$1.5k; only a redeploy fixes it; a quote-derived `minOut` prevents user loss. The advertised DOLA route delivers -24% at 2k and -69% at 5k DOLA→USDC. A weak or zero `minOut` is user input (C4-invalid; cf. MR-008) and does not determine severity. Any slippage leak goes to Curve LPs and arbitrageurs, never from protocol funds.

**Recommendation**: Pick a deep DOLA venue before the story-111 broadcast (plan L186: DOLA/sUSDS Curve). The helper is ownerless and takes the venue from a deploy-script constant, so fixing it later means a redeploy. Alternatively, have the UI compute price impact against pair spot for every route and block on it.

---

## QA Findings

### [Q-01] The cutover core's "read live" rescue amounts and post-conditions run only in forge simulation; interim index-4 mints before step 10 leave unswept sUSDS on the paused old pooler <!-- id: pps40q1 -->

- **Severity**: QA
- **issueId**: `pps40q1`
- **Fingerprint**: `c8fb41a168e1ed1098cb04eb88f045c722d43597e243550968b621a56df6d86a`
- **Fingerprint input**: `script/helpers/UniPoolerCutoverCore.sol:_step7PullDebt / _step11MoveBalances / _assertRetired:simulation-only-postconditions-baked-amounts`
- **Root cause class**: `simulation-only-postconditions-baked-amounts` (class alias `ForgeLocalPassPrecedesBroadcast`)
- **Story**: 103
- **Location**: [script/helpers/UniPoolerCutoverCore.sol#L442-L560](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/script/helpers/UniPoolerCutoverCore.sol#L442-L560) (`_step7PullDebt` L442, `_step11MoveBalances` L502-L536, `_assertRetired` L547)

```solidity
    /// @notice Step 11. Move the old pooler's sUSDS and parked USDS, read live after step 10.
    function _step11MoveBalances(...) internal returns (...) {
        sUSDSRescued = ICutoverERC20(l.sUSDS).balanceOf(p.oldPooler);       // read in SIMULATION, baked into calldata
        if (sUSDSRescued > 0) old.rescueERC20(l.sUSDS, l.newPooler, sUSDSRescued);
        usdsRescued = ICutoverERC20(l.usds).balanceOf(p.oldPooler);
        ...
        require(
            ICutoverERC20(l.sUSDS).balanceOf(p.oldPooler) == 0 && ICutoverERC20(l.usds).balanceOf(p.oldPooler) == 0,
            "UniPoolerCutoverCore: old pooler not drained"                   // simulation-only
        );
    }
```

**Description**: The "read live after step 10" amounts are read in simulation and baked into the rescue calldata. The drain check (L532-L535), the step-7 `mintDebt == 0` check and `_assertRetired` all run only in simulation. Until the step-10 tx is mined, index 4 still dispatches to the old pooler, and every interim mint wraps USDS into sUSDS **on the old pooler** (`BalancerPoolerV2._dispatch`). The baked rescue misses that sUSDS, which stays on the old pooler after step 12 pauses it. The current rate is about 6.8 sUSDS an hour (about 1,957 sUSDS in about 12 days since the 2026-10-01 holding pattern).

There is also a conditional brick that does **not** apply to today's config (live `batchDonationSize` is 0). If the owner re-enables the donation before the cutover, an interim mint's PSM sweep can push the old pooler's USDS below the baked `usdsRescued`. The step-11 USDS rescue then reverts, and the broadcast halts before step 12.

**Failure scenario**: No attacker is involved. Ordinary index-4 mints between simulation and the mining of step 10 leave residue that the script claims is zero.

**Evidence**: Not separately fork-tested in tier 3. Supporting static instances are simulation-only strict equalities (SLITHER-003/006/008/012/013/014/016/017/020), logged as context in `reports/40/filtered/dedup-log.md`. The step-5/6 facet of the same mechanism is fork-proven under L-01 and not double-counted here.

**Impact**: No loss. `rescueERC20` is `onlyOwner` and not pause-gated, so the residue is recoverable (opportunity cost only). The retired pooler silently keeps protocol sUSDS that the in-script post-conditions claim is zero.

**Recommendation**: Run the step-11 rescue in a second invocation after step 10 is mined. Alternatively, have story 103's `:verify` assert old-pooler sUSDS/USDS == 0 and `mintDebt == 0` **live, after broadcast**, and sweep any residue.

**Class precedent (not duplicates)**: `9fa8eee3010ec38a3aa38c93bdc8141dd42eb6a2a469648865c02f5ca2f84787` (carried, `dev` / DeployMocks) and `78cb5942d483…` (fixed; `CutoverStableStakerV2Mainnet`). Both are in different contracts, so this is not a regression.

---

### [Q-02] Story 103's rewire respec turns a self-healing condition into a griefable DoS: dropping the step-2 skim makes a 1-wei unsynced donation fail simulation, and `_assertRetired`'s owner-BPT == 0 require must go <!-- id: pps40q2 -->

- **Severity**: QA (faithfulness facet: story-unsafe, Law 1 marginal)
- **issueId**: `pps40q2`
- **Fingerprint**: `6d49f9353148dcfaa9791a68b5b4eed6513ed728e0f9f78f2a8ed642af73a201`
- **Fingerprint input**: `script/helpers/UniPoolerCutoverCore.sol:_step2EnsurePairEmpty (as story 103 respecifies it) / _assertRetired:story-spec-griefable-precondition`
- **Root cause class**: `story-spec-griefable-precondition`
- **Story**: 103 (`incomplete`, checklist L202/L203). Cross-referenced in [spec-conformance.md](./spec-conformance.md).
- **Location**:
  - [script/helpers/UniPoolerCutoverCore.sol#L336-L349](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/script/helpers/UniPoolerCutoverCore.sol#L336-L349) (`_step2EnsurePairEmpty`, the skim that story 103 drops)
  - [#L551-L554](https://github.com/Behodler/phoenix-phase-2-staging/blob/a4f9f3c66ee133a7cacb79f4d24300bba5945966/script/helpers/UniPoolerCutoverCore.sol#L551-L554) (`_assertRetired` owner-BPT clause)

```solidity
    // _step2EnsurePairEmpty today: an unsynced donation is skimmed, so it self-heals
        if (ICutoverERC20(l.sUSDS).balanceOf(l.pair) > 0 || ICutoverERC20(l.phUSD).balanceOf(l.pair) > 0) {
            pair.skim(p.owner);
        }
    // _assertRetired: conflicts with the 2026-10-10 amendment ("must not revert on non-zero owner BPT")
        require(
            ICutoverERC20(l.bPool).balanceOf(p.oldPooler) == 0 && ICutoverERC20(l.bPool).balanceOf(p.owner) == 0,
            "UniPoolerCutoverCore: BPT remains"
        );
```

**Description**: Story 103's checklist (L202) has the rewired step 2 **drop the skim** and "only assert the pair is empty (reserves AND balances (0,0))". Without the skim, a 1-wei **unsynced** transfer to the pair fails simulation at step 2, even though `escrow.exitAndSeed` would skim exactly that donation harmlessly to `newPooler` (escrow L365-L366). The spec turns a self-healing condition into a griefable DoS. Separately, `_assertRetired` requires owner BPT == 0, while story 103 (L203, 2026-10-10 amendment) says the rewired core must **not** revert on non-zero owner BPT. If the require is not removed in the rewire, a 1-wei BPT donation to OWNER before simulation becomes a grief.

**Failure scenario**:
1. The story-103 rewire drops the step-2 skim and asserts reserves AND balances == (0,0).
2. A griefer transfers 1 wei to the pair (unsynced), or 1 wei of BPT to OWNER.
3. Simulation fails at step 2 or in `_assertRetired`. Nothing broadcasts.

**Evidence**: This is spec-level. The story-103 implementation is not in the tree at `a4f9f3c`, so there is no fork test or revert selector. The current core's skim and `_assertRetired` clause are quoted above.

**Impact**: A marginal liveness grief of the future rewired run. It is strictly weaker than the already-ledgered sync brick (`9a694ae01fe1…`). It is related to yield-claim-nft L-26 `b2a29359fde5…` (wont-fix) but is not the same defect. L-26 accepted a fail-loud **synced** donation against the escrow. This respec would make an **unsynced** donation, which the escrow self-heals today, into a grief.

**Recommendation**: In the rewire, assert reserves == (0,0) only and leave balances to the escrow's skim. Drop the owner-BPT clause from `_assertRetired`: verify should *report* residual owner BPT, not revert on it (OBLIGATIONS item 4).

---

## Centralization Risks

None this run. The owner is trusted for knowing actions (Law 3), so "a malicious owner could…" vectors are not reported.
Non-obvious owner consequences are reported above as footguns (L-01, L-03, L-05).

---

## Carryover (reconfirmed in run 40)

Following the pipeline convention, carryover is **not merged or renumbered** into this bundle. Each originating
audit's QA report is copied **in full, verbatim**, to `submissions/carryover/qa-report-<NN>.md`. Each copy has a
run-40 header naming every retained entry, its ledger status and its run-40 reconciliation. Nothing was pruned,
because every entry in both originating reports is still `open` in the ledger.

| Fingerprint | issueId | Original run / entry point | Status | Run-40 reconciliation | Full text |
|---|---|---|---|---|---|
| `9a694ae01fe1c054801295c02e0995c82599a051ffe54881c407d1b9b4ab5add` | `pps39l1` | run 39 / `dev` | `open` | **Reconfirmed** (PATTERN-001 + SLITHER-005). The core step-2 `reserves == (0,0)` gate is unchanged at `a4f9f3c` L336-L349, so 2-wei donate+sync pair poisoning still has no recovery branch. `lastSeenRun` → 40. This run's L-02 adds an honest-user trigger for the same brick, and L-01 extends the window. | [`carryover/qa-report-39.md`](./carryover/qa-report-39.md) |
| `59527bfa84786a87002d80b9bf678c5e798c4d9b2905609ac0f786bd46737632` | `pps38l1` | run 38 / `balancer-holding` | `open` | **Reconfirmed** (PATTERN-005). The 4-address holding-pattern verifier blind spot now also lives in `UniPoolerCutoverCore._step0Preconditions` (L286-L292), which checks only the caller-supplied `p.poolers`. `lastSeenRun` 38 → 40. It stays Low while story 103 is `incomplete`. | [`carryover/qa-report-38.md`](./carryover/qa-report-38.md) |

The same carryover files also hold the other still-open entries of those two reports. **These were not re-observed by
this contract scan**, which did not run the `dev` or `balancer-holding` entry points, and they are carried as-is:
- `9fa8eee3010ec38a3aa38c93bdc8141dd42eb6a2a469648865c02f5ca2f84787` (`pps39q1`)
- `c35d7cea7c0c71f66d59e5cf2b52b4ea844f1f1e1874540e5393664d8fc615a9` (`pps39q2`)
- `b469855d97e475c98d72fd0fd71f0766f3f106d9704be2b4c48b780680f65788` (`pps38q1`). **Fix observed:** the NatSpec was corrected in `a456b2a`. **Proposed** `/ledger phoenix-phase-2-staging fixed b469855d97e4`, not applied.

Older `dev` carryovers (audits 05, 21, 26-30) remain open in the ledger and remain in `reports/39/submissions/carryover/`. This contract scan neither reconfirms nor closes them.

---

## Cross-references

- [`spec-conformance.md`](./spec-conformance.md): F-01 (`pps40f1`), F-02 (`pps40f2`), the faithfulness facets of L-02, L-04 and Q-02, the **OBLIGATIONS** section (story 103 → yield-claim-nft L-27 / F-02-052; re-check L-01, L-03 and Q-01 when it lands), and the Sepolia exclusion.
- Tier-3 evidence: `reports/40/tier3/invariants.md`, `core-fork-tests.log`, `core-code001-fuzz-fresh.log`, `helper-invariants.log`.

---

## Appendix: automated QA baseline (4naly3er)

**Attached as a sibling file: [`4naly3er-report.md`](./4naly3er-report.md).** Status: **partial. 56 of 57 scope files were analysed. Sepolia was excluded by directive.**

| Step | Result |
|---|---|
| Joint run over `reports/40/static/scope-files.txt` (basePath `work/` at `a4f9f3c`, byte-identical to `src/` for all 57 files) | **FAILED, exit 1.** Every file reported `Cannot compile AST`, then the tool crashed with `TypeError … reading 'nodeType'` in `NC/uselessOverride`. |
| Per-file runs (one-line scope each, sequential) | **56/57 analysed, exit 0, 0 AST failures.** `VerifyStableStakerV2Cutover.s.sol` needed a retry: it timed out at 300 s, then completed in 420 s. |
| `script/DeployMocks.s.sol` | **GAP: NOT analysed.** solc-js `DeclarationError: Identifier already declared` (`IYieldStrategy` reached through two remappings). This is the same gap as runs 30 and 39. Silence on this file is a tool limitation, **not a clean result**. No run-40 finding is located in it. |

Category totals across the 56 per-file reports: H 5, M 21, L 172, NC 479, Gas 302 (category rows, which repeat across files).
**None rises to a finding.** The High hits are `get_dy_underlying()` flagged as a flash-loanable price. In
`UniswapHelper` that call is used only in the view quote paths, never for settlement. The real issue with that venue
is depth, reported as L-05. The Medium hits are fee-on-transfer (known-invalid; no FoT token is in play),
`block.number` on L2s (mainnet-only scripts), "library function not internal" (an interface false positive), and
unchecked `transfer` in mocks, local-anvil helpers and tests. The per-file triage is in the attached file. Nothing
was written into `src/`.
