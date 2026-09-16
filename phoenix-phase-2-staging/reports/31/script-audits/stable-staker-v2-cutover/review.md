# Script review: `stable-staker-v2-cutover`

| | |
|---|---|
| Project | phoenix-phase-2-staging |
| Run | 31 (script-audit) |
| Entry point | `stable-staker-v2-cutover` (`:preview` / `:broadcast`) |
| Story | story-082, mainnet StableStaker V1 to V2 cutover with Antimatter |
| Source | [`1c1608c`](https://github.com/Behodler/phoenix-phase-2-staging/tree/1c1608c0e56a55cbeb436926d139fa89ff7a3144) on `master` |
| Script | [`script/CutoverStableStakerV2Mainnet.s.sol`](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol), [`script/helpers/StableStakerCutoverCore.sol`](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/helpers/StableStakerCutoverCore.sol), JS tail `scripts/patch-mainnet-addresses-stable-staker-v2.js` |
| Outcome | 0 High, 0 Medium, 3 Low, 1 QA, 3 faithfulness (F-01 Low, F-02 and F-03 QA) |

## Status: pre-flight review, the cutover has not been broadcast

The cutover has **not** been broadcast at `1c1608c`. Three observations show this:

- `server/deployments/progress.stable-staker-v2-cutover.1.json` does not exist in the source tree.
- The `StableStakerV2` and `Antimatter` keys in `server/deployments/mainnet-addresses.ts` are still zero placeholders.
- On chain, StableStakerV1 `0xbce8…079A` is live and unpaused. Its pauser is the global Pauser, all three pools are Active, and it holds 9/13/7 stakers.

Treat everything below as a **pre-flight review** of a script that is about to run, not a verification of a completed deployment. Every finding is fixable by editing the script or doing registry hygiene before anything is signed.

**Story provenance.** Globbing the whole `phStaging2` tree for `082-*` returns exactly one document:
`~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/082-mainnet-stable-staker-v2-cutover-script.md`.
It sits in **`auto-complete/`**, which means it was approved by a machine and not reviewed by a human. Its Review Status is `ISSUES_FOUND`, triaged as "non-blocking". That matters for F-03, where a scope addition to mint authority has no human sign-off.

---

## 1. Does it do what it intends?

**Mostly yes, on the happy path.** The `:preview` variant was run exactly as `package.json` defines it, plus `--fork-block-number 25975869` so the run is reproducible. It ran from `work/`, with no `--broadcast` and no progress file before or after. Result: **PASS, forge exit 0**.

| Check family | Evaluated | Passed |
|---|---|---|
| Preconditions (config + Phase 0) | 27 | 27 |
| Step post-conditions (Phases 2 to 7) | 189 | 189 |
| Phase 8 wiring assertions | 59 | 59 |
| Preview smoke tests | 12 | 12 |

What the fork run shows:

- **Every staker migrated.** 29 V1 stakers moved to V2: DOLA 9, USDC 13, USDe 7. There were 0 stragglers, 0 zero-credit positions and 0 dropped users. V1 `totalStaked` and `stakerCount` end at 0 on every pool.
- **The story-060 surplus was relinquished** before `initiateMigration`: **26.898455742910213445 DOLA** and **27.043385 USDC**. USDe had no surplus; its principal matched exactly.
- **Per-user losses stayed inside the script's bounds.** Worst-case loss per pool:

  | Pool | Loss (bps) | Loss (tokens) | Script bound |
  |---|---|---|---|
  | USDe | **34.8** | 8.93 USDe | 61 bps |
  | USDC | **0.865** | 0.170245 USDC | 2 bps + 2 wei |
  | DOLA | **0.034** | 0.00415 DOLA | 2 bps + 2 wei |

  USDC dust users holding 12 to 90 wei each lose exactly 2 wei. That is precisely the `WEI_SLACK` boundary; see L-01.
- **The phUSD minter set changed only by the V1 bit.** The mask went **511 to 510** and `mintVersion` stayed at 0. The V2 and Antimatter grants are new mappings, and only the V1 bit cleared. phUSD supply rose by 85.471458401387198196, which equals the sum of V1 pending rewards minted during migration, exactly.
- **Smoke tests passed.** The Antimatter mint-revocation proof passed. A 100-unit stake and withdraw worked on every V2 pool. A 1000 DOLA stake followed by a 10-minute warp and `autoAnnihilate` paid phUSD. Audit probe D extended `autoAnnihilate` to all three pools, for both a fresh actor and a real migrated staker, and all six calls succeeded.

**Where intent and implementation diverge.** Each item below is filed:

- **Story-082 AC5 says "dust cannot grief the cutover".** It can. A 9-wei DOLA stake makes the per-user post-condition revert (L-01).
- **The "067 floor" cannot fail.** It compares `principalOf(V2)` with `V2.totalStaked`, and both sides book the same `credited` value. On the fork it held with equality on all three pools. Story-067 anchors the floor on the pre-migration booked total, and that comparison is not implemented (F-01).
- **The post-broadcast `:preview` does not verify.** The broadcast key chains it as a verification step. It actually re-performs any outstanding step under prank, so a partial mainnet cutover still reports green (L-02).
- **Phase 8 asserts registration, not a working breaker.** It checks that V2 and Antimatter are registered with Pauser, not that `Pauser.pause()` works (L-03).
- **The script makes a third mint grant the story does not list.** `phUSD.setMinter(Antimatter, true)` is outside story-082's Phase 5 list. It is required and disclosed (Decision 3), but it has no human sign-off (F-03).

**Disclosed relaxations.** These are not filed as defects:

- The per-user loss bound is relaxed from 0 bps to 2 bps + 2 wei on the ERC4626 pools and 61 bps on USDe (Decision 4).
- V1 is left unpaused rather than paused (Decision 9; the story allows either).
- V1 stays an authorized client with 0 principal on all three strategies, and its idle buffers stay on V1 (Decision 14). The allocation consequence of this is surfaced as F-02.

## 2. Unintended side effects

**None observed.** The fork run produced **1341 changed storage-slot writes**. Each one maps to a declared step or to the external venue activity that the exit and re-deposit mechanically require (autoDOLA, autoUSDC, sUSDe, the Curve pools and router). **0 were unintended.**

The following were not touched: PhusdStableMinter `0x94855ACA`, StableYieldAccumulator `0x0cD353bf`, the old V1 migrator `0x17DC492A`, every other Pauser-registered contract, and PhlimboV3 and its hooks.

Events match the plan. V1 emitted 3 `MigrationInitiated` and 29 `MigratedOut`. V2 emitted 29 `DepositedFor`. Pauser emitted 2 `ContractRegistered`. The strategies emitted `PrincipalRelinquished` 1/1/0.

Residual state the script leaves behind, and how each item was judged:

| Residual | Disposition |
|---|---|
| `V1.migrator` and `V2.migrator` stay set to the transient CrossVersionMigrator | Lead, not filed (see below) |
| V1 idle buffers (6.997 DOLA, 10.43 USDC, 49.85 USDe) stay on V1 | Disclosed (Decision 14); allocation question raised in F-02 |
| `Pauser.pause()` reverts `EnforcedPause` (`0xd93c0665`) at registered indices 2 and 4. V2 (index 28) and Antimatter (index 29) are never reached by the loop, and an OWNER call to `v2.pause()` reverts `StableStaker: only pauser` | Pre-existing; the script's slice is L-03 and the root cause is MR-31-SSV2C-01 |

### Leads investigated and not filed

| Lead | Why it was not filed |
|---|---|
| The CrossVersionMigrator keeps its migrator role on V1 and V2 after finalize | **Inert.** Harness `test_E` showed that the owner calling `initiateMigration(t)` on the migrator reverts `StableStaker: pool not active` for all 3 tokens. Owner `migrate(DOLA, [former staker])` is a no-op, non-owner `migrate` reverts, and `V1.depositFor` from the migrator address reverts. The migrator never calls `V2.initiateMigration` or `batchMigrate`, and no reachable consequence was found. The dev-path rehearsal has the same pattern as ledger L-06 `08adbb692840`; that entry stays the record of it. |
| V1's previous migrator `0x17DC492AfA0C25fb7293edc5c00c7d4d2FCcb342` is overwritten without being read or asserted first | It holds **zero** DOLA, USDC and USDe, and `staker()` is V1. Overwriting it strands no value. |
| USDe strategy bytecode drift: `YS_USDE` `0xaC2e…7f95` is a build from before story-047 | The only missing surface is the set-aside buffer-recipient getter and setter. The script detects this with a `staticcall` probe and skips the recipient step, and that strategy pays each client directly. |
| Stale `scripts/patch-mainnet-addresses-stable-staker.js` (the story-055 patcher that writes the retired `StableStaker` key) still exists | It is not in this entry point's chain. If it were run by mistake it **exits 4 before writing**, and the new patcher's header warns against using it. |

The **orchestrator independently reproduced** two harness results at block 25975869:

- **`test_G`:** a planted 9-wei V1 DOLA stake makes the full preview revert with `cutover-post: cutover lost more principal than the strategy can explain`.
- **`test_B`:** after finalize, `Pauser.pause()` reverts. Both `0x3984eBC84d45a889dDAc595d13dc0aC2E54819F4` and `0xf5F91E8240a0320CAC40b799B25F944a61090E5B` return `paused() == true` on live mainnet.

## 3. Knock-on problems and the sibling-script cluster

| Rank | Sibling | Relation | Knock-on |
|---|---|---|---|
| 1 | `script/DeployMocks.s.sol`, `_deployAntimatterAndStableStakerV2` / `_rehearseStableStakerCutover` (`dev`, story-080) | Anvil rehearsal the mainnet script says it mirrors | **Q-01:** the rehearsal omits the Antimatter phUSD grant, which the mainnet script proves load-bearing, so the rehearsal cannot exercise V2's only reward path. The migrator-role pattern here is ledger L-06 `08adbb692840`. |
| 2 | `test/StableStakerCutoverDust.t.sol` | Tests the shared helper | No test covers a vault with share price above 1; L-01 asks for that regression. The market branch runs only when `RPC_MAINNET` is set. |
| 3 | `verify-stable-staker.sh` (`test:stable-staker`) | Local V2 verification | Never calls `autoAnnihilate`. This overlaps open ledger F-03 `c476a12b04fa` and Q-01 limb 2. |
| 4 | `script/archives/MigrateStableStakerMainnet.s.sol` (story-055) | Created the current V1 | Leftover `patch-mainnet-addresses-stable-staker.js`; lead not filed (above). |
| 5 | Archived saga2 set (stories 060/062/067) | Source of the strategy map, surplus, pause pattern and floor | F-01 is the **third recurrence** of the story-067-floor defect class, after YS-26 `018c109ec76f` and YS-32 `523ef3df52a6`. |
| 6 | `promotion-ready` (stories 071/073/076) | Source of the gas flags and the two-sided minter delta | L-02 recurs the `ForgeLocalPassPrecedesBroadcast` / "verification against simulated state" family (fix-pending M-01 `2c53e944caee`). The story-075 assert-only verifier pattern was not carried forward. |

**Manual review, out of slice: MR-31-SSV2C-01.** The global emergency breaker is **already broken protocol-wide**. Two retired contracts (`0x3984…19F4` and `0xf5F9…0E5B`) are still registered with Pauser and are already paused. `Pauser.pause()` loops over every registered contract with no try/catch, so it reverts for all 30 contracts. This predates the cutover and sits outside the entry point. It is parked as manual-review item **MR-31-SSV2C-01** for a human decision and should be rated on its protocol-wide impact. L-03 covers only this script's slice: the cutover hands V2's and Antimatter's *only* pause authority to that dead breaker, and Phase 8 reports this as healthy.

**Tooling gap.** 4naly3er produced **no appendix** for this run. The direct run failed on imports. A staged run with absolute remappings compiled, then hung for more than 32 minutes at 100% CPU and was killed without writing a report. There is no automated QA baseline; every finding here comes from the script-audit pipeline and the fork harness.

---

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| L-01 | Low | The fixed 2-wei per-user slack is below autoDOLA's round-trip rounding (3 wei). A 9-wei V1 DOLA stake reverts the cutover's post-condition, so dust can stall the run (contradicts AC5). Reproduced (`test_G`). | Derive the wei slack from the destination vault's share price, or treat positions whose predicted loss is over the bound as capped stragglers; add a share-price > 1 dust regression test. | [StableStakerCutoverCore.sol#L452-L455](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/helpers/StableStakerCutoverCore.sol#L452-L455) |
| L-02 | Low | The post-broadcast `:preview` re-performs any outstanding step under prank instead of asserting it is done, so a partial or diverged mainnet cutover verifies green (probes C and C2). | Add an assert-only verify mode or script, gated on on-chain state and not on the progress file, that requires each step to be done, never mutates, and re-checks per-user loss from on-chain events. | [CutoverStableStakerV2Mainnet.s.sol#L143-L190](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L143-L190) |
| L-03 | Low | V2's and Antimatter's only pause authority goes to a Pauser whose `pause()` loop already reverts on two pre-paused registered contracts; Phase 8 asserts registration, not pausability. Reproduced (`test_B`). | Before broadcast, `setPauser` away and `unregister` the two stale Pauser entries (or unpause them), and add a Phase 0/8 check that every registered contract is `!paused()` or that a simulated `Pauser.pause()` succeeds. | [CutoverStableStakerV2Mainnet.s.sol#L540-L566](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L540-L566) |
| F-01 | Low | The "067 floor" compares two values that are booked identically, so it can never fail; story-067's pre-migration anchor is not implemented. Third recurrence of the class. | Gate `V2.totalStaked` against the `principalSnapshot` less the allowed bps and wei slack, or rename the check and record the Decision-4 relaxation as human-accepted. | [StableStakerCutoverCore.sol#L469-L471](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/helpers/StableStakerCutoverCore.sol#L469-L471) |
| F-02 | QA | Stakers bear the cutover loss (USDe 34.8 bps, 8.93 USDe) while larger protocol-held value stays with the protocol: V1 idle buffers, the relinquished story-060 surplus, and the USDe booking haircut. | Record explicit owner acceptance in story-082, or add an optional Phase 7b top-up from rescued V1 buffers via a temporary migrator `depositFor`; never a per-client cap. | [StableStakerCutoverCore.sol#L300-L413](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/helpers/StableStakerCutoverCore.sol#L300-L413) |
| Q-01 | QA | The story-080 DeployMocks rehearsal omits the Antimatter phUSD grant, and the local verifier never calls `autoAnnihilate`, so the rehearsal cannot exercise V2's only reward path. **Unverified**: upgrade to Low once the anvil revert is confirmed. | Add `phUSD.setMinter(antimatter, true)` with a read-back to the rehearsal, and add a stake, short warp and `autoAnnihilate` assertion to `verify-stable-staker.sh`. | [DeployMocks.s.sol#L1879-L1895](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/DeployMocks.s.sol#L1879-L1895) |
| F-03 | QA | Spec deviation: a third mint grant, phUSD mint authority to Antimatter, is not in story-082's Phase 5 list and has only machine approval (`auto-complete`). | Record human sign-off for the Antimatter phUSD grant in story-082 (or a follow-up story) before broadcast, and document its bound (`approvedMinterCount()==1` plus the V2 rate) in Phase 8 NatSpec. | [CutoverStableStakerV2Mainnet.s.sol#L425-L450](https://github.com/Behodler/phoenix-phase-2-staging/blob/1c1608c0e56a55cbeb436926d139fa89ff7a3144/script/CutoverStableStakerV2Mainnet.s.sol#L425-L450) |

L-01 and L-02 are also cross-listed as faithfulness deviations in `submissions/spec-conformance.md`. The full write-ups are in `submissions/qa-report.md` and `submissions/spec-conformance.md`.

### Fingerprints

All findings carry `entryPoint: stable-staker-v2-cutover` and `branch: master`.

- L-01 (`pps31l1`): `e0d4df1ddb699c8f34e034209cf8a6311bffa3bfd79429662637976f527dd054`
- L-02 (`pps31l2`): `2c82d65e65e163c9f986c669aaf0b56abcfc80ae9f91016dd3f84fc1fb6b7da7`
- L-03 (`pps31l3`): `0711215fcc1767f9aff5cee42cead479a605b37e56ccbfb5d025eaac211cae06`
- F-01 (`pps31f1`): `dfed4279095251f3acd34987e79e3a1eecfce16adaca31cc6c776e8f724e713a`
- F-02 (`pps31f2`): `436848b0e31bb43b9e54b2d494f808528d190faa1fb6d93cff9462c1148497e9`
- Q-01 (`pps31q1`): `ca095edfd77eb5c995570804e32901905437b90bc37ed74d5484860593878257`
- F-03 (`pps31f3`): `103002cc29903e4e5aada96eae77148b740846e289e2218d5d3f613404a20db0`

---

## Pre-broadcast actions

1. **Fix L-01 (required).** Replace the constant `WEI_SLACK = 2` with a slack derived from the vault, or treat positions whose predicted loss exceeds the bound as capped stragglers. Until then, anyone can stall the run for 9 wei of DOLA while V1 is unpaused, and it can also happen organically.
2. **Fix L-03, or deal with the stale Pauser entries (required).** Move the pauser away from `0x3984…19F4` and `0xf5F9…0E5B` and unregister them (or unpause them), so V2 and Antimatter do not arrive behind a dead breaker. Add a check that pausability actually works. Resolve MR-31-SSV2C-01 alongside this.
3. **Human sign-off on F-03 (required).** Record owner approval of the Antimatter phUSD mint grant in story-082 or a follow-up story. The story is currently machine-approved only.
4. **L-02 (recommended).** Add an assert-only verification pass, so the `&&` tail of `:broadcast` proves the live deployment rather than simulating the missing steps over it.

F-01, F-02 and Q-01 do not block the broadcast. F-01 and F-02 need a human disposition, and Q-01 needs to be run on anvil to confirm.

---

*Evidence:* `side-effects.json`, `fork-logs/preview-25975869.log`, `fork-logs/h-{A,B,F,G}*.log`, `fork-logs/h-test_{C,C2,D,E}_*.log`. Harness: `phoenix-phase-2-staging/work/test/audit-run31/CutoverAuditRun31.t.sol`, written by the audit and not part of the audited source.
