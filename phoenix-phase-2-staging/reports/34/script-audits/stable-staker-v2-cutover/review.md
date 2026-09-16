# Script review: `stable-staker-v2-cutover` (phoenix-phase-2-staging, run 34)

| | |
|---|---|
| **Entry point** | `package.json` → `stable-staker-v2-cutover:preview`, `:broadcast`, `:verify` |
| **Source commit** | [`84e2324`](https://github.com/Behodler/phoenix-phase-2-staging/tree/84e2324829bd6470ea4a42480290c5239dbec49e) on `master` (regression range `29aeb2b..84e2324`: response commit `9ea09d5` [story-087] plus `3275151` [story-087] NatSpec polish; untagged `0a497f5` / `49d7804` touch only `src/mocks/MockAutoDOLA.sol` and reach neither cutover forge target) |
| **Fork** | Ethereum mainnet. Live preview at block **25988932**; story-087 failing block **25985945**; fix-verification harness at the run-33 block 25981150 for comparability |
| **Mainnet status** | **Not broadcast.** No progress file at HEAD; `StableStakerV2` / `Antimatter` placeholders still `0x0` in `server/deployments/mainnet-addresses.ts` (L155, L157) |
| **Ledger** | No status changed. Every `fixed` below is a proposal for a human to apply with `/ledger` |

Log and artefact paths below are relative to this directory
(`phoenix-phase-2-staging/reports/34/script-audits/stable-staker-v2-cutover/`).

---

## 0. Verdict

**The response commit closes everything it claims.** Story 087 set out to close audit-33 L-05, L-06, L-07 and Q-02, and
all four verify as fixed on the fork. The five prior entries that were waiting on them (L-01, L-02, L-03, L-04, F-01) are
also proposed `fixed`. That makes **9 proposed-fixed, pending human `/ledger`**.

- **0 High / 0 Medium.**
- **1 new Low: L-08** (`pps34l8`, borderline). The 2 bps ERC4626 loss bound sits inside autoDOLA's stepwise live
  spread, so `:preview`'s go/no-go depends on the block.
- **1 new QA: Q-04** (`pps34q4`, borderline). The documentation overclaims breaker liveness at Phase 7 halt 5. The
  window is contained and is the unavoidable residual of the L-05 fix.

**Not broadcast-ready today, for one operational reason.** OWNER is short **0.001495 ETH**:

```text
ETH_BUDGET|gasBudget / gasPriceWei / requiredWei: 22000000 300000000 7920000000000000
ETH_BUDGET|SHORTFALL|OWNER balance / shortfall wei (TOP UP BEFORE :broadcast): 6424919451687286 1495080548312714
```

(`fork-logs/preview-25988932.log` L46-47, block 25988932.) This is the L-07 preflight working as designed:
`_preflightOwnerEth` would refuse `:broadcast`. **Top up OWNER before `:broadcast`.** Separately, L-08 means a green
preview is only valid for the autopool regime it ran in, so re-run `:preview` immediately before signing.

---

## 1. Does it do what it intends?

**Yes.** Every stated purpose holds on the fork at 84e2324. The one gap is evidence, not behaviour: story 087's E3 item.

### Story authority (Law 2)

Each tag was resolved by globbing the whole `~/code/product-owner/stories/phStaging2/` tree, one hit each: 082, 083,
084, 085 (its floor is superseded by 087), 086 and **087** (`087-cutover-audit33-breaker-window-selfexit-gate-eth-preflight.md`,
the story under regression, 30 acceptance items in sections A–E). All of them are in `auto-complete/`; see §7.

### Live preview at 25988932

`PREVIEW_MODE=true forge script … --fork-block-number 25988932` exited 0 (`fork-logs/preview-25988932.log`). All nine
strict breaker stages succeeded:

```text
GLOBAL_PAUSE|phase0|SUCCEEDED|registered=26
GLOBAL_PAUSE|after-phase1 … after-phase6|SUCCEEDED|registered=25   (6 lines)
GLOBAL_PAUSE|after-phase7|SUCCEEDED|registered=27
GLOBAL_PAUSE|after-phase8|SUCCEEDED|registered=27
```

Phase 6 bounds at that block:

| Pool | Exit (P → R) | Worst user (round trip) | Bound | Exit-realization headroom |
|---|---|---|---|---|
| DOLA | 0.474 bps | 0.959 bps | 2 bps + 1000 wei | 0.186580 DOLA |
| USDC | 0.366 bps | within bound (dust users covered by 1000 wei slack) | 2 bps + 1000 wei | 0.322280 USDC |
| USDe | 3.761 bps | 33.75 bps | 61 bps + 1000 wei | 14.692232 USDe |

Phase 7 runs in the order story 087 asks for (`_phase7_finalize`, L689-752): `setPauser(PAUSER)` → `unpause()` →
`register(V2)` → `Antimatter.setPauser(PAUSER)` → `require(!antimatter.paused())` → `register(Antimatter)`. Phase 8's
registrant sweep reports 27 OK, `claimEnabled` stays false, and the smoke tests pass after the simulated pause, which
shows snapshot isolation holds.

### Story-087 conformance: 27 met, 2 justified deviations, 1 partial

| Outcome | Count | Items |
|---|---:|---|
| Met | 27 | A1–A8, B2–B8, C1, C3–C6, D1–D3, E1, E2, E4, E5 |
| Deviation, justified | 2 | **B1**: one 1000 wei `WEI_SLACK` per pool in the realization bound (8e-19 of DOLA P, 0.005 bps of USDC P; real haircuts still fail closed). **C2**: `eth_getBalance` plus the env gas price, instead of `OWNER.balance` plus `max(env, tx.gasprice)`. The story's "forge pre-funds `--sender`" premise did not reproduce, and `tx.gasprice` in the local pass is `block.basefee`, not the pinned price |
| Partial | 1 | **E3** (below) |

**E3, partial.** The item "run `:preview` against mainnet RPC; confirm every `GLOBAL_PAUSE|…|SUCCEEDED` stage" is
ticked `[x]`, but the story's own Verification Results say the live preview **failed in Phase 6** at block 25985945, so
after-phase6 to after-phase8 never ran live. Run 34 supplies the missing evidence: all nine stages pass at 25988932.
The same `run()` still reverts at 25985945, and that block dependence is **L-08**. Detail is in
[`spec-conformance.md`](../../submissions/spec-conformance.md).

---

## 2. Does it introduce unintended side effects?

**No unintended persistent state.** `vm.startStateDiffRecording` over the real phases 0-7 at 25988932 writes **20
accounts, the same set as run 33** (`fork-logs/r34-test_A_stateDiff.log`). Story 087 reorders Phase 7 pause-state
transactions only. It adds no account and no new class of write.

| Account | Writes | Intended |
|---|---|---|
| StableStakerV1 `0xbce8…079A` | Phase 1: pauser Pauser → OWNER, paused. Phase 6: migrator → CVM, 3 pools `Migrating`, `migrationInfo (R,P)` snapshots, 29 user exits, `totalStaked` → 0 | yes |
| Pauser `0x7c5A…85a3` | `unregister(V1)` (26 → 25); `register(V2)` **after** `V2.unpause`, `register(Antimatter)` (→ 27) | yes |
| phUSD `0xf3B5…D605` | minters +V2 +Antimatter −V1 (mask 511 → 510); 29 pending-reward mints | yes |
| YS_DOLA / YS_USDC / YS_USDE | V2 client; set-aside buffers 10/10/25; recipient → V2 (DOLA, USDC); V1 surplus relinquished; principal V1 → V2 | yes |
| Antimatter (new) | owner, phUSD, minter, approved minter {V2}, pauser = Pauser | yes |
| StableStakerV2 (new) | 3 pools, strategies, rates, migrator, 29 users, pauser = Pauser, unpaused | yes |
| CrossVersionMigrator (new) | reentrancy slot only | yes |
| External vaults, Curve pools, router, tokens | share and reserve balances from V1 exits and V2 re-deposits | yes |

`0x5615…b72f` is forge's harness. The residual inert state (the CVM keeps the migrator role on V1 and V2; V1 idle
buffers stay on V1) is F-02 (`436848b0e3`, wont-fix) and is not re-filed.

