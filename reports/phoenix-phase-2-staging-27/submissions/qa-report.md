# QA Report — phoenix-phase-2-staging, audit 27

**Project:** `phoenix-phase-2-staging` @ commit `1d8a3a7` (`1d8a3a7515adca7819c530a01a87c132863a5ae2`, branch `master`)
**Run:** `phoenix-phase-2-staging-27`
**Audit type:** **script audit** — `/audit-script`, entry point **`dev`** (`package.json` → `npm run dev`)
**Execution mode:** local **anvil, chain 31337** — **no mainnet fork was used or in scope for this entry point**. Both legs were run end-to-end: the armed leg (`LOCAL_PROMO_KENDU=true`) and the dormant leg (`LOCAL_PROMO_KENDU=false`).
**Known-issues suppression:** **BLOCKED this run.** The `known-issues.md` declared for this project **does not exist at HEAD**, so the 11 strings cached in `registered-projects.json` are a registry-only snapshot with **no authority**. No finding in this report was suppressed, softened or down-ranked on known-issues grounds.

**This bundle is the run's primary submission artifact.** Run 27 produced **no High and no Medium findings**; everything the run has to say about new defects is below.

## Summary

| Severity | Count |
|----------|------:|
| Low | 4 |
| QA | 2 |
| Centralization | 0 |
| **Total (new, this run)** | **6** |

| Label | issueId | Title (abbreviated) | Contract |
|-------|---------|---------------------|----------|
| L-01 | `pps27l1` | `npm run test:fund-user` bricked by the terminal privilege sweep | `script/interactions/FundTestUser.s.sol` |
| L-02 | `pps27l2` | Cutover rehearsal covers 1 of 5 mainnet dispatcher swaps, and is not re-targetable | `script/DeployMocks.s.sol` |
| L-03 | `pps27l3` | Intermediate-window assertion pins the premise, not the consequence | `script/DeployMocks.s.sol` |
| L-04 | `pps27l4` | Retired dispatcher retains unswept prime; mainnet twin has the same shape | `script/DeployMocks.s.sol` |
| Q-01 | `pps27q1` | `tokenIdToDispatcher` not asserted in the post-swap invariant block | `script/DeployMocks.s.sol` |
| Q-02 | `pps27q2` | Dormant leg mirrors mainnet's promo slot but not its address book | `script/DeployMocks.s.sol` |

### Labels are run-scoped — key on fingerprint

Every label in this file is **run-27's**. On entry point `dev` the ledger already holds a run-21 and a run-26 finding under **the same label strings** — three distinct findings share `L-01`, three share `L-02`, three share `L-03`, three share `L-04`, three share `Q-01`, and two share `Q-02`. Note `L-02` in particular: run-26's `L-02` (`pps26l2`) is the `wont-fix` entry removed from the carryover bundle, while run-27's `L-02` (`pps27l2`) is the live finding carrying the mutually-exclusive triage decision — collapsing those two on the label would be a serious error. Never key an artifact, a carryover copy or a `/ledger` operation on a label. Key on the 64-character fingerprint, or on the `issueId`.

### This is not the full open set

This bundle covers **only run-27's own six findings**. It deliberately does **not** renumber around, absorb or restate the prior-run entries that remain open. Those live beside it and must be read with it:

- [`carryover/qa-report-05.md`](carryover/qa-report-05.md) — audit-05 QA still open (1 entry)
- [`carryover/qa-report-21.md`](carryover/qa-report-21.md) — audit-21 QA/Low still open (13 entries + M-02 appendix; **none** disposed)
- [`carryover/qa-report-26.md`](carryover/qa-report-26.md) — audit-26 QA/Low still open (L-01, L-03, L-04, Q-01; L-02 removed as `wont-fix`)
- [`M-01-C1.md`](M-01-C1.md) — carried Medium, prior run
- [`spec-conformance.md`](spec-conformance.md) — Law-2 faithfulness for this run (none of the six below is a story deviation)
- [`4naly3er-report.md`](4naly3er-report.md) — automated SAST/gas appendix; **read its scope note first** (see the appendix section at the end of this file)

---

## Low Risk Findings

### [L-01] The terminal privilege sweep bricks `npm run test:fund-user` on every fresh local chain, and the comment on the failing line still claims the deployer is an authorized minter <!-- id: pps27l1 -->

