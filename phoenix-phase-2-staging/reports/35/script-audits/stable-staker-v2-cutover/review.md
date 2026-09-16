# Script review: `stable-staker-v2-cutover` (run 35)

- **Source**: [Behodler/phoenix-phase-2-staging @ `7ac6e70`](https://github.com/Behodler/phoenix-phase-2-staging/tree/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963), branch `master`, read-only. Regression delta `84e2324..7ac6e70` (baseline run 34).
- **npm keys**: [package.json#L49-L55](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/package.json#L49-L55) (`:preview`, `:broadcast` with the backup/patch JS tail, `:verify`).
- **Stories**: 082-088 (carried), 088 (now in range), 091, 092; hard runtime dependency on 090. All resolve to one document each under `~/code/product-owner/stories/phStaging2/auto-complete/phStaging2-stable-staker-v2/`, machine-approved. 089 (DeployMocks) is out of scope under the owner ruling that rehearsal-fidelity findings are invalid.
- **Mode**: fork preview on anvil at mainnet block 25990689. `:broadcast` was simulated with `--unlocked` in place of `--ledger`. Nothing was sent to mainnet. Evidence paths below are relative to `reports/35/script-audits/`.
- **Primary report**: [`../../submissions/qa-report.md`](../../submissions/qa-report.md). Line links here use that report's corrected line numbers.

## Conclusion

The cutover does what stories 088, 091 and 092 intend on real bytecode. On anvil it completed all 67 transactions (22,982,701 gas), `:verify` passed, the address patch applied cleanly (57 = 57 keys), and the post-cutover status, initiate and smoke checks all read the retired state correctly. **0 High, 0 Medium.** This run files **3 Low and 2 QA** findings:

- **L-09.** One story-092 acceptance criterion holds only in forge's local pass. The Phase 6b re-seed amount `R` is signed as a literal, so the mined state can leave DOLA on OWNER without `:verify` noticing, or halt the session. Borderline Medium, flagged for human review.
- **L-10.** The ETH budget constant was not re-derived for the larger session and is now 4.7% from a mid-run `-32003` halt. This is an incomplete fix of L-07.
- **L-11.** A halt after Phase 6 that outlives the minter window keeps every migrated staker frozen.

Carryover: L-08 is proposed `fixed`. Q-04 is still live and should be fixed together with Q-05.

## 1. Does it do what it intends?

**Yes, with one acceptance criterion enforced only locally (L-09) and one control whose constant is stale (L-10).**

| Story / AC | Result | Evidence |
|---|---|---|
| 088: `ERC4626_MAX_LOSS_BPS` 2 → 5, Phase 0 Pauser-registration assert, Phase 7 HALT CAVEAT docs | Met. DOLA exit lost 0.47 bps and USDC 0.34 bps, against the 5 bps bound. The `:broadcast` comment still overclaims (Q-04, carryover) | `05`, `07` |
| 091: source/destination split, Phase 3b sDOLA `ERC4626YieldStrategy` deploy, persist, Pauser wiring, `setWithdrawer(SYA)` | Met. V2 DOLA principal lands on the sDOLA strategy, and V1 principal on 0x1760 is 0 | `07`, `09` |
| 092 Phase 0: window gate `T0+6h <= now < T0+78h − WINDOW_SAFETY_MARGIN` | Met. Preview at +75h reverts on the margin | `04-cutover-preview-last6h.log` |
| 092 Phase 6b: record minter config, disable DOLA, execute, compute `R`, re-seed, re-register, SYA repoint, retire the source | Met end to end. `:verify` passed with 29 per-user credits | `07`, `09` |
| 092 step 5: "assert OWNER DOLA back to its level before execution" | **Local pass only.** The clean broadcast left 0.002309 DOLA on OWNER and `:verify` passed | **L-09**; `07-cutover-run-latest.json`, `09-verify-clean.log` |
| 087: the ETH preflight must cover the whole session | Mechanism works (refuses at OWNER's live balance, 0 txs sent). **The constant is stale:** the binding upfront check is 25.16M against a 22M budget | **L-10**; `06`, `07-gas-analysis.txt` |
| 092 runbook / RE-INITIATE PATH | Documented. It omits the fact that stakers stay frozen during a window lapse | **L-11**; `16-R35-OBS04-test.log` |

Documented deviations, judged justified (not filed):
- **OBS-35-09(i).** Phase 0 skips the window check on `principal == 0` alone. The story wording also required "repoint done". Requiring both would deadlock the halt-after-execute resume (Decision 4). Principal cannot reappear, because DOLA minting is disabled before the execute.
- **OBS-35-09(ii).** The re-seed runs before registration, which shortens EOA custody by one transaction (Decision 1). The fork end state matches every story-092 Phase 8 assert.

## 2. Unintended side effects?

| ID | Effect | Classification |
|---|---|---|
| UE-35-01 | Clean run: `R_local` 14633.137717… vs `R_mined` 14633.140027…, so 0.002309 DOLA of minter collateral stays on OWNER. `:verify` is green | **Unintended → L-09** |
| UE-35-02 | A claim-equivalent `skimSurplus` (−39.28 DOLA) mined before tx #43 makes tx #48 `noMintDeposit` revert. The halt leaves 14,593.85 DOLA on OWNER, DOLA minting disabled and a dangling approval. The resume converges | **Unintended → L-09** |
| UE-35-03 | 38.58 DOLA of surplus (including V1's relinquished 26.90) is re-seeded as minter principal | Intended by story 092. Opportunity cost, not a loss |
| UE-35-04 | The standing OWNER→minter max DOLA approval is removed | Unintended but benign (reduces approval surface) |
| UE-35-05 | `registerStablecoin` zeroes `mintedToday` / `lastMintTimestamp` | Story-acknowledged. No effect at this block |

External protocol internals (Tokemak, sDOLA, sUSDe, Curve) are touched only through the intended exits and deposits.

## 3. Knock-on problems / cluster

- **Coupling with `initiate-dola-ys-withdrawal`.** Phase 0 and Phase 6b depend on a withdrawal initiated at least 6h earlier, with the execute mined no later than `T0+78h`. That coupling works as designed on the fork. V1's exit is not gated by the pending withdrawal, and the execute resets the status to None.
- **Window × halt × pause.** L-09 (revert branch) and L-10 are the two realistic halt sources inside the window. Either one, combined with operator latency beyond `T0+78h`, becomes L-11's staker freeze.
- **Go signal.** Operators are told to use `dola-ys-withdrawal:status` and the initiate script's printed deadline. Both ignore the 6h start margin (status Q-01, initiate Q-01). Phase 0 fails closed, so the cost is a wasted attempt, not an unsafe start.
- **Precedent.** L-09 is in the same `ForgeLocalPassPrecedesBroadcast` class as open `promotion-ready:broadcast` L-02 `b57dcb4bb594`, and as the archived `MigrateSaga2Rescue.s.sol`, where a forge-baked amount diverged by a few wei and reverted.
- **Off-chain address book.** The patch script extracts addresses correctly despite the committed conflict markers. The dev-server and UI breakage is Q-06.

## Findings register

Where links are pinned to `7ac6e70`.

| Label | Sev | Fingerprint | What | Mitigation | Where |
|---|---|---|---|---|---|
| L-09 (`pps35l9`) | Low (borderline M, human review) | `78cb5942d483` | The Phase 6b re-seed `R` is baked in forge's local pass. The mined execute can strand excess DOLA on OWNER without `:verify` noticing, or revert `noMintDeposit` and halt with ~14.6k DOLA on the EOA | End the first broadcast leg after the execute so the resume reads the mined `R`, add an OWNER-residual check to `:verify`, and fix the halt (b) NatSpec | [Cutover#L1116-L1145](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L1116-L1145), [#L166-L167](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L166-L167), [Verify#L318](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/VerifyStableStakerV2Cutover.s.sol#L318) |
| L-10 (`pps35l10`) | Low, ⚠ INCOMPLETE FIX of L-07 `d6896c6e843d` | `72e528c8715f` | `CUTOVER_GAS_BUDGET = 22M` was sized for 46 txs. The 67-tx session peaks at 25.16M on the upfront check (4.7% slack), so `ETH_BUDGET\|OK` can precede a `-32003` halt | Re-derive from the 67-tx run (max of cumulative gas used + signed limit), round up to about 27M and state the staker counts, or compute it in `:preview` | [Cutover#L411-L423](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L411-L423), [#L456-L486](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L456-L486), [package.json#L52](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/package.json#L52) |
| L-11 (`pps35l11`) | Low (QA/Low borderline, human review) | `e6e1f293bbad` | If a halt after Phase 6 outlives `T0+78h`, every resume reverts in Phase 0 before Phase 7 can unpause V2, so migrated stakers stay frozen until re-initiation plus 6h | Minimum: document the freeze in the RE-INITIATE PATH runbook. Preferred: let a lapsed-window resume run Phase 7 with DOLA minting kept disabled and 6b left pending | [Cutover#L597-L645](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L597-L645), [#L160](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L160) |
| Q-05 (`pps35q5`) | QA | `df5f14bae8a7` | The `:broadcast` comment claims one breaker dead window and 46 txs. Story 092 added a second window (autoDOLA tx #56 → #57) and 21 txs | Rewrite the breaker paragraph in one edit with Q-04: name both dead windows and their remedies, and the current tx count | [package.json#L52](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/package.json#L52), cf. [Cutover#L177-L182](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L177-L182) |
| Q-06 (`pps35q6`) | QA (entry point may be `dev`, human review) | `9c4e21bb9fd7` | Merge 7ac6e70 committed conflict markers in `addresses.ts` and `local.json`. `local.json` no longer parses and the dev `/contracts` endpoint loses addresses. The mainnet patch is unaffected | Resolve the markers, regenerate `local.json`, and add a CI conflict-marker / `JSON.parse` check | [local.json#L5-L9](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/local.json#L5-L9), [#L120-L124](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/local.json#L120-L124), [#L408-L418](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/local.json#L408-L418), [addresses.ts#L1-L5](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/addresses.ts#L1-L5) |

### Carryover (run 34, not re-filed)

| Label | Status | Fingerprint | What | Mitigation | Where |
|---|---|---|---|---|---|
| L-08 (`pps34l8`) | fix-pending → **propose fixed** | `6022a9eb9989` | The Phase 6 ERC4626 loss bound sat inside autoDOLA's live spread. It is now 5 bps against 0.47 / 0.34 bps measured. Residual: the bound is still checked only in the local pass (L-09 class) | Human applies `/ledger phoenix-phase-2-staging fixed 6022a9eb9989` | [Cutover#L252](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L252) |
| Q-04 (`pps34q4`) | fix-pending, **still live** (possible incomplete fix) | `a62956952abd` | The `:broadcast` comment still says every Phase 7 halt keeps the breaker live | Fix in the same edit as Q-05, then `/recheck … a62956952abd` | [package.json#L52](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/package.json#L52) |

L-07 `d6896c6e843d` stays `fixed`, and L-10 carries `incompleteFixOf`. The other fixed entries (L-01 to L-06, F-01, Q-02) showed no regression on the fork. The wont-fix entries (F-02, Q-01, F-03, Q-03) are unaffected.

## Refuted / not filed

| Obs | Verdict | Reason |
|---|---|---|
| OBS-35-05 | Confirmed behaviour, not filed | `registerStablecoin` resets the mint-window counters. The window had elapsed 45 days earlier, so the effect is nil. The worst case is one fresh 4,000 phUSD fully collateralised window. Story-acknowledged |
| OBS-35-06 | Confirmed value routing, not filed | `R − P` = 38.58 DOLA becomes minter principal, and story 092 records `R > P` as intended. This is protocol-owned yield moving into phUSD collateral: opportunity cost, not loss |
| OBS-35-08 | Confirmed ordering, not filed | The live preview cannot run until `T0+6h`. Initiation moves nothing and can be re-initiated, and story 092 prescribes this order. Suggestion only: a preview-only simulated initiation |
| OBS-35-09(i) | Documented deviation, justified | Skip on `principal == 0` alone. Requiring "AND repoint done" would deadlock the halt-after-execute resume (Decision 4) |
| OBS-35-09(ii) | Documented deviation, justified | Re-seed before registration shortens EOA custody (Decision 1). The end state matches Phase 8 |
| OBS-35-09(iii) | Confirmed, benign | The standing OWNER→minter max approval is removed. No non-archived script relies on it |
| OBS-35-07 (patch/tsc break) | Refuted for the cutover path | The patch regex is unaffected (57 = 57, exit 0) and the repo has no tsc step. The residual dev breakage is filed as Q-06 |
| OBS-35-I2 (Temp.s.sol out-of-band execute) | Not filed (Law 3) | It needs a knowing out-of-band OWNER `totalWithdrawal` inside a window the owner opened. "Pulls V1 stakers' value" is overstated because `_totalWithdraw` is pro-rata by principal. It only matters below par, and autoDOLA is above par |
| OBS-35-10 | Noted, not filed | Stories 082-092 sit in the undocumented `auto-complete` state and are machine-approved |

## Limits of this review

- `initiatedAt` was aged in storage rather than warped, because a real 6h warp reverts the execute with `InvalidDataReturned()` against the fork-frozen Chainlink feed.
- L-09's DOLA-mint trigger (0 mints in 30 days) and its Tokemak down-step trigger were not reproduced. The skim trigger was.
- The live bytecode at 0x1760, the minter and SYA is not Etherscan-verified. Selectors and behaviour were corroborated on the fork only.
- 4naly3er crashed, so there is no automated QA baseline.