**Transient and operational effects.** None of these is new persistent state:

- **ETH preflight refuses today** (MR-34-SSV2C-02). Intended behaviour. It is the pre-broadcast action in §0.
- **Regime-dependent Phase 6 gate** (L-08). See §3.
- **Halt-5 breaker reach** (Q-04). See §3.

---

## 3. Does it cause knock-on problems elsewhere?

### L-08: the go/no-go flips with autoDOLA's spread regime (Low, borderline)

The Phase 6 per-user bound for ERC4626 pools is a hard-coded constant whose NatSpec justifies it from a single planning
block
([`CutoverStableStakerV2Mainnet.s.sol#L147-L154`](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L147-L154)):

```solidity
    /// @dev Per-user loss bound on the 1:1 ERC4626 strategies. The story planned 0 bps, but the live
    ///      autoDOLA autopool is NOT loss-free on either leg: the planning preview (block ~25975061)
    ///      measured, per leg, autoDOLA: exit R/P = 1 - 1.70e-6, re-deposit x * (1 - 1.73e-6)
    ///      (~0.034 bps round trip); autoUSDC: exit R/P = 1 - 4.32e-5, re-deposit ~ 1 - 4.3e-5
    ///      (~0.86 bps round trip). 2 bps is ~2.3x the worst observation: loose enough not to trip on
    ///      the autopools' own valuation spread, tight enough that a real vault loss still stops the
    ///      run. Recorded in story 082's Autonomous Decisions.
    uint256 public constant ERC4626_MAX_LOSS_BPS = 2;
```

