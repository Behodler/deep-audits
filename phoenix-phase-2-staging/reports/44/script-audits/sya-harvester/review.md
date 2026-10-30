# Script review: `sya-harvester` (story-122 Script A)

**Project:** phoenix-phase-2-staging @ `669cbc1` (master) · **Run:** 44 (script audit) · **Fork block:** 26303964
**Forge target:** `script/DeploySyaHarvesterMainnet.s.sol:DeploySyaHarvesterMainnet`; verifier `script/VerifySyaHarvester.s.sol`; knock-on helper `script/helpers/ClaimUnblockState.sol`
**Story:** story-122 (`~/code/product-owner/stories/phStaging2/auto-complete/sya-antimatter-cutover/122-sya-antimatter-mainnet-catch-up.md`; state `auto-complete`, machine-approved, Review Status ISSUES_FOUND, triaged non-blocking). The route rules come from **vault-RM** story-052 (`~/code/product-owner/stories/vault-RM/auto-complete/curve-adapter-m01/052-curve-amm-adapter-route-contiguity-m01.md`). They do not come from phStaging2 story-052: the two share a number and nothing else.
**Nothing was broadcast to mainnet.** Execution covered the preview on a mainnet fork, a broadcast-mode run on a local anvil fork (impersonated OWNER, no Ledger) and fork tests. The patcher was run only on a `work/` copy, which was restored afterwards.

---

## Operational bottom line

> **Broadcast Script B (`antimatter-pool`) BEFORE this script (Script A).**

