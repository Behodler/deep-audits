# QA Report: phoenix-phase-2-staging, script audit of `stable-staker-v2-cutover` (run 31)

- **Repository**: https://github.com/Behodler/phoenix-phase-2-staging
- **Commit**: `1c1608c0e56a55cbeb436926d139fa89ff7a3144` (branch `master`)
- **Entry point**: `stable-staker-v2-cutover` (`package.json` script), story-082
  (`~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md`;
  state folder `auto-complete`, meaning a machine approved it and no human has reviewed it)
- **Fork harness**: `phoenix-phase-2-staging/work/test/audit-run31/CutoverAuditRun31.t.sol`, a mainnet fork at block 25975869
  that inherits the unmodified script. Its logs are under
  `phoenix-phase-2-staging/reports/31/script-audits/stable-staker-v2-cutover/fork-logs/`.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| QA (unverified) | 1 |
| Centralization | 0 |
| **Total** | **4** |

This run produced no centralization findings.

| Label | Issue ID | Title (short) | Verified | Pre-broadcast blocker |
|---|---|---|---|---|
| L-01 | `pps31l1` | Fixed 2-wei slack is below autoDOLA rounding, so a 9-wei dust stake stalls the cutover | fork-verified | yes |
| L-02 | `pps31l2` | Post-broadcast `:preview` re-runs missing steps instead of asserting them | fork-verified | no |
| L-03 | `pps31l3` | V2 and Antimatter pause authority handed to a Pauser whose `pause()` loop is already bricked | fork-verified | yes |
| Q-01 | `pps31q1` | DeployMocks rehearsal omits the Antimatter phUSD mint grant | **unverified (needs-poc)** | no |

### Faithfulness findings (not duplicated here)

The Law-2 story deviations for this entry point have their full write-ups in
[`spec-conformance.md`](./spec-conformance.md). They are not repeated here:

- **F-01** (`pps31f1`), fingerprint `dfed4279095251f3acd34987e79e3a1eecfce16adaca31cc6c776e8f724e713a`. The "067 floor" post-condition compares two identically booked numbers, so it can never fail.
- **F-02** (`pps31f2`), fingerprint `436848b0e31bb43b9e54b2d494f808528d190faa1fb6d93cff9462c1148497e9`. Stakers absorb the cutover loss (USDe 34.8 bps), while protocol-held value several times larger stays with the protocol.
- **F-03** (`pps31f3`), fingerprint `103002cc29903e4e5aada96eae77148b740846e289e2218d5d3f613404a20db0`. The script adds a phUSD mint grant to Antimatter that is not in story 082's Phase 5 list. Q-01 below concerns the same grant from the opposite side: the rehearsal *omits* it.

L-01 and L-02 also contradict story-082 text, so `spec-conformance.md` cross-lists them. This file is their primary report.

---

## Low Risk Findings

### [L-01] A 9-wei V1 DOLA stake makes the cutover's per-user loss post-condition revert: the fixed 2-wei slack is smaller than autoDOLA's round-trip rounding, so dust can stall the cutover the story says it cannot <!-- id: pps31l1 -->

**Fingerprint**: `e0d4df1ddb699c8f34e034209cf8a6311bffa3bfd79429662637976f527dd054`

**Entry Point**: `stable-staker-v2-cutover`