It is selected in
[`_maxLossBps`, L1220-L1223](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L1220-L1223):

```solidity
    function _maxLossBps(address ys) internal view returns (uint256) {
        if (_marketAdapter(ys) == address(0)) return ERC4626_MAX_LOSS_BPS;
        return 2 * ICutoverStrategy(ys).slippageToleranceBps() + 1;
    }
```

**Observed on the fork:**

| Block | autoDOLA per-leg spread | DOLA users over bound | Preview |
|---|---|---|---|
| 25981150 (run 33) | 0.017 bps | 0/9 | passes |
| 25985945 (story 087) | 1.035 bps (2.07 bps round trip) | **9/9, including all 4 non-dust users**, uniform at 2.069–2.093 bps | **reverts** `cutover-post: cutover lost more principal than the strategy can explain` |
| 25988932 (live) | 0.474 bps | 0/9 (0.948–0.959 bps) | passes, 9 stages |

The spread moves in discrete steps: up between 25981231 and 25981232, down between 25988000 and 25988001. The
high-spread regime lasted about 6,769 blocks (~22.5 h). The breach is not a dust-rounding artefact: the largest
non-dust staker (~1,000 DOLA) loses 2.069 bps.

**Why it is a footgun, not only a calibration nit.** The bound is enforced only in forge's local pass. If the regime
steps up during the ~30-transaction Ledger session, the landed Phase 6 migration exceeds 2 bps and nothing on chain
re-checks it. `test_B_driftLanding_postBroadcastTools` shows that the resume-shape check and the verifier's per-user
credit check both **pass** on that landed state. Only `:verify`'s live per-pool aggregate reverts, short by 0.008936
DOLA, and about 0.009 DOLA of organic V2 stake would mask it. Story 087's Concerns claim that the verifier's per-user
check "bounds the total" is false: it covers only the re-deposit leg.

**Severity.** Low. At current size the over-spec value is under $1 (~0.009 DOLA; the ~0.26 DOLA total spread is
socialized by design). A red go/no-go fails closed before any transaction and V1 keeps serving users. The loss is
proportional in bps, so **re-weigh toward Medium if pool TVL grows materially before broadcast**.

### Q-04: the halt-5 window is contained (QA, borderline)

