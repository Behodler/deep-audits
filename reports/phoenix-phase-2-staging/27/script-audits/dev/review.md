# Script audit — `dev` (phoenix-phase-2-staging, run-27)

**Project:** `phoenix-phase-2-staging`
**Entry point:** `dev` (`package.json:16`)
**HEAD:** `1d8a3a7515adca7819c530a01a87c132863a5ae2` (`1d8a3a7`, branch `master`) — *"[story-079] Rehearse cutover mechanics, toggle Kendu promo, sweep deployer grant"*
**Baseline:** `e1db0f1` (`entryPointBaselines.dev`, set by run-26)
**Delta:** one commit, one file — `script/DeployMocks.s.sol`, **+293 / −1**
**Execution:** live local **anvil, chain 31337**, both toggle legs run end-to-end. No mainnet fork — and correctly so: every address in this closure is minted fresh at run time (`entry-manifest.json` → `forkAvailable: false`).
**Mode:** regression / **fix verification**

Supporting artifacts: [`intent.md`](intent.md) · [`closure-summary.md`](closure-summary.md) · [`cluster-analysis.md`](cluster-analysis.md) · [`side-effects.json`](side-effects.json) · [`closure-manifest.json`](closure-manifest.json) · [`entry-manifest.json`](entry-manifest.json) · [`classified-findings.json`](classified-findings.json) · [`evidence/`](evidence/) (26 files) · [`../../submissions/qa-report.md`](../../submissions/qa-report.md) · [`../../submissions/spec-conformance.md`](../../submissions/spec-conformance.md)

---

## What this run was for

This is **not** a cold audit of `dev`. It is a follow-up whose primary job was to re-prove three `fix-pending` Low findings the owner triaged after run-26, against the single-file change story 079 shipped to remediate them:

| Ledger entry | run-26 label | Claim under test |
|---|---|---|
| `eda17642828a6dd3bce6890d9900add9d27a317f80b78212a30f123301d17fd4` (`pps26l1`) | L-01 | `setDispatcher`, `replaceDispatcher` and `hook.pull()` execute **zero** times on the local chain |
| `12bcca3b617c6c077babfad810a2457a1b8f3a5d352217b4acb135e8b9859e79` (`pps26l3`) | L-03 | The dormant Kendu promo state — the one mainnet ships on day one — is unreachable locally |
| `b8e3d59139aeee24bd97a6e1087c3e992ab4dee99949a7bde8c30d55ee5e84f6` (`pps26l4`) | L-04 | The deploy script grants itself phUSD mint authority and never revokes it |

**All three fixes verified genuine, and the verification was empirical, not read off the diff.** Under the fix-pending rules a fix that merely stops tripping a scanner is not a verified fix, so each claim was re-executed on chain and each verdict is anchored to a broadcast bundle or a `cast` read-back, never to source inspection:

- **L-01** — `pull` / `setDispatcher` / `replaceDispatcher` counted as **broadcast transactions** in `broadcast/DeployMocks.s.sol/31337/run-latest.json`, by the `function` field of each *dispatched* transaction rather than by source occurrence: **1 / 1 / 1 on both legs**, against **0 / 0 / 0** at the run-26 baseline. The dispatched order on the armed leg is `[355] hook.pull()` → `[359] hook.setDispatcher(0xdB05A386…4402)` → `[360] newUb.setHook(0x2B0d36FA…0dd5)` → `[361] NFTMinterV2.replaceDispatcher(1, 0xdB05A386…4402)`, and `352 / 356 / 357 / 358` identically on the dormant leg. That matches the mainnet fail-closed ordering contract at `DeployMainnetPromotionReady.s.sol:148` exactly. A rehearsal that asserted the right things in the wrong order would rehearse nothing; this one does not have that defect. Evidence: [`legA-armed-04-broadcast-callcounts.txt`](evidence/legA-armed-04-broadcast-callcounts.txt), [`legB-dormant-03-broadcast-callcounts.txt`](evidence/legB-dormant-03-broadcast-callcounts.txt), [`legA-armed-broadcast-run-latest.json`](evidence/legA-armed-broadcast-run-latest.json).
- **L-03** — env propagation was the thing most likely to be *asserted* rather than *tested*, so it was tested through the real npm key, unmodified: `LOCAL_PROMO_KENDU=false npm run dev` ran end-to-end (clean → anvil → `deploy:local` → `simulate-yield.sh` → `extract:addresses` → `generate:ts-anvil` → `serve`). `startPromotion` was broadcast **zero** times — the dormant bundle is 391 transactions against the armed leg's 394, and the difference is **exactly** the three promo transactions. On chain afterwards: `promoToken 0x0`, `promoPhase 0`, `promoRewardBalance 0`, `promoRewardPerSecond 0`. Evidence: [`legB-dormant-01-npm-run-dev.log`](evidence/legB-dormant-01-npm-run-dev.log), [`legB-dormant-02-onchain-state.txt`](evidence/legB-dormant-02-onchain-state.txt), [`legA-armed-14-promo-state.txt`](evidence/legA-armed-14-promo-state.txt).
- **L-04** — `MockPhUSD.setMinter(deployer, false)` is broadcast transaction **[393] of 394**, the last of the run, exactly as designed. The full 10-row ACL was read back independently with `cast call authorizedMinters` against `mintVersion() == 1`: deployer `(false, 1)`, PhlimboV2 `(false, 1)`, and all eight legitimate minters — PhlimboV3, PhusdStableMinter, StableStaker, BalancerPoolerHook, NudgeRatchetHook, UniboostHookEYE/SCX/FLX — `(true, 1)`. The table was checked for **completeness, not just correctness**: every `phUSD.setMinter(x, true)` site in the file at HEAD (`:876`, `:985`, `:1089`, `:1127`, `:1131`, `:1725`×3, `:2063`, `:2148`, `:2317`, `:2414`) resolves to one of the ten asserted rows, so no grant the script issues escapes the assertion. Evidence: [`legA-armed-09-phusd-acl.txt`](evidence/legA-armed-09-phusd-acl.txt), [`legA-armed-04-broadcast-callcounts.txt`](evidence/legA-armed-04-broadcast-callcounts.txt).