- **issueId:** `pps27l1`
- **Fingerprint:** `65db3324e7d0bc49f2c26be40c067ec8d578a112a2088065f53bc726c2af42f9`
- **Location:** `script/interactions/FundTestUser.s.sol#L45-L46` (`run`) — repo path `lib/phoenix-phase-2-staging/script/interactions/FundTestUser.s.sol`
- **Root cause class:** `PrivilegeRevocationBreaksDependentScript`
- **Relation:** **`introducedBy`** `b8e3d59139aeee24bd97a6e1087c3e992ab4dee99949a7bde8c30d55ee5e84f6` (`pps26l4`, run-26 L-04)

**Relation — read this before triaging.** L-01 is a **regression introduced by** the fix to run-26's `pps26l4`. It is **not** an incomplete fix and must not be rewritten as one: `pps26l4`'s claim was "the deployer's phUSD grant is never revoked", and its fix closed that claim completely and correctly on `DeployMocks.s.sol`. This entry is the **collateral** that fix shipped, in a different file, with a different root cause and a different one-line remedy. Closing `pps26l4` without scheduling this one in the same sitting makes the closure read as clean while a documented developer command stays broken.

**Description**

`_sweepResidualPrivileges` (`DeployMocks.s.sol:1917`) revokes the deployer's phUSD mint authority as the **last transaction of every `npm run dev`** — transaction `[393]` of 394 in the broadcast bundle. `FundTestUser.s.sol:46` then calls `MockPhUSD(phUSD).mint(testUser, phUSDAmount)` inside a broadcast opened at `:43` with `AddressLoader.getDefaultPrivateKey()` — anvil account #0, i.e. the deployer — and the file contains no `setMinter` re-grant anywhere.

This is live today, reproduced empirically on a fresh chain immediately after a clean `npm run dev`: **`npm run test:fund-user` exits 1 with the verbatim revert `Not authorized to mint`** (`src/mocks/MockPhUSD.sol:48`), trace tail `└─ ← [Revert] Not authorized to mint` / `Error: script failed: Not authorized to mint`.

The comment immediately above the failing call — `FundTestUser.s.sol:45`, `// Mint phUSD (deployer is authorized minter)` — **now asserts the opposite of the truth** and will actively mislead whoever debugs this.

A repo-wide consumer sweep bounds the blast radius at exactly one dependent: `simulate-yield.sh` mints permissionless `MockDola`; `MintPhUSD.s.sol` routes through `PhusdStableMinter`'s own grant; `FullFlowTest.s.sol` uses `minter.mint`. But `script/interactions/README.md` points at `npm run test:fund-user` **four times** (`:47`, `:283`, `:352`, `:383` — the last reading "Fund test user first"), so the broken command sits inside the documented developer workflow rather than in an obscure corner.

Story 079 found this itself, recorded it as Autonomous Decision 4 / Review Issue 1, and deliberately declined to fix it to honour its own single-file constraint; both validators endorsed that reading and both recommended scheduling the one-liner. **Filing it here is that scheduling, not a disagreement** — and it is therefore not routed to `spec-conformance.md`.

**Impact**

A documented developer-onboarding command fails on every fresh local chain, with a revert that points at the token rather than at the deploy script that removed the grant. No asset, availability or value impact — chain 31337, mock token, published key. The cost is a developer's time, recurring on every fresh chain, and lengthened by a comment that confidently states a false precondition.

**Recommended Mitigation**

> Add the one-line self-grant inside `FundTestUser.s.sol`, immediately after `vm.startBroadcast(deployerKey);` at `:43` and before the mint at `:46` — `MockPhUSD(phUSD).setMinter(deployer, true);` — since the deployer remains the token owner after the sweep. Update the now-false comment at `:45` to say the script grants itself the right rather than assuming it. Prefer the self-grant over re-exempting the deployer in the sweep: the sweep's declarative end-state ACL is the more valuable artifact and should not be weakened to accommodate a utility script. Optionally symmetric: revoke again before `vm.stopBroadcast()` so the utility leaves the ACL as it found it.

**Escalation trigger**

Raise above Low if any **further** consumer of the deployer's phUSD grant is added or found that sits on the mainnet or promotion-ready side rather than chain 31337, or if the same sweep pattern is mirrored into a mainnet script where the revoked grant is needed by a subsequent live step. Either moves the harm axis off the disposable chain.

**Evidence**