At halt 5 (after `v2.unpause()`, before `Pauser.register(V2)`), a committed global `Pauser.pause()` succeeds but leaves
`V2.paused() == false`, contrary to the `//:broadcast` key and the Phase 7 NatSpec. Containment holds: all three V2
strategies are Pauser-registered and pause, so stake, withdraw and `autoAnnihilate` revert `EnforcedPause`
(`0xd93c0665`) and claim reverts `claim disabled`. **Zero** user entry points succeed. The intuitive remedy, a direct
`V2.pause()`, reverts `onlyPauser`. The working remedy is `V2.setPauser(OWNER)` then `V2.pause()`
(`test_P7_halt5_globalPauseCannotReachV2`, `fork-logs/r34-gapfix-halt5.log`). It is the one-transaction trade-off
of the L-05 fix and is filed as `residualOf` L-05, not as an incomplete fix. It would rise to Low if a strategy were
later unregistered.

### Run-33 harness bit-rot and stale `pocPath`

`work/test/audit-run33/CutoverAuditRun33.t.sol` **no longer compiles** at 84e2324, because story 087 deleted
`_aggregatePrincipalFloor`. Unless it is skipped, it also breaks the whole `work/` build. Its scenarios were ported 1:1 to
`work/test/audit-run34/CutoverAuditRun34.t.sol` (19/19 pass). The ledger `pocPath` for **L-05 `fc44ca36`, L-06
`cf4b531a` and L-07 `d6896c6e`** still points at the run-33 file. A `/recheck` that replays those entries will read
**INCONCLUSIVE (bit-rot)**, not LIKELY-FIXED. Finding-manager deliberately did not rewrite the field. Tracked as
MR-34-SSV2C-01.

### Sibling scripts

The delta does not touch DeployMocks' cutover rehearsal. Its divergence remains the owner-ruled "UI mock, not a
rehearsal" class (Q-01/Q-03 wont-fix) and is not re-filed.

---

## 4. Fix verification: every prior entry for this entry point

All fork tests below are in `work/test/audit-run34/CutoverAuditRun34.t.sol` unless marked *project* (unmodified
upstream suites, 55/55 in `fork-logs/r34-project-cutover-suites.log`).

| Label | Issue ID | Fp prefix | Run-33 position | Run-34 verdict | Evidence |
|---|---|---|---|---|---|
| L-05 | `pps33l5` | `fc44ca36bccc` | open: Phase 7 registers V2 while paused (3-tx dead breaker) | **FIXED** (residual → Q-04) | `test_P7_everyHaltPoint_breakerLive_resumeConverges` (dead = 0), `test_P7_haltAfterAntimatterSetPauser_previewRunPasses`, `test_P7_antimatterPausedRequire_unreachable`; live `after-phase7 SUCCEEDED registered=27` |
| L-06 | `pps33l6` | `cf4b531aee54` | open (borderline M): self-exit read as loss; halted resume could not finish | **FIXED** (residual → MR-34-SSV2C-03) | `test_SX_selfExitBetweenTxs_verifierPasses`, `test_SX_selfExitThenHalt_resumeCompletes_verifierPasses`, `test_SX_inverse_haircutPlusSelfExit_verifierStillFails`, `test_F01_haircut5bps_failsClosedBothShapes` |
| L-07 | `pps33l7` | `d6896c6e843d` | open: no ETH budget preflight | **FIXED** (fix is firing: shortfall today) | `test_L07_ownerEthReader`; live `ETH_BUDGET\|SHORTFALL`; `_preflightOwnerEth` (L319) called only on broadcast (L216) |
| Q-02 | `pps32q2` | `1c859cdebb64` | open: operator doc key describes superseded end state | **FIXED** (runbook regime gap folded into L-08) | Doc keys re-read against 84e2324 code; stale-phrase grep clean (no test) |
| L-04 | `pps32l4` | `46c053534c58` | held open pending L-05 | **FIXED** | *project* `test_fork_breakerProbe_everyPauseStateTx_phases1_3_7` (dead == 1, the single documented forced tx) |
| L-03 | `pps31l3` | `0711215fcc17` | proposed fixed; residual via L-05 | **FIXED** (strengthened: 9 stages) | `preview-25988932.log` 9 × SUCCEEDED; registrant sweep OK 27 |
| L-02 | `pps31l2` | `2c82d65e65e1` | proposed fixed; residual via L-06 | **FIXED** | *project* `test_verifierIsReadOnly`; verifier still rejects `PREVIEW_MODE` |
| L-01 | `pps31l1` | `e0d4df1ddb69` | proposed fixed (second proposal) | **FIXED** | `WEI_SLACK = 1000` unchanged; `preview-25988932.log` per-user bounds pass |
| F-01 | `pps31f1` | `dfed42790952` | proposed fixed; residual via L-06 | **FIXED** (coverage kept after the floor was deleted) | `test_F01_haircut5bps_failsClosedBothShapes`, `test_F01_boundarySweep_resumeShape` (1.92 bps pass / 2.12 bps fail) |

