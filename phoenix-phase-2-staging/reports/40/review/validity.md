# Run 40 validity check (final review)

- Project: `phoenix-phase-2-staging`, full-audit contract scan, run 40
- Source commit: `a4f9f3c66ee133a7cacb79f4d24300bba5945966` (`src/` HEAD and `work/` HEAD both at this commit)
- Checked against: the C4 known-invalid patterns, the root `CLAUDE.md` three-law hierarchy, and memory rulings ("DeployMocks is a UI mock, not a rehearsal", "Fail-loud can be correct", "Never file audit-authored test files", "Disclose when re-filing an owner wont-fix", "Subagent tool output is not evidence")
- This review was read-only. No finding, submission or ledger file was modified.

## Verdict summary

| Finding | Verdict | One-line reason |
|---|---|---|
| L-01 `pps40l1` | **VALID** | A non-obvious footgun (custody and liveness) in existing mainnet-intended core code, fork-reproduced. No owner-theft framing. |
| L-02 `pps40l2` | **VALID** | The root cause is the first-party helper guard (existence-only). The ycn L-26 re-file is disclosed and quoted, and its new-trigger argument holds. |
| L-03 `pps40l3` | **VALID** | It is a resumability defect against story 103's own "resume from receipts", not a complaint about failing loud. |
| L-04 `pps40l4` | **VALID** (borderline QA) | Anchored in the core's mainnet RECOVERY branch and an upstream unit test that proves a false mainnet property. It is not a DeployMocks fidelity finding. |
| L-05 `pps40l5` | **VALID-WITH-EDITS** | The valid core is a protocol-shipped venue choice that impairs an advertised route. Its "user value at risk with weak minOut" facet is a user-input mistake and must not carry the severity. |
| Q-01 `pps40q1` | **VALID** | Simulation-only post-conditions and baked rescue amounts in existing code. QA is the right level. |
| Q-02 `pps40q2` | **VALID** | Anchored in existing code (`_assertRetired` L551-554, step-2 skim L340-342) plus the story's own text (L202/L203). Law 2 / Law 1 story-unsafe is valid. |
| F-01 `pps40f1` | **VALID** | The story contradicts itself, and the plan contradicts the story's amendment. This is a finding about story text (Law 2), not speculation. |
| F-02 `pps40f2` | **VALID-WITH-EDITS** | Factually confirmed on chain. The location/contract field wrongly points at the core contract. |

No finding is INVALID. None uses a malicious-owner framing, a non-standard or fee-on-transfer token, an approve race, or CryptoPunks. None sits in OOS parent or forked code, and none is about an audit-authored test file.

---

## Reproduction (memory rule: subagent tool output is not evidence)

I reproduced **`test_CODE001_dustSwap_phUSDIn_seedReverts`** from `work/test/audit-run40/UniPoolerCutoverCoreRun40.fork.t.sol` myself.

- Command: from `phoenix-phase-2-staging/work`, with `RPC_MAINNET` from `/home/justin/code/audits/.envrc`:
  `forge test --match-path test/audit-run40/UniPoolerCutoverCoreRun40.fork.t.sol --match-test test_CODE001_dustSwap_phUSDIn_seedReverts --threads 1 -vvv`