- `script-audits/dev/evidence/legA-armed-10-fund-user-regression.log` — the failing run, verbatim revert
- `script-audits/dev/evidence/legA-armed-09-phusd-acl.txt` — post-sweep phUSD ACL state
- `script-audits/dev/evidence/legA-armed-04-broadcast-callcounts.txt` — tx `[393]` = `MockPhUSD.setMinter(deployer,false)`, the last tx of 394

---

### [L-02] The cutover rehearsal covers 1 of 5 mainnet dispatcher swaps and is not re-targetable to the other classes <!-- id: pps27l2 -->

- **issueId:** `pps27l2`
- **Fingerprint:** `6af1ae30ed82698039f24b41a9d1dc5a672bf3723ee364435c3df179457f85c5`
- **Location:** `script/DeployMocks.s.sol#L1768-L1871` (`_rehearseDispatcherSwap`)
- **Root cause class:** `PartialRehearsalCoverage`
- **Borderline:** yes — Low vs Medium is a genuine judgement call here; see the unresolved decision below.

**Description**

`DeployMainnetPromotionReady.s.sol` performs the swap on five indices — 1, 2, 3 (Uniboost, USDC 6dp), 4 (BalancerPoolerV2, USDS 18dp) and 7 (NudgeRatchet) — with `pull` / `setDispatcher` / `setHook` / `replaceDispatcher` call sites at `:1300`/`:1341`/`:1342`/`:1363`, `:1456`/`:1519`/`:1520`/`:1528` and `:1584`/`:1623`/`:1624`/`:1632`. **Phase 7.6 mirrors exactly one**, on index 1.

Indices 2 and 3 are genuine duplicates of index 1 and cost nothing. Index 7's two distinguishing claims (`hookTypeId`, `ratio == 100`) are honestly pinned by static assertions that execute and pass. **Index 4 has no local mirror of any kind**, and it is the index that differs most: its mainnet swap carries a **BPT custody transfer old → new** governed by a five-clause safety doctrine and a resume guard (`:1385-1420`), and its hook `scale` is `1` rather than `1e12` because the prime is 18-decimal USDS. The local rehearsal only ever exercises the 6-decimal branch, so any defect class that manifests only on an 18-decimal prime is definitionally out of reach.

Crucially the helper is **not re-targetable despite appearances**. `REHEARSAL_SWAP_INDEX` (`:225`) looks like a knob, but `_rehearseDispatcherSwap` constructs the replacement as a `Uniboost` (`:1805`), asserts `rewardToken.decimals() == 6` (`:1818`), and asserts `require(price < 1e12, "index price is not 6-decimal-shaped")` (`:1846`) — which would **fail outright at index 4**, where the registered price is `10 * 10**18`. Changing the constant alone breaks the run. `price < 1e12` is additionally a magnitude heuristic with no mainnet counterpart.

This is not a hypothetical miss. Ledger entry `85d794b386b15b201963dc03cdc36b8607f1a87b45e939323af0b1563d38aea7` (acknowledged Medium, entry point `dispatcher-replace-sky-pooler`) — "Sky-pooler cutover leaves index-4 unmintable: `newPooler._minter` never set to `NFTMinterV2`, `mint(4)` reverts" — is a real index-4 cutover defect that already shipped, at precisely the index this finding shows is rehearsed nowhere.

**Impact**

The class of defect the local chain can catch is "a 6-decimal Uniboost swap went wrong", not "a cutover swap went wrong". The BPT custody shift — the single highest-value movement in the whole cutover — and the 18-decimal-prime hook-scale interaction remain rehearsed nowhere. The ordering property itself **is** class-independent and **is** genuinely gated, so this narrows the fix's reach rather than negating it.

**Escalation trigger (verbatim from the finding record)**

> Raise to MEDIUM if ANY of the following becomes true: (a) the index-4 mainnet swap — including the BPT custody transfer old->new — is scheduled for broadcast while it remains rehearsed NOWHERE (no local mirror, no fork rehearsal in the promotion-ready entry point, no Foundry unit test covering the custody shift), because at that point this gap is the sole missing gate on the highest-value movement in the cutover; or (b) a SECOND index-4-specific cutover defect is discovered, which would establish the miss as recurring rather than a single incident; or (c) the BPT custody transfer is found to be non-recoverable once mis-executed (no owner-side rescue path), since an unrehearsed irreversible high-value movement is an availability/value question, not a coverage question. Absent all three, Low is the honest label.