### The non-vacuity result

This is the most interesting technical result of the run and deserves its own emphasis.

`hook.pull()` is a no-op at zero debt, so `require(hook.mintDebt() == 0)` after it is trivially true — a green assertion that means nothing. Story 079 named this itself as *"the most likely place for the executing agent to produce a green result that means nothing"*, and guarded it with `require(mintDebtBefore > 0, "VACUOUS REHEARSAL: …")` at `:1786-1789` plus a deliberate `_accrueIndex1MintDebt` (`:1878`) that drives one real index-1 mint before the pull.

**The guard is load-bearing, and that was measured rather than assumed.** `hook.mintDebt()` read **0** on entry to Phase 7.6 — despite three earlier index-1 mints in the same run — and `5015015000000000000` after `_accrueIndex1MintDebt`, immediately before the `pull()`. Without that deliberate accrual the mint-debt conservation assertion **would have been vacuous**. The recipient's phUSD balance then moved by exactly `5015015000000000000`, matching `price 10030030 × scale 1e12 × ratio 50/100`, with `hook.scale` and `hook.ratio` read on chain. The story's own figure reproduced **to the wei on both legs**.

This is exactly the failure mode this repository has recorded before — a Tier-3 invariant harness whose mock never failed, so the invariants passed on `0 == 0`. Here the same shape was anticipated by the story, defended in code, and the defence was confirmed to fire. Evidence: [`legA-armed-03-deploy.log`](evidence/legA-armed-03-deploy.log) (lines 297-298), [`legB-dormant-01-npm-run-dev.log`](evidence/legB-dormant-01-npm-run-dev.log) (lines 818-819), [`legA-armed-07-onchain-swap-state.txt`](evidence/legA-armed-07-onchain-swap-state.txt), `side-effects.json` → `L01_swapRehearsal.nonVacuity`.

### Story 079's own claims survived re-execution

Story 079 ships 19 ticked checklist boxes. The 19th is the closing commit-hygiene box, verified separately against the commit record. **All 18 substantive boxes hold**; **10 load-bearing ones were independently re-executed** (both toggle legs of `npm run dev` from clean, broadcast-bundle call counting, `cast call` state reads, the ACL read-back, an out-of-band post-swap mint probe). The remaining eight are static or process claims and were proved by direct inspection of the diff and the tree. **Zero were found ticked-without-implementation.**

That is worth stating plainly, because this project has the opposite on record twice. Run-22 produced `ForgeLocalPassPrecedesBroadcast`, where a passing PoC did not make its claim true. Run-26 produced `daab9e86d033…` (still open), a checklist line certifying a four-clause seven-leg confirmation of which one clause and one leg were actually asserted. Run-27 looked for a third instance and did not find one: story 079's *"18/18 verified"* is honest.

It also **disclosed its own shipped regression** — Autonomous Decision 4 records, before the fact, that the L-04 revoke breaks `npm run test:fund-user`, and declines the one-line fix to honour the story's single-file constraint rather than burying the consequence. That is a meaningful improvement in this project's remediation quality and the report credits it explicitly.

### The counterweight

The run still produced **6 new findings: 0 High / 0 Medium / 4 Low / 2 QA**. Two of them qualify the fixes above and should be read alongside them:

- **`pps27l1`** — the L-04 fix **shipped a live regression**. `npm run test:fund-user` now reverts `Not authorized to mint` on every fresh chain, and the comment at `FundTestUser.s.sol:45` now asserts the opposite of the truth.
- **`pps27l2`** — the L-01 fix rehearses **1 of 5** mainnet swap classes, and `REHEARSAL_SWAP_INDEX` reads like a knob but is not one.

Neither reopens the entry it qualifies; both are filed as their own narrower claims. The reasoning is in **Verification of prior findings** below.

---

## Question 1 — Does the entry point do what it intends?

**Yes, on the delta under audit.** `dev` has two declared purposes: rehearse the mainnet cutover, and give the UI a realistic chain to bind against. Run-26 found three points where it served the second at the cost of the first, silently. Story 079 remediates exactly those three and nothing else — the scope-creep sweep enumerates every added top-level symbol (`armKenduPromo`, `REHEARSAL_SWAP_INDEX`, `_rehearseDispatcherSwap`, `_accrueIndex1MintDebt`, `_pinNudgeRatchetStaticClaims`, `_sweepResidualPrivileges`, `_requireLiveMinter`) and each maps to one of L-01 / L-03 / L-04. Nothing rides along.

All five declared pre-conditions and all fifteen declared post-conditions were observed to execute and pass on chain; the full table with sites and measured values is in [`intent.md`](intent.md) §3–§4. The load-bearing ones:

- **P2, the vacuity gate** — passes, and is load-bearing (above).
- **Q2, conservation** — passes with a non-zero operand (`5.015015e18`), so it is a real equality rather than `0 == 0`.
- **Q4–Q10, config preservation** — `configs(1).dispatcher` moved to the replacement while `price 10040060`, `growth 10` and `disabled false` were preserved, the hook was **reused** (both old and new point at `0x2B0d36FA…0dd5`), `recipient` and `ratio` unchanged, and `dispatcherToIndex` moved in both directions (`new → 1`, `old → 0`).
- **Q13, the ACL table** — 10 rows, independently reproduced by `cast call`.

The chain also **ends fully working**, which was the checklist's own bar: a post-run `NFTMinterV2.mint(1, deployer)` succeeds (status `0x1`) and accrues `5020030000000000000`, `local-addresses.ts:34` names the replacement dispatcher, and `serve` reports `/health` `deploymentsLoaded: true` on both legs ([`legA-armed-11-postswap-mint-probe.txt`](evidence/legA-armed-11-postswap-mint-probe.txt), [`legA-armed-13-serve-health.txt`](evidence/legA-armed-13-serve-health.txt)).

Two intent gaps are recorded rather than left implicit. The rehearsal's *coverage* claim is narrower than it reads (`pps27l2`), and its intermediate-window assertion pins the fail-closed premise rather than its consequence (`pps27l3`). Both are qualifications of a fix that works, not refutations of it.

## Question 2 — Does it introduce unintended side effects?

**Every on-chain write observed is accounted for in [`side-effects.json`](side-effects.json).** The intended mutating set is small and fully matched: `hook.pull()` ×1, `hook.setDispatcher` ×1, `newUb.setHook` ×1, `replaceDispatcher(1, newUb)` ×1, `phUSD.setMinter(deployer, false)` ×1 (terminal), plus the greenfield deploy set. No unaccounted write appeared in either 394-tx or 391-tx bundle.

Two writes are **new state the baseline did not produce** and are only indirectly implied by the stated purpose. Both are recorded as `intended: partially`:

1. **`_accrueIndex1MintDebt`'s extra index-1 mint.** It ratchets the index-1 price and deposits prime residue on the incumbent dispatcher. It is a necessary consequence of the non-vacuity defence, not a defect.
2. **Retiring a dispatcher that still holds prime.** Measured on chain, the retired incumbent `0xdbC43Ba4…64E6` holds **20.030020 USDC** — exactly 50 % of four index-1 mints at prices `10000000 + 10010000 + 10020010 + 10030030` — of which `5.015015` (25 %) was created by the fix's own accrual mint and `15.015015` pre-existed. **The fix did not invent the residue class**; it converted a live retained balance on the *live* dispatcher into a residue on an *off-index* one. Recoverability was **proved, not assumed**: `Uniboost.rescueERC20(USDC, deployer, 20030020)` against the retired contract returned status `0x1` and left its balance at `0`, and `pool()` remains callable there. The value is parked, not lost — this is explicitly **not** filed as a value leak. Filed as `pps27l4`, with the mainnet magnitude marked `unverified` (see **Coverage and limits**).

The off-chain side is clean. The address-book repoint at `:1864-1866` edits `deployments["UniboostEYE"].addr` in place rather than re-`_trackDeployment`ing it, and the rationale checks out: `contractNames` receives `"UniboostEYE"` exactly once (`:668`), and the emitted `progress.31337.json` carries exactly one `UniboostEYE` key holding the replacement address. The incumbent's address is recorded nowhere off-chain, which is consistent with the intent.