- Fork block: **26181500** (the test's `FORK_BLOCK`; the log prints `fork block 26181500`)
- Result: **`[PASS] test_CODE001_dustSwap_phUSDIn_seedReverts() (gas: 15306350)`**, 1 passed / 0 failed
- Observed:
  - interfering swap: 1e15 phUSD in, 820,799,260,898,805 wei sUSDS out
  - baked sAmt / pAmt = 18,571,887,281,957,274,477,649 / 22,558,708,306,572,739,389,505
  - OWNER after the exit: BPT 0, sUSDS 18,571,886,765,729,696,524,411, phUSD 22,560,181,609,305,761,341,301
  - sUSDS shortfall vs the baked sAmt = **516,227,577,953,238 wei**, which exactly matches the finding's figure. phUSD spare = 1.47e18, which also matches.
  - pair reserves 0 / 0, new-pooler LP 0
  - seed revert data: `0x08c379a0…5472616e7366657248656c7065723a205452414e534645525f46524f4d5f4641494c4544` = `Error("TransferHelper: TRANSFER_FROM_FAILED")`, asserted byte-exact by the test
  - the re-run asserts `vm.expectRevert("UniPoolerCutoverCore: owner holds no BPT")`, and that assertion passed
- Conclusion: the L-01 Scenario A headline (exit lands, seed reverts, both legs sit on OWNER, pair empty, no resume) is independently reproduced. I checked the call order: the swap is replayed between simulation and the exit, and the test asserts the exit **succeeds** before it asserts the seed reverts. So the test covers the headline, not a narrower claim.

Supporting on-chain read for F-02 (`cast call` on BPT `0x642BB6…db04` at block 26181448): `0xE74E…1322`, `0x5f97…53d2` and `0xde44…3D07` each hold 0. `0xc65f…e8db` holds 12,036,965,096,910,719,316,967, against totalSupply 32,438,774,213,867,981,521,320, which is **37.1%**. Confirmed.

---

## Per-finding detail

### L-01: EOA custody across separate broadcast txs, dust-swap split, no resume. **VALID**

- **Owner trust (Law 3):** Passes. The finding says "No third-party theft path (owner controls the EOA, Law 3)" and "No value extractable (ECON-001)". The harm it describes is custody on the trusted EOA plus a liveness stall. The trigger is a third-party Balancer swap, organic or a ~$0.03 grief, not an owner action. It is correctly tagged `footgun: true`: a competent owner would be surprised that a 0.001-phUSD swap splits the cutover with no resume path. It also breaks story 103's 2026-10-07 requirement, verified at story L221-223: "no protocol funds … transit the owner EOA".
- **Speculation on future code:** Passes. The root cause is in code that exists at a4f9f3c: `_step4WithdrawBPT` L362, `_step5ExitBalancer` L373-374, `_checkMinAmountsOut` L396-408 and `_step6SeedPair` L429-432, all verified. The finding is honest that no mainnet entry point calls the core yet (verified: the only importer is `DeployMocks.s.sol` L86/L148/L2026). That is handled correctly through Low severity plus a re-weigh trigger, not by speculating. DeployMocks' own NatSpec (L1960) names this core as "the mainnet script (103) broadcasts".
- **DeployMocks ruling:** Not engaged. The finding is not about rehearsal fidelity. It fork-tests the mainnet core against real mainnet state.
- **Excerpt check:** `withdrawBPT(p.owner, bal)` L362, `require(bptIn > 0, "…owner holds no BPT")` L374, and `addLiquidity(… sAmt, pAmt, sMin, pMin, l.newPooler, …)` L429-430 all match the source.
- **Test path:** `work/test/audit-run40/…` is evidence, not the defect location. Correct.
- **Edits:** None required. The unverified "without --slow, steps 7-12 land on an unseeded pooler" sub-claim is already labelled "Not exercised on fork" in qa-report.md L122.

### L-02: UniswapHelper existence-only guard lets an honest user become first LP. **VALID**

- **OOS parent/forked:** Passes. `src/periphery/UniswapHelper.sol` is a first-party upstream blob at a4f9f3c (`git ls-tree` → `7a44621…`). The defect is the helper's own `_requirePair()` (L428-431: `if (p == address(0)) revert PairNotFound();`). It does not lie in UniswapV2: first-LP-sets-price is standard V2 behaviour, and the helper's guard choice is the defect. It does not lie in yield-claim-nft either: the escrow's strict `PairNotEmpty` gate is accepted design (L-26 wont-fix), and the fix location is the helper.
- **Story rationale verified:** Story 109 L80 says the guard "stops `Router02.addLiquidity` from silently creating the pair before story 103's cutover seeds it". An existing pair is not an empty pair, so that stated purpose is not achieved. This is a valid Law-1-over-Law-2 framing. `DeployUniswapHelperMainnet.s.sol` L43-46 ("until the pair exists every … liquidity call reverts") is confirmed as the runbook premise.
- **Re-filing an owner wont-fix:** Passes. `wontFixDisclosure` and `wontFixDisclosureText` name ycn L-26 `b2a29359fde5…` (wont-fix 2026-10-07) and quote the owner verbatim ("it should just panic and then I'll have to figure out what to do if there is a pair…") together with the re-weigh condition. The qa-report Borderline table also surfaces the disclosure. The new-trigger argument holds on three counts. The contract is different (a story-109 helper, not the escrow). The trigger is different (an honest user, or a protocol UI, through a protocol-shipped contract, not an adversarial 1-wei grief the owner judged). The fix location is different (a one-line reserve check in the helper). The finding does not overclaim L-26's re-weigh condition; it says "only partly met (deadline exists, value not exposed)".
- **Caveat to keep visible (no edit required):** An honest user could also reach an existing empty pair through Uniswap's own interface, so the incremental trigger is specifically *protocol-shipped exposure*. The finding's own severity-raise trigger (the UI exposes the helper's add form before Stage 4) already captures this.
- **Excerpt check:** `_requirePair` L428-431 and `addLiquiditySUSDS` L273-292 match the source.

### L-03: Index-4 OnlyDispatcher window between steps 8 and 10, no resume gates. **VALID**

- **Fail-loud can be correct:** The finding does not complain that mints revert during the window. It says the window is "inherent to three independent owner contracts". The defect it reports is that a halt *inside* the window cannot be resumed, because step 0 L297 requires `hook.dispatcher() == oldPooler`, while story 103 L47/L144 explicitly requires "resume from receipts". That is a Law-2 gap with a concrete, cheap fix (move the step-9 setters before step 8, add skip-if-done gates) and a fixed precedent (L-02 `2c82d65e65e1`). Low is justified. Fail-loud is fine, but a promised resume path that does not exist is a reportable defect.
- **Owner trust:** The owner can finish by hand (`replaceDispatcher`). The finding states this and uses it to cap severity at Low. That framing is correct.
- **Excerpt check:** `_step8RepointHook` L448-456, `_step9ConfigurePooler` L460-487 and `_step10ReplaceDispatcher` L490-499 match. Counting setHook + setMinter + setPSM + setMaxTout + setBatchMinter + setBatchDonationSize + 4×setAuthorizedPooler + setNudgeStreamer gives 11 txs, consistent with "~11".
- **Edits:** None.

### L-04: RECOVERY branch never enables Recovery Mode; the mock conflates paused with recovery. **VALID** (Low acceptable, borderline QA)

- **DeployMocks / mock-only ruling:** The finding is anchored in the **mainnet core path**, not mock fidelity. The defect location is `UniPoolerCutoverCore._step5ExitBalancer` RECOVERY branch L384-386 (`removeLiquidityRecovery(...)` with no `enableRecoveryMode`). It is fork-proven against the real V3 Vault: `PoolNotInRecoveryMode` `0xef029adf`. The mock (`src/mocks/MockBalancerVault.sol` L243 `require(poolPaused, …)`) and `test/UniPoolerCutoverCore.t.sol::test_cutover_recovery` (L312-317) are cited as *why the core's own upstream test proves a property that is false on mainnet*. That is a valid test-fidelity facet. The DeployMocks ruling does not apply: the DeployMocks rehearsal is PROPORTIONAL-only and the finding says so.
- **Test files:** `test/UniPoolerCutoverCore.t.sol` (`02b7678…`) and `src/mocks/MockBalancerVault.sol` (`97b7592…`) are both upstream blobs at a4f9f3c, last touched by upstream commit `f8b102f [story-100]`. Neither is audit-authored.
- **Fail-loud:** It fails closed in simulation, before step 4's `withdrawBPT`, so nothing is stranded, and the finding says this. Reporting it as Low rather than "fail-loud is correct" is justified for two reasons. First, the documented deadline fallback (plan L36-39; story 103 L57 "step 3 already allows for that") does not work as written. Second, the in-repo test certifies it falsely. The finding is honest that the paused-pool `enableRecoveryMode` path was not fork-tested, and it flags human review. Plan L38 says `enableRecoveryMode` is permissionless once paused, so the remedy is one extra call. QA would also be defensible. Low with the HR flag is acceptable.
- **Edits:** None required.

### L-05: Thin hardcoded DOLA venue. **VALID-WITH-EDITS**

- **User input mistake?** Split verdict. The **valid core** is a protocol-shipped route choice. `CURVE_DOLA_3CRV` is a deploy-script constant (verified at `DeployUniswapHelperMainnet.s.sol` L74), and stories 109/111 prescribe it (story 111 L39). The helper is ownerless and immutable, so an advertised route is functionally impaired above ~$1.5k and needs a redeploy to fix. That is a non-obvious venue-choice footgun and a function-availability Low. It is **not** a user-input mistake.
- **Invalid facet that must not carry severity:** The impact text "user value at risk only with `minOut == 0` or a UI that hides price impact" and `externalRequirements: "User or UI submits a weak minOut"` describe a C4 user-input mistake. The finding's own I3 invariant shows that a quote-derived `minOut` protects every call. MR-008 (zero-minOut) is correctly parked in `manual-review.json` as user input, and L-05 must not lean on it.
- **Required edits:**
  1. Lead the Impact with route unusability: the advertised DOLA route delivers -24% at 2k and -69% at 5k, the helper is immutable, and fixing it means a redeploy. Say explicitly that no loss occurs with a quote-derived `minOut`.
  2. Remove "User or UI submits a weak minOut" as the external requirement, or label it as not the basis for severity (user-input, C4-invalid; cf. MR-008).
  3. Optionally note that story 111 L39 itself names the venue, so the spec gap covers both 109 and 111.

### Q-01: Simulation-only post-conditions and baked rescue amounts. **VALID**

- Anchored in existing code: `_step7PullDebt` L442-445, `_step11MoveBalances` L508-535 and `_assertRetired` L547-560, all verified. The halt branch is honestly marked unreachable under today's config (`batchDonationSize == 0`). The residue is recoverable through `onlyOwner` `rescueERC20`, which keeps it at QA. There is no owner-malice framing and no user-input dependency. Not fork-tested, and the finding says so. That is acceptable at QA.
- **Edits:** None.

### Q-02: Story-103 respec turns a self-healing condition into a griefable precondition. **VALID**

- **Speculation:** Passes. It is anchored in (a) the current step-2 skim, L340-342, which story 103 drops; (b) the current `_assertRetired` owner-BPT clause; and (c) the story's own text, L202 ("only asserts the pair is empty (reserves AND balances (0,0))") and L203 ("must NOT revert on a non-zero owner BPT balance"), both verified verbatim. A finding about a story's own text is valid under Law 2, and Law 1 overrides for the story-unsafe facet. The future rewire is described only as the story specifies it, without invention.
- **Line-number correction verified:** The `_assertRetired` owner-BPT `require` spans **L551-554** at a4f9f3c (L551 `require(`, L552 the `… && balanceOf(p.owner) == 0` clause, L553 the message, L554 `);`). qa-report.md L431 correctly links `#L551-L554`. The finding JSON still says "L552-553" (description) and `lineEnd: 553`. That narrower range is not wrong, because it covers the clause and its message, but it is inconsistent with the render.
- **Precision note (no edit required):** In today's core the owner-BPT clause is not griefable, because step 5 exits the OWNER's whole BPT balance (L373), so a pre-simulation donation gets exited too. It becomes a grief only once the rewire stops exiting owner BPT. The finding says "must be removed in the rewire", which is correct.
- **Edits (cosmetic):** Align the JSON `description` and `lineEnd` to L551-554 to match the rendered report.

### F-01: Story 103 self-contradiction (EOA custody). **VALID**

- This is a finding about story text, which is valid under Law 2. Verified: story 103 L59-71 (step 2 `withdrawBPT(OWNER, fullBalance)`, step 4 `addLiquidity … from the owner`, step 9 USDS dust sweep) and L150 (pair-absence precondition) contradict the 2026-10-07 amendment at L221-223. The plan at a4f9f3c (`docs/BalancerWinddownPlan.md` §4 Stage 2) still has `pair.skim(OWNER)`, `withdrawBPT(OWNER, fullBalance)` and `rescueERC20(USDS, OWNER, fullBalance)`, all verified. The finding does not claim a Law-1 exploit and says that trusted-owner EOA custody is not an attack path. Law 3 framing is correct.
- **Edits:** None.

### F-02: Story 103 names the wrong third-party BPT holders. **VALID-WITH-EDITS**

- Factually confirmed on chain at block 26181448 (see Reproduction above): three named holders at 0, and `0xc65f…e8db` at 12,036.97 BPT (37.1%). Story 103 L116/L213 name the stale addresses, and plan L62 names `0xc65f…`. Law-2 procedural, with no exploit claimed. Correct.
- **Required edit:** `contract` / `fileLine` / the fingerprint input read `script/helpers/UniPoolerCutoverCore.sol (story-103 Concerns)`, which attributes a story-text defect to the core contract. Relabel the displayed location to `story-103 text (L116, L213)`, consistent with F-01's `story-103 text / docs/…`. To avoid fingerprint drift, keep the already-minted fingerprint `91aa9008aaca…` unchanged and add a note that the preimage's contract token is a label artefact. Do not re-mint the fingerprint unless that is done deliberately through finding-manager and the ledger.

---

## Cross-cutting checks

- **Malicious-owner framing:** None in any finding. qa-report.md L50/L462 explicitly decline centralization vectors under Law 3.
- **Non-standard / FoT / approve-race / CryptoPunks:** Not present.
- **Audit-authored test files as defect locations:** None. Every `work/test/audit-run40/*` path is cited as evidence only. The one upstream test cited as part of a defect (`test/UniPoolerCutoverCore.t.sol`, L-04) is an upstream blob at a4f9f3c.
- **Known-invalid parking:** MR-008 (zero-minOut / ethOut=0 dust) is correctly parked in `manual-review.json` as user input. It is visible and not silently dropped.