**⚠ Unresolved human decision — the two outcomes are mutually exclusive**

This entry is `residualOf` `eda17642828a6dd3bce6890d9900add9d27a317f80b78212a30f123301d17fd4` (`pps26l1`, run-26 L-01). Run-26's L-01 claimed the swap calls execute **zero** times; this run proves they now execute, so that filed claim is closed. L-02 makes a **new, narrower** claim: only 1 of 5 mainnet swap classes is mirrored, and the helper is not re-targetable.

A triager who reads run-26's recommendation as having asked for **all five** classes may reasonably prefer to **reopen `pps26l1` as an incomplete fix** instead of minting this entry. **If the reopen is chosen: do NOT apply `/ledger phoenix-phase-2-staging fixed pps26l1`; drop this entry and annotate `pps26l1` as an incomplete fix, which then inherits L-02's escalation trigger verbatim.** No agent took a position on the ledger shape; the choice is left visible.

**Recommended Mitigation**

> Two options, in preference order. (a) Add a second rehearsal on index 4 in a follow-on story: swap `BalancerPoolerV2` with the BPT custody shift mirrored (`old.withdrawBPT(new)` with the destination asserted, then `replaceDispatcher(4)`), which exercises the 18-decimal prime, `scale == 1`, and the highest-value movement in the cutover. (b) At minimum, make the existing helper honestly index-1-only: rename `REHEARSAL_SWAP_INDEX` to something that does not read as a knob, or replace the hard-coded `price < 1e12` with a decimals-derived bound (`price < 10 ** (uint256(IERC20Metadata(prime).decimals()) + 6)` or equivalent) and gate the `decimals() == 6` assertion on the dispatcher class. Either way, add a comment stating explicitly which mainnet indices are and are not mirrored, so the coverage claim is not over-read.

**Evidence**

- `script-audits/dev/evidence/static-03-mainnet-swap-coverage.txt` — the five mainnet swap sites vs the one local mirror
- `script-audits/dev/evidence/legA-armed-04-broadcast-callcounts.txt`
- `script-audits/dev/evidence/legA-armed-07-onchain-swap-state.txt` — `hook.scale == 1e12`, reward-token decimals 6

---

### [L-03] The intermediate-window assertion pins the fail-closed premise instead of its consequence <!-- id: pps27l3 -->

- **issueId:** `pps27l3`
- **Fingerprint:** `19e2e0c2d6a35689a2216fc420de9ff53d0331ec45cec36b9ce31e8dcb85b6b9`
- **Location:** `script/DeployMocks.s.sol#L1828-L1834` (`_rehearseDispatcherSwap`); property lives at `lib/yield-claim-nft/src/hooks/UniboostMintDebtHook.sol:128-136`
- **Root cause class:** `AssertionRestatesPremiseNotConsequence`
- **Borderline:** mildly, toward QA — resolved at Low, with a checkable de-escalation condition below.

**Description**

Run-26's L-01 recommendation asked for proof "(iii) that a mint attempted in the intermediate window **REVERTS** rather than succeeding". Story 079 Decision 9 substituted a **structural** assertion: `require(hook.dispatcher() == address(newUb), ...)` plus `(address midDispatcher,,,) = nftMinterV2.configs(idx); require(midDispatcher == oldUb, ...)`. The stated rationale is sound and the story explicitly permits the choice — a reverting call issued while `vm.startBroadcast` is active is recorded into the broadcast bundle and would fail `deploy:local`.

But the two assertions restate the **setup** — hook points at new, index still points at old — and then derive the revert by reasoning about a line they never touch: `UniboostMintDebtHook.onDispatch:129`, `if (msg.sender != dispatcher) revert OnlyDispatcher();`. **Delete that line and the local rehearsal still passes green, the run still exits 0, and the fail-closed property — the entire reason the mainnet ordering is what it is — is silently gone.**

That is not a contrived edit: `UniboostMintDebtHook` is a first-party contract under active development and the hook is explicitly designed to be repointable across swaps. Both assertions currently pass on chain, so there is **no live defect** — this is a gate that would not catch the regression it was added for.

**Impact**

Phase 7.6 regression-gates the **order** of the four calls (which it does well) but not the **consequence** that makes that order correct. A future change removing or weakening the `OnlyDispatcher` gate would ship with a green local rehearsal — the specific failure shape the rehearsal was added to prevent, and one whose wrong direction the mainnet script itself characterises as a silent value leak.

