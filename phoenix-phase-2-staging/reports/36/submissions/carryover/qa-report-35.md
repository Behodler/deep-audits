# Carryover QA report: audit 35 (entry points `stable-staker-v2-cutover`, `dola-ys-withdrawal:status`, `initiate-dola-ys-withdrawal`), carried at audit 36

> **Carryover QA report, audit 35** (cut down from
> [`reports/35/submissions/qa-report.md`](../../../35/submissions/qa-report.md)). Audit 36 prepended this header and pruned one entry.
> Retained below (still open / fix-pending as of audit 36): **L-09, L-10, Q-05, Q-06** (`stable-staker-v2-cutover`), **Q-01** (`dola-ys-withdrawal:status`), **Q-01** (`initiate-dola-ys-withdrawal`).
> Removed as no longer live: **L-11** (`pps35l11`, `e6e1f293bbad`): `wont-fix` (human triage 2026-09-16).
> Labels are the originals — the gap between L-10 and Q-05 is the L-11 removal above, not an omission. Relative links in the body (`./carryover/…`, `./spec-conformance.md`) point into the audit-35 directory.
>
> **Audit-36 disposition (no status was changed).** Every retained entry is no longer flagged at `91ed727`: the stories 093–097 fixes landed and were verified on an anvil mainnet fork (block 25994908). Each is **PROPOSED `fixed`; only a human applies it.** Evidence for all: [`reports/36/script-audits/cluster-analysis.md`](../../script-audits/cluster-analysis.md) (Verdicts on prior entries).
>
> | Entry point | Label | issueId | Fingerprint | Status | Run-36 evidence (short) | Apply |
> |---|---|---|---|---|---|---|
> | stable-staker-v2-cutover | L-09 | `pps35l9` | `78cb5942d4834f366ab7d5600a449c73bb8d43833dd8b822e25801d623e39cc6` | fix-pending (fix owed, not yet verified) | Story 094 two-leg flow: real broadcast re-seeded mined R, OWNER DOLA 0, `:verify` residual 0 | `/ledger phoenix-phase-2-staging fixed 78cb5942d483` |
> | stable-staker-v2-cutover | L-10 | `pps35l10` | `72e528c8715f0fb1e6c4fb3a7b98844c7f5cf0cc2211cb376a20cd2f3356dbc1` | fix-pending (fix owed, not yet verified) | Story 095: 27M budget vs 25.17M leg-1 peak, 7.26% headroom re-measured | `/ledger phoenix-phase-2-staging fixed 72e528c8715f` |
> | stable-staker-v2-cutover | Q-05 | `pps35q5` | `df5f14bae8a75c93f0c162bd3d4b842c21215bd12656531f51b356ec7dd75bc6` | open (untriaged) | Story 095: breaker paragraph names both dead windows; tx counts match the anvil run | `/ledger phoenix-phase-2-staging fixed df5f14bae8a7` |
> | stable-staker-v2-cutover | Q-06 | `pps35q6` | `9c4e21bb9fd79d8bc0f09ed0089b2cd63d94bfdbcdd1e44728b1ef4b324ab08c` | open (untriaged) | Story 093: no conflict markers, deployments JSON parses, CI guard added | `/ledger phoenix-phase-2-staging fixed 9c4e21bb9fd7` |
> | dola-ys-withdrawal:status | Q-01 | *not minted* | `8633815e4b2b833011046cf0ded65501329f76f0bf6fee6a79840d6b0e845a7f` | open (untriaged) | Story 097: status phases agree with the cutover gate at every anvil stage | `/ledger phoenix-phase-2-staging fixed 8633815e4b2b` |
> | initiate-dola-ys-withdrawal | Q-01 | *not minted* | `4cdafc61037cb255ee4422487b88a8f0654718b6fbef5c6bb658c66d9b6a879e` | open (untriaged) | Story 097: margin line, start deadline, LOCAL-PASS ESTIMATE labels, status pointer printed | `/ledger phoenix-phase-2-staging fixed 4cdafc61037c` |
>
> **Still outstanding for a human:** the two `Q-01` entries have no issueId (both would derive to `pps35q1`); story 090's AC text still omits the 6h margin (PO task).
> - **First seen:** phoenix-phase-2-staging-35 · **Last flagged:** phoenix-phase-2-staging-35 (`7ac6e70`) · **Not flagged at:** phoenix-phase-2-staging-36 (`91ed727`).
> - **Line numbers below were accurate at the originating commit `7ac6e70`. Re-verify them against current HEAD `91ed727` before acting.**