## Question 3 — Have other problems surfaced because of it?

**Yes — one, and the closure mapper predicted it before it was reproduced.**

`script/interactions/FundTestUser.s.sol:46` calls `MockPhUSD(phUSD).mint(testUser, phUSDAmount)` inside a broadcast opened at `:43` with `AddressLoader.getDefaultPrivateKey()` — anvil account #0, the deployer — and the file contains no `setMinter` re-grant anywhere. Reproduced on a fresh chain immediately after a clean `npm run dev`:

```
$ npm run test:fund-user
  │   └─ ← [Revert] Not authorized to mint
  └─ ← [Revert] Not authorized to mint
Error: script failed: Not authorized to mint
FUNDUSER_EXIT=1
```

The revert is `MockPhUSD.sol:48`. The comment one line above the failing call — `// Mint phUSD (deployer is authorized minter)` — now states the opposite of the truth, which is the part a future reader will trip on: it converts a seconds-long fix into a misdirected debugging session.

**This is a cluster interaction, not a contract bug**, and the blast radius was bounded by an independent consumer sweep rather than taken on the mapper's word. Across `script/interactions/`, `*.sh` and the docs, exactly one consumer mints phUSD as the deployer: `simulate-yield.sh:44` mints permissionless `MockDola`; `MintPhUSD.s.sol:41` routes through `PhusdStableMinter`'s own grant; `FullFlowTest.s.sol:106,113` uses `minter.mint`; the nudge/donation/mint-flow tests use permissionless mocks and `NFTMinterV2.mint`. No second consumer exists, so the severity is not raised by a missed dependent. It *is* raised slightly above "obscure utility" by documentation exposure: `script/interactions/README.md` points at `npm run test:fund-user` four times (`:47`, `:283`, `:352`, `:383` — the last reading *"Fund test user first"*), so the broken command sits inside the documented developer workflow.

Filed as `pps27l1`, related to `pps26l4` as **`introducedBy`** — *not* `incompleteFixOf`. The L-04 fix closed its own claim completely and correctly on `DeployMocks.s.sol`; this is collateral in a different file, with a different root cause and a different one-line remedy.

The rest of the cluster is clean. `DeployMainnetUniboostCutover.s.sol:723` reads the single-valued `UniboostEYE` key and is unaffected. `TestNudgePayout.s.sol:119` mints at index 1 but resolves through `configs` at mint time rather than a cached address, so the repoint is transparent to it — confirmed by the successful post-swap mint probe. `VerifyPromotionReady.s.sol` is read-only and address-hard-coded; run-26's recommendation to run it against the local end state was declined by the story for exactly that reason, and the reasoning holds.

---

## Findings register

Six new findings. Every `Mitigation` cell is a one-line compression of the finding record's own `recommendation`, which is carried verbatim in the record and in [`../../submissions/qa-report.md`](../../submissions/qa-report.md).