**Escalation and de-escalation triggers (verbatim from the finding record)**

> Two triggers. Raise toward MEDIUM if the `OnlyDispatcher` gate in `UniboostMintDebtHook.onDispatch` is in fact modified, removed, or made conditional in any commit while no test anywhere asserts the revert — at that point the ungated property is a live fail-open on the mainnet cutover ordering, not a coverage gap. Conversely, DROP to QA if a Foundry unit test is confirmed to exist in `lib/yield-claim-nft` asserting `onDispatch` reverts `OnlyDispatcher()` for a non-dispatcher caller: the property would then be gated somewhere, and this reduces to a preference about where.

**Recommended Mitigation**

> Add the live probe the story's own Implementation Notes step 6 already specifies, bracketed outside the broadcast so it is never recorded into the bundle: between `vm.stopBroadcast()` and `vm.startBroadcast(deployerPrivateKey)`, mint the prime budget and approve, then `try nftMinterV2.mint(idx, deployer) { revert("intermediate-window mint SUCCEEDED - fail-closed ordering is broken"); } catch {}`. Keep the structural assertions as well — they localise the failure. If the bracketing is judged too risky inside a `--slow` broadcast, the cheaper alternative is a standalone Foundry unit test in the yield-claim-nft repo asserting that `onDispatch` reverts `OnlyDispatcher()` for a non-dispatcher caller, so the property is gated somewhere even if not in this script.

**Neighbours — cited, not collapsed**

- `c76a8f9f94795987c0d2aa5626c69a8afc430b24423cf3c853b9199022e4e9d1` (L-06, open) — same systemic family (DeployMocks asserts a rehearsal step vacuously), different phase, function, state and fix. Must not be re-minted.
- `c358427cf96b10658184091d879bb13ddaf8f0a6ecf181f1452625dff1590702` (entry point `uniboost-cutover`, open Low) — concerns the **mainnet** window being genuinely non-atomic; L-03 concerns the **local rehearsal's** assertion not proving the revert property.
- **Q-01 below is related but separate** — see the note under Q-01.

**Evidence**

- `script-audits/dev/evidence/story079-full.diff` (added lines 193-205) — the substituted assertions
- `script-audits/dev/evidence/legA-armed-03-deploy.log` (lines 301-302) — both assertions passing on chain
- `lib/yield-claim-nft/src/hooks/UniboostMintDebtHook.sol:128-136` — the ungated property

---

### [L-04] The dispatcher swap retires a Uniboost still holding retained prime and never sweeps it, and the mainnet twin `_swapUniboost` has the same no-sweep shape on live positions <!-- id: pps27l4 -->

- **issueId:** `pps27l4`
- **Fingerprint:** `9ee101a0cc41eb9330ea64db0607f4e17afb65ce8d0afedafb497056dd080066`
- **Location:** `script/DeployMocks.s.sol#L1780-L1866` (`_rehearseDispatcherSwap`); mainnet twin `DeployMainnetPromotionReady.s.sol:1443-1538` (`_swapUniboost`)
- **Root cause class:** `RetiredContractRetainsValueNoSweep`
- **Law 3:** reportable **non-obvious operational footgun**, not an owner-trust suppression and not an owner-malice vector.

**Description**

`Uniboost._dispatch` streams `donationSplit%` of the dispatched prime to the recipient and **retains the remainder** for a later `pool()` (`Uniboost.sol:222-238`; split is 50). `_accrueIndex1MintDebt` now deterministically drives one extra index-1 mint on every local run, adding to that retained balance, and Phase 7.6 retires the holder moments later **with no sweep and no assertion about its balance**.

Measured on chain after a clean run: the retired incumbent `0xdbC43Ba45381e02825b14322cDdd15eC4B3164E6` holds `20030020` (20.030020 USDC) — exactly 50% of four index-1 mints at prices `10000000 + 10010000 + 10020010 + 10030030` — of which `5015015` (25%) was created by story-079's own accrual mint; the remaining `15015015` pre-existed the fix. **The change did not invent the residue; it converted a live retained balance on the LIVE dispatcher into a residue on an OFF-INDEX one.** The replacement starts at zero retained prime (verified: `USDC.balanceOf(new) == 0` immediately post-swap).

