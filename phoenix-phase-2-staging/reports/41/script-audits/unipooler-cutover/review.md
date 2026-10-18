# Script review: `unipooler-cutover` (phoenix-phase-2-staging, run 41)

| | |
|---|---|
| **Entry point** | `unipooler-cutover` (`:preview` / `:broadcast` / `:verify`), `package.json` [L76](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/package.json#L76) |
| **Source** | `phoenix-phase-2-staging` @ [`e75ee07`](https://github.com/Behodler/phoenix-phase-2-staging/tree/e75ee0776efcf20918b7db71d717eafb61bbd1a6), branch `master` (trunk); nested `lib/yield-claim-nft` @ `0fd6bdf` |
| **Story** | phStaging2 **103** `auto-complete/phStaging2-Balancexit/103-mainnet-unipooler-cutover-script-stage2.md`, plus amendments 2026-10-07 (ycn 052 escrow), 2026-10-08 (L-27), 2026-10-10 (F-02-052) |
| **Mode** | fork-preview at live mainnet. CLI preview at block **26,221,761** (`-vvvv`); exact `npm run unipooler-cutover:preview` at **26,221,847**; live head at start 26,221,713 |
| **Scan type** | First audit of this entry point (cold for the entry point). Reconciled against open run-39/40 findings and the routed yield-claim-nft fixes |
| **Closure** | `script/DeployMainnetUniPoolerCutover.s.sol`, `script/VerifyUniPoolerCutover.s.sol`, `script/helpers/UniPoolerCutoverCore.sol`, `scripts/quote-balancer-exit-min-amounts.js`, `scripts/patch-mainnet-addresses-unipooler-cutover.js`, `src/periphery/UniswapHelper.sol` (cluster), yield-claim-nft `UniPoolerCutoverEscrow`, `BalancerPoolerV2`, `BalancerPoolerMintDebtHook` |

## Headline

**0 High / 0 Medium.** 4 Low, 3 QA and 2 faithfulness findings. Nothing moves value out of protocol custody, and nothing lets a third party extract it. In every failure mode found, the BPT stays on the old pooler or in the escrow, OWNER is never credited, and `escrow.abort()` or a re-quoted call recovers. The Lows are liveness hazards on a one-shot migration with a hard deadline: Balancer pauses the pool on **30 Oct 2026**, 12 days after this review.

Two Lows are flagged as **borderline Medium** for owner review: L-01 (the OnlyDispatcher window) and L-03 (the pair-poisoning brick). The conditions under which each would become Medium are in the [QA report](../../submissions/qa-report.md#borderline-owner-decision-needed).

The script is fit to broadcast once the operator works through the [pre-broadcast checklist](#operator-pre-broadcast-checklist) below. None of the findings blocks the broadcast if the checklist is followed.

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| [L-01](../../submissions/qa-report.md#l-01-index-4-mints-revert-onlydispatcher-for-12-broadcast-txs-tx-819-between-hooksetdispatcher-and-replacedispatcher-and-a-halt-inside-that-window-has-no-resume-path) `pps41l1` | Low (footgun, borderline M) | Index-4 mints revert `OnlyDispatcher` for 12 txs (tx 8..19), and a halt inside that window (Ledger, gas spike, OWNER ETH exhausted) has no resume path | Run step 9 (configure) before step 8 so the window is 2 txs; fund OWNER per the gas formula and document a receipts-driven resume | [`UniPoolerCutoverCore.sol#L337-L344`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/helpers/UniPoolerCutoverCore.sol#L337-L344) |
| [L-02](../../submissions/qa-report.md#l-02-script-does-not-mitigate-ycn-l-28-with-10-bps-floors-and-a-public-mempool---slow-broadcast-a-30-susds-swap-010-fee-between-tx-4-and-tx-5-reverts-exitandseed) `pps41l2` | Low | ycn L-28 not mitigated: a ~30 sUSDS Balancer swap (~$0.10 fee) between tx 4 and tx 5 reverts `exitAndSeed` through the public mempool | Broadcast through a private relay (at least tx 5) and quote at 40–50 bps, or record that the owner accepts public-mempool exposure | [`DeployMainnetUniPoolerCutover.s.sol#L402-L430`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/DeployMainnetUniPoolerCutover.s.sol#L402-L430), [`package.json#L76`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/package.json#L76) |
| [L-03](../../submissions/qa-report.md#l-03-canonical-susdsphusd-pair-does-not-exist-on-mainnet-yet-anyone-can-createpair-and-sync-11-wei-for-1-2-of-gas-after-which-the-cutover-fails-step-2-permanently-and-the-script-has-no-recovery-branch) `pps41l3` | Low (borderline M) | The canonical pair does not exist yet. Anyone can `createPair` and `sync` 1+1 wei (~$1–2 gas), and step 2 then fails permanently with no recovery branch | Check reserves are (0,0) just before the broadcast; optionally pre-create the pair; prepare (do not run) an atomic transfer + `pair.mint` recovery helper | [`UniPoolerCutoverCore.sol#L478-L483`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/helpers/UniPoolerCutoverCore.sol#L478-L483) |
| [L-04](../../submissions/qa-report.md#l-04-uniswaphelper_requirepair-is-still-existence-only-at-e75ee07-if-story-111s-helper-is-deployed-and-ui-exposed-before-this-cutover-an-honest-add-liquidity-in-the-tx-1---tx-5-window-makes-exitandseed-revert-pairnotempty) `pps41l4` | Low (footgun) | `UniswapHelper._requirePair` checks existence only. If the helper ships first, an honest add-liquidity in the tx 1→5 window reverts `exitAndSeed` | Deploy `uniswap-helper` only after `unipooler-cutover:verify` passes, or add a non-zero-reserves check to `_requirePair` | [`UniswapHelper.sol#L428-L431`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/src/periphery/UniswapHelper.sol#L428-L431) |
| [Q-01](../../submissions/qa-report.md#q-01-rescue-amounts-txs-2021-and-the-withdrawbpt-amount-are-baked-in-forges-local-pass-interim-index-4-mints-or-third-party-dust-leave-a-residue-on-the-paused-old-pooler-that-makes-the-mandatory-verify-tail-hard-fail) `pps41q1` | QA | Rescue amounts (tx 20/21) are fixed in forge's local pass. Interim mints or 1-wei dust leave residue on the old pooler and the `:verify` tail hard-fails | Downgrade the sUSDS/USDS residue check in `_checkDrained` to a warning that prints the `rescueERC20` command; keep the BPT check hard | [`UniPoolerCutoverCore.sol#L671-L711`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/helpers/UniPoolerCutoverCore.sol#L671-L711), [`DeployMainnetUniPoolerCutover.s.sol#L251-L254`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/DeployMainnetUniPoolerCutover.s.sol#L251-L254) |
| [Q-02](../../submissions/qa-report.md#q-02-no-resume-tooling-_alreadycompleted-treats-configs4--unipooler-tx-19s-effect-alone-as-completed-so-a-crash-after-tx-19-re-runs-as-nothing-to-do-the-headers-_fundescrow-resume-claim-is-true-of-no-reachable-path) `pps41q2` | QA (faithfulness facet) | No resume tooling: a crash after tx 19 re-runs as "Nothing to do", and the header's claim that resumes go through `_fundEscrow` is true of no reachable path | Make `_alreadyCompleted` require the full end state and list missing txs 20–24; fix the header or add a guarded `RESUME_ESCROW` entry | [`DeployMainnetUniPoolerCutover.s.sol#L450-L468`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/DeployMainnetUniPoolerCutover.s.sol#L450-L468), [`#L50-L54`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/DeployMainnetUniPoolerCutover.s.sol#L50-L54) |
| [Q-03](../../submissions/qa-report.md#q-03-plan-4-step-11s-post-broadcast-forked-test-mint-dispatches-wraps-and-accrues-debt-never-runs-against-landed-state-verify-has-no-mint-and-the-broadcast-tails-trailing-preview-is-a-guaranteed-no-op) `pps41q3` | QA (faithfulness facet) | Plan §4 step 11's post-broadcast test mint never runs on landed state: `:verify` has no mint and the trailing `:preview` is a no-op | Move the dealt-user index-4 test mint (in a reverted snapshot) into `VerifyUniPoolerCutover.run`; drop or relabel the trailing `:preview` | [`VerifyUniPoolerCutover.s.sol#L35-L85`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/VerifyUniPoolerCutover.s.sol#L35-L85) |
| [F-01](../../submissions/spec-conformance.md#f-01-story-103s-background-still-prescribes-the-superseded-owner-custody-cutover) `pps41f1` | Faithfulness (QA) | Story 103 Background (L63-75) still prescribes the superseded OWNER-custody flow; the code correctly follows the 052 escrow amendment | Mark the Background "Cutover sequence" superseded inline and point it to the 2026-10-07 amendment; correct `BalancerWinddownPlan.md` §4 | [`UniPoolerCutoverCore.sol#L48-L58`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/helpers/UniPoolerCutoverCore.sol#L48-L58), [`#L525`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/helpers/UniPoolerCutoverCore.sol#L525) |
| [F-02](../../submissions/spec-conformance.md#f-02-story-103-names-the-wrong-third-party-bpt-holders) `pps41f2` | Faithfulness (QA) | Story 103 (L120, L217) names three third-party BPT holders that each hold 0 BPT; 37.1% of supply sits elsewhere | Update the holder list (run 40: `0xc65f…e8db`) or drop the named addresses and keep "only the old pooler's BPT is exited" | [`quote-balancer-exit-min-amounts.js#L101`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/scripts/quote-balancer-exit-min-amounts.js#L101), [`UniPoolerCutoverCore.sol#L521`](https://github.com/Behodler/phoenix-phase-2-staging/blob/e75ee0776efcf20918b7db71d717eafb61bbd1a6/script/helpers/UniPoolerCutoverCore.sol#L521) |

Labels are scoped to this run and entry point: run-41 `L-01` is not run-40 L-01 or run-39 L-01. Seven of the nine are still-open manifestations of earlier ledger entries in this entry point (see [Routed fixes and reconciliation](#routed-fixes-and-reconciliation)). Q-02 and Q-03 are new.

---

## 1. Does it do what it intends?

**Yes.** The script implements story 103 together with all three amendments, and every declared pre- and post-condition holds on a live-mainnet fork.

### What the story asks for, and what was observed

| Story 103 requirement | Observed |
|---|---|
| Cut NFTMinterV2 index 4 from BalancerPoolerV2 `0x7f68…11F1` to a fresh UniPoolerV2 on the canonical sUSDS/phUSD UniV2 pair, in one owner session | 24 OWNER txs. `configs(4)` = UniPoolerV2, with price `18171715966592552134`, growth 1 and disabled=false unchanged |
| No protocol funds through any EOA (ycn 052) | OWNER has **zero** token delta in BPT, sUSDS, phUSD and USDS after every one of the 13 core steps (core not-credited invariant plus state diff) |
| Exit the old pooler's whole BPT (PROPORTIONAL by default, RECOVERY via `RECOVERY_EXIT=true`), seed the pair, LP to UniPoolerV2 | 20,401.809 BPT moved old → escrow and burned. Seeded 18,249.048 sUSDS / 22,958.789 phUSD, 0.10% above the 10 bps floors. 20,468.904 LP to UniPoolerV2 |
| `hook.pull()`, then `mintDebt()==0`; `hook.setDispatcher(new)` before `new.setHook(hook)` | `pull()` is a no-op (debt 0). Order holds (tx 6 → 7 → 8) |
| Copy PSM, maxTout, batchMinter, batchDonationSize, nudgeStreamer; re-authorize the same four poolers; no Pauser registration | All copied, four poolers at `poolerAuthVersion` 1. No Pauser write |
| Move old pooler's sUSDS to the new pooler; parked USDS → escrow → `wrapUsds()` | 2,609.475 sUSDS rescued; 471,642,227,069 USDS wrapped into 423,653,907,109 sUSDS shares on UniPoolerV2 |
| Retire the old pooler: `setMinter(OWNER)` + `pause()` | Old pooler paused, minter = OWNER, holds 0 BPT / 0 sUSDS / 0 USDS |
| L-27: live `old.pool()==escrow.bpt()` guard before `withdrawBPT` | Present at core L519-525 and fork-proven, including a non-vacuity test (see [§ Routed fixes](#routed-fixes-and-reconciliation)) |
| F-02-052: no owner→escrow BPT transfer; floors sized on the old pooler's BPT only | Confirmed. In-test floors equal the CLI quote to the wei |
| Revision 2: no escrow balance check that a third-party donation can fail | Escrow checks are delta-only; residuals are warnings |

The seed price is 1 sUSDS = 1.2581 phUSD. That equals the Balancer mid (1.2543 after the 0.30% fee), so the seed opens no arbitrage gap.

### Pre/post-conditions and runs

- **13 pre-condition groups passed**: chainid, fresh progress, 11 address-book keys, live wiring, non-zero floors, ownership, story-099 revoke, index/hook wiring, empty pair, escrow immutables, L-27 guard, floor band, owner-not-credited.
- **12 post-condition groups passed**: LP/floors, `mintDebt==0`, hook ↔ pooler, config copy, index config, rescue/wrap deltas, old pooler retired, `_assertRetired` + `_checkWiring` + `_checkDrained`, preview E2E mint, preview `quotePool`-floored `pool()`, `:verify` on post-cutover state, and no progress file written by preview.
- **Preview exits 0** in both the CLI run (`logs/preview-proportional.vvvv.log`) and the exact npm key (`logs/preview-npm-key.log`, "Script ran successfully.").
- **`RECOVERY_EXIT=true` fails closed on the live pool.** It reverts in forge's local pass, so nothing would be signed: `PoolNotInRecoveryMode(0x642BB6860b4776CC10b26B8f361Fd139E7f0db04)` from inside `escrow.exitAndSeed → Router.removeLiquidityRecovery` (`logs/preview-recovery-live.log`).
- **RECOVERY works once the pool is in Recovery Mode.** It succeeds and `:verify` passes after governance `pausePool` plus the permissionless `vault.enableRecoveryMode(BPT)` on a fork. It also succeeds when only the Vault is paused. It reverts after `pausePool` without `enableRecoveryMode`.
- **`:verify` exits 1 before the broadcast, as designed** ("no progress file"). It passes against the post-cutover fork state.
- **Tests:** audit fork suite `work/test/audit-run41/UniPoolerCutoverRun41.fork.t.sol` **17/17 PASS** at 26,221,761. Upstream story-103 suites **56/56 PASS** (Mainnet fork 11, Core 37, VerifyGuards 8).

### Where it falls short of the story text

- **Step gating** (`_isConfigured` / `_trackConfig`) was not implemented. It was replaced by all-or-nothing refusal, which the story discloses as Decision 7. Part of the rationale for that decision is false (see **Q-02**).
- **Plan §4 step 11's post-broadcast test mint** only runs before the broadcast (see **Q-03**).
- The **story text itself** is stale in two places, F-01 and F-02. In both cases the code is correct and the document is wrong.

---

## 2. Unintended side effects?

**None.** Every persistent write maps to a stated step.

| Measure | Value |
|---|---|
| OWNER top-level txs (what `--broadcast` signs) | **24** |
| Persistent storage writes (excluding the harness script's own 63 local writes) | **149** |
| Events | **52** |
| Unintended effects | **0** |
| Simulated gas | ~9.36M (~0.0028 ETH at the 0.3 gwei default; OWNER holds 0.01303 ETH) |

### Two incidental effects, both explained

1. **Orphaned default hook.** UniPoolerV2's base constructor (`ATokenDispatcherV2.sol:51`) deploys a `DefaultDispatchHook`. Tx 8 `setHook` replaces it, and it is left orphaned and empty. This is by design in the base contract and moves no value. The closure manifest's created-contracts list does not include it.
2. **Sky Vat writes.** `escrow.wrapUsds → sUSDS.deposit` triggers `sUSDS.drip()`, which writes `suck`/`move` to the Sky Vat (SSR accrual). This is accounting inside an external protocol, not a movement of protocol funds.

### End state

- **OWNER:** 0 BPT, and zero delta in all four tokens and in ETH apart from gas.
- **Old pooler:** 0 BPT / 0 sUSDS / 0 USDS, paused, minter OWNER.
- **Escrow:** 0 of all four tokens.
- **UniPoolerV2:** holds all of the new pair's non-burned LP, plus 2,609.475 sUSDS and the wrapped shares.
- **No writes** to MultiPooler, NudgeStreamer, BatchNFTMinter, Pauser, MintPageView or NFTStaker. No phUSD mint and no change to phUSD's minter set.

### OnlyDispatcher window

The window opens at tx 7 (`hook.setDispatcher`) and closes at tx 19 (`replaceDispatcher`). Index-4 mints revert during it. That is in the stated sequence, so it is not counted as an unintended effect, but its length and the lack of a resume path are reported as **L-01**.

---

## 3. Knock-on and cluster effects

| Sibling | Relationship | Verdict |
|---|---|---|
| `balancer-holding` (story 099) | Precondition: all four poolers revoked on the old pooler | **Holds on chain**: `authVersion` = 2, each `poolerAuthVersion` = 1, and the step-0 require passes. The open sibling finding pps40 L-01 (`59527bfa8478`, four hardcoded addresses) is unchanged by this script and belongs to that entry point; it is not re-filed |
| `uniswap-helper` (stories 109/111) | Shares the canonical pair | **Not deployed** (address-book `UniswapHelper` = `0x0`). It must be deployed **after** the cutover. Story 111's "may go before or after" is unsafe for the "before" order (**L-04**, reconciles pps40 L-02) |
| `dev` / DeployMocks Phase 11.7 | Uses `UniPoolerCutoverCore` verbatim | **UI mock, not a rehearsal** (owner ruling 2026-09-15), so no rehearsal-fidelity findings are filed. Its strict escrow-empty assertion is not a mainnet concern |
| `stable-staker-v2-cutover` (completed) | Its phUSD-minter mask includes MINT_DEBT_HOOK | No interaction: no phUSD minter writes, no mint, hook recipient unchanged |
| MintPageView | Reads `configs(4)` and then `primeToken()` | Keeps working (UniPoolerV2.primeToken = USDS). Its NatSpec still names BalancerPoolerV2 (cosmetic) |
| MultiPooler / off-chain pooling bots | MultiPooler forwards only the 4-arg Uniboost `pool` | UniPoolerV2's 3-arg `pool` cannot be reached through MultiPooler. BalancerPoolerV2 had the same limitation, so nothing regresses. Off-chain bots must switch to `pool(sUSDSIn, minPhusdOut, minLP)` (observation only) |

**Stale PoCs.** The run-39 and run-40 PoCs in `work/test/audit-run39/**` and `work/test/audit-run40/**` no longer compile against the rewired core. This is **bit-rot, not evidence that those findings were fixed**. They were excluded with `--skip`, and each finding was re-judged from fresh run-41 tests.

---

## Routed fixes and reconciliation

> **None of the transitions below has been applied.** Every status change is a **proposal only**. A human applies it through `/ledger`. No entry in `../yield-claim-nft/ledger.json` was written by this run. Source: `proposed-transitions.json` (`"applied": false`).

### Fixes routed from yield-claim-nft to story 103

| Entry | Status | Verdict | Proposed command |
|---|---|---|---|
| ycn **L-27** `ycn22l27` (`2268ead7cba4`) | fix-pending | **Satisfied → propose `fixed`.** A live `pool()==escrow.bpt()` guard sits immediately before the only `withdrawBPT` call site (core L519-525). Fork tests: the script flow with `setPool` injected (guard reverts, `withdrawBPT` called 0 times), the direct amendment test, the guarded re-fund after `abort()`, and a non-vacuity test showing the unguarded manual path strands 1000 DAI. The one residual (the header's `_fundEscrow` resume claim) is documentation and is filed as Q-02, not as an incomplete fix | `/ledger yield-claim-nft fixed 2268ead7cba4` |
| ycn **F-02-052** `ycn22f2` (`5a7732a4ea71`) | fix-pending | **Satisfied → propose `fixed`.** No owner→escrow BPT transfer exists. Floors are checked against `bptWithdrawn`, and the quote sizes on `BPT.balanceOf(OLD_POOLER)`. Non-zero owner BPT is reported only, and the upstream test proves it is neither moved nor a cause of a revert | `/ledger yield-claim-nft fixed 5a7732a4ea71` |
| ycn **L-28** `ycn22l28` (`d77a482de757`) | fix-pending | **FIX-PENDING STILL LIVE (owed, not delivered) → manifests as L-02.** Story 103 never claims to address L-28: no private relay, bundle or MEV handling. Since no fix was attempted, this is not an INCOMPLETE FIX signal. Keep it fix-pending. Its closeCondition (wont-fix as obsolete after a successful mainnet cutover) applies only after the broadcast lands | none |

### phStaging run-39/40 entries proposed `fixed`

| Entry | Verdict | Proposed command |
|---|---|---|
| **pps40l1** (`7d5a26570be9`, OWNER EOA custody across txs) | The escrow makes exit and seed one atomic tx (tx 5). No funds transit OWNER, and between tx 4 and tx 5 the BPT sits on a contract that has `abort()` | `/ledger phoenix-phase-2-staging fixed 7d5a26570be9` |
| **pps40l4** (`5dce56307136`, RECOVERY never enables Recovery Mode) | RECOVERY is fork-proven against real Balancer governance (pool pause plus permissionless `enableRecoveryMode`, and the Vault-paused-only case). Residual nit: the runbook should name the one-line `vault.enableRecoveryMode(BPT)` call | `/ledger phoenix-phase-2-staging fixed 5dce56307136` |
| **pps40q2** (`6d49f9353148`, 1-wei unsynced pair donation DoS) | Step 2 records the donation and the escrow skims it; `_assertRetired` has no owner-BPT require | `/ledger phoenix-phase-2-staging fixed 6d49f9353148` |

### Still live, carried as manifestations in this entry point

| Prior entry | → run 41 | Status |
|---|---|---|
| pps40l3 (`85095591a60a`, OnlyDispatcher window, no resume) | **L-01** `pps41l1` | open |
| pps39l1 (`9a694ae01fe1`, 2-wei donate+sync bricks the pair) | **L-03** `pps41l3` | open |
| pps40q1 (`c8fb41a168e1`, local-pass-only post-conditions, baked rescue amounts) | **Q-01** `pps41q1` | open |
| pps40l2 (`1d7e436f7dad`, UniswapHelper first-LP brick) | **L-04** `pps41l4` | open, conditional on deploy order; **unverified this run** (static re-check plus run-40 fork proof) |
| pps40f1 (`48d88a589ca4`, story self-contradiction) | **F-01** `pps41f1` | open (doc) |
| pps40f2 (`91aa9008aaca`, wrong third-party BPT holders) | **F-02** `pps41f2` | open (doc) |

**Owner wont-fix disclosed, not re-raised.** ycn L-26 (`b2a29359fde5`, wont-fix 2026-10-07) has the same escrow-side root cause as L-03. L-03 quotes its triageReason verbatim. It tracks the phStaging script's missing recovery branch, which is pps39 L-01 and is open in its own right, so the wont-fix does not suppress it.

No REGRESSION and no INCOMPLETE FIX signals were raised in this run.

---

## Manual-review disposition

| Item | Subject | Disposition |
|---|---|---|
| **MR-41-UPC-01** | No pre-session ETH-balance check. With `CUTOVER_GAS_PRICE_WEI` raised into ~1.45–1.6 gwei, 21k intrinsic gas per tx plus the per-tx 2×-limit admission check exhaust OWNER's 0.01303 ETH inside the OnlyDispatcher window, even though the headline estimate (cost < balance) fits | **Folded into L-01** as an additional halt cause (a Law-3 footgun), with the safe-config funding formula in L-01's recommendation. The gas bands are estimates from recorded simulation gas, not fork-measured per-tx `eth_estimateGas` |
| **MR-41-UPC-02** | Known-issue pass: none of the 11 cached KIs matches any finding. The nearest were KI #10 (admin trust) and KI #9 (external protocol behaviour). The KI cache has no suppression authority, and in-source NatSpec cannot sanitize | **Record only.** Nothing was removed |

---

## Closure-manifest correction and address notes

- **Canonical pair address.** The closure manifest predicted the sUSDS/phUSD pair at `0x194e1F063A8Fc3daa24222BA536EE34E3bB8b5fA`. **That prediction is wrong.** The canonical UniV2 CREATE2 address is **`0x0b96b8ab66d40ba3C7501aa8C28Cdc37688F6F7f`**, verified with `cast create2` and observed in the state diff (`getPair` writes, seed, LP). Use the latter for any pre-broadcast reserve check or monitoring.
- **Preview vs broadcast CREATE addresses.** Under `vm.prank`/`startPrank` (preview and fork harnesses), `createPair` does not consume an OWNER nonce. In a real broadcast it is OWNER nonce 1758. Each later CREATE therefore lands one nonce later on mainnet than in the preview:

  | Contract | Preview (prank) | Broadcast (predicted, OWNER nonce now 1758) |
  |---|---|---|
  | UniPoolerV2 | `0xd50E0B0C73f2fc9829E95B5B87df5a64b2D215C4` (1758) | `0x56997ea45091CBc01DB8a09E60DEDB8b3706a3D2` (1759) |
  | Escrow | `0x56997ea45091CBc01DB8a09E60DEDB8b3706a3D2` (1759) | `0xc369699A59703D7610aaD36A0Fbb8451b7fF3CeA` (1760) |
  | Pair | `0x0b96…6F7f` (CREATE2) | `0x0b96…6F7f` (CREATE2) |

  **The preview's printed escrow address is the broadcast's UniPoolerV2 address.** Do not copy addresses out of the preview log into the runbook or address book; the patcher reads the broadcast receipts instead. The upstream test `test_fork_escrowPreDonation_doesNotBlockCutover` pre-funds `nonce+1`, which on mainnet is the UniPooler, not the escrow. The property it proves (delta-only checks) does not depend on the address, so this is only a test-comment inaccuracy. Nonce drift is not exploitable: forge pins nonces, so an interleaved OWNER tx makes the next scripted tx fail with "nonce too low" instead of silently shifting addresses.
- **Fork block wording.** `qa-report.md` cites "mainnet block 26221713", which is the live head when the run started. The preview and audit fork tests ran at 26,221,761, and the npm-key preview at 26,221,847.

---

## Operator pre-broadcast checklist

These steps come from the findings' recommendations. Do them in this order, in the **same shell** that will run `:broadcast`.

1. **Deadline.** Broadcast before the Balancer pool pause on **30 Oct 2026** while PROPORTIONAL still works. After the pause, use `RECOVERY_EXIT=true` and first send the permissionless `vault.enableRecoveryMode(BPT)` (fork-proven). Without it the script fails closed with `PoolNotInRecoveryMode`.
2. **UniswapHelper not deployed** (L-04). Confirm the address-book `UniswapHelper` is `0x0` and nothing is UI-exposed. Deploy `uniswap-helper` **only after** `unipooler-cutover:verify` passes.
3. **Fund OWNER for gas** (L-01, MR-41-UPC-01). OWNER needs at least `Σ over all 24 txs of (2 × estimated gas + 21,000) × CUTOVER_GAS_PRICE_WEI`, the 2× gas limit forge sets with `--gas-estimate-multiplier 200`. That is about 0.006 ETH at the 0.3 gwei default; the current 0.01303 ETH is not enough above ~1.3 gwei. **Do not raise `CUTOVER_GAS_PRICE_WEI` without redoing this check.** Confirm the base fee is comfortably below the chosen gas price.
4. **Mempool exposure** (L-02). Either set `:broadcast`'s `--rpc-url` to a private relay (e.g. Flashbots Protect, at least for tx 5) and quote at 40–50 bps, or **record in writing** that the owner accepts public-mempool exposure for this cutover (ycn L-28 stays fix-pending either way).
5. **Pair state immediately before** (L-03). Check `getPair(sUSDS, phUSD)` against the canonical `0x0b96b8ab66d40ba3C7501aa8C28Cdc37688F6F7f`. If the pair exists, its reserves must be `(0,0)`. If they are not, stop: `abort()` is not needed yet (no BPT has moved), and the recovery is an atomic transfer + `pair.mint(UniPoolerV2)` helper, never Router02 with zero mins. Keep that helper prepared but not run.
6. **Re-quote floors right before.** `eval "$(node scripts/quote-balancer-exit-min-amounts.js <bps>)"`, then `:preview`, then `:broadcast` straight away in the same shell, so preview and broadcast use the same, fresh floors. The seed deadline is local-pass time + 1 h, so a tx 5 stalled longer than that reverts `BadDeadline` (custody stays safe).
7. **Run `:preview` and read it.** Exit 0, all pre/post-conditions logged OK, and the E2E mint and `pool()` succeed. Ignore the preview's printed CREATE addresses (see above).
8. **Stay attended for the whole session**, especially txs 7–19 (the OnlyDispatcher window, L-01). Have the receipts-driven resume (the remaining txs from `run-latest.json`) ready to hand-send. If a crash happens after tx 19, a re-run will print "Nothing to do" (Q-02); rely on `:verify`, not the re-run.
9. **After the broadcast** (Q-01, Q-03). If `:verify` fails with `old pooler holds sUSDS/USDS`, sweep it with `rescueERC20` (not pause-gated): sUSDS to UniPoolerV2, USDS to the escrow followed by `wrapUsds`. Then re-run `:verify`. Do a manual index-4 test mint on the landed contracts, because the trailing `:preview` will not do one.
10. **Never call `old.setPool`** while an escrow pointing at the old pooler is live (L-27 header rule). Any resume into an existing escrow is a hand-typed `withdrawBPT` with no guard.

---

## Evidence index

All paths are under `reports/41/script-audits/unipooler-cutover/` unless stated.

- `intent.md`, `side-effects.json`, `cluster-analysis.md`, `classified-findings.json`, `proposed-transitions.json`, `entry-manifest.json`, `closure-manifest.json` (pair prediction superseded, see above)
- `logs/preview-proportional.vvvv.log`, `logs/preview-npm-key.log`, `logs/preview-recovery-live.log`, `logs/verify-prebroadcast.log`
- `logs/run41-forktests.log` (17/17), `logs/upstream-story103-tests.log` (56/56), `logs/fullrun-statediff.log`, `logs/statediff-summary.txt`, `logs/patcher-dryrun.log`, `logs/quote.env`
- `reports/41/submissions/qa-report.md` (L-01..L-04, Q-01..Q-03), `reports/41/submissions/spec-conformance.md` (F-01, F-02)
- `reports/41/submissions/carryover/qa-report-39.md`, `qa-report-40.md` (earlier open entries, not merged)
- `reports/41/findings/{low,qa,faithfulness}/unipooler-cutover__*.json`
- Reproduce: `cd work && source ../../.envrc && forge test --skip 'test/audit-run3[3-9]/**' --skip 'test/audit-run40/**' --match-path test/audit-run41/UniPoolerCutoverRun41.fork.t.sol -vvv`