| Label | Sev | What | Mitigation | Where |
|---|---|---|---|---|
| **L-01** `pps27l1`<br>`65db3324e7d0bc49…` | Low | The terminal privilege sweep bricks `npm run test:fund-user` on every fresh local chain, and the comment on the failing line still claims the deployer is an authorized minter. Reproduced: exit 1, verbatim `Not authorized to mint`. | Add the one-line self-grant `MockPhUSD(phUSD).setMinter(deployer, true);` inside `FundTestUser.s.sol` after `:43`, and correct the false comment at `:45` — do not weaken the sweep's declarative end-state ACL to accommodate a utility script. | [record](../../findings/low/L-01-fund-test-user-bricked-by-privilege-sweep.json) · `script/interactions/FundTestUser.s.sol#L45-L46` · [evidence](evidence/legA-armed-10-fund-user-regression.log) |
| **L-02** `pps27l2`<br>`6af1ae30ed826980…` | Low | The rehearsal covers 1 of 5 mainnet dispatcher swaps and is **not re-targetable**: `REHEARSAL_SWAP_INDEX` reads like a knob, but the helper hard-codes the index-1 6-decimal Uniboost shape, so index 4 — 18-decimal prime, BPT custody shift — is rehearsed nowhere. | Add a second rehearsal on index 4 mirroring the BPT custody shift; failing that, make the helper honestly index-1-only (rename the constant, replace `price < 1e12` with a decimals-derived bound) and comment which indices are and are not mirrored. | [record](../../findings/low/L-02-rehearsal-covers-one-of-five-dispatcher-swaps.json) · `script/DeployMocks.s.sol#L1768-L1871` · [evidence](evidence/static-03-mainnet-swap-coverage.txt) |
| **L-03** `pps27l3`<br>`19e2e0c2d6a35689…` | Low | The intermediate-window assertion pins the fail-closed **premise**, not its **consequence**: deleting `UniboostMintDebtHook.onDispatch`'s `OnlyDispatcher` gate leaves the whole local rehearsal green while the property it exists to protect is gone. | Add the live probe the story's own Implementation Notes step 6 specifies — a `try nftMinterV2.mint(idx, deployer)` bracketed outside the broadcast — keeping the structural assertions; or, failing that, a `yield-claim-nft` unit test asserting `onDispatch` reverts `OnlyDispatcher()`. | [record](../../findings/low/L-03-intermediate-window-assertion-pins-premise.json) · `script/DeployMocks.s.sol#L1828-L1834` · [evidence](evidence/story079-full.diff) |
| **L-04** `pps27l4`<br>`9ee101a0cc41eb93…` | Low | The swap retires a Uniboost still holding retained prime and never sweeps it — 20.03 USDC locally, a quarter of it created by the fix itself — and the mainnet twin `_swapUniboost` has the same no-sweep shape on live positions. Value proved parked, not lost. | Snapshot the incumbent's prime balance in Phase 7.6 and either sweep it to the replacement or assert it is zero; more importantly, carry the decision to the promotion-ready entry point and measure each mainnet incumbent's balance on a fork before the cutover. | [record](../../findings/low/L-04-retired-dispatcher-retains-unswept-prime.json) · `script/DeployMocks.s.sol#L1780-L1866` · [evidence](evidence/legA-armed-08-retired-dispatcher.txt) |
| **Q-01** `pps27q1`<br>`9067d8a232b53421…` | QA | Phase 7.6 asserts `configs` and both directions of `dispatcherToIndex` but not `tokenIdToDispatcher` — the third mapping `replaceDispatcher` repoints, and the one `uri(id)` dereferences for NFT metadata. No defect today; the state is correct on chain. | Add one line to the post-swap invariant block: `require(nftMinterV2.tokenIdToDispatcher(idx) == address(newUb), …)`, and consider mirroring it into `DeployMainnetPromotionReady.s.sol`'s per-index read-back. | [record](../../findings/qa/Q-01-tokeniddispatcher-not-asserted.json) · `script/DeployMocks.s.sol#L1840-L1853` · [evidence](evidence/legA-armed-07-onchain-swap-state.txt) |
| **Q-02** `pps27q2`<br>`e0ac78243e5fe4b8…` | QA | The dormant leg mirrors mainnet's promo **slot** but not its **address book**: `local-addresses.ts` ships a real, funded MockKendu where `mainnet-addresses.ts` ships `Kendu: 0x0`, so the zero-address rendering path is still never rehearsed. | Do not blank the local Kendu address (the nudge stream needs it) — emit `Kendu: "0x0"` from `generate-ts-addresses.js` when `LOCAL_PROMO_KENDU=false`, or add a UI fixture; and qualify the dormant-leg log line's unconditional "day-one mainnet shape" claim. | [record](../../findings/qa/Q-02-dormant-leg-local-address-book-not-mirrored.json) · `script/DeployMocks.s.sol#L2174-L2183` · [evidence](evidence/legB-dormant-02-onchain-state.txt) |

Labels are **run-scoped**. On this entry point the ledger already holds run-21 and run-26 findings under the same label strings — three distinct findings share `L-01`, three share `L-02`, three share `L-03`, three share `L-04`, three share `Q-01`, and two share `Q-02`. `L-02` is the trap: run-26's is the `wont-fix` entry dropped from carryover, run-27's is the live finding carrying the mutually-exclusive triage decision. Key every artifact, carryover copy and `/ledger` operation on the 64-character fingerprint or the `issueId`, never on the label.

### On `pps27l2` and the escaped index-4 defect

The Low-vs-Medium call on `pps27l2` is the run's load-bearing severity judgement and the corroboration deserves to be stated honestly rather than buried.

Ledger entry `85d794b386b15b201963dc03cdc36b8607f1a87b45e939323af0b1563d38aea7` — an **acknowledged Medium** on entry point `dispatcher-replace-sky-pooler`, *"Sky-pooler cutover leaves index-4 unmintable: `newPooler._minter` never set to `NFTMinterV2`, `mint(4)` reverts"* — is a real index-4 cutover defect that has **already shipped once**, at precisely the index this finding shows is rehearsed nowhere. That is not a hypothetical miss, and the report says so.

It nonetheless did **not** promote `pps27l2` to Medium. The escaped defect already carries its own Medium, where its severity properly lives. C4 Medium wants the protocol's function or availability impacted, or value leaked; `pps27l2` impacts the coverage of a *test*. A rehearsal gap does not itself cause loss — it removes one gate that would have caught a loss caused by something else. Counting that same escaped defect a second time on the rehearsal artifact would double-book it and inflate the report. The finding carries a three-clause escalation trigger to Medium, quoted in full in the QA bundle: the index-4 swap being scheduled for broadcast while rehearsed nowhere; a *second* index-4-specific defect establishing the miss as recurring; or the BPT custody transfer proving non-recoverable once mis-executed.