**The value is parked, not lost, and this was proved rather than assumed.** `Uniboost.rescueERC20(USDC, deployer, 20030020)` against the retired contract returned status `0x1` and left its balance at **0**; `pool()` remains callable there (`poolerAuthVersion(MultiPooler) == authVersion == 1`, owner still the deployer). This is explicitly **not** filed as a value leak.

The cross-artifact half is why it is worth recording: mainnet `_swapUniboost` (`DeployMainnetPromotionReady.s.sol:1443-1538`) has **no sweep either**, and its indices 1/2/3 incumbents are live dispatchers that have been accumulating real retained USDC from real user mints.

**⚠ Unverified claim — the mainnet magnitude was NOT measured**

> `unverifiedClaims`: *the magnitude of retained prime held by the mainnet indices 1/2/3 Uniboost incumbents at cutover time.*

The **shape** of the mainnet twin is statically confirmed. The **magnitude** is not: `dev` targets a fresh anvil and no mainnet fork was in scope for this entry point. This claim contributed **zero** to the severity label — the label derives exclusively from what was measured on chain 31337 plus the statically-confirmed shape. The magnitude question is **referred to the promotion-ready entry point**, where a fork-based measurement of each incumbent Uniboost's prime balance belongs. Do not read it as measured.

**Impact**

Local: cosmetic — a small residue on a disposable chain, recoverable in one owner transaction (demonstrated). Mainnet (**magnitude unverified**): after the cutover the retained-prime pot silently splits across two addresses; any pooling automation bound to the address-book dispatcher calls `pool()` on a contract whose retained balance is zero and reverts `"Uniboost: nothing to pool"` until fresh mints accrue, while the real balance sits on a retired contract nothing points at. Recoverable in one owner transaction once noticed. The Law-3 footgun test is met: a competent, non-malicious operator would reasonably assume the dispatcher the address book names is the dispatcher holding the pot, and would be surprised to learn otherwise.

**Escalation trigger**

Raise to **Medium** if a fork measurement at the promotion-ready entry point shows a mainnet incumbent holding a materially non-trivial retained prime balance **and** any of: recovery is not a single owner transaction (`rescueERC20` unavailable, ownership transferred or renounced, or a `poolerAuthVersion` / `authVersion` mismatch making `pool()` unreachable on the retired contract); or the pooling automation's revert is persistent enough to halt a distribution the protocol depends on. Raise to **High** only if the retained balance is shown to be genuinely **unrecoverable** — at that point it is asset loss, not misplacement.

**Recommended Mitigation**

> In DeployMocks Phase 7.6, snapshot `IERC20(rewardToken).balanceOf(oldUb)` before the swap and, after `replaceDispatcher`, either sweep it to the replacement (`oldUb.rescueERC20(rewardToken, address(newUb), residue)`) or assert it is zero — so the local rehearsal actually exercises the decision instead of leaving it implicit. More importantly, carry the question to the promotion-ready entry point: before the mainnet cutover, read each incumbent Uniboost's prime balance and decide explicitly whether to sweep it to the replacement or leave it for a later `rescueERC20`; whichever is chosen, assert the end state so the pot's location is recorded rather than discovered. Recommend a fork-based measurement of the mainnet incumbents' balances as part of that entry point's audit.

**Evidence**

- `script-audits/dev/evidence/legA-armed-07-onchain-swap-state.txt` — post-swap dispatcher/hook state
- `script-audits/dev/evidence/legA-armed-08-retired-dispatcher.txt` — the `20030020` balance and the successful `rescueERC20` probe (status `0x1`, balance → 0)
- `script-audits/dev/evidence/legB-dormant-04-obs03-residue.txt` — residue on the dormant leg
- `script-audits/dev/evidence/legA-armed-11-postswap-mint-probe.txt` — replacement starts at zero retained prime

---

## QA Findings

### [Q-01] Phase 7.6 asserts `configs` and both directions of `dispatcherToIndex` but not `tokenIdToDispatcher`, the third mapping `replaceDispatcher` repoints and the one that drives NFT metadata <!-- id: pps27q1 -->

- **issueId:** `pps27q1`
- **Fingerprint:** `9067d8a232b53421317b2663c757a6b80f5dc77076d138bd691a8fcfff49f947`
- **Location:** `script/DeployMocks.s.sol#L1840-L1853` (`_rehearseDispatcherSwap`); contract under test `lib/yield-claim-nft/src/NFTMinterV2.sol:227-247`
- **Root cause class:** `IncompleteAssertionCoverage`