F-02, F-03, Q-01 and Q-03 are wont-fix. The delta does not touch their root causes, and they were not re-filed.

---

## 5. Findings register

Code links are pinned to `84e2324`. Labels are run-scoped; use the issue ID or fingerprint as the stable handle.

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-08** `pps34l8` `6022a9eb9989` | Low (borderline) | 2 bps ERC4626 per-user bound sits inside autoDOLA's stepwise spread: preview reverts at 25985945, passes at 25988932; enforced only in the local pass, so a mid-session regime step lands >2 bps, caught only by a maskable `:verify` aggregate | Re-derive `ERC4626_MAX_LOSS_BPS` in its own story from a multi-day autopool sample (e.g. ~5 bps) and fix the NatSpec; pre-quote the ERC4626 round trip in `_initiatePool` and log `LOSS_HEADROOM`; document regime dependence and "re-run `:preview` right before signing" in `//:broadcast`; correct story 087's Concerns or add a per-user pre → credited check to the verifier | [`CutoverStableStakerV2Mainnet.s.sol#L147-L154`](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L147-L154), [`#L1220-L1223`](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L1220-L1223) · Report: [`qa-report.md` L-08](../../submissions/qa-report.md) · Record: [`L-08…json`](../../findings/low/L-08-loss-bound-inside-live-autopool-spread.json) |
| **Q-04** `pps34q4` `a62956952abd` | QA (borderline) | `//:broadcast` key and Phase 7 NatSpec claim the breaker is live at every Phase 7 halt; at halt 5 a global pause does not reach V2 (strategies contain it: 0 user paths succeed) | Name the halt-5 window in the doc key and NatSpec, with its containment and the OWNER remedy (`V2.setPauser(OWNER)` then `V2.pause()`); optionally make the preview/Phase 8 `GLOBAL_PAUSE` probe assert that V2 and Antimatter are actually paused | [`CutoverStableStakerV2Mainnet.s.sol#L689-L752`](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L689-L752) · Report: [`qa-report.md` Q-04](../../submissions/qa-report.md) · Record: [`Q-04…json`](../../findings/qa/Q-04-breaker-liveness-doc-overclaim-halt5.json) |
| L-05 `pps33l5` (prior; **proposed `fixed`**) | Low | Phase 7 registered V2 while paused | Implemented by story 087 (unpause before register); no further change beyond Q-04's doc correction | [`CutoverStableStakerV2Mainnet.s.sol#L737-L748`](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L737-L748) · Report: [`carryover/qa-report-33.md`](../../submissions/carryover/qa-report-33.md) |
| L-06 `pps33l6` (prior; **proposed `fixed`**) | Low | Aggregate floor counted self-exits as loss | Implemented by story 087 (exit-realization bound on V1 `(R,P)`, self-exit-net verifier aggregate); no further change; USDe exit-leg residual in MR-34-SSV2C-03 | `script/helpers/StableStakerCutoverCore.sol` (realization bound; per-user bound L499-502) · Report: [`carryover/qa-report-33.md`](../../submissions/carryover/qa-report-33.md) |
| L-07 `pps33l7` (prior; **proposed `fixed`**) | Low | No ETH budget preflight | Implemented by story 087 (`_preflightOwnerEth`); no code change; top up OWNER before broadcast | [`CutoverStableStakerV2Mainnet.s.sol#L319`](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L319), [`#L216`](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L216) · Report: [`carryover/qa-report-33.md`](../../submissions/carryover/qa-report-33.md) |
| Q-02 `pps32q2` (prior; **proposed `fixed`**) | QA | Stale operator doc key | Implemented by story 087 D (keys rewritten); remaining regime-dependence note tracked under L-08 rec 3 | `package.json` `//StableStakerV2Cutover` · Report: [`carryover/qa-report-32.md`](../../submissions/carryover/qa-report-32.md) |
| L-04 `pps32l4` (prior; **proposed `fixed`**) | Low | Phase-1 → Phase-7 V1 registered-while-paused window | Implemented by story 084; hold condition (L-05) now met; no further change | [`CutoverStableStakerV2Mainnet.s.sol#L689-L752`](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L689-L752) (Phase 7 backstop) · Report: [`carryover/qa-report-32.md`](../../submissions/carryover/qa-report-32.md) |
| L-01 / L-02 / L-03 `pps31l1-3` (prior; **proposed `fixed`**) | Low | Wei slack; mutating post-broadcast "verification"; registration-not-liveness assert | Implemented by stories 083/086/084; no further change | [`CutoverStableStakerV2Mainnet.s.sol#L146`](https://github.com/Behodler/phoenix-phase-2-staging/blob/84e2324829bd6470ea4a42480290c5239dbec49e/script/CutoverStableStakerV2Mainnet.s.sol#L146) (`WEI_SLACK`) · Report: [`carryover/qa-report-31.md`](../../submissions/carryover/qa-report-31.md) |
| F-01 `pps31f1` (prior; **proposed `fixed`**) | Faithfulness | "067 floor" could not fail | Implemented by story 087 (realization bound keeps the coverage); re-deposit-leg residual tracked under L-08 rec 4 | `script/helpers/StableStakerCutoverCore.sol` · Report: [`carryover/spec-conformance-31.md`](../../submissions/carryover/spec-conformance-31.md) |

---

## 6. Manual review (visible channel)

None of these items is a ledger finding, and none has been dropped. Full text: [`manual-review.md`](../../manual-review.md).

| ID | Kind | Needs |
|---|---|---|
| **MR-34-SSV2C-01** | Audit tooling | Retire or skip `work/test/audit-run33/`; repoint L-05/L-06/L-07 `pocPath` to the run-34 ports |
| **MR-34-SSV2C-02** | Operational, pre-broadcast | Top up OWNER by at least 0.001495 ETH (0.00792 ETH needed at 0.3 gwei); re-derive the 22M gas budget if staker counts grow |
| **MR-34-SSV2C-03** | Acknowledged residual (story 087 Concerns) | USDe realization bound covers the exit leg only (61 bps). Re-evaluate if L-08 rec 4 is declined |
| **MR-34-SSV2C-04** | Audit-method gap | Breaker probes (audit harness and the project's Phase 8/preview probe) must assert the target contracts are paused, not only that `pause()` did not revert. This gap is how Q-04 escaped the first pass |
| **MR-31-SSV2C-01** | Out-of-slice, restated | **Still OPEN, awaiting human decision.** The live Pauser's `pause()` loop has no try/catch, so any paused registrant bricks the global breaker. Currently cleared by external state only (26 registrants, 0 paused at 25988932); no structural guard |

---

## 7. Governance observation (not a code finding)

- **Undocumented state folder.** Stories 080–087 all sit in `auto-complete/`, which is not one of the documented states
  (`complete | incomplete | review | archive`). Each is stamped "Approved by: story-batch workflow (machine approval —
  not human-reviewed)", and every step of 087 ran with `--inline-delegation` ("Independence: reduced").
- **087 was completed despite `Review Status: ISSUES_FOUND`**, triaged "non-blocking". Its archived
  `preview-mainnet.log` and `anvil-broadcast-preflight-refusal.log` predate the final build.
- **The completion stamp predates the review it cites.** `Auto-Completed` / `Base Commit Updated` are dated
  2026-09-15T23:46:26Z, before the Autonomous Decisions (2026-09-16T00:20Z) and the Review (2026-09-16T02:05Z).
- **E3 is ticked but was unmet** by the story's own evidence (§1).

Law-2 grading in this run relied on the story text and on independent fork evidence, not on completion state. A human
should review stories 082–087 before broadcast.

---

## 8. Evidence-integrity notes

- **Independent spot-reproduction** (`spot-reproduction.md`, poc-validator) re-ran every headline result from `work/`
  (HEAD 84e2324, script/verifier/core/project suites byte-identical to `src/`) and confirmed it: preview passes at
  25988932 with 9 stages and the exact ETH shortfall; preview reverts at 25985945 (measured **2.093 bps**, correcting
  the earlier ~2.07 figure); the run-34 harness passes; project suites 19 + 16 + 20 = 55/0. It also corrected the source
  path (`script/…`, not `lib/phoenix-phase-2-staging/script/…`) and pinned the constant to L154 and `_maxLossBps` to L1220-1223.
- **A vacuous audit-authored test was caught and fixed before filing.** `test_B_previewRun_atStory087Block` wrapped
  `run()` in try/catch with no assertion, so it passed either way. It now `fail()`s on success and `assertEq`s the exact
  revert reason, and passes (`fork-logs/r34-gapfix-fullfile.log` L1335). The spot-check also found that
  `test_P7_everyHaltPoint_…` scores "LIVE" on registered contracts only; that gap produced Q-04 and MR-34-SSV2C-04.
- **Full harness file:** `CutoverAuditRun34.t.sol` 19 passed, 0 failed (`fork-logs/r34-gapfix-fullfile.log` L3739).
  `git ls-tree -r 84e2324` does not contain it, so it is audit-authored and not filed as project code.
- **Fingerprint scheme verified.** It was checked by reproducing the ledger fingerprints of L-05, L-06 and L-07 from
  `sha256(contract:function:rootCauseClass:entryPoint)`. This review independently recomputed L-08 (`6022a9eb…`) and Q-04
  (`a6295695…`) from their stored preimages, and both match.
- **Ledger write verified.** Entry count went 177 → 179 (L-08, Q-04 added) with no status change on any existing entry.

---

## 9. Next steps for the human

1. **Confirm the nine fixes** (proposals; nothing has been applied):

   ```text
   /ledger phoenix-phase-2-staging fixed fc44ca36bccc   # L-05 pps33l5
   /ledger phoenix-phase-2-staging fixed cf4b531aee54   # L-06 pps33l6
   /ledger phoenix-phase-2-staging fixed d6896c6e843d   # L-07 pps33l7
   /ledger phoenix-phase-2-staging fixed 1c859cdebb64   # Q-02 pps32q2
   /ledger phoenix-phase-2-staging fixed 46c053534c58   # L-04 pps32l4
   /ledger phoenix-phase-2-staging fixed 0711215fcc17   # L-03 pps31l3
   /ledger phoenix-phase-2-staging fixed 2c82d65e65e1   # L-02 pps31l2
   /ledger phoenix-phase-2-staging fixed e0d4df1ddb69   # L-01 pps31l1
   /ledger phoenix-phase-2-staging fixed dfed42790952   # F-01 pps31f1
   ```

2. **Top up OWNER** `0xCad1…D0B6` by at least 0.001495 ETH, with margin for a higher gas price and any resume leg.
3. **Decide on L-08.** Either commission a recalibration story (a multi-day autopool sample, an ERC4626 round-trip
   pre-quote, the runbook note, and the story 087 Concerns correction or a per-user total verifier check), or accept the
   regime-dependent gate knowingly. If the owner intends to fix it, file it as `fix-pending`, not `acknowledged`. Do the
   same for Q-04's doc correction.
4. **Re-run `:preview` immediately before signing.** Confirm nine `GLOBAL_PAUSE … SUCCEEDED` lines, `ETH_BUDGET|OK`, and
   Phase 6 DOLA/USDC worst-user loss well under 2 bps. If `:verify` then reports the DOLA aggregate short right after a
   green local pass, treat it as a mid-session regime step (L-08), not a confirmed exploit. The resume path will not
   detect it.
5. **Housekeeping.** Retire or skip the run-33 harness and repoint the L-05/L-06/L-07 `pocPath` (MR-34-SSV2C-01). Review
   stories 082–087 by hand (§7). Rule on MR-31-SSV2C-01.