---

## Verification of prior findings

Four verification records, none applied. **All ledger commands below are PROPOSALS ONLY.** `fix-pending` is human-set and never auto-closed; the sanitizer wrote nothing to the ledger this run. Full records in [`classified-findings.json`](classified-findings.json) → `findings[0..3]`.

### DEV27-V01 — `pps26l1` / `eda17642828a6dd3bce6890d9900add9d27a317f80b78212a30f123301d17fd4` — **FIXED**

The filed claim was that the swap calls execute **zero** times. That claim no longer reproduces: 1/1/1 dispatched on both legs against 0/0/0 at baseline, in the mandated order, with the conservation gate proved non-vacuous. Graded FIXED rather than INCOMPLETE-FIX deliberately: run-26's recommendation said in terms *"one index is sufficient to make the ordering executable and therefore regression-testable"* and left the index unspecified. The implementation did exactly that. The residual coverage gap is a **new, narrower** claim than the one filed, so it belongs in its own entry.

```
/ledger phoenix-phase-2-staging fixed pps26l1        # PROPOSAL ONLY — ⚠ ON HOLD
```

> **⚠ ON HOLD — a human must choose.** This command is **mutually exclusive** with keeping `pps27l2` as a new entry. A triager who reads run-26's recommendation as having asked for **all five** swap classes should instead **reopen `pps26l1` as an incomplete fix and drop `pps27l2`**, in which case `pps26l1` inherits `pps27l2`'s escalation trigger verbatim. No agent took a position on the ledger shape; the choice is left visible. Note that even under the reopen reading the correct instrument is an incomplete-fix reopen, **not** an `F-XX`.

### DEV27-V02 — `pps26l3` / `12bcca3b617c6c077babfad810a2457a1b8f3a5d352217b4acb135e8b9859e79` — **FIXED**

Verified through the real `npm run dev` key, unmodified, with `LOCAL_PROMO_KENDU=false`: dormant chain state confirmed on chain, `startPromotion` absent from the 391-transaction bundle, and the toggle logged both at the top of `run()` (log line 105, between `Chain ID:` and `=== Phase 1`) and in the completion summary (lines 437-441). The armed leg still arms correctly and its four original post-condition `require`s are **byte-identical to the baseline** — the diff's only deleted line in the entire +293/−1 change is the unconditional call site `_armLocalKenduPromotion(deployer, v3);`.

```
/ledger phoenix-phase-2-staging fixed pps26l3        # PROPOSAL ONLY
```

The residual address-book fidelity gap the story discloses itself is filed separately as `pps27q2` (QA) and does **not** reopen this entry.

### DEV27-V03 — `pps26l4` / `b8e3d59139aeee24bd97a6e1087c3e992ab4dee99949a7bde8c30d55ee5e84f6` — **FIXED**

The revoke is broadcast transaction `[393]` of 394 and the ACL assertion table was checked for **completeness** against every grant site in the file, not merely for correctness. Phase 7.6 does not change the covered set: it **reuses** `uniboostHookEYE` and issues no new phUSD grant (`:1807` calls `_wireUniboost`, not `_deployUniboostHook`). One honest caveat recorded on the record: the two-field `canMint && mintVersion == phUSD.mintVersion()` idiom is used correctly, but `mintVersion` never leaves `1` on this chain, so it is correct-by-construction rather than proven discriminating by the run.

```
/ledger phoenix-phase-2-staging fixed pps26l4        # PROPOSAL ONLY — apply IN THE SAME SITTING as scheduling pps27l1
```

> **⚠ Pair this closure with `pps27l1`.** `pps27l1` is the regression this fix ships. **Closing `pps26l4` without scheduling `pps27l1` in the same sitting makes the closure read as clean while a documented developer command stays broken.** The relation is `introducedBy`, not `incompleteFixOf`, and must not be rewritten as the latter.

### DEV27-V04 — `pps26q1` / `1c98937375adc20c171c86ba91246476283add1bf72736a0e945606c643d1e9e` — **STILL-LIVE**

See **Still-open, cited but not re-filed** below. `doNotRefile: true`, `doNotClose: true`, no status proposed.

---

## Still-open, cited but not re-filed

Five ledger entries were cited by this run's analysis and are **still live at HEAD**. Each was reconciled as still-open with `lastSeenRun` bumped to `phoenix-phase-2-staging-27` and carried over in full. **None must be re-minted as a new finding** — re-minting would create a second fingerprint for a defect the ledger already tracks.