Script A is correct and safe on its own terms. Its routes pass the story-052 checks, its storage writes are exactly the five intended ones, and its resume logic is sound. The one material problem is *when* it runs. A's last transaction, `StableStakerV2.setClaimEnabled(true)`, turns 205.42 AM of pending reward (32 staker/pool positions) into AM that can be claimed. At the fork block `Antimatter.totalSupply()` is 0 and no AM/sUSDS market exists. Once AM circulates, any holder can create or pre-price the AM/sUSDS pair that Script B is about to seed:
- If the pair is created before B starts, B aborts at its Step-0 guard (this entry point's **L-01**, fail-safe).
- If the pair is pre-priced **during** B's broadcast, the protocol's seeded AM can be stolen (**antimatter-pool M-01**, Medium, borderline High), or a never-seeded cutover can be spoofed as complete (**antimatter-pool M-02**).

**Evidence that B-first removes the theft:** the antimatter-pool control test `test_PoC_M01_control_noScriptA_cannotReproduce` runs the identical attack without Script A. The attacker has no AM to price the pair with, the seed lands at the correct 2,457.70 AM : 2,077.157 sUSDS, and 1e-6 sUSDS buys only about 1.2e-6 AM. With Script A first (`test_PoC_M01_frontRunStealsSeededAM`), the attacker buys 2,452.65 AM for 1e-6 sUSDS (+$1,319.14 realized). Both orders work mechanically: on anvil, A-then-B and B-then-A each succeed with exit 0. So putting B first costs nothing.

The runbook (`docs/SyaAntimatterMainnetCutover.md` L15-16: "A and B, in either order. They touch disjoint state") and story-122 L16 ("A and B in either order, then C") should be amended. This is filed as **F-01** (unsafe story).

---

## 1. Does it do what it intends?

**Yes.** Every stated purpose was met on the fork, and the human's standing warning (check every Router NG route off-chain against the story-052 rules, then dry-run each direction on a fork with balance-delta assertions) is implemented mechanically, before the first `vm.startBroadcast`:

| tx | what | result |
|---|---|---|
| 1 | Deploy `SYAHarvester(OWNER, PoolManager, SYA, Router NG)` at `0xdb70…09BE` (nonce 1791) | immutables checked |
| 2 | `setRoute(USDe)`: USDe → crvUSD → USDC (k=2) | stored route byte-equal to the payload; passes the 052 check |
| 3 | `setRoute(DOLA)`: DOLA → USDC via DOLA/FRAXBP `exchange_underlying` (k=1) | as above |
| 4 | `setEthPool(ETH/USDC, 3000, 60, no hooks)` | exact |
| 5 | `StableStakerV2.setClaimEnabled(true)` | `require(claimEnabled())` holds |

- **Route safety.** The script's checker and an independent run-44 checker (which adds `i != j` and `n_coins >= 2`) both pass on the forward and reverse payloads. The bidirectional 1,000-unit dry runs return USDe→USDC 998.37, USDC→USDe 1,001.23, DOLA→USDC 994.04 and USDC→DOLA 1,005.00. All four are at or above the 970 floor.
- **Harvest smoke.** Inside a snapshot, the caller receives 0.003666 ETH, exactly one NFT is burned and the harvester ends empty.
- **Verification.** `VerifySyaHarvester` passes on the post-A state, both progress-only and with the book filled. The patcher FILLs and is idempotent. The story's fork tests pass 19/19.
- **Resume.** Gates are byte-exact chain state, and a progress address with no code aborts. The sya-harvester **M-01 `004d4547d93b` fix** (setRoute contiguity, pin `6b862aa`) is confirmed live: on the real router, a gapped payload delivers crvUSD and is rejected.

**Where it falls short:**
- **Ordering (L-01, F-01).** The story's "either order" rule is unsafe. See the bottom line above.
- **DOLA route depth (L-02).** The dry run proves the route is correct but says nothing about capacity. The DOLA/FRAXBP metapool holds about 4,982 DOLA, and its base pool holds only about 184.9k USDC. 100k DOLA returns 8,998.58 USDC.
- **Ticked-but-false checklist item (F-02, disclosed).** "`stable-staker-v2-cutover:verify` still passes against current mainnet" is false. The verifier aborts at Phase 6b (OWNER DOLA residual 88,138,771,830,498 wei) before it reaches the story-122 Phase 7 `claimEnabled` edit. That edit therefore has no end-to-end coverage on live state.
- **Dry-run hygiene (Q-02).** The reverse leg is measured on a pool the forward leg has already moved. On DOLA it logs 1,005.003, against 1,002.515 from an untouched pool.

## 2. Unintended side effects

**Storage: none.** prestateTracer diffMode across all five transactions shows writes only to the new harvester, the one `StableStakerV2` slot (`claimEnabled`, with the packed pauser address unchanged) and OWNER's nonce and gas. Gas cost is 0.000982 ETH at 0.3 gwei.

**Economic: one, and it matters.** tx5 makes 205.42 AM of fresh Antimatter claimable where `totalSupply` was 0. This is not a solvency problem: StableStakerV2's NatSpec already states that nothing in its safety argument depends on AM being unobtainable. The problem is market structure. It creates the third-party AM float that Script B's threats depend on (L-01; antimatter-pool M-01/M-02).

**Operational residue:**
- **Q-01 (disclosed):** the progress file is written in forge's local pass, so it can say `completed` / `claimEnabled: true` for a broadcast that crashed. `ClaimUnblockState` trusts that record. Three chain-anchored gates mitigate this, so it is QA.
- **Q-03:** the fixed 0.3 gwei legacy price has 2.0x headroom over the fork basefee. If a transaction stalls mid-sequence, the runbook's "re-run `:broadcast`" re-signs the same nonce at the same price, which nodes reject until the price is raised by at least 10%.

## 3. Knock-on and cluster problems

- **Script B (`antimatter-pool`, sibling).** Storage is disjoint, which anvil confirms in both orders. Economics are not: after A, a staker claim (25.4768 AM) followed by `createPair(AM, sUSDS)` makes B's preview exit 1 with the R1 abort. That is L-01. The theft and spoof variants are filed under antimatter-pool (M-01, M-02) and are not re-filed here.
- **CutoverStableStakerV2Mainnet / VerifyStableStakerV2Cutover / ClaimUnblockState (predecessor).** The `_doneClaimStillDisabled()` truth table is correct. The only weakness is the disclosed local-pass record (Q-01). As noted under F-02, the cutover verifier is red on mainnet at Phase 6b whether or not A has run.
- **Script C (`uniswap-helper`, successor).** No interaction with A's state. OWNER keeps 0.004899 ETH after A+B on the fork.
- **ClaimPhlimboUsdcToEth (downstream consumer).** At the fork block a harvest pays the caller about $8.23 in ETH and burns an index-4 NFT that costs 18.32 USDS to mint. No rational third party will harvest until SYA yield accrues. This is existing sya-harvester ledger L-02 `464b94269170` (open), referenced and not re-filed.
- **ClaimWithdrawStableStaker (anvil only).** A stale `require(!claimEnabled)` at L105 contradicts DeployMocks L1554. It has no mainnet effect and was not filed.

---

## Findings register

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| [L-01](../../submissions/qa-report.md) | Low | A opens `StableStakerV2.claim` before B creates the AM/sUSDS market, so ~205 AM in third-party hands can pre-create or pre-price the pair and trip B's R1 abort; runbook calls A and B order-independent. Enabling condition for antimatter-pool M-01/M-02 | Reorder the runbook to B (private RPC) before A, or bundle B's seed with A's `setClaimEnabled`; if A must go first, plan a seed-into-existing-pair fallback; drop the "disjoint state" rationale | `script/DeploySyaHarvesterMainnet.s.sol` L459-470; runbook §Order L15-16 |
| [L-02](../../submissions/qa-report.md) | Low | DOLA route sells through a near-empty DOLA/FRAXBP metapool (~4,982 DOLA; base ~184.9k USDC); 100k DOLA → 8,998.58 USDC, which the 1,000-unit dry run cannot see | Survey deeper DOLA venues on a fork and re-route; add an upper-bound-size dry-run leg or reserve-depth floor; set a monitoring threshold for `setRoute`; amend story-122 to record the venue choice | `script/DeploySyaHarvesterMainnet.s.sol` L161-167 |
| [Q-01](../../submissions/qa-report.md) | QA (disclosed) | Progress file written in forge's local pass can record `claimEnabled:true` / `completed` for a crashed broadcast, and `ClaimUnblockState` trusts it | Write the final record from a post-broadcast, receipt-checking step (e.g. patcher confirms all 5 receipts before FILL), or also require code at the recorded harvester | `script/helpers/ClaimUnblockState.sol` L37-46 |
| [Q-02](../../submissions/qa-report.md) | QA | Reverse dry-run leg runs on a pool already moved by the forward leg in the same snapshot, so its floor is not an independent check of live state | Revert to (or retake) the snapshot between the forward and reverse legs | `script/DeploySyaHarvesterMainnet.s.sol` L510-539 |
| [Q-03](../../submissions/qa-report.md) | QA | Fixed 0.3 gwei legacy price with no basefee check; a stalled mid-sequence tx makes "re-run `:broadcast`" re-sign the same nonce at the same price | Runbook: check basefee and set `SYA_HARVESTER_GAS_PRICE_WEI` ≥ 2× basefee, re-run stalled txs at ≥ +10%; or add a broadcast-mode `block.basefee < gasPrice` preflight | `package.json` L94 (`sya-harvester:broadcast`) |
| [F-01](../../submissions/spec-conformance.md) | Spec (Medium weight; unsafe story) | Story-122 and the runbook declare A and B order-independent ("disjoint state"); A's `setClaimEnabled` puts AM in third-party hands, enabling L-01 and antimatter-pool M-01 | Amend story-122 L16/L192 and runbook §Order to require B (via private RPC) before A, or bundle B's seed with A's `setClaimEnabled`; drop the "disjoint state" rationale | story-122 L16, L192; runbook L15-16 |
| [F-02](../../submissions/spec-conformance.md) | Spec (Low weight; disclosed) | Checklist item "`stable-staker-v2-cutover:verify` still passes against current mainnet" is ticked but false; the verifier aborts at Phase 6b before the story-122 Phase 7 edit | Human decides the Phase 6b OWNER DOLA residual (after establishing its provenance), then re-run the cutover verifier on the post-A state for Phase 7 coverage; amend the checklist tick | `script/VerifyStableStakerV2Cutover.s.sol` L466-470 (Phase 7); Phase 6b residual check |

The QA report (`../../submissions/qa-report.md`) is the target for the Low and QA labels.

---

## Referenced, not re-filed

These are existing ledger entries that this run touched. Run-44 evidence is recorded against each, and no status change is proposed.

| Ledger | Label | Fingerprint | Status | Run-44 relevance |
|---|---|---|---|---|
| sya-harvester | L-01 | `d7744b9d2400` | open | 1-wei DOLA and 1-wei USDe donations did **not** brick a harvest on live pools at 26303964 (`test_run44_dustDonation_*`). This is evidence for the ledger note only. |
| sya-harvester | L-02 | `464b94269170` | open | Live: a harvest pays about $8.23 in ETH against an 18.32 USDS NFT cost, so no rational third party harvests yet. |
| sya-harvester | L-03 | `4994fe853f91` | open | Unchanged by this deployment. |
| sya-harvester | L-05 | `3dc300229056` | open (QA by owner) | The script-level checker rejects `swap_type` 9 and values above 8. The shipped payloads use 1 and 2. |
| sya-harvester | Q-04 | `dd56134239f8` | open | The single aggregate `minEthOut` is amplified for DOLA by the thin pool. L-02 above is the separate route-config root cause. |
| sya-harvester | Q-05 | `bec3cacbc1ef` | open | The USDe route goes via crvUSD, as story-122 specifies. It performs at 99.46% at 100k. |
| sya-harvester | M-01 | `004d4547d93b` | fixed | The pin `6b862aa` setRoute contiguity fix is confirmed live. The stored routes pass, and a gapped payload delivers crvUSD on the real router. |
| antimatter | M-02 | `64807f2b1456` | wont-fix | The unbacked AM-half phUSD mint is accepted design. It is only the realization path for antimatter-pool M-01, and its disposition does not cover attacker capture of protocol-minted AM. |

Same-family prior entries (not duplicates): phoenix-phase-2-staging dev L-01 `1e8cc0dc58ba` and promotion-ready L-03 `ea648ec5eab0` (status written in the local pass, different scripts); stable-staker-v2-cutover L-07 `d6896c6e843d` (fixed; same 0.3 gwei convention, different root cause, not a regression); unipooler-cutover L-02 `01d60c7d1d49`; phoenix-phase-2-staging L-05 `b7ff538a654c` (thin DOLA venue in UniswapHelper, a different venue).

## Human-review flags

1. **F-02: origin of the DOLA residual / L-09.** The Phase 6b failure is the pps **L-09** fix (`78cb5942d483`, fixed @`91ed727`) firing loudly. It is not a regression. Where OWNER's 88,138,771,830,498 wei DOLA residual came from is **not established**: it could be the cutover silent-excess artefact, or dust that arrived later. **Do not relax the Phase 6b check until that is established, or L-09 silently re-opens.**
2. **pps36m1 reopen trigger: judged NOT fired.** wont-fix M-01 `cf684d5dc289` (pps36m1) was checked against story-122's edit to `VerifyStableStakerV2Cutover` (`753796b`, Phase 7 L463-470). The edit changes only the Phase 7 `claimEnabled` require message and adds an inline comment. The patcher, the `stable-staker-v2-cutover` package.json keys and the verifier's pending-tail NatSpec are untouched. Status is unchanged, and this is a human decision.
3. **antimatter-pool M-02: possible downgrade, to be re-weighed.** It depends on the same A-before-B precondition. The PoC has now proven the address-book poisoning, and only Script C acting on the entry remains inferred. The classifier's possible Low should be re-weighed against that narrower residual.
4. **Carried, not re-run:** the story-121 `test_bookKey_isZeroPlaceholder` failure (disclosed in story-122 Review issue 2) was neither re-found nor refuted. The full suite was not run because of WSL2 load.

## Evidence

- Fork tests: the story's `test/DeploySyaHarvesterMainnet.fork.t.sol` (19/19, `logs/forktest-story122.log`); the audit's `work/test/audit-run44/SyaHarvesterRun44.fork.t.sol` (`logs/forktest-run44*.log`). In the audit suite, `test_run44_bidirectional_sizes` fails by design at 100k DOLA, which is the L-02 evidence.
- Anvil broadcast and state diffs: `logs/anvil-broadcast.log`, `logs/artifacts/diff1..5.json`, `call1..5.json`, `scriptA-anvil-run-latest.json`. Ordering runs: `logs/scriptB-broadcast-afterA-anvil.log`, `logs/preview-after-scriptB-anvil.log`, `logs/scriptB-preview-after-claim-and-pair.log`.
- Verifier and patcher: `logs/verify-postA.log`, `logs/verify-postA-bookfilled.log`, `logs/patcher.log`, `logs/ssv2-cutover-verify-postA.log` (the Phase 6b abort).
- Cross-entry PoC (the B-first evidence): `phoenix-phase-2-staging/work/test/audit-run44/AntimatterPoolPoC44.fork.t.sol`, logs in `reports/44/pocs/logs/`.
- Inputs: `intent.md`, `side-effects.json`, `cluster-analysis.json`, `manual-review-and-references.json`. Classified records: `reports/44/findings/{low,qa,faithfulness}/sya-harvester__*.json`.