**Relationship to L-03 — related, not merged.** Q-01 and L-03 are both "the Phase 7.6 assertion block does not cover X" on the same function, and may reasonably be read side by side. They are **separate findings with separate fixes and different severities**, and were kept separate on the separate-mitigation test: a `try/catch` mint probe does nothing for `tokenIdToDispatcher`, and a `tokenIdToDispatcher` require does nothing for `OnlyDispatcher`. **Do not merge the ledger entries, and do not level the severities** — L-03 is Low, Q-01 is QA. Merging would also lose the `uri()`/metadata analysis, which is unique to this entry.

**Description**

`NFTMinterV2.replaceDispatcher` repoints **three** mappings: `configs[index].dispatcher` (`:238`), `dispatcherToIndex` old/new (`:241-242`) and `tokenIdToDispatcher[index]` (`:244`). Phase 7.6 asserts the first two in both directions, plus price/growth/disabled preservation — thorough — but **never reads the third**.

That mapping is what `NFTMinterV2.uri(id)` dereferences to build each NFT's metadata JSON (name/image/description pulled from the dispatcher). Verified on chain that **no defect exists today**: `tokenIdToDispatcher(1) == 0xdB05A386810c809aD5a77422eb189D36c7f24402`, correctly repointed on both legs.

The realistic failure the gap would miss is a future edit to `replaceDispatcher` dropping line 244, after which every index-1 NFT's `uri()` would keep resolving through the **retired** dispatcher's metadata — a stale but well-formed string that nothing would flag. The mainnet script shares the same omission, so closing it here would make the local rehearsal strictly stronger than its mirror (which it already is on `disabled` and `price < 1e12`).

**Impact**

None today. A one-line assertion gap in an otherwise exhaustive post-condition block, on the one mapping whose failure mode is silent-and-plausible rather than loud.

**Escalation trigger**

Raise to **Low** only if `tokenIdToDispatcher` is found to be written **conditionally** somewhere — a path where the sibling writes land but this one does not — which would make the gap reachable without a code edit and turn a completeness note into a real blind spot.

**Recommended Mitigation**

> Add one line to the post-swap invariant block at `:1849-1853`: `require(nftMinterV2.tokenIdToDispatcher(idx) == address(newUb), "tokenIdToDispatcher did not repoint - uri() would resolve through the retired dispatcher");`. Consider mirroring it into `DeployMainnetPromotionReady.s.sol`'s per-index preservation read-back for the same reason.

**Evidence**

- `script-audits/dev/evidence/legA-armed-07-onchain-swap-state.txt` — `tokenIdToDispatcher(1)` correct on both legs
- `lib/yield-claim-nft/src/NFTMinterV2.sol:227-247` — the three writes

---

### [Q-02] The dormant leg mirrors mainnet's promo slot but not its address book: `local-addresses.ts` still ships a real, funded MockKendu where `mainnet-addresses.ts` ships `Kendu: 0x0` <!-- id: pps27q2 -->

- **issueId:** `pps27q2`
- **Fingerprint:** `e0ac78243e5fe4b85b1d4165e2cea13c5d311f5153805bddb215b9b73a4b7644`
- **Location:** `script/DeployMocks.s.sol#L2174-L2183` (`_rehearsePhlimboV3Cutover`); artifacts `server/deployments/local-addresses.ts` vs `server/deployments/mainnet-addresses.ts`
- **Root cause class:** `PartialDayOneMirror`

**Description**

With `LOCAL_PROMO_KENDU=false` the PhlimboV3 promo slot is genuinely dormant on chain — `promoToken` `0x0`, phase 0, balance 0, rate 0, `startPromotion` broadcast **zero** times — which is the mainnet day-one shape and is exactly what run-26 L-03 asked for.

But the generated address book is not a mirror: `server/deployments/local-addresses.ts` carries `Kendu: "0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82"`, a real MockKendu with `totalSupply` `1.05e24`, whereas the hand-maintained `server/deployments/mainnet-addresses.ts` carries `Kendu: "0x0000000000000000000000000000000000000000"`. So a UI developer on the dormant leg exercises "dormant promotion on a live token address", while day-one mainnet presents "dormant promotion on the zero address" — **the zero-address handling path is still never rehearsed**.