| Fingerprint | Label | Status | Why cited |
|---|---|---|---|
| `1e8cc0dc58ba0ecb…` | L-01 (run-21) | open | `DeployMocks` writes `"deploymentStatus": "completed"` unconditionally at `:2605` during forge's local pass, so a half-finished broadcast is indistinguishable from a clean one in the artifact — which is precisely why the story-074 resume-leg handling is un-rehearsable locally. Cited by the L-01 verification; unchanged. |
| `ce524709d965de78…` | L-02 (run-21) | open | `DeployMocks` still carries no `block.chainid` guard, against the project's own `CLAUDE.md`, while every `DeployMainnet*` script carries one twice. Unchanged by the delta. |
| `c76a8f9f94795987…` | L-06 (run-21) | open | Same systemic family as `pps27l3` — `DeployMocks` asserting a rehearsal step vacuously — but a different phase, function, state and fix. Cited as a neighbour, explicitly **not** collapsed into `pps27l3`. |
| `3177eed94ecb6218…` | L-03 (run-21) | open | The **mainnet** artifact's type ambiguity (`0x0` placeholders indistinguishable from real addresses). Distinct from `pps27q2`, which is the **local** artifact failing to reproduce the mainnet shape; neither fix closes the other. If both are scheduled, fix `3177eed9` first — it makes `pps27q2`'s fix cheaper and better-defined. |
| `f7de907d79814065…` | M-02 (run-21) | open | `BatchNFTMinterMultiToken.setNudgeStreamer` lacks a zero-address guard. **Unaffected by this delta** — the new path uses the guarded `Uniboost.setNudgeStreamer`. Cited to record the non-impact, not to re-file. |

### `1c98937375adc20c…` (run-26 `Q-01`, `pps26q1`) — still fully open, marginally aggravated

Q-01 is that six scripts attribute their most substantial change to a *"Story 079"* that does not exist. A document numbered 079 now exists — but it is the run-26 **remediation** story, and its own Concerns section says so verbatim: *"This story is NOT that missing story… Q-01 remains open."* Q-01 is listed under the story's *Explicitly OUT of scope* section and the executor was instructed not to touch the references.

Verified at HEAD: **22** occurrences of `Story 079` / `STORY 079` across six files (`script/DeployMocks.s.sol`, `script/interactions/AddressLoader.sol`, `ClaimPhlimboRewards.s.sol`, `FullFlowTest.s.sol`, `SetDesiredAPY.s.sol`, `WithdrawFromPhlimbo.s.sol`), **text byte-identical** to the baseline — only line numbers shifted ([`static-01-story079-refs-and-scope.txt`](evidence/static-01-story079-refs-and-scope.txt)).

The work those references attribute — the PhlimboV2 → V3 cutover rehearsal, DepositPageViewV3, the address-book restructure — therefore **still has no acceptance criteria anywhere**. Grade: **not fixed, not partially addressed, still fully open**, and if anything marginally aggravated: the number is now consumed, so a reader resolving `Story 079` from the source lands on a document describing none of the work that cites it. **Do not close this on the strength of a document numbered 079 existing** — that would be exactly the auto-close the fix-pending rules forbid.

### Stays disposed

`ec29eacd9501270a16ecd6c13c27e404357ab4e343bbfca5fd2fd421735170e4` (`pps26l2`, *"`clean:local` leaves `addresses.ts` / `local-addresses.ts` stale"*) remains human-triaged **`wont-fix`**. It was **not** re-filed, not resurrected and not carried over. `pps27l1` was checked against it and is a different script and a different mechanism — a revoked ACL grant, not a stale artifact.

---

## Law-2 faithfulness

**Zero `F-XX` findings are owed this run, and that is a reasoned decision rather than an empty channel.** The full grading is in [`../../submissions/spec-conformance.md`](../../submissions/spec-conformance.md); the summary:

Story 079 was resolved by globbing the whole `phStaging2` project tree — exactly one match, in the `complete` state folder, its recorded base commit equal to the audited HEAD. It was read in full and graded clause by clause, and the implementation was found **faithful**. Three candidates were considered for `F-XX` routing and each was declined with a stated reason:

- **`pps27l1`** — the strongest surface case, a change that shipped a broken developer command. But **story 079 found it itself**, recorded it as Autonomous Decision 4 and Review Issue 1, and deliberately declined to fix it to honour its own single-file constraint; both validators endorsed that reading and both recommended scheduling the one-liner. The implementation does exactly what the story says, including the part where the story says *"this breaks, and I am not fixing it here."* Filing `F-XX` would penalise a story for disclosing a consequence honestly.
- **`pps27l2`** — run-26's recommendation left the index unspecified; one index is what was asked for and one index is what was built. A residual coverage gap, not a deviation.
- **`pps27q2`** — the story discloses the residual in its own Concerns and correctly scoped the fix out (the Kendu nudge stream legitimately needs MockKendu). What remains is an unqualified log-line claim, which is comment accuracy — squarely QA under C4.