**Location**:
- [script/helpers/StableStakerCutoverCore.sol#L452-L455](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/helpers/StableStakerCutoverCore.sol#L452-L455) (`_assertPoolPostMigration`)
- [script/CutoverStableStakerV2Mainnet.s.sol#L109](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L109) (`WEI_SLACK`) and [#L117](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L117) (`ERC4626_MAX_LOSS_BPS`)

**Description**: Story 082 AC5 asks for "invariants that ensure dust cannot grief (revert/stall) the cutover". The dust predicate `_depositWouldFail` only checks whether the V2 deposit would **revert**. The per-user post-condition then allows a flat 2-wei slack on top of the bps bound. The bps term is `pre * 2 / 10_000`, which is 0 for any position under 5,000 wei.

A small position is rounded down three times:
1. its V1 `stake` credit (`convertToAssets(previewDeposit)`),
2. the exit credit (`amt*R/P`),
3. the V2 re-deposit credit (`convertToAssets(shares)`).

On autoDOLA one share is worth about 1.19 DOLA-wei (totalAssets 55113967399722755135519 / totalSupply 46317440394398677974688), and that round trip loses 3 wei. The planner marks the position MIGRATABLE because the deposit does not revert, and the post-condition then reverts. V1 stays Active and unpaused until the run's own Phase 1, so anyone can plant such a position at any time for 9 wei of DOLA plus gas.

**Impact**: The whole cutover reverts on the first pool with `cutover-post: cutover lost more principal than the strategy can explain`. This applies to both `:preview` and the broadcast's local pass. It keeps reverting on every re-run while the planted position exists. The owner cannot remove another user's V1 position: withdraw, claim, emergencyWithdraw and userMigrate are self-only, and migrating the position is exactly what trips the check. The only way forward is to change code or a constant. No funds are at risk, because the revert fires in forge's local pass before any transaction is sent. The harm is a permissionless, near-free stall of a mainnet operation that the story explicitly says cannot happen. Dust can also arise without an attacker: 63 of 400 DOLA stake sizes between 1 and 400 wei exceed the bound, and live USDC dust users already sit exactly on the 2-wei boundary.

**Attack path**:
1. Before the owner broadcasts, any address calls `StableStakerV1.stake(DOLA, 9)`.
2. V1 books 8 wei. `_depositWouldFail` returns false, so the planner marks the position MIGRATABLE instead of STRAGGLER.
3. The owner runs `:preview` (or the broadcast's local pass). After batch migration, the 8 -> 5 wei round trip on autoDOLA loses 3 wei.
4. `_assertPoolPostMigration` requires `loss <= 8*2/10000 + WEI_SLACK(2) = 2` and reverts.
5. Every retry reverts the same way while the position exists.

**Evidence**:

```solidity
// script/helpers/StableStakerCutoverCore.sol:452-455
require(
    pre - post <= pre * maxLossBps / CUTOVER_MAX_BPS + weiSlack,
    "cutover-post: cutover lost more principal than the strategy can explain"
);

// script/CutoverStableStakerV2Mainnet.s.sol:109, :117
uint256 public constant WEI_SLACK = 2;
uint256 public constant ERC4626_MAX_LOSS_BPS = 2;
```

- `test_F_dustLossVsWeiSlack` (`fork-logs/h-F.log`) tries every stake input from 1 to 400 wei:
  `DUSTSEARCH|DOLA|worstStakeInput=9|worstLossWei=3|countAboveBound=63`. autoUSDC gives `worstLossWei=2|countAboveBound=0`.
- `test_G_plantedDolaDustStallsCutover` (`fork-logs/h-G.log`): a griefer calls `V1.stake(DOLA, 9)`, the log shows `planted V1 DOLA principal (wei) 8`, and a full `run()` in `PREVIEW_MODE` ends with
  `PLANTED_DUST|cutover REVERTED| cutover-post: cutover lost more principal than the strategy can explain`.
- At current mainnet state, USDC dust users holding 12/22/30/66/86/90 wei each lose exactly 2 wei, which is the slack boundary (`fork-logs/h-A-users-events.log`).

**Recommended Mitigation**: Derive the absolute slack from the destination vault instead of a constant, e.g. `weiSlack = 2 + ceil(vault.convertToAssets(1)) + 1` to cover share-price rounding on both floors. Alternatively, add the planner's own predicted loss for that user (`amount - convertToAssets(previewDeposit(amount*R/P))`) to the bound. Another option is to treat positions whose predicted round-trip loss exceeds the bound as allow-listed stragglers under the existing 1-cent cap. Add a regression test to `test/StableStakerCutoverDust.t.sol` that plants a 9-wei DOLA-shaped position on a vault whose share price is above 1.

---

### [L-02] The post-broadcast `:preview` 'verification' re-executes any outstanding step under prank instead of asserting it is already done, so a partial or diverged mainnet cutover verifies green <!-- id: pps31l2 -->

**Fingerprint**: `2c82d65e65e163c9f986c669aaf0b56abcfc80ae9f91016dd3f84fc1fb6b7da7`

**Entry Point**: `stable-staker-v2-cutover`

**Location**:
- [script/CutoverStableStakerV2Mainnet.s.sol#L143-L190](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L143-L190) (`run`: `vm.startPrank(OWNER)` then `_phase1`..`_phase7`, then `_phase8_wiringAssertions`)
- [script/CutoverStableStakerV2Mainnet.s.sol#L532-L564](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L532-L564) (Phase 7 `if (!done) do();` gates)
- [script/helpers/StableStakerCutoverCore.sol#L440](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/helpers/StableStakerCutoverCore.sol#L440) (per-user loop over `plan.migratable` only)

**Description**: The `package.json` doc key and story 082 both say that after a broadcast, `:preview` "re-runs every assertion and smoke test against the live deployment", with every phase detecting "from on-chain state that it is done and skips". The code does something different. Every phase has the form `if (!done) do();`, and preview impersonates OWNER. Any step that did **not** land on mainnet is therefore quietly performed inside the simulation, and Phase 8 checks the simulated state. Nothing in preview mode, even with a progress file loaded, requires that no mutations were needed.

The per-user loss bound is only evaluated over `plan.migratable` from the same leg. After a broadcast that list is empty, so the on-chain credits are never re-checked.

This belongs to the run-22 `ForgeLocalPassPrecedesBroadcast` family. All planning and assertions run in forge's local pass, and the batches are frozen there, before the Ledger session sends about 47 transactions with `--slow --skip-simulation`. A V1 `stake` that lands after the local pass but before the Phase-1 `pause()` transaction is missing from every batch (cf. ledger `c04da307336c` on `promotion-ready:broadcast`). Phase 7 still revokes V1's phUSD mint, which bricks that user's `userMigrate` while their frozen pending reward is non-zero. The chained preview then migrates them in simulation and reports success.

**Impact**: The operator's only automated outcome check can report a finished cutover while mainnet is in one of these states:
- V1 can still mint phUSD,
- V2 is still paused, or
- a staker is stranded on V1 behind a revoked mint.

The owner can fix each of these in one or two transactions (re-revoke, unpause, or re-grant the V1 mint so the stranded user can `userMigrate`, then revoke again). The problem is that nothing tells the operator a fix is needed. No direct loss is proven, and per-user loss on mainnet stays bounded by the strategies' own minOut floors.

The same class of issue exists as fix-pending M-01 `2c53e944caee` (`VerificationRunsAgainstSimulatedNotBroadcastState`, `promotion-ready:broadcast`). Story 075 fixed that one with an assert-only verifier (`VerifyPromotionReady.s.sol`), and story 082 did not reuse that pattern.

**Evidence**:

```solidity
// script/CutoverStableStakerV2Mainnet.s.sol:158-172 (preview branch of run())
vm.startPrank(OWNER);
...
_phase7_finalize();

// script/CutoverStableStakerV2Mainnet.s.sol:532-535, :563 (inside _phase7_finalize)
if (_canMintPhUSD(STABLE_STAKER_V1)) {
    IPhUSDOwner(PHUSD).setMinter(STABLE_STAKER_V1, false);
    ...
}
if (v2.paused()) v2.unpause();

// script/helpers/StableStakerCutoverCore.sol:440
for (uint256 i = 0; i < plan.migratable.length; i++) {
```

- `test_C_previewMasksMissingRevoke` (`fork-logs/h-test_C_previewMasksMissingRevoke.log`): after a full cutover, `phUSD.setMinter(V1,true)` simulates a revoke that did not land. `run()` in `PREVIEW_MODE` then gives
  `[PASS] ... MASK_REVOKE|preview run() PASSED although V1 phUSD mint was live on-chain`, and the log prints "REVOKED" again.
- `test_C2_previewMasksPausedV2` (`fork-logs/h-test_C2_previewMasksPausedV2.log`): the Pauser pauses V2 to simulate an unpause that did not land. `run()` gives
  `MASK_PAUSED_V2|preview run() PASSED although V2 was paused on-chain`.
- In both cases the console output is byte-identical to a clean verification ("V1 pauser -> Pauser and V1 unpaused (inert); V2 + Antimatter registered with Pauser; V2 unpaused").

**Recommended Mitigation**: Add a separate assert-only verifier (like story-075's standalone `VerifyPromotionReady.s.sol`), or an explicit `VERIFY_ONLY` mode set by an environment flag that never calls `vm.startPrank`/`vm.startBroadcast` and never mutates state.
- Base this mode on **on-chain state**, not on the progress file. Do **not** key it off progress-file `deploymentStatus == completed`, because progress files can be stamped `completed` during forge's local pass (ledger `1e8cc0dc58ba`).
- In this mode every phase must `require(alreadyDone, "verify: step X not on chain")` and never perform the step.
- The live assertions must include:
  - V1 phUSD mint revoked,
  - V2 and Antimatter unpaused,
  - V1 `stakerCount`/`totalStaked` per pool within the straggler allow-list,
  - V2 `pauser == Pauser`,
  - the Antimatter minter set.
- Re-check the per-user loss bound against V2 `userInfo`, using on-chain receipts (V1 `MigratedOut` / V2 `DepositedFor` events, or persisted pre-migration principals) instead of the empty same-leg plan.
- Separately, assert that the set of V1 stakers at the Phase-1 pause block equals the frozen planning set, and fail loudly if a staker slipped in during that window.

---

### [L-03] The cutover hands V2's and Antimatter's only pause authority to a global Pauser whose `pause()` loop already reverts `EnforcedPause` on two pre-paused registered contracts; Phase 8 asserts registration, not a working breaker <!-- id: pps31l3 -->

**Fingerprint**: `0711215fcc1767f9aff5cee42cead479a605b37e56ccbfb5d025eaac211cae06`

**Entry Point**: `stable-staker-v2-cutover`

**Manual review**: The root cause, a protocol-wide Pauser brick caused by two already-paused retired contracts that are still registered, lies outside this entry point. It is tracked as manual-review entry **`MR-31-SSV2C-01`**, which is awaiting a human decision and should be rated there on its protocol-wide impact across all 30 registered contracts. This finding covers only the script's part: the script moves two new funds-holding contracts onto a breaker that is already broken, and Phase 8 treats registration as if it proved pausability.

**Location**:
- [script/CutoverStableStakerV2Mainnet.s.sol#L540-L566](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L540-L566) (`_phase7_finalize`)
- [script/CutoverStableStakerV2Mainnet.s.sol#L623-L625](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L623-L625) (`_phase8_wiringAssertions`)

**Description**: Phase 7's own NatSpec states the invariant it depends on: `Pauser.pause()` calls `pause()` on every registered contract with no try/catch, and OZ `_pause` reverts on a contract that is already paused, so a paused registered V1 would brick the protocol-wide emergency pause. Following that reasoning, the script unpauses V1, calls `v2.setPauser(PAUSER)` and `antimatter.setPauser(PAUSER)`, and registers both contracts.

On mainnet today, two registered contracts are already paused:
- index 2: `0x3984eBC84d45a889dDAc595d13dc0aC2E54819F4` (PhlimboEA V1)
- index 4: `0xf5F91E8240a0320CAC40b799B25F944a61090E5B` (old USDC yield strategy)

The loop therefore reverts before it reaches V1 (index 18), V2 (28) or Antimatter (29). After Phase 7, `StableStakerV2.pause()` is `onlyPauser`, so OWNER cannot pause V2 without first sending `setPauser(OWNER)`. Story 082 Decision 9 flagged the pre-paused contracts for "human attention", but at `1c1608c` the script neither checks for them nor handles them, and Phase 8's registration check passes regardless. Story text carries no suppression authority.

This is a non-obvious owner footgun under Law 3. The script's author clearly believes the loop works, since the script unpauses V1 specifically to keep it working, while two other members already break it.

**Impact**: After the cutover, the permissionless EYE-burn emergency stop does not work for any registered contract. That includes:
- the new V2, which holds all migrated principal (about 5.75k USD across 29 positions), and
- Antimatter, whose `annihilate` mints unbacked phUSD.

Incident response falls back to the Ledger owner sending two transactions per contract (`setPauser(OWNER)`, then `pause()`). The broken state existed before the cutover, but this script extends it to the two new contracts, and its own rationale assumes the breaker works. No asset is directly at risk; the harm only appears if a separate exploit is already in progress. It is fixable without code changes, so it is not permanent. Note that `Pauser.unpause()` also loops without try/catch, so the global unpause is fragile in the same way.

**Evidence**:

```solidity
// script/CutoverStableStakerV2Mainnet.s.sol:556-560 (_phase7_finalize)
if (v2.pauser() != PAUSER) v2.setPauser(PAUSER);
if (!IPauserRegistry(PAUSER).isRegistered(address(v2))) IPauserRegistry(PAUSER).register(address(v2));
if (antimatter.pauser() != PAUSER) antimatter.setPauser(PAUSER);
if (!IPauserRegistry(PAUSER).isRegistered(address(antimatter))) {
    IPauserRegistry(PAUSER).register(address(antimatter));

// script/CutoverStableStakerV2Mainnet.s.sol:623-624 (_phase8_wiringAssertions): registration only
require(IPauserRegistry(PAUSER).isRegistered(address(v2)), "Phase8: V2 not registered with Pauser");
require(IPauserRegistry(PAUSER).isRegistered(address(antimatter)), "Phase8: Antimatter not registered");
```

`test_B_pauserLoopAfterFinalize` (`fork-logs/h-B.log`), run after a full cutover:
- An EYE-funded actor calls `Pauser.pause()`: `PAUSER_LOOP|REVERTED|0xd93c0665` (`EnforcedPause()`).
- Pausing each contract individually while pranking as the Pauser:
  - `PAUSE_ONE|2|0x3984eBC84d45a889dDAc595d13dc0aC2E54819F4|REVERT|0xd93c0665`
  - `PAUSE_ONE|4|0xf5F91E8240a0320CAC40b799B25F944a61090E5B|REVERT|0xd93c0665`
  - the other 28 succeed, including `|18|...(V1)|ok`, `|28|...(V2)|ok` and `|29|...(Antimatter)|ok`.
- OWNER calling `V2.pause()` directly gives `OWNER_PAUSE_V2|REVERT| StableStaker: only pauser`.
- A live `cast call` confirms `paused()==true` and `pauser()==Pauser` for both stale contracts at the fork block.

**Recommended Mitigation**: Before or as part of the cutover, clean up the registry. For the two retired contracts, the preferred fix is to `setPauser` them away from the Pauser and then call `Pauser.unregister` (which is `onlyOwner` and requires `x.pauser() != Pauser`). That is two transactions per contract with no code change. Unpausing them also works, but it may re-open deprecated entry points on PhlimboEA V1 or the old USDC strategy.

Also add a Phase 0/8 check so that "registered" means "actually pausable". Either:
- iterate `Pauser.getPausableContracts()` and require `!paused()` for each, or
- in preview, simulate `Pauser.pause()` from a prank funded with EYE inside `snapshotState`/`revertToState`.

Track the pre-existing registry brick separately under `MR-31-SSV2C-01`.

---

## QA Findings

### [Q-01] The story-080 DeployMocks rehearsal omits the Antimatter phUSD mint grant that the mainnet script proves load-bearing, and the local verifier never calls autoAnnihilate, so the rehearsal cannot exercise V2's only reward path <!-- id: pps31q1 -->

**Fingerprint**: `ca095edfd77eb5c995570804e32901905437b90bc37ed74d5484860593878257`

**Entry Point**: `stable-staker-v2-cutover`

**Status**: **UNVERIFIED, needs-poc.** This finding comes from reading the code only. The claimed revert of `autoAnnihilate` on anvil was **not executed** in this audit. `test_D_autoAnnihilateAllPools` only double-checks the **mainnet** path and is not a PoC for this claim. The finding stays at QA until a local run confirms the revert; after that it should move to Low, with the exact revert string recorded.

**Location**:
- [script/DeployMocks.s.sol#L1879-L1895](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/DeployMocks.s.sol#L1879-L1895) (`_deployAntimatterAndStableStakerV2`)
- [src/mocks/MockPhUSD.sol#L48](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/src/mocks/MockPhUSD.sol#L48)
- Mainnet counterpart: [script/CutoverStableStakerV2Mainnet.s.sol#L440-L446](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L440-L446)

**Description**: Story 082 names DeployMocks' `_deployAntimatterAndStableStakerV2` and `_rehearseStableStakerCutover` as "THE TEMPLATE for ordering and assertions". The mainnet script adds `phUSD.setMinter(antimatter, true)` (Decision 3), because `Antimatter.annihilate` pays its antimatter half with `_phUSD.mint(recipient, amount)`. The executor showed with a negative control that without this grant, `autoAnnihilate` reverts with `phUSD: caller is not authorized to mint`.

DeployMocks grants only `antimatter.setApprovedMinter(V2)` and `phUSD.setMinter(V2)`. Its local phUSD is `MockPhUSD`, whose `mint` requires `info.canMint && info.mintVersion == mintVersion`. The local verifier (`verify-stable-staker.sh` -> `ClaimWithdrawStableStaker.s.sol`) checks that `claimEnabled` is false and then withdraws, without ever calling `autoAnnihilate`. On anvil, the only reward path available while `claimEnabled == false` therefore appears to revert, and no local test would catch it. Story 082 Decision 3 flagged this as a follow-up, and it is still unfixed at `1c1608c`.

**Impact**: The local rehearsal and dev environment, used for UI and integration testing of the V2 reward flow, differ from mainnet on a mint grant the reward path depends on. Future edits to the mainnet cutover or the V2 reward path get no warning from local runs. The run-30 verdict that the V1 -> V2 exception is "verified WORKING" did not cover `autoAnnihilate`. There is **no mainnet impact**: the mainnet preview smoke-tests `autoAnnihilate`, and this audit confirmed it works on all three pools on the fork.

**Evidence**:

```solidity
// script/DeployMocks.s.sol:1880 and :1890: the only two grants
antimatter.setApprovedMinter(address(stableStakerV2), true);
phUSD.setMinter(address(stableStakerV2), true);
// no phUSD.setMinter(address(antimatter), true) anywhere in DeployMocks.s.sol

// script/DeployMocks.s.sol:1865, :211
antimatter.setPhUSD(IFlaxStaker(address(phUSD)));
MockPhUSD public phUSD;

// src/mocks/MockPhUSD.sol:48
require(info.canMint && info.mintVersion == mintVersion, "Not authorized to mint");

// script/CutoverStableStakerV2Mainnet.s.sol:441-446: mainnet grants it
if (GRANT_ANTIMATTER_PHUSD_MINT) {
    if (!_canMintPhUSD(address(antimatter))) {
        IPhUSDOwner(PHUSD).setMinter(address(antimatter), true);
    }
    require(_canMintPhUSD(address(antimatter)), "Phase5: Antimatter cannot mint phUSD (annihilate dead)");
```

Double-check of the mainnet path only, not of the anvil claim: `test_D_autoAnnihilateAllPools` (`fork-logs/h-test_D_autoAnnihilateAllPools.log`) logs `AA_FRESH|DOLA|ok`, `AA_FRESH|USDC|ok`, `AA_FRESH|USDe|ok`, and a migrated staker succeeds on each pool.

**Related**:
- The second part (the verifier never calls `autoAnnihilate`) overlaps open ledger F-03 `c476a12b04fa` (`test:stable-staker`, doc-vs-harness drift). A human should decide whether it folds into that entry. The first part (the missing grant) is new.
- The same grant appears in this run's F-03 (`pps31f3`), which covers the mainnet script adding it without human sign-off. That is the opposite root cause, and the fixes are independent.

**Recommended Mitigation**: First confirm the finding by running the story-080 dev rehearsal and calling `autoAnnihilate` on anvil, and record the exact revert string. Then:
- in `_deployAntimatterAndStableStakerV2`, add `phUSD.setMinter(address(antimatter), true)` with a read-back at the current `mintVersion`;
- extend `verify-stable-staker.sh` / `ClaimWithdrawStableStaker.s.sol` with a step that stakes, calls `evm_increaseTime` for a short period, then calls `autoAnnihilate`, and asserts that phUSD received is above 0 and that the Antimatter owed was consumed.

---

## Appendix: automated QA baseline (4naly3er)

**Not produced this run (tooling gap).** 4naly3er was pointed only at the entry point's first-party Solidity at `1c1608c`:
`script/CutoverStableStakerV2Mainnet.s.sol` and `script/helpers/StableStakerCutoverCore.sol`.

1. **Direct run.** It failed with `@forge-std/Script.sol import not found`. The project has no `remappings.txt`
   and resolves imports only through `foundry.toml`.
2. **Staged run.** I rewrote the `foundry.toml` remappings to absolute paths in a scratchpad staging tree, with `lib/` and `src/` symlinked in. The submodule was not modified. This time compilation succeeded, but analysis then hung for more than 32 minutes: 100% CPU with memory flat at about 540 MB. I killed it, and it wrote no report.

There is no automated baseline for this bundle. The four findings above came from the script-audit pipeline and the fork harness, not from a bot report.