---

# QA Report for phoenix-phase-2-staging, run 35 (script audit)

- **Run**: `phoenix-phase-2-staging-35`
- **Source**: [Behodler/phoenix-phase-2-staging @ `7ac6e70`](https://github.com/Behodler/phoenix-phase-2-staging/tree/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963), branch `master`, read-only
- **Entry points**: `stable-staker-v2-cutover`, `dola-ys-withdrawal:status`, `initiate-dola-ys-withdrawal`
- **Inputs**: `reports/35/findings/low/*.json`, `reports/35/findings/qa/*.json`, `reports/35/script-audits/classified-findings.json`, `reports/35/script-audits/classification-log.md`
- **Fork evidence**: anvil fork of mainnet block 25990689. Every `fork-logs/…` path below is relative to `reports/35/script-audits/`.

> **Labels are per entry point.** Each entry point numbers its findings in its own sequence. `stable-staker-v2-cutover` continues from run 34 (L-08, Q-04), so this run adds L-09..L-11 and Q-05..Q-06. The two DOLA-withdrawal entry points each begin at Q-01. **Label `Q-01` therefore appears twice**, so every heading below names its entry point. Use the fingerprint or issueId as the stable handle, not the bare label.
>
> **Two issueIds are not minted yet.** Both `Q-01` findings would derive to `pps35q1`, which breaks uniqueness. Their records and ledger entries keep `issueId: null` until a human chooses the IDs. Reference them by fingerprint: `8633815e4b2b…` (status) and `4cdafc61037c…` (initiate). Their headings carry a `pending` stamp in place of an ID.
>
> **Carryover is not in this file.** Run-34 QA findings that are still open (L-08 `pps34l8`, Q-04 `pps34q4`) are in [`carryover/qa-report-34.md`](./carryover/qa-report-34.md). Faithfulness tags (F-L-09, F-L-10, F-Q-01@status, F-Q-01@initiate) are cross-listed in [`spec-conformance.md`](./spec-conformance.md). This file is the primary report for all seven findings.

## Summary

*Counts and the summary table updated by the audit-36 carryover to the retained set (original bundle: 3 Low, 4 QA; L-11 removed as wont-fix).*

| Severity | Count |
|----------|-------|
| Low Risk | 2 |
| QA (non-critical) | 4 |
| Centralization | 0 |
| **Total** | **6** |

| Entry point | Label | issueId | Severity | Fingerprint (12) | Flags |
|---|---|---|---|---|---|
| stable-staker-v2-cutover | L-09 | `pps35l9` | Low | `78cb5942d483` | **Human review: Low/Medium borderline.** Same root-cause class as promotion-ready:broadcast L-02 `b57dcb4bb594` |
| stable-staker-v2-cutover | L-10 | `pps35l10` | Low | `72e528c8715f` | **⚠ INCOMPLETE FIX** of fixed L-07 `d6896c6e843d` |
| stable-staker-v2-cutover | Q-05 | `pps35q5` | QA | `df5f14bae8a7` | Fix together with fix-pending Q-04 `a62956952abd` |
| stable-staker-v2-cutover | Q-06 | `pps35q6` | QA | `9c4e21bb9fd7` | **Human review: may belong under `dev`** (L-07 `98e72721`). Was proposed as Q-07 |
| dola-ys-withdrawal:status | Q-01 | *pending* | QA | `8633815e4b2b` | issueId not minted |
| initiate-dola-ys-withdrawal | Q-01 | *pending* | QA | `4cdafc61037c` | issueId not minted |

---

## Entry point: `stable-staker-v2-cutover`

### [stable-staker-v2-cutover L-09] Phase 6b re-seeds a DOLA amount fixed in forge's local pass. The mined result can leave excess collateral on OWNER without :verify noticing, or revert noMintDeposit and halt the session <!-- id: pps35l9 -->

- **Severity**: Low. **Human review: borderline Medium** (see below).
- **Entry point**: `stable-staker-v2-cutover`
- **Fingerprint**: `78cb5942d4834f366ab7d5600a449c73bb8d43833dd8b822e25801d623e39cc6`
- **Root-cause class**: `ForgeLocalPassPrecedesBroadcast`
- **Faithfulness**: F-L-09. Violates story-092 Technical Details step 5: "assert OWNER DOLA back to its level before execution, so no DOLA is left on OWNER".
- **Location**:
  - [CutoverStableStakerV2Mainnet.s.sol#L1116-L1145](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L1116-L1145) (`_minterReseedSdola`; the literal `approve`/`noMintDeposit` are at L1138-L1139 and the local-only post-checks at L1141-L1142)
  - [CutoverStableStakerV2Mainnet.s.sol#L166-L167](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L166-L167) (halt-point (b) NatSpec claim)
  - [VerifyStableStakerV2Cutover.s.sol#L318](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/VerifyStableStakerV2Cutover.s.sol#L318) (`_verifyPhase6b_minterMove`)
- **Related**: same root-cause class as **promotion-ready:broadcast L-02** `b57dcb4bb59489f0676ca1a6a44293be0057b0649be5551bab4723fa5cbbf135`. That finding is in a different script and entry point, so this is not a duplicate. Precedent: run-22 MR-22 / `MigrateSaga2Rescue.s.sol`. Compounds with L-11 `e6e1f293bbad` and L-10 `72e528c8715f`.

**Description.** The cutover is broadcast with `--broadcast --skip-simulation --slow --ledger`. Under those flags, forge runs the whole script once in a local EVM when the session starts, then signs the recorded calldata one transaction at a time. The steps are:

1. In Phase 6b, `_minterExecuteWithdrawal` computes `R`, the change in OWNER's DOLA balance, during that local pass.
2. `_minterReseedSdola` then records `DOLA.approve(minter, r)` and `minter.noMintDeposit(sdolaStrategy, DOLA, r)` with `r` as a literal value.
3. On chain, the execute is tx #43 of 67. It mines minutes to hours after the local pass and redeems a pro-rata share of the *live* autoDOLA shares at the *live* price.
4. Both post-checks run only in the local pass: `_doneMinterReseeded` and `balanceOf(OWNER) == ownerDolaBeforeExec`.
5. On the mined state, `:verify` only checks that the minter's sDOLA principal is at least the recorded local `R`. Nothing re-checks OWNER's leftover DOLA.

The resume path re-reads `R` from chain correctly. The first, uninterrupted run does not. The halt-point (b) NatSpec says "a local-pass R that differs from the mined one cannot strand or over-deposit". That claim is false outside the resume path.

**Impact.**
- **Excess branch: `R_mined > R_local`.** This is the default case, because the autoDOLA price accretes continuously. Collateral backing outstanding phUSD stays on the OWNER EOA instead of moving to the sDOLA strategy. The story AC is violated, `:verify` still passes, and nobody is told. The amount is dust, up to about 1 DOLA.
- **Revert branch: `R_mined < R_local`.** This happens if surplus leaves the minter between session start and tx #43. Triggers:
  - an `SYA.claim`, which any holder of the claim NFT can call
  - a Tokemak valuation step down

  OWNER holds about 0 DOLA of its own, so even a 1-wei shortfall makes `noMintDeposit` revert. When it does:
  - about 14.6k DOLA of phUSD collateral sits on a hot Ledger EOA
  - DOLA minting is disabled
  - an approval of about 14.6k DOLA to the minter is left behind. It is harmless, because the minter only pulls from `msg.sender`.
  - the operator must resume, which again needs the full 0.00792 ETH budget, while the 78h window runs and V2 stays paused

**Severity rationale.**
- **Why not Medium.** Nothing is lost or stolen. The collateral sits on the trusted owner's EOA. The documented, fork-proven resume restores it in one attended leg, and the revert is loud on an attended path. Minting and V2 availability are already off by design during the session.
- **Why not QA.** A story-092 AC is not enforced on chain, a NatSpec safety claim is false, and `:verify` cannot see the excess branch. Run-22 M-01 was Medium because that script had *no* outcome verification. Here `:verify` exists and covers registration and principal, and only OWNER's leftover balance goes unchecked.
- **Likelihood.** Low for the revert branch: 5 SYA claims in 30 days, against less than an hour of exposure before the execute, is under 1% per session. Phase 6's V1 relinquish adds about 27 DOLA of skimmable surplus mid-session, which is a mild incentive to claim.

> **⚠ HUMAN REVIEW: Low/Medium borderline.** The classifier kept this at Low. **Re-rate to Medium if either condition holds:**
> 1. The halt compounds with a late-window start. A revert here that outlives the minter window triggers L-11's staker freeze.
> 2. The number of pools, the pool sizes, or the SYA claim frequency grows materially.

**Evidence** (anvil fork 25990689; side-effects `UE-35-01/02`):
- **Clean broadcast.** Recorded args for txs #47/#48 are `14633137717790185615971`. The mined execute transferred `14633140027218540037484` to OWNER, and OWNER was left with `2309428354421513` wei of DOLA. `:verify` exited 0. See `fork-logs/07-cutover-run-latest.json` and `fork-logs/09-verify-clean.log`.
- **Injected run.** `fork-logs/inject-driver.sh` impersonates SYA and calls `skimSurplus(DOLA, claimer)`, which is byte-identical to the per-strategy call inside `SYA.claim`. The call removes 39.284 DOLA and mines after the local pass and before the execute, so the trigger order matches the headline. Result: tx #48 `noMintDeposit` failed with `SafeMath: subtraction underflow`. At the halt, OWNER held `14593854548308164103700` DOLA, DOLA minting was disabled, and the allowance was left at `14633137717790185615971`. See `fork-logs/12-cutover-broadcast-skimInjected.log`, `12-driver-skim.log`, `12-progress-halted.json` and `12-run-latest.json`.
- **Resume.** The log shows "recorded R differs … re-seeding the live delta", the run converges, and `:verify` exits 0. See `fork-logs/13-cutover-resume-after-skimHalt.log`, `13-progress-completed.json` and `14-verify-after-resume.log`.
- **Plausibility.** `fork-logs/sya-rewardscollected-30d.tsv` shows 5 claims in 30 days. `fork-logs/minter-phusdminted-30d.tsv` shows no DOLA mints.

**Recommended Mitigation.** Never sign an amount derived from state that an earlier signed transaction changes. Either option below works:
1. **End the first broadcast leg right after the execute.** When not resuming, stop after `_minterExecuteWithdrawal`, for example with a `PHASE6B_EXECUTE_ONLY` gate, or a deliberate `return` once `minterExecRecorded` has just been set. The operator then re-runs `:broadcast`, and its local pass reads the mined `R`. This reuses the resume path, which is already fork-proven.
2. **Re-seed a deliberately conservative amount**, then sweep the remainder in the resume or verify leg.

With either option, add two checks to `VerifyStableStakerV2Cutover._verifyPhase6b_minterMove`:
```solidity
require(IERC20(DOLA).balanceOf(OWNER) == minterMove.ownerDolaBeforeExec, "verify: OWNER DOLA residual");
// and bound the minter's sDOLA principal against the actual WithdrawalExecuted / DOLA Transfer amount
// read from the execute receipt logs, not against the recorded local-pass R.
```
Also correct the halt-point (b) NatSpec (L166-L167).

---

### [stable-staker-v2-cutover L-10] `CUTOVER_GAS_BUDGET` is still sized for the 46-transaction session. The 67-transaction session needs 25.16M gas against a 22M constant, so ETH_BUDGET\|OK can precede a halt mid-Phase 6 <!-- id: pps35l10 -->

- **Severity**: Low
- **Entry point**: `stable-staker-v2-cutover`
- **Fingerprint**: `72e528c8715f0fb1e6c4fb3a7b98844c7f5cf0cc2211cb376a20cd2f3356dbc1`
- **Root-cause class**: `StaleOperationalBudget`
- **Faithfulness**: F-L-10. The story-087 AC says the budget must cover the session so the operator is not halted mid-run with `-32003`. Stories 091 and 092 added 21 transactions without re-deriving it.
- **Location**:
  - [CutoverStableStakerV2Mainnet.s.sol#L411-L423](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L411-L423) (`CUTOVER_GAS_BUDGET = 22_000_000` and its derivation NatSpec)
  - [CutoverStableStakerV2Mainnet.s.sol#L456-L486](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L456-L486) (`_preflightOwnerEth`, `ETH_BUDGET|…` output)
  - [package.json#L52](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/package.json#L52) (the ":broadcast" comment still says "46 transactions")

> **⚠ INCOMPLETE FIX of L-07** (`pps33l7`, status **fixed** at `84e2324`). L-07's fingerprint is `d6896c6e843de66ebc7ef9202fb8071aa60fcc13a3f22b69323f1256f58d7bcd`. The preflight mechanism from that fix landed, but the constant it checks against was not re-derived after stories 091 and 092. L-07 is left `fixed` in the ledger. **A human decides** whether to reopen L-07 or keep L-10 as a separate entry.

**Description.** `CUTOVER_GAS_BUDGET = 22_000_000` is documented as 18,317,077 gas used plus 3,383,096 for the largest late gas limit (#37, USDe migrate). Those figures come from the 46-transaction rehearsal in audit 33. At `7ac6e70` the session is 67 transactions:
- Phase 3b adds a 3,106,997-gas CREATE plus 3 more transactions.
- Phase 6b adds 17 transactions, including the 559,036-gas execute.

`_requiredOwnerEth` computes 22M × price × 1.2, a gas-equivalent of 26.4M.

**Impact.** A fork broadcast with OWNER funded to exactly the required 0.00792 ETH at 0.3 gwei did complete, but with almost no slack:
- Total gas used was 22,982,701, already above the "budget".
- The node's upfront balance check is cumulative gas used so far plus the signed limit. It peaks at **25,163,101 on tx #41** (USDe migrate, signed limit 6,706,846). That leaves 1,236,899 gas, or 4.7%, of the 20% margin.
- Each extra USDe staker adds about 0.38M gas used and 0.77M gas limit to tx #41. V1 stays open until Phase 1, so about two new V1 USDe stakers, or normal limit variance, would make the node reject tx #41 or later with `-32003`.

The run would then halt mid-Phase 6 with V1 and V2 both paused, some pools possibly migrated, and the minter window running. The operator had trusted `ETH_BUDGET|OK`. The resume again requires the full stated budget.

**Severity rationale.** This is an owner footgun (Law 3). The preflight is the owner's own safety control, and it reports OK against a stale derivation whose own sizing rule now needs 25.16M, more than 22M. Failing loud before any transaction only protects against funding below the stated budget, not against a stated budget that is too low. It is not Medium: nothing is lost, the run is resumable, and a further condition (staker growth or limit variance above 4.7%) is needed. Likelihood is low to moderate.

**Evidence.**
- `fork-logs/07-gas-analysis.txt`, `07-gas-table.tsv` and `07-limits.txt`: per-transaction gas used and signed limits, from `cast tx <hash> gas`.
- `fork-logs/07-cutover-broadcast-budgetExact.log`: OWNER went from `7920000000000000` to `1025437594769664` wei.
- `fork-logs/06-cutover-broadcast-actualEth.log`: at OWNER's live balance the preflight refused and sent 0 transactions.
- `fork-logs/05-cutover-preview-executable.log`: `ETH_BUDGET|SHORTFALL 1524805707318410`.

**Recommended Mitigation.**
1. Re-derive the budget from the 67-transaction session. The binding figure is the maximum over transactions of (cumulative gas used before the transaction + its signed limit), which is 25.16M at block 25990689.
2. Round up, for example to 27M, and keep the 1.2× factor.
3. State the staker counts the figure assumes: DOLA 9, USDC 13, USDe 7.
4. Better still, have `:preview` compute the budget instead of relying on a constant. Sum the simulated gas per recorded transaction × 2 (the estimate multiplier), take the running maximum, and print `ETH_BUDGET` from that figure.
5. Update the "46 transactions" text in the `:broadcast` comment and in the NatSpec.

---

### [stable-staker-v2-cutover Q-05] The `:broadcast` comment still claims one breaker dead window and 46 transactions. Story 092 added a second dead window (autoDOLA `setPauser(OWNER)` to `Pauser.unregister`) and 21 transactions <!-- id: pps35q5 -->

- **Severity**: QA (non-critical, documentation drift)
- **Entry point**: `stable-staker-v2-cutover`
- **Fingerprint**: `df5f14bae8a75c93f0c162bd3d4b842c21215bd12656531f51b356ec7dd75bc6`
- **Root-cause class**: `StaleOperatorRunbook`
- **Location**:
  - [package.json#L52](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/package.json#L52) (the `//stable-staker-v2-cutover:broadcast` comment)
  - For comparison, the correct text: [CutoverStableStakerV2Mainnet.s.sol#L177-L182](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L177-L182) (halt (g) NatSpec)

> **Fix together with fix-pending Q-04** (`pps34q4`, fingerprint `a62956952abd4fe22391f1fbff9f5e219961d003367a3c8a1dc4162529b9ea86`), carried over in [`carryover/qa-report-34.md`](./carryover/qa-report-34.md). Both findings concern the same comment but are **distinct defects**, so neither suppresses the other. Q-04's Phase 7 overclaim is still present in this comment at `7ac6e70`, and the carryover flags it as a possible incomplete fix.

**Description.** The comment says: "The breaker is live for the whole session EXCEPT the one forced tx between V1.setPauser(OWNER) and Pauser.unregister(V1) … Every other halt point, including every Phase 7 one, keeps the breaker live and converges on resume." Story 092 retires 0x1760 with the same forced ordering. A halt between tx #56 (`setPauser(OWNER)`) and tx #57 (`unregister`) leaves `Pauser.pause()` reverting until OWNER calls `Pauser.unregister(0x1760)`. The comment also still says "46 transactions".

**Impact.** Suppose the session halts at tx #56 and the operator reads only the `:broadcast` comment. They would believe the breaker is live and might walk away, leaving the protocol-wide permissionless pause dead. There is no direct asset impact.

**Severity rationale.** QA. The second dead window and its remedy are documented correctly in the `//StableStakerV2Cutover` comment and in the script's halt (g) NatSpec, and `:preview` probes for it (a preview on the un-remedied halt reverts `globalPause(phase0)`). The stale `:broadcast` comment is a documentation defect.

**Evidence.** Static review of the `:broadcast` comment text (`stable-staker-v2-cutover/entry-manifest.json`) and the halt (g) NatSpec. The transaction indices come from the clean anvil run: tx #56 is `setPauser(address)` on 0x1760, and tx #57 is `unregister` on the Pauser (`fork-logs/07-gas-analysis.txt`).

**Recommended Mitigation.** Rewrite the breaker paragraph of the `:broadcast` comment in one edit that also fixes Q-04:
- Name both dead windows: V1 tx #1 to #2, and autoDOLA tx #56 to #57, whose remedy is for OWNER to call `Pauser.unregister(0x1760…)`.
- Name the two Phase 7 coverage gaps (the Q-04 fix).
- Replace "46 transactions" with the current count.

---

### [stable-staker-v2-cutover Q-06] Merge commit 7ac6e70 left unresolved conflict markers in `server/deployments/addresses.ts` and `local.json`, so `local.json` no longer parses <!-- id: pps35q6 -->

- **Severity**: QA (non-critical, repository hygiene off the mainnet path)
- **Entry point**: `stable-staker-v2-cutover`. **Human review: this finding may belong under the `dev` entry point** (see below).
- **Fingerprint**: `9c4e21bb9fd79d8bc0f09ed0089b2cd63d94bfdbcdd1e44728b1ef4b324ab08c`
- **Root-cause class**: `CommittedMergeConflictMarkers`
- **Location**:
  - [server/deployments/local.json#L5-L9](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/local.json#L5-L9), [#L120-L124](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/local.json#L120-L124), [#L408-L418](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/local.json#L408-L418)
  - [server/deployments/addresses.ts#L1-L5](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/deployments/addresses.ts#L1-L5)
  - [server/index.js#L34](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/server/index.js#L34) (`loadExtractedAddresses`)

> **⚠ HUMAN REVIEW: the entry point may be wrong.** This defect arguably belongs to the `dev` entry point. It relates to **dev L-07** (`pps28l7`, open, fingerprint `98e72721490398830324ab4cb3e7f31cb746ca7bce1f3e46c92d58fc761509c1`), which is about `local.json` being removed from git tracking. The fingerprint was left as sanitized. Proposed action: run `/recheck` on dev L-07 to decide whether to move this finding. No status change is proposed. The proposed label was Q-07; it became Q-06 so the QA labels stay sequential after the proposed Q-06 was raised to L-11.

**Description.** `<<<<<<< HEAD / ======= / >>>>>>> sprint/stable-staker-v2` blocks are committed in two places:
- the header comment at `addresses.ts` L1-L5
- `local.json` L5-L9, L120-L124 and L408-L418

`JSON.parse(local.json)` throws "Unexpected token <". `server/index.js` catches the error and returns `null`. `addresses.ts` is described as "copied directly into UI projects", and it will not compile there. Story ref: story-089 (address keys, local deployment).

**Impact.** The dev stack's `/contracts` endpoint loses the extracted addresses, and UI projects that copy `addresses.ts` get a TypeScript syntax error. It is certain to affect dev and UI consumers. The mainnet address patch is unaffected, which was fork-verified.

**Severity rationale.** QA. This is a repository hygiene defect with no asset impact, and it is off the mainnet broadcast path.

**Evidence.** `node -e 'JSON.parse(…)'` fails at line 5, and a grep finds the markers at the lines listed above (re-confirmed at `7ac6e70` while writing this report). `fork-logs/08-patch.log` and `08-mainnet-addresses.patch.diff` show the mainnet patch is unaffected.

**Recommended Mitigation.**
1. Resolve the conflicts: keep one generated header in `addresses.ts`, and regenerate `local.json` from the latest dev deploy.
2. Add a CI or pre-commit check that fails on conflict markers (`git diff --check`, or a grep for `^<<<<<<<|^>>>>>>>`) and runs `JSON.parse` over `server/deployments/*.json`.

---

## Entry point: `dola-ys-withdrawal:status`

### [dola-ys-withdrawal:status Q-01] Status prints "EXECUTABLE - cutover may broadcast now" during the last 6h of the window and while the strategy is paused, when the cutover will refuse to start <!-- id: pending (fingerprint 8633815e4b2b) -->

- **Severity**: QA (non-critical, incorrect operator signal)
- **Entry point**: `dola-ys-withdrawal:status`
- **Fingerprint**: `8633815e4b2b833011046cf0ded65501329f76f0bf6fee6a79840d6b0e845a7f`
- **issueId**: *not minted.* The ledger holds `issueId: null` until a human chooses the ID. Select this finding by fingerprint.
- **Root-cause class**: `StatusIgnoresConsumerGate`
- **Faithfulness**: F-Q-01@status. Story-092 runbook step 2 says "`npm run dola-ys-withdrawal:status` must say EXECUTABLE" and treats that line as the go signal. The story-092 Phase 0 AC, however, is `initiatedAt+6h <= now < initiatedAt+78h - WINDOW_SAFETY_MARGIN`.
- **Location**:
  - [DolaStrategyWithdrawalStatus.s.sol#L53-L60](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/DolaStrategyWithdrawalStatus.s.sol#L53-L60)
  - The start gate it fails to mirror: [CutoverStableStakerV2Mainnet.s.sol#L264](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/CutoverStableStakerV2Mainnet.s.sol#L264) (`WINDOW_SAFETY_MARGIN = 6 hours`)
- **Related**: initiate-dola-ys-withdrawal Q-01 `4cdafc61037c`. It has the same 6h-margin theme but different code and a different fix.

**Description.** The EXECUTABLE branch of the status script (`nowTs <= expiresAt`) mirrors the strategy's own window. It does not mirror the cutover's start gate, `block.timestamp + WINDOW_SAFETY_MARGIN < closesAt`, and it does not check `strategy.paused()`, even though the execute is `whenNotPaused`.

**Impact.** Between `initiatedAt + 72h` and `initiatedAt + 78h`, or while the strategy is paused, the operator is told "cutover may broadcast now". `:preview` and `:broadcast` will refuse in Phase 0, and the attempt is wasted. There is no asset impact, because the cutover fails closed before signing anything.

**Severity rationale.** QA. The operator gets the wrong signal for the consumer's gate, but the consumer fails closed before any transaction and prints guidance. The message mismatch is moderately likely; the asset impact is zero.

**Evidence.** On the anvil fork with `initiatedAt` aged to 75h, status printed "EXECUTABLE - cutover may broadcast now; seconds until expiry: 10783" (`fork-logs/04-status-last6h.log`). On the same state, the cutover `:preview` reverted with "Phase0: fewer than WINDOW_SAFETY_MARGIN seconds left…" (`fork-logs/04-cutover-preview-last6h.log`). The scanner's chain-ID sub-claim was refuted and is not part of this finding.

**Recommended Mitigation.**
- Split the phase output:
  - "EXECUTABLE – cutover may START (>6h left)"
  - "EXECUTABLE but too late to START a cutover (<6h left): wait for expiry, then re-initiate"
- When `strategy.paused()` is true, print an override: "strategy PAUSED – execute will revert".
- Import `WINDOW_SAFETY_MARGIN` from a shared constant instead of duplicating it.

---

## Entry point: `initiate-dola-ys-withdrawal`

### [initiate-dola-ys-withdrawal Q-01] The initiate script says to broadcast the cutover "between executableAt and expiresAt", which ignores story 092's 6h start margin, and prints timestamps from forge's local pass <!-- id: pending (fingerprint 4cdafc61037c) -->

- **Severity**: QA (non-critical, conflict between stories in operator output)
- **Entry point**: `initiate-dola-ys-withdrawal`
- **Fingerprint**: `4cdafc61037cb255ee4422487b88a8f0654718b6fbef5c6bb658c66d9b6a879e`
- **issueId**: *not minted.* The ledger holds `issueId: null` until a human chooses the ID. Select this finding by fingerprint.
- **Root-cause class**: `StoryConflictOperatorTiming`
- **Faithfulness**: F-Q-01@initiate. The script follows story-090's literal AC ("broadcast the cutover between executableAt and expiresAt"), but that text conflicts with story-092's `WINDOW_SAFETY_MARGIN` start gate, and story 090 was not updated. This is a conflict between stories, not an unsafe story.
- **Location**: [InitiateDolaStrategyWithdrawal.s.sol#L181-L196](https://github.com/Behodler/phoenix-phase-2-staging/blob/7ac6e7077b3f1bddbb7d7c98b15ff4502df92963/script/InitiateDolaStrategyWithdrawal.s.sol#L181-L196)
- **Related**:
  - dola-ys-withdrawal:status Q-01 `8633815e4b2b`: same 6h-margin theme, different script.
  - stable-staker-v2-cutover L-09 `78cb5942d483`: same local-pass versus mined-state theme.

**Description.** The readback, including `require(initiatedAt == block.timestamp)`, and the printed `initiatedAt` / `executableAt` / `expiresAt` all run after `vm.stopBroadcast()` inside forge's local EVM. With `--skip-simulation --ledger`, the mined `initiatedAt` is later by the confirmation latency, so the "READBACK OK" line asserts a local-pass state. The instruction line also leaves out the 6h safety margin that cutover Phase 0 enforces.

**Impact.** The operator plans the cutover against a deadline up to 6h, plus signing latency, later than the real start deadline. If they start near `expiresAt`, Phase 0 reverts, and they must re-initiate and wait another 6h. The consumer fails safe, so there is no asset impact.

**Severity rationale.** QA. This is a conflict between stories in operator output, and the consumer fails safe. Likelihood is low.

**Evidence.** On the anvil fork, the printed `initiatedAt` was `1789569551` (local pass), while the `WithdrawalInitiated` event and storage held `1789569586` (mined). See `fork-logs/02-initiate-broadcast-anvil.log` and `fork-logs/02-initiate-statediff.json`. The preview is at `fork-logs/01-initiate-preview.log`.

**Recommended Mitigation.**
- Print "start the cutover between executableAt and expiresAt − 6h (WINDOW_SAFETY_MARGIN)".
- Label the printed timestamps as local-pass estimates, and point the operator to `npm run dola-ys-withdrawal:status` for the mined values. That script also needs its Q-01 fix above.
- Update story 090's AC text to include the margin. The stories tree is read-only for the audit, so this is for the product owner.

---

## Centralization Risks

None this run. Owner-controlled actions in all three entry points were assessed under Law 3. Their non-obvious consequences are filed above as footguns (L-10, L-11). Actions with obvious consequences are trusted and not reported.

---

## Appendix: automated QA baseline (4naly3er)

**Not attached. The tool ran but crashed.** `yarn analyze` in `tools/4naly3er` was run against the submodule root, with a scope file listing `script/CutoverStableStakerV2Mainnet.s.sol`, `script/DolaStrategyWithdrawalStatus.s.sol`, `script/InitiateDolaStrategyWithdrawal.s.sol` and `script/VerifyStableStakerV2Cutover.s.sol`. It exited 1 inside the solc-0.8.27 wasm compile with `TypeError: Cannot read properties of undefined (reading 'contents')`, which points to an import-resolution failure on the scripts' nested `lib/` remappings. The partial output was discarded rather than attached as an empty "clean" report. This run's QA therefore has **no bot-report baseline**. The seven findings above come from manual review plus fork verification.