### The story-078:301 tension — recorded, and **nominal**

Story 078 states at line 301: *"Do not modify `DeployMocks.s.sol`."* The delta modifies exactly that file, +293/−1. The tension is real and is recorded here rather than left for a reader to discover, but it is adjudicated as **nominal**:

1. **078's constraint is scoped to its own change.** It is the trailing clause of a bullet about `DROPPED_CONTRACT_NAMES`, inside 078's own constraints section — a blast-radius fence around that story's view-surface rework, not a standing repository-wide freeze. Reading it as a freeze would make every subsequent story touching the file — including the audit remediations the project itself asked for — a spec violation by construction.
2. **The added lines contain zero 078 view symbols.** Verified mechanically, not argued: a sweep of `DepositPageView` / `MintPageView` / `ViewRouter` / `DROPPED_CONTRACT_NAMES` / `DepositView` across the diff's **added** lines returns **0 occurrences** ([`static-04-law2-078-and-scope.txt`](evidence/static-04-law2-078-and-scope.txt)).
3. **The sole deleted line is `_armLocalKenduPromotion(deployer, v3);`** — the L-03 gating target, not a view surface.
4. Story 079 is later, more specific, and names `DeployMocks.s.sol` in its title as its sole in-scope file.

The delta cannot disturb what 078 was protecting. No `F-XX` is owed and no follow-up action is proposed; the adjudication is recorded so a future reader who greps 078 for constraints does not mistake a resolved tension for an unexamined one.

---

## Coverage and limits

What this run did **not** cover matters as much as what it did.

- **Entry-point scoped.** This was `/audit-script` over the `dev` closure across the `e1db0f1 → 1d8a3a7` delta, not a project sweep. `entryPointBaselines.dev` is advanced to `1d8a3a7`; the **project-level `lastAuditedCommit` remains `0e190e8`** and `branchBaselines.master` is likewise unadvanced. **The project baseline is 134 files behind HEAD, and those files remain unscanned at project level.** Advancing either baseline on the strength of an entry-point-scoped run would silently drop unscanned code from the next regression diff — a Law-1 recall failure. Precedent: runs 20–26.
- **No mainnet fork, by design and by correctness.** `dev` targets a fresh anvil; every address in the closure is minted at run time, so `RPC_MAINNET` / `ETHERSCAN_API_KEY` corroboration is not applicable. Bytecode corroboration on 31337 is recorded `skipped`, not as a gap.
- **`pps27l4`'s mainnet leg is `unverified`.** The **shape** of the mainnet twin `_swapUniboost` (`DeployMainnetPromotionReady.s.sol:1443-1538`) is statically confirmed to have no sweep. The **magnitude** of retained prime held by the live indices 1/2/3 incumbents at cutover time was **not measured** — no fork was in scope here. That claim contributed **zero** to the finding's severity label, which derives exclusively from what was measured on chain 31337 plus the statically-confirmed shape. The magnitude question is **referred to the `promotion-ready` entry point**, where a fork-based measurement of each incumbent's prime balance belongs. Do not read it as measured.
- **4naly3er could not compile the two files every finding is filed against.** The appendix at [`../../submissions/4naly3er-report.md`](../../submissions/4naly3er-report.md) covers the 25 first-party `src/**/*.sol` files and **excludes** `script/DeployMocks.s.sol` and `script/interactions/FundTestUser.s.sol`. The cause is a tool limitation, not a defect in the scripts: 4naly3er's own solc invocation does not honour the repo's `lib/<a>/lib/<b>/=` diamond-canonicalization remappings (`foundry.toml:51-77`), so `IPausable` and siblings resolve from two physical files and solc emits `DeclarationError: Identifier already declared`. The same scripts compile cleanly under forge and were executed end-to-end on chain 31337 during this audit. The limitation was recorded at run-25 and was **re-attempted and re-confirmed at HEAD `1d8a3a7`**, not assumed. **Consequence: the appendix provides no automated coverage of the deploy/rehearsal scripts, and neither corroborates nor contradicts any of the six findings. Do not read a clean line there as a clean line here.**
- **Known-issues suppression was blocked.** The `known-issues.md` declared for this project does not exist at HEAD, so the 11 strings cached in `registered-projects.json` are a registry-only snapshot with no authority. No finding was suppressed, softened or down-ranked on known-issues grounds.
- **Not enumerated:** `./simulate-yield.sh` and `server/index.js` were not enumerated for state reads (no delta impact expected, and none observed).
- **Law-1 accounting.** Zero findings dropped, parked or suppressed. All ten input records reached classification and reporting; all six new findings are in visible channels; all four verification records are reported; all twenty still-open `dev` ledger entries are carried over in full, never as pointer stubs.