Story 079 discloses this in its own Concerns ("The dormant leg is not a perfect mainnet mirror") and correctly rejected blanking the local Kendu address as out of scope: the Kendu nudge stream legitimately uses MockKendu and gating it was explicitly forbidden. The implementation is therefore faithful, and this was **considered for spec-conformance routing and deliberately declined**. What remains is the dormant-leg **log line**'s unqualified "this is the day-one mainnet shape" — a comment-accuracy issue, squarely QA under C4.

**Impact**

The dormant leg is a faithful mirror of the **contract state** and a partial mirror of the **environment**. The UI's zero-address-token rendering path remains unexercised locally.

**Relation to existing entries — distinct, adjudicated**

- `3177eed94ecb62181138179a2d2c1e1c9be6830b111ba69f2f0a1bd483b93237` (L-03, open) — that entry is about the **mainnet** artifact's type ambiguity (a consumer cannot tell "not deployed" from a real address); Q-02 is about the **local** artifact failing to reproduce the mainnet shape. They share only the premise "mainnet Kendu is 0x0". Neither fix closes the other. **Sequencing:** fixing `3177eed9` first (a placeholder type distinguishable from a real address) makes Q-02's fix cheaper and better-defined.
- `12bcca3b617c6c077babfad810a2457a1b8f3a5d352217b4acb135e8b9859e79` (L-03, run-26) — `residualOf`; this entry explicitly **does not reopen** it.

**Escalation trigger**

Raise to **Low** if the UI is shown to have a zero-address-token handling path that actually diverges (a render or read that behaves differently at `0x0` and is not covered by any other fixture) — the gap would then be hiding a real, identified defect class rather than an unexercised branch.

**Recommended Mitigation**

> Do not blank the local Kendu address — it would break the nudge stream, which legitimately needs MockKendu. Instead give the dormant leg a way to reproduce the zero-address environment without touching the chain: emit `Kendu: "0x0"` into the generated `local-addresses.ts` when `LOCAL_PROMO_KENDU=false` (a change in `server/generate-ts-addresses.js` keyed off the same toggle, not in the Solidity), or add a third UI-side fixture. Either way, amend the dormant-leg log line so it states which parts of the mainnet day-one shape it does and does not reproduce, rather than the current unqualified "this is the day-one mainnet shape".

**Evidence**

- `script-audits/dev/evidence/legB-dormant-02-onchain-state.txt` — promo slot dormant (`promoToken` `0x0`, phase 0, balance 0, rate 0)
- `script-audits/dev/evidence/legB-dormant-03-broadcast-callcounts.txt` — `startPromotion` broadcast zero times

---

## Centralization Risks

**None.** No `C-XX` finding was raised this run. Three of the six entries above were explicitly checked against Law 3: L-01 and L-03 involve no owner action at all; L-04 was assessed and **retained as a reportable non-obvious operational footgun** rather than suppressed under owner trust, with its safe-config guidance carried in the recommendation. No malicious-owner vector is asserted anywhere in this report.

---

## Appendix — Automated report (4naly3er)

Attached as [`4naly3er-report.md`](4naly3er-report.md), generated against `lib/phoenix-phase-2-staging` @ `1d8a3a7`.

**Its scope is narrower than this run's findings, and the gap is recorded rather than left silent.** The appendix covers the **25 first-party `src/**/*.sol` files** (`src/mocks/`, `src/views/`) — 15 gas classes, 28 NC classes, plus Low and Medium sections. It **excludes** `script/DeployMocks.s.sol` and `script/interactions/FundTestUser.s.sol`, i.e. the two contracts every one of the six findings above is filed against.

The exclusion is a **tool limitation, not a defect in the scripts**: 4naly3er's own solc invocation does not honour the repo's `lib/<a>/lib/<b>/=` diamond-canonicalization remappings (`foundry.toml:51-77`), so `IPausable` and siblings resolve from two physical files and solc emits `DeclarationError: Identifier already declared`. The scripts compile cleanly under forge and were executed end-to-end on chain 31337 during this audit. The same limitation was recorded at run-25; it was **re-attempted and re-confirmed at HEAD `1d8a3a7`**, not assumed. Remappings were supplied by materialising `foundry.toml`'s `remappings` array into a `remappings.txt` inside a throwaway hardlink copy of the submodule; `lib/` itself was not written to.

**Consequence:** the appendix provides **no** automated coverage of the deploy/rehearsal scripts. It neither corroborates nor contradicts L-01..L-04 / Q-01..Q-02. Do not read a clean line there as a clean line here.
