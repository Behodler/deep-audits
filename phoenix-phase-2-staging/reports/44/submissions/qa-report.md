# QA Report: phoenix-phase-2-staging, run 44 (script audit)

- **Source:** [Behodler/phoenix-phase-2-staging](https://github.com/Behodler/phoenix-phase-2-staging) @ `669cbc11a41b1bd677ac422391532bb79199b9a6` (branch `master`)
- **Entry points:** `antimatter-pool` (Script B: `script/CutoverAntimatterPoolMainnet.s.sol` and `script/VerifyAntimatterPoolCutover.s.sol`) and `sya-harvester` (Script A: `script/DeploySyaHarvesterMainnet.s.sol`)
- **Story:** story-122, `~/code/product-owner/stories/phStaging2/auto-complete/sya-antimatter-cutover/122-sya-antimatter-mainnet-catch-up.md` (state: `auto-complete`, which is final)
- **Fork block:** 26303964

Labels are numbered per entry point, so `L-01` exists under both entry points. Every reference below is namespaced, e.g. "antimatter-pool L-01 (pps44l1)". The issue ID (`pps44…`) is the unambiguous handle.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 5 |
| QA (non-critical, operational) | 3 |
| Centralization | 0 |
| **Total** | **8** |

| Label | Issue ID | Fingerprint (12) | Title |
|---|---|---|---|
| antimatter-pool L-01 | pps44l1 | `3b115d7566b3` | The "always-run" minter revoke is skipped when a failed seed leaves a foreign AM/sUSDS pair |
| antimatter-pool L-02 | pps44l2 | `d7e81a8dfc48` | [DISCLOSED] The verifier anchors no recorded seed figure to chain state |
| antimatter-pool L-03 | pps44l3 | `01af21afa2ae` | 1 wei sent to the predictable seeder address blocks Script B or fails `:verify` |
| sya-harvester L-01 | pps44l4 | `f7cafa264ec4` | Running A before B puts AM in third-party hands before the AM/sUSDS market exists |
| sya-harvester L-02 | pps44l5 | `eed486cbeaf3` | The DOLA route sells through a near-empty DOLA/FRAXBP metapool |
| sya-harvester Q-01 | pps44q1 | `c28c5f19e81b` | [DISCLOSED] A local-pass progress file can record `claimEnabled:true` for a crashed broadcast |
| sya-harvester Q-02 | pps44q2 | `eb9785c544a5` | The reverse dry-run leg runs on a pool the forward leg has already moved |
| sya-harvester Q-03 | pps44q3 | `6f2c622285c7` | A fixed 0.3 gwei legacy price has no basefee check and no replacement path |

### Cross-references to other run-44 submissions (read before counting)

- **Mediums:** `submissions/antimatter-pool/M-01.md` (pps44m1, `3c8730ba2a83…`) and `submissions/antimatter-pool/M-02.md` (pps44m2, `cc55a47ec045…`).
  - **sya-harvester L-01 (pps44l4) is the enabling condition for M-01 and M-02.** Running A first puts AM into circulation, and that is what lets a third party pre-create or pre-price the pair. It is kept separate because its root cause and fix differ: L-01's fix is a runbook reorder, while the Mediums need on-chain precondition and resume-gate fixes. A runbook reorder does **not** fix M-01 or M-02, and an M-01 fix does not make the A-first order safe for B's availability.
  - **antimatter-pool L-02 (pps44l2) overlaps M-02's verifier leg.** M-02's PoC shows `VerifyAntimatterPoolCutover` passing on a never-seeded cutover, and M-02's mitigation section points at this finding for the verifier fix. L-02 is the standalone verifier-coverage defect. Its fix (anchor the verifier to chain state) is the same fix M-02's verifier leg calls for. **Triage should count the verifier gap once.** If M-02's verifier recommendation is adopted, L-02 closes with it, and vice versa. M-01 also cites L-02 to explain why the verifier stays silent after the theft.
  - antimatter-pool L-01 (pps44l1) is step 4 of M-02's attack narrative (the seeder is still a minter after Step 0 aborts). It is a separate defect: the revoke ordering.
- **Faithfulness:** `submissions/spec-conformance.md`. These records are not restated here.
  - antimatter-pool L-01 has a story-deviation twin: antimatter-pool F-02 (pps44f2, `7a2a50635466…`), "the revoke must always run, even on resume".
  - sya-harvester L-01 has a story-deviation twin: sya-harvester F-01 (pps44f3, `031dd8696af0…`), "A and B in either order". That story claim is itself unsafe under Law 1.
  - antimatter-pool F-01 (pps44f1) and sya-harvester F-02 (pps44f4) have no QA counterpart.
- **Bot report:** `submissions/4naly3er-report.md` (appendix). It covers the antimatter-pool closure only; see the Appendix for the sya-harvester coverage gap.

---

## Low Risk Findings

### [antimatter-pool L-01] The "always-run" minter revoke does not run when the seed failed and the AM/sUSDS pair exists: Step 0 aborts first and leaves the seeder an approved Antimatter minter <!-- id: pps44l1 -->

- **Issue ID:** pps44l1
- **Fingerprint:** `3b115d7566b3761d97fb1472df1c0e43fa22e9629624795071014a705a3f5bf1`
- **Entry point:** `antimatter-pool`
- **Severity:** Low (Law-3 footgun)
- **Root cause class:** `GuardOrderingSkipsCleanup`

**Location:**
- [CutoverAntimatterPoolMainnet.s.sol#L258-L271](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/CutoverAntimatterPoolMainnet.s.sol#L258-L271) (Step 0)
- [CutoverAntimatterPoolMainnet.s.sol#L404-L413](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/CutoverAntimatterPoolMainnet.s.sol#L404-L413) (Step 8)
- [docs/SyaAntimatterMainnetCutover.md#L92-L94](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/docs/SyaAntimatterMainnetCutover.md#L92-L94) (runbook)

```solidity
// Step 0 (L260-265)
address existing = IAmCutoverFactory(c.factory).getPair(c.antimatter, c.sUSDS);
bool seedDone;
if (existing != address(0)) {
    require(
        p.seeder != address(0) && p.seeder.code.length > 0 && IERC20(existing).balanceOf(OWNER) > 0,
        "Step 0: the AM/sUSDS pair ALREADY EXISTS and this cutover did not create it - ABORT ..."
// ...
// ---- Step 8: revoke (ALWAYS) ----   (L404-413, unreachable once Step 0 reverts)
if (am.isApprovedMinter(address(seeder))) {
    _begin();
    am.setApprovedMinter(address(seeder), false);
    _end();
}
```

**Description:** Story-122 L132 says "The revoke (step 8) must always run, even on resume", and runbook L94 says "B's minter revoke runs on every run." Suppose tx5 (the seed) reverts after tx4 (`setApprovedMinter(seeder,true)`) has landed. `--slow` then stops, and tx6 (the revoke) is never sent. On re-run, Step 0 sees the existing pair. In the AM-dear front-run, the attacker owns that pair and OWNER holds none of its LP, so the `require` reverts before Step 8 is reached. Every resume aborts at the same point, and the minter grant stays in place indefinitely.

**Impact:** Demonstrated in `test_r44_04`: after the AM-dear front-run makes tx5 revert with `AntimatterNotFullyConsumed`, the resume reverts at Step 0 and `isApprovedMinter(seeder)` stays `true`.

Exploitability is nil today. The seeder's only mint path is the `onlyOwner` `seed()` (`test_r44_01`). The harm is a stale privileged grant that the script's guard and runbook say cannot exist, so the owner must notice it and revoke it by hand. A competent owner would be surprised by this, which makes it a Law-3 footgun. `VerifyAntimatterPoolCutover` does catch the unrevoked minter (verifier L60-63), but only if the operator reaches `:verify`.

**Story disclosure:** `disclosedInStory: false`. The story states the opposite as a requirement (story-122 L132): "**Resumable:** each step has a `done` gate read from chain state. … The revoke (step 8) must always run, even on resume." The story deviation is filed separately as antimatter-pool F-02 (pps44f2) in `spec-conformance.md`.

**Evidence:**
- Test: `work/test/audit-run44/AntimatterPoolRun44.fork.t.sol::test_r44_04_frontRun_amDear_seedReverts_revokeNeverRuns_thenDustLpSpoofCompletes`, which passes.
- Logs: `reports/44/script-audits/antimatter-pool/logs/forktest-run44-antimatter.log`, and in-suite (18/18) `reports/44/pocs/logs/poc44-insuite-audit44.log`.
- Also `side-effects.json` `adversarialRuns.frontRun_amDear_postA`, and the resume-matrix row "tx4 + tx5 REVERTED with foreign pair".

**Related:** M-02 (pps44m2) step 4 relies on this state. M-02 shares the same Step-0 branch but is a different failure (false completion rather than skipped cleanup) and was not merged with this finding.

**Recommendation:** Run the revoke before any abort. If a recorded seeder `isApprovedMinter`, revoke it first (or inside the Step-0 failure branch), then abort. Also state in the runbook that a tx5 revert requires a manual `setApprovedMinter(seeder,false)`.

---

### [antimatter-pool L-02] [DISCLOSED] VerifyAntimatterPoolCutover anchors no recorded figure to chain state: `reserves > 0` and `OWNER LP > 0` are the only live seed checks, so a never-seeded, foreign-priced pair verifies <!-- id: pps44l2 -->

- **Issue ID:** pps44l2
- **Fingerprint:** `d7e81a8dfc482608ac6d9cc8130f27a04de069c14de01d17403935a588d19c4f`
- **Entry point:** `antimatter-pool`
- **Severity:** Low
- **Root cause class:** `VerifierRecordNotChainAnchored`

> **Overlap notice:** this is the same verifier gap as **M-02's verifier leg** (pps44m2, `cc55a47ec045…`; see M-02 §Recommended Mitigation, "Verifier"). Count it once in triage. The finding is kept separate because it stands without M-02's resume-gate root cause, and M-01 (pps44m1) also relies on it.

**Location:** [VerifyAntimatterPoolCutover.s.sol#L54-L85](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/VerifyAntimatterPoolCutover.s.sol#L54-L85)

```solidity
// live checks (L64-67)
(uint112 r0, uint112 r1,) = IAmCutoverPair(pairAddr).getReserves();
require(r0 > 0 && r1 > 0, "verify: AM/sUSDS reserves are zero");
uint256 ownerLp = IERC20(pairAddr).balanceOf(OWNER);
require(ownerLp > 0, "verify: OWNER holds no AM/sUSDS LP");
// record checks (L72-76): compared only against each other, never against chain state
require(p.phusdSupplyBefore - p.phusdSupplyAfter == p.amMinted, "verify: record: phUSD burned != AM minted");
require(p.amSupplyAfter - p.amSupplyBefore == p.amMinted, "verify: record: AM supply rise != AM minted");
require(p.amReserve == p.amMinted, "verify: record: pair AM reserve at seed != AM minted");
// L81-82: current pair AM reserve and OWNER LP are only console.log'd ("drift")
```

**Description:** Story-122 L133-140 lists the end-state checks: phUSD burned equals AM minted, the pair's AM reserve equals AM minted, UniPoolerV2 holds its prior LP minus the slice, and OWNER holds the LP. These reach the verifier only as checks on the progress record's internal consistency. The live checks never compare the pair's AM reserve or OWNER's LP share with the record, and they never check the price.

**Impact:** Demonstrated on the M-02 dust-LP spoof (never seeded); reasoned, not executed, for the M-01 drained pool (OWNER LP > 0 and reserves > 0 trivially hold). It cannot detect a pair someone else created, wrong reserves, or a missing seed. It does catch an unrevoked minter (verifier L60-63).

This is a detection gap, not a loss path. Its consequence is that M-01 and M-02 stay invisible to the post-broadcast check.

**Story disclosure:** `disclosedInStory: true`. The story-122 Auto-Completed `[low]` note (L371) reads: "Script B's verifier cross-checks recorded seed figures but not against chain receipts, and only logs the UniPoolerV2 LP decrement rather than asserting it." The reviewer note at L330(b) says the same. Disclosure is not suppression: the story records the gap but does not fix it, and it does not note that the gap certifies a foreign pair.

**Evidence:**
- Test: `work/test/audit-run44/AntimatterPoolRun44.fork.t.sol::test_r44_04_frontRun_amDear_seedReverts_revokeNeverRuns_thenDustLpSpoofCompletes` (verify passes on never-seeded state).
- Logs: `reports/44/script-audits/antimatter-pool/logs/forktest-run44-antimatter.log` and `pocs/logs/poc44-insuite-audit44.log`.
- M-02's PoC (`test_PoC_M02_dustLpSpoofsCompletedCutover`, log `pocs/logs/poc44-test_PoC_M02_dustLpSpoofsCompletedCutover.log`) runs the production verifier against the patched book and records `VerifyAntimatterPoolCutover PASSED on a never-seeded cutover`.

**Related:** pps balancer-holding L-01 (`59527bfa8478…`, open) is in the same verifier-coverage family. It covers a different verifier and is not a duplicate.

**Recommendation:** Assert at least the following:
- OWNER's AM/sUSDS LP / totalSupply ≥ 99%. Drift comes only from later third-party adds, which the verifier can bound.
- AM supply ≥ the recorded `amMinted`.
- The pair's AM reserve is consistent with the recorded `amMinted`.
- The pair price falls within a sanity band of the phUSD/sUSDS price.

Alternatively, read the seed tx receipt's `Seeded` event from `broadcast/run-latest.json`.

---

### [antimatter-pool L-03] 1 wei of any of five tokens sent to the nonce-predictable seeder address blocks Script B at Step 9 (pre-deploy), or fails `:verify` permanently (post-deploy), because `_requireSeederEmpty` demands zero balances while the seeder itself tolerates pre-existing ones <!-- id: pps44l3 -->

- **Issue ID:** pps44l3
- **Fingerprint:** `01af21afa2ae0515ac4b9b6e0dd4b1beaa5f070904e784d914b1debb4b1ef064`
- **Entry point:** `antimatter-pool`
- **Severity:** Low
- **Root cause class:** `GriefableAbsoluteBalanceCheck`

**Location:**
- [CutoverAntimatterPoolMainnet.s.sol#L156-L163](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/CutoverAntimatterPoolMainnet.s.sol#L156-L163) (`_requireSeederEmpty`)
- Called at [Step 9, L426](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/CutoverAntimatterPoolMainnet.s.sol#L426) and by the [verifier at L59](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/VerifyAntimatterPoolCutover.s.sol#L59)
- Contrast with [AntimatterPoolSeeder.sol#L272-L278](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/src/periphery/AntimatterPoolSeeder.sol#L272-L278)

```solidity
// script: absolute zero (L156-163)
function _requireSeederEmpty(AntimatterPoolSeeder s, Config memory c, address amPair) internal view {
    address a = address(s);
    require(IERC20(c.phUSD).balanceOf(a) == 0, "end state: seeder holds phUSD");
    require(IERC20(c.antimatter).balanceOf(a) == 0, "end state: seeder holds Antimatter");
    require(IERC20(c.sUSDS).balanceOf(a) == 0, "end state: seeder holds sUSDS");
    require(IERC20(c.phusdSusdsPair).balanceOf(a) == 0, "end state: seeder holds phUSD/sUSDS LP");
    if (amPair != address(0)) require(IERC20(amPair).balanceOf(a) == 0, "end state: seeder holds AM/sUSDS LP");
}

// seeder: before/after delta (L272-274)
/// @dev `seed` must leave nothing behind: every balance ends where it started (zero, unless
///      something was sent here out of band, which `rescueERC20` recovers).
function _requireUnchanged(uint256[5] memory before, uint256[5] memory afterwards) internal view {
```

**Description:** The seeder's own `_requireUnchanged` compares before and after balances, so it tolerates tokens sent out of band; NatSpec L272-273 says "…which `rescueERC20` recovers". The script and verifier instead require absolute zero balances of phUSD, AM, sUSDS, phUSD/sUSDS LP and AM/sUSDS LP. The seeder address is `CREATE(OWNER, nonce)`, which anyone can compute: `0xdb70…09BE` at nonce 1791.

**Impact:**
- **Pre-deploy (`test_r44_09`):** 1 wei of sUSDS sent to `0xdb70…` before the run makes the preview/local pass revert with `end state: seeder holds sUSDS`. Nothing is broadcast, so this fails loud and safe, but B cannot run until the owner burns a nonce.
- **Post-deploy (`test_r44_10`):** 1 wei sent after a completed run makes `:verify` revert until OWNER calls `seeder.rescueERC20` ([L204](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/src/periphery/AntimatterPoolSeeder.sol#L204)). Neither the script nor the runbook mentions that remedy.

The griefer's cost is negligible, and funds are never at risk.

**Story disclosure:** `disclosedInStory: false`. The story requires the end-state check "The seeder holds nothing." (story-122 L138). It does not consider out-of-band dust or the predictable address.

**Evidence:**
- Tests: `work/test/audit-run44/AntimatterPoolRun44.fork.t.sol::test_r44_09_dustToPredictedSeeder_bricksPreviewAtStep9` and `::test_r44_10_dustAfterRun_failsVerifier`.
- Isolated `test_r44_10` log: `reports/44/script-audits/antimatter-pool/logs/forktest-run44-t10.log`.
- `test_r44_10` failed in the earlier full-suite run (`forktest-run44-antimatter.log`, `forktest-run44-t10-t04.log`, both `SUsds/insufficient-balance`). That was a test-harness bug, now fixed: a `vm.prank` was consumed by an argument expression. It did not refute the finding. The current in-suite run passes 18/18 (21/21 with the M-01/M-02 PoC suite): `reports/44/pocs/logs/poc44-insuite-audit44.log`.
- The record's `evidenceNote` describing the in-suite failure is stale.
- Also `side-effects.json` `adversarialRuns.dustToSeeder`.

**Related (not duplicates):**
- pps unipooler-cutover L-03 (`4f454372eed2…`, open): the same class of dust trip on an absolute-state precondition.
- sya-harvester project L-01 (`d7744b9d2400…`, open): the same dust-donation theme in `SYAHarvester._sellYield`.

**Recommendation:** Compare seeder balances to their pre-seed values (as the contract does), or treat dust below a threshold as a warning. Document `seeder.rescueERC20` as the remedy in the runbook.

---

### [sya-harvester L-01] Script A opens StableStakerV2.claim before Script B creates the AM/sUSDS market, putting ~205 AM in third-party hands that can pre-create or pre-price the pair and trip Script B's R1 abort, blocking B until a seed-into-existing-pair path is added; the runbook calls A and B order-independent <!-- id: pps44l4 -->

- **Issue ID:** pps44l4
- **Fingerprint:** `f7cafa264ec4c31f670e1819486aaa8dc734a5fa40987989ba658b93fc9ebf9a`
- **Entry point:** `sya-harvester`
- **Severity:** Low (Law-3 footgun)
- **Root cause class:** `ClusterOrderingHazard`

> **Enabling condition for antimatter-pool M-01 (pps44m1) and M-02 (pps44m2).** This finding's own impact is availability-only. The theft is in M-01, and the false-green cutover is in M-02. Both have independent root causes and fixes, so neither collapses into this one.

**Location:**
- [DeploySyaHarvesterMainnet.s.sol#L459-L470](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/DeploySyaHarvesterMainnet.s.sol#L459-L470) (Step 6)
- [docs/SyaAntimatterMainnetCutover.md#L15-L16](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/docs/SyaAntimatterMainnetCutover.md#L15-L16) (runbook §Order)
- B's guard: [CutoverAntimatterPoolMainnet.s.sol#L262-L268](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/CutoverAntimatterPoolMainnet.s.sol#L262-L268)

```solidity
// ---- Step 6: claim enable ----  (DeploySyaHarvesterMainnet.s.sol L459-470)
IStableStakerV2ClaimGate v2 = IStableStakerV2ClaimGate(c.stableStakerV2);
if (v2.claimEnabled()) {
    console.log("  claimEnabled already true - skipped");
} else {
    _begin();
    v2.setClaimEnabled(true);
    _end();
```
```markdown
1. **A and B, in either order.** They touch disjoint state (A: a new harvester + one StableStakerV2 flag; B:
   UniPoolerV2's LP, Antimatter's minter list, a new pair).
```

**Description:** The runbook (L15-16) and story-122 (L16) say A and B may run in either order because they touch disjoint state. Storage is indeed disjoint. But A's last tx sets `StableStakerV2.claimEnabled`, and from then on `claim()` mints raw Antimatter. At block 26303964, `Antimatter.totalSupply() == 0`, and 32 staker/pool positions hold 205.42 AM of `pendingReward`.

Once AM is in circulation, any holder has both the motive (listing AM) and the means (AM plus sUSDS) to create and seed a UniswapV2 AM/sUSDS pair at a price of their choosing. Script B's Step-0 guard aborts if the pair exists. B therefore cannot run until a new story adds a seed-into-existing-pair path, and that path carries the price-manipulation risk that Step 0 exists to avoid.

**Impact:** Script B is blocked, which is fail-safe with no loss of funds. The protocol-owned AM/sUSDS liquidity cutover is delayed, and so is Script C, which requires B. Alternatively, the cutover must be redesigned around a pair whose initial price a third party set. Griefing via R1 (`createPair` needs no AM) already exists; running A first widens it from deliberate griefers to ordinary AM holders. Combined with the B-side root causes, the same ordering enables M-01 (theft of seeded AM) and M-02 (spoofed completion).

**Story disclosure:** `disclosedInStory: false`. Story-122 L16 asserts the unsafe order: "Run order for the human: A and B in either order, then C." It repeats this in the L192 checklist: "order (A, B in either order, then C)". The unsafe story claim is filed as sya-harvester F-01 (pps44f3) in `spec-conformance.md`.

**Evidence:**
- Anvil run after A (`side-effects.json` `orderingRuns.AthenClaimThenPairThenB`): `0xd57e..7c66` `claim(DOLA)` minted 25.4768 AM (supply 0 → 25.48), and `createPair(AM,sUSDS)` succeeded.
- Script B's preview then exited 1 with "Step 0: the AM/sUSDS pair ALREADY EXISTS and this cutover did not create it - ABORT (griefing risk R1, story 113)". See `reports/44/script-audits/sya-harvester/logs/scriptB-preview-after-claim-and-pair.log` L154/L166.
- Both orders succeed when nobody else acts (`scriptB-broadcast-afterA-anvil.log`, `scriptB-broadcast-first-anvil.log`).

**Recommendation:** Change the runbook order to B (through a private RPC, as already recommended) BEFORE A. Alternatively, send B's seed and A's `setClaimEnabled` in the same private bundle. If A must go first, accept that B may need a seed-into-existing-pair fallback and plan it before broadcasting A. Update story-122 L16 and runbook §Order to drop the "disjoint state" rationale.

---

### [sya-harvester L-02] DOLA route sells through a near-empty DOLA/FRAXBP metapool (~4,982 DOLA; base pool holds only ~184.9k USDC); 100k DOLA returns 8,998.58 USDC, and the 1,000-unit dry run cannot see this <!-- id: pps44l5 -->

- **Issue ID:** pps44l5
- **Fingerprint:** `eed486cbeaf36e6dea35297dc88e20280296d3ce987e303c6ba70d4995590b27`
- **Entry point:** `sya-harvester`
- **Severity:** Low
- **Root cause class:** `ThinLiquidityRouteConfig`

**Location:**
- [DeploySyaHarvesterMainnet.s.sol#L161-L167](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/DeploySyaHarvesterMainnet.s.sol#L161-L167) (`dolaRoute`)
- Pool constant at [L96](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/DeploySyaHarvesterMainnet.s.sol#L96)

```solidity
address public constant POOL_DOLA_FRAXBP = 0xE57180685E3348589E9521aa53Af0BCD497E884d;   // L96

/// @notice DOLA -> USDC through the DOLA/FRAXBP metapool, exchange_underlying 0 -> 2.
function dolaRoute(Config memory c) public pure returns (Route memory r) {
    r.token = c.dola;
    r.path[0] = c.dola;
    r.path[1] = POOL_DOLA_FRAXBP;
    r.path[2] = c.usdc;
    r.swapParams[0] = [uint256(0), 2, 2, 1, 3];
}
```

**Description:** The DOLA payload uses `exchange_underlying` on `0xE571..884d`. It is specified verbatim in story-122 L95 and copied from `lib/sya-harvester/test/fork/MainnetRoutes.sol`, which was discovered at block 26,261,000.

At block 26303964 the pool holds 4,982.26 DOLA and 8,919.26 FRAXBP LP. FRAXBP (`0xDcEF..41A2`) holds 1,799,188 FRAX against only 184,870 USDC. The script's floor (97% of par at `DRY_RUN_UNITS` = 1,000) passes at 994.04 USDC, but the route can absorb only about 5k DOLA.

SYAHarvester sells with `minOut` 0 on every hop and enforces only a single aggregate `minEthOut`. A pool this thin can be moved very cheaply around a harvest.

**Impact:** No protocol funds are lost: PhlimboV3 receives a fixed USDC claim, and the harvester caller bears slippage and MEV. However, once DOLA yield per harvest grows past a few thousand dollars, harvests that include the DOLA strategy become unprofitable or revert with `Unprofitable`. The SYA→PhlimboV3 USDC flow then stalls, unless callers exclude the DOLA strategy, which leaves the DOLA yield unharvested. The story-052 checks and the dry run validate correctness but not depth, so this risk is invisible to the script's own guards.

**Story disclosure:** `disclosedInStory: false`. The pool is the story's own choice (story-122 L95): "DOLA→USDC: `path=[DOLA, 0xE57180685E3348589E9521aa53Af0BCD497E884d, USDC, 0…]`, `swapParams[0]=[0,2,2,1,3]` (exchange_underlying), pools all zero." The code matches the story, so this is not a faithfulness deviation. The story does not discuss the venue's depth.

**Referenced, not refiled:** sya-harvester project Q-04 (`dd56134239f856d7fb56b6a4ec790899b596d91b4d46b6ff6dcab75c0cfca354`, open) covers SYAHarvester's per-hop `minOut` of 0 and its single aggregate `minEthOut`. That contract-level root cause belongs to the sya-harvester ledger and is not re-filed here. This finding covers only the deployment script's choice of a thin venue, a distinct root cause. The thin pool amplifies Q-04. Also related, not a duplicate: pps L-05 (`b7ff538a654c…`, open), a near-empty hardcoded DOLA venue (DOLA-3CRV) in UniswapHelper, which is a different contract and venue.

**Evidence:**
- Test: `work/test/audit-run44/SyaHarvesterRun44.fork.t.sol::test_run44_bidirectional_sizes`. This test asserts the 97% floor at each size and is expected to fail at the 100k leg; that failure is the evidence.
- Log: `reports/44/script-audits/sya-harvester/logs/forktest-run44.log` shows `[FAIL: fwd >= 97% par: 8998581324 < 97000000000]`.
- `side-effects.json` `routeDepth`: DOLA→USDC 10 → 9.950744, 1,000 → 994.039768, 100,000 → 8,998.581324. The USDe route returns 100,000 → 99,464.83, which is healthy.
- The record's `poc.status` says "passing" and `poc.log` is null. Both are inaccurate; the log above is the correct reference.

**Recommendation:**
- Survey deeper DOLA venues on a fork (e.g. Curve NG DOLA/crvUSD, DOLA/sUSDS, DOLA/USDC pools), and pick the route that maximises output at the expected per-harvest DOLA size.
- Add a dry-run leg at that upper-bound size (or a reserve-depth floor) to the script's preflight.
- Document a monitoring threshold for re-pointing via `setRoute`.
- Story-122 should record why this pool was chosen. Under Law 2 the story text specified it, so amend the story rather than silently diverging from it.

---

## QA (Non-Critical, Operational) Findings

### [sya-harvester Q-01] [DISCLOSED] Progress file written in forge's local pass can record `claimEnabled:true` / `completed` for a broadcast that crashed, and ClaimUnblockState trusts it <!-- id: pps44q1 -->

- **Issue ID:** pps44q1
- **Fingerprint:** `c28c5f19e81baa2b4444f1d6edb3f0a575c607fa57b42cf66b5b228b13a049a5`
- **Entry point:** `sya-harvester`
- **Severity:** QA (downgraded from proposed Low)
- **Root cause class:** `LocalPassProgressWrite`

**Location:** [script/helpers/ClaimUnblockState.sol#L37-L46](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/helpers/ClaimUnblockState.sol#L37-L46)

```solidity
function progressRecordsClaimEnabled(string memory progressPath) internal view returns (bool) {
    string memory json;
    try vm.readFile(progressPath) returns (string memory j) {
        json = j;
    } catch {
        return false;
    }
    if (bytes(json).length == 0 || !vm.keyExistsJson(json, ".claimEnabled")) return false;
    return vm.parseJsonBool(json, ".claimEnabled");
}
```

**Description:** Confirmed on anvil: `progress.sya-harvester.1.json` was written ("Progress file written", `anvil-broadcast.log` L116 and L133) before "ONCHAIN EXECUTION COMPLETE" (L140). If the broadcast crashes, the file can still say `completed` / `claimEnabled:true`, and `progressRecordsClaimEnabled` accepts that record. The truth table is otherwise correct. No further logic error was found in `ClaimUnblockState`, `_doneClaimStillDisabled`, or the verifier's Phase 7 branch.

**Impact:** This matters only when `claimEnabled` is already true on chain. story-122 L371 cites three mitigations (chain-state resume gates, the no-code abort, zero-exit-only patchers); only the first two are chain-anchored, and the patcher control does not hold in the antimatter-pool sibling (M-02, pps44m2). The same local-pass record factor does real damage in the antimatter-pool sibling, where it is filed under M-02 (pps44m2).

**Story disclosure:** `disclosedInStory: true`. The story-122 Auto-Completed `[low]` note (L371) reads: "Scripts A and B write progress files during forge's local simulation pass, so a crashed broadcast can leave completed/seeded records with simulated values. Mitigated by chain-state resume gates, no-code abort and zero-exit-only patchers. Remaining weak points: ClaimUnblockState may treat a simulated claimEnabled record as on record (only matters when true on chain); …" Reviewer note L329(a) says the same. Disclosure is not suppression.

**Evidence:** `reports/44/script-audits/sya-harvester/logs/anvil-broadcast.log` (ordering), and `cluster-analysis.json` rank 1.

**Related (not duplicates):** this is a recurring family.
- pps dev L-01 (`1e8cc0dc58ba…`, open): DeployMocks local-pass progress.
- pps promotion-ready:broadcast L-03 (`ea648ec5eab0…`, open): a status flag written before the event it attests.

**Recommendation:** Write the final progress record from a post-broadcast step that reads receipts. For example, extend the patcher to confirm that `run-latest.json` holds receipts with status 1 for all 5 txs before it FILLs. Alternatively, have ClaimUnblockState also require code at the recorded harvester.

---

### [sya-harvester Q-02] Reverse dry-run leg is measured on a pool already moved by the forward leg in the same snapshot, so its balance-delta floor is not an independent check of current pool state <!-- id: pps44q2 -->

- **Issue ID:** pps44q2
- **Fingerprint:** `eb9785c544a5041689f52c9a8a6847f9360f02bacc49c7dac0bce878af0d25ef`
- **Entry point:** `sya-harvester`
- **Severity:** QA
- **Root cause class:** `WeakDryRunIsolation`

**Location:** [DeploySyaHarvesterMainnet.s.sol#L510-L539](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/script/DeploySyaHarvesterMainnet.s.sol#L510-L539)

```solidity
uint256 snap = vm.snapshotState();                                          // L514
// Forward: tokenIn -> USDC
usdcOut = _exchange(r, tokenIn, c.usdc, amountIn, fwd, intermediate);       // L520
// Reverse: USDC -> tokenIn   (same snapshot, pool already moved by the forward leg)
Route memory rev = reverseRoute(r, c.usdc);
tokenBack = _exchange(rev, c.usdc, tokenIn, DRY_RUN_UNITS * 1e6, bwd, intermediate); // L531
// ...
vm.revertToState(snap);                                                     // L538
```

**Description:** `_dryRunBothWays` takes a single `vm.snapshotState()`. It runs tokenIn→USDC, then USDC→tokenIn on the reversed route against the post-forward pool, and only then reverts. On the DOLA route, the forward 1,000 DOLA is about 20% of the metapool's DOLA balance, so the forward leg's imbalance subsidises the reverse leg.

The script logged 1005.003 DOLA (`preview.log` L114). The same reverse swap from the untouched pool gives 1002.515 DOLA. The check still proves the pool indices, which was the human's actual concern (story-122 L19, L202). But the reverse 97% floor measures a round trip, not the live reverse route.

**Impact:** No wrong payload can pass because of this: a wrong-index or gapped reverse route would still fail. The reverse output recorded in story-122's preview evidence overstates the live reverse quote by about 0.25% on DOLA.

**Story disclosure:** `disclosedInStory: false`. The story specifies a sequential bracket (L109-111): "Fork dry run in both directions, inside a `vm.snapshotState()` … `vm.revertToState()` bracket … Then swap back `USDC→tokenIn` on the reversed route". It does not say whether each leg should see fresh state.

**Evidence:** `work/test/audit-run44/SyaHarvesterRun44.fork.t.sol::test_run44_reverseIndependent_1000` passes (`reports/44/script-audits/sya-harvester/logs/forktest-run44-c.log`). USDC→DOLA from fresh state gives `1002514964587012398095`, against the script's `1005003257603299609885`. The same thin DOLA pool behind sya-harvester L-02 (pps44l5) causes the subsidy, but this is a different defect and was not merged.

**Recommendation:** Revert to the snapshot (or take a fresh one) between the forward and reverse legs, so each direction is measured against the live pool state the broadcast will meet.

---

### [sya-harvester Q-03] Fixed 0.3 gwei legacy price with no basefee check: a stalled mid-sequence tx makes the runbook's "Re-run `:broadcast`" re-sign the same pending nonce at the same price <!-- id: pps44q3 -->

- **Issue ID:** pps44q3
- **Fingerprint:** `6f2c622285c7016f58d518c54194baef58fac111275f616aabb62e2283cb7812`
- **Entry point:** `sya-harvester`
- **Severity:** QA
- **Root cause class:** `OperationalGasPriceNoReplacementPath`

**Location:**
- [package.json#L94](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/package.json#L94) (`sya-harvester:broadcast`)
- [docs/SyaAntimatterMainnetCutover.md#L92-L94](https://github.com/Behodler/phoenix-phase-2-staging/blob/669cbc11a41b1bd677ac422391532bb79199b9a6/docs/SyaAntimatterMainnetCutover.md#L92-L94) (runbook)

```
"sya-harvester:broadcast": "... export SYA_HARVESTER_GAS_PRICE_WEI=${SYA_HARVESTER_GAS_PRICE_WEI:-300000000} && forge script ... --broadcast --skip-simulation --slow --ledger ... --legacy --with-gas-price $SYA_HARVESTER_GAS_PRICE_WEI --gas-estimate-multiplier 200 -vvv && node scripts/patch-mainnet-addresses-sya-harvester.js && npm run sya-harvester:verify && ..."
```
```markdown
- **Every script is resumable.** Re-run `:broadcast`; each step is gated on chain state and only the missing ones
  are sent.
```

**Description:** The broadcast key fixes `--legacy --with-gas-price ${SYA_HARVESTER_GAS_PRICE_WEI:-300000000}`. At the fork block, basefee is 0.1486 gwei (148,620,393 wei, so 2.0x headroom), and nothing checks basefee before signing 5 sequential Ledger transactions with `--slow`.

If basefee rises above 0.3 gwei mid-sequence, the pending tx stalls, forge exits non-zero, and neither the patcher nor `:verify` runs. The runbook (L92) says to re-run `:broadcast`. That repeats the default price and re-signs the stuck nonce, which nodes reject as replacement-underpriced until the operator raises the env var by at least 10%. The progress file already says `completed` / `claimEnabled:true` from the local pass (disclosed; see sya-harvester Q-01).

**Impact:** Operational only: delay and operator confusion. Funds are not at risk, and the resume gates prevent double configuration. The budget is ample: A uses 0.000982 ETH of 0.007282, and A+B uses 0.002383. A completes at legacy prices up to 1.479 gwei, and A then B up to 0.655 gwei.

**Story disclosure:** `disclosedInStory: false`. Story-122 L73 prescribes the pinned-price template (`export <X>_GAS_PRICE_WEI=${<X>_GAS_PRICE_WEI:-300000000} && forge script ... --legacy --with-gas-price $<X>_GAS_PRICE_WEI ...`). It does not discuss stuck-transaction replacement.

**Evidence:** `side-effects.json` `gas` block (anvil receipts at block 26303964, `basefeeAtFork_wei: 148620393`). The stuck-tx path is reasoned, not demonstrated on a fork, because anvil auto-mines. `test_run44_harvest_realGasPrice` passes at 0.3 gwei (`forktest-run44.log`).

**Related (not duplicates):**
- pps unipooler-cutover L-02 (`01d60c7d1d494d0112fd31a66dd91b3bd746ca68cd55b45476cf0591d82ddde7`, **open**) covers the adjacent public-mempool broadcast theme in a different script. Its root cause differs: mempool exposure, not a missing replacement path.
- pps stable-staker-v2-cutover L-07 (`d6896c6e843d…`, fixed) uses the same pinned 0.3 gwei convention with a different root cause (ETH budget preflight). This is not a regression of L-07.

**Recommendation:** In the runbook, check basefee before broadcasting and set `SYA_HARVESTER_GAS_PRICE_WEI` to at least 2× basefee. On a stalled tx, re-run with a price at least 10% higher so it replaces the same nonce. Alternatively, add a preflight `require(block.basefee < gasPrice)` in broadcast mode (`vm.envUint` read).

---

## Centralization Risks

None this run. Owner-only paths in scope (`AntimatterPoolSeeder.seed`/`rescueERC20`, `Antimatter.setApprovedMinter`, `StableStakerV2.setClaimEnabled`) are exercised by the owner's own scripts. Under Law 3 they are not filed as "malicious owner" vectors. The owner-side footguns are filed above as antimatter-pool L-01 and sya-harvester L-01.

---

## Appendix: Automated report (4naly3er)

The full output is in `reports/44/submissions/4naly3er-report.md`. It is unreviewed bot output, and none of its entries are pipeline findings.

- **Coverage:** the antimatter-pool closure (`CutoverAntimatterPoolMainnet.s.sol`, `VerifyAntimatterPoolCutover.s.sol`, `src/periphery/AntimatterPoolSeeder.sol`) compiled cleanly, with 0 AST failures.
- **Totals:** 1 Medium-template (M-1, centralization boilerplate), 12 Low, 23 NC and 13 Gas categories.
- **Gap:** the sya-harvester closure (`DeploySyaHarvesterMainnet.s.sol`, `VerifySyaHarvester.s.sol`, `script/helpers/ClaimUnblockState.sol`) did **not** compile under 4naly3er's solc-js. The error is 9553, a duplicate `IStableYieldAccumulator` resolved through two remapping paths, at DeploySyaHarvesterMainnet.s.sol:426. forge resolves this with context remappings. The bot baseline for that entry point is absent, and only the manual findings above cover it.
