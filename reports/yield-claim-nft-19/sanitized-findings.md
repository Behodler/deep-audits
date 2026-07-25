# Sanitized Findings — yield-claim-nft run-19

- **Project:** `yield-claim-nft` @ `d4cc563` (stories 046 / 047)
- **Stage:** sanitization (known issues + C4 known-invalid) → ledger reconciliation
- **Ledger read:** `reports/ledgers/yield-claim-nft.json` — 40 entries, `lastAuditedCommit` `e4de393`, `lastRun` `yield-claim-nft-18`
- **Known issues applied:** 7 (inline `registered-projects.json → yield-claim-nft.knownIssues`)
- **Machine-readable:** `sanitized-findings.json`
- **NO LEDGER WRITE PERFORMED.** This document contains a *plan* only. `finding-manager` applies it; every write must be diffed against `/tmp/claude-1000/-home-justin-code-audits/49604d59-1c33-400a-860d-ac12d107b9b6/scratchpad/ledger-snapshot-start.json`.

## Counts

| | |
|---|---|
| Consolidated findings in | **12** |
| Survivors (proceed to severity-classifier) | **11** |
| — of which `new` (mint a new fingerprint) | 9 |
| — of which **EXPIRED CLOSURE** (own bucket, reconciles to L-08, no new fingerprint) | 1 (DEDUP-19-02) |
| — of which `still-open` (note update only, no new report) | 1 (DEDUP-19-12 → Q-17) |
| Suppressed / withheld from the H-M set | **1** (DEDUP-19-04 → L-13 `wont-fix`, **contested**) |
| Sub-claim suppressions inside surviving findings | 4 |
| Bucket-level suppressions (non-finding channels) | 3 |
| **REGRESSIONS** | **0** |
| Incomplete fixes | 0 |
| Expired closures | 1 |

Precise survivor breakdown (11 of 12 in): `new` = DEDUP-19-01, -03, -05, -06, -07, -08, -09, -10, -11 (9, each minting a fingerprint). `expired-closure` = DEDUP-19-02 (reconciles to existing L-08; **no new fingerprint**). `still-open` = DEDUP-19-12 (reconciles to Q-17; updates the existing entry instead of filing). **Findings carrying a report this run = 10** (the 9 new + DEDUP-19-02). The 12th, DEDUP-19-04, is the single suppression.

---

## 1. Known-issue / known-invalid application

The 7 registered known issues, and what each did (or did not) suppress. **Nothing was suppressed on a loose match.**

| KI | Text | Applied? | Effect |
|---|---|---|---|
| KI-1 | "Owner-driven attacks are out of scope (owner decides which tokens to list via dispatchers)" | **Partially** | Suppresses the *malicious/knowing* owner vector only. Does **not** reach DEDUP-19-05/-06/-07 — see §3 Law-3 test. Suppressed: the 69 Tier-1 `centralization-risk` hits; the R-03 residual-allowance vector (requires an owner repointing `setNudgeStreamer` at a hostile under-pulling streamer — an *obvious* knowing owner action). |
| KI-2 | "Dodgy/malicious tokens are out of scope (owner controls dispatcher registration and token selection)" | **Partially** | Suppresses the "owner deploys `Uniboost` against a deliberately hostile prime token" vector inside DEDUP-19-09. Does **not** suppress DEDUP-19-09 itself: that finding's claim is a *deploy-time guard asymmetry* — `NudgeRatchet`/`NudgeRatchetDelayRelease` enforce `decimals() == 6` at construction and `Uniboost` enforces nothing — plus the post-story-046 loss of failure isolation (two foreign token movements, no try/catch). An asymmetry against the contract's own siblings is a first-party defect, not a token-selection decision. |
| KI-3 | "Fee-on-transfer token handling uses balance-before/after pattern (documented design)" | **Partially** | Suppresses the **generic FoT** half of MR-02 (already permanently C4-invalid on this project family). Does **not** suppress MR-02's *cross-stream shared-balance solvency* claim — `NudgeStreamer` holds all streams in one token balance and credits `buffer += amount` with **no balance-delta check**, so the claim is that `Σ buffers == held balance` breaks, which is a different claim from "the dispatcher mis-sizes a FoT transfer". MR-02 stays **parked and visible**, not suppressed. |
| KI-4 | "Owner trust assumptions for registering dispatchers, setting prices, pausing, emergency withdraw" | **Partially** | Same treatment as KI-1. Note KI-4 does **not** enumerate `setBatchMinter` / `setRecipient` / `setNudgeStreamer` / `setPSM` — the mutators at issue in DEDUP-19-05/-06/-07 — and in any case Law 3's footgun exception governs. |
| KI-5 | "Pauser trust assumptions (designated pauser can pause/unpause)" | **Not applied** | No finding this run turns on pauser trust. (`pause()` appears in DEDUP-19-05 only as one of four *accidental* recovery-path closers, not as a trusted-role abuse.) |
| KI-6 | "Price growth via basis points may compound to very large values over many mints (documented design)" | **Not applied** | No finding this run touches bps price growth. |
| KI-7 | "All findings from previous audit `reports/yield-claim-nft-02/` that have been fixed in stories 24-28" | **Not applied** | No run-19 finding maps to H-01 / H-02 or to stories 024–028. |

### C4 known-invalid list

| Pattern | Applied? | Effect |
|---|---|---|
| Non-standard / weird ERC-20 (except USDT) | Partially | Folded into the KI-2/KI-3 dispositions above. The live topology is USDC/USDS; no weird-token finding survives on its own. |
| Fee-on-transfer | Yes | See KI-3. |
| CryptoPunks | n/a | — |
| Approve race / `safeApprove` front-running | **Not applied to DEDUP-19-11.** | DEDUP-19-11 is *not* the approve-race pattern. It is a **structural asymmetry**: every other `forceApprove` in these four contracts (`Uniboost:275/279, 300/306`; `PromotionUniV2_Eth:466/472, 483/485, 503/507`; `BalancerPoolerV2:336`) is paired with a zeroing reset and the streamer approve is the sole unpaired one, with the safe-today property resting on a **cross-repo** implementation detail rather than a local invariant. Exploitability is already refuted in-run (R-03) and the item is retained explicitly as hardening at QA, not as a vector. |
| User input mistakes / phishing | n/a | — |
| Reckless admin mistakes | Partially — see §3 | Malicious-owner and obvious-harm misconfig suppressed; **non-obvious footguns kept** per Law 3's exception. |
| Root cause in parent/forked OOS contract | **Contested — see §4** | Would ordinarily exclude DEDUP-19-01. Overridden under Law 1 with a scope caveat + cross-project action. |
| Common automated-tool findings without an HM exploit path | Yes | The Tier-1/Semgrep noise bucket (§6) is routed to QA/4naly3er, not filed as findings. |

---

## 2. Survivors

All fingerprints are `sha256(<basename>.sol:<function>:<rootCauseClass>)` with an **empty `entryPoint`** (contract scan). The empty discriminator reproduces the legacy hash byte-for-byte; this was verified against ledger entry **L-15**, whose recorded `fingerprintBasis` `PromotionUniV2_Eth.sol:pool:onchain-priceless-lp-add-mev` hashes to its recorded fingerprint `e64f73d6…` exactly. Note the convention uses the **basename**, not the repo-relative path.

### S-01 · DEDUP-19-01 — payment-token / nudge-token collision, whole pot swept by an arbitrary `batchMint` caller
- **Fingerprint:** `d06e3191ca39615a9fd31804c64ec00c93abf55a7f81c190b5d03c1bd62f271a`
- **Basis:** `BatchNFTMinterMultiToken.sol:batchMint:prime-token-nudge-token-collision-ungated-dust-sweep`
- **Reconciliation:** **NEW** — no ledger match on any of the 40 entries.
- **Known-issue check:** no match. Nearest candidates rejected: KI-1/KI-4 (owner-driven) — **rejected**, see below; DEDUP-001 (unbacked phUSD) — different asset, different mechanism, no mint path involved.
- **Scope:** **KEPT LIVE WITH CAVEAT.** The literal root-cause lines sit in the project's own nested `lib/phoenix-nft-staking`, which the OOS rule ("root cause in parent/forked contracts") would normally exclude. Overridden under **Law 1**: reachability is manufactured entirely by *this* repo's dispatcher topology — three of the four in-scope dispatchers (`NudgeRatchet`, `Uniboost`, `PromotionUniV2_Eth`) prime in USDC and feed a USDC nudge stream — and by the first-party decision to keep feeding it through the streamer. It is filed as an **integration hazard against the first-party callers**. It must not fall between two ledgers: see **CROSS-PROJECT-ACTIONS → XP-01**.
- **Not a centralization finding.** The finding opens on an owner action (`setDispatcherIndex` / `setTokenMinter`) but is then executed by an **unprivileged third party** for 1 wei — Tier-3 `Run19_T1_PaymentTokenCollision`, 4/4 pass, 190.0 USDC of a 200 USDC pot extracted, repeatable, control arm 0. A permissionless extraction path with a PoC is a security finding regardless of what opened the door. **Do not downgrade it to centralization and do not suppress it under KI-1/KI-4.**
- **Fingerprint anchoring note:** anchored on the root-cause contract deliberately, so the *same* fingerprint mints on the `phoenix-nft-staking` ledger and the two entries link rather than diverge.

### S-02 · DEDUP-19-02 — mandatory streamer wedges every mint and strands resident USDC — **EXPIRED CLOSURE of L-08**
- **Fingerprint:** reconciles to **L-08 `0b97f155a3db366698fbd9256ee767d98cf4467cce09d85a5df2acd0b343a156`** (status `fixed`). **No new fingerprint minted for the strand half.**
- **Reconciliation verdict:** **EXPIRED CLOSURE — its own bucket. NOT a regression. NOT an incomplete fix.**
- **Basis:** L-08's story-038 patch — the full-balance sweep in `NudgeRatchet._dispatch` — is **intact in source at `d4cc563`** (`src/dispatchers/NudgeRatchet.sol:142-162`). Nothing regressed and nothing was half-fixed. What expired is the *rationale*: the closure was explicitly judged, in the entry's own triage note, *"on whether out-of-band USDC becomes recoverable, NOT on literal `rescueERC20` presence"*. Story-046 made that sweep's only delivery leg an **external cross-repo call that can revert**, so the recoverability property the closure rested on no longer holds. Tier-3 `test_T2c` proves the funds are unreachable today: owner raw call to `rescueERC20(address,address,uint256)` returns `false` (selector absent), positive control on a freshly deployed `NudgeRatchetDelayRelease` returns `true`, and the only forwarding path is itself reverting.
- **⚠ DO NOT tell any reviewer to restore the sweep. It is already there.** The remedy is a *new* escape hatch (real `rescueERC20`, or an owner sweep not dependent on `collectNudge` succeeding), and/or a donation-disable so a mis-wire degrades rather than bricks.
- **Reopen is a human decision.** Proposed only (LP-02 / MR-07). `finding-manager` must **append** to the existing `fixNote`, never overwrite it.
- **Author pre-declaration handled:** the contract NatSpec pre-declares the wedge "NOT an audit finding". Per Law 1 an author's say-so does not auto-suppress. That declaration covers the deliberate liveness coupling; it does **not** cover the second-order consequence (escape hatch omitted on a rationale that no longer holds), which is the load-bearing half.
- **Contingency (Law 1, no-disappearance):** if the human **declines** the L-08 reopen, the *wedge* half — a distinct root cause from L-08's strand half — must still be filed as a new entry with fingerprint `03864c76ccf6622211cc6427630e49aa656b2cb8fa354d14559b0a3f305fef1a` (basis `NudgeRatchet.sol:_dispatch:mandatory-streamer-liveness-wedge`). Pre-computed here so declining the reopen cannot silently erase both halves.

### S-03 · DEDUP-19-03 — `NudgeRatchetDelayRelease.release()` lump is 100% back-runnable
- **Fingerprint:** `e6fbf0d61ccce8fe1be4ceee4ea394e588cb279f551dba08f73dc404d20c41e4`
- **Basis:** `NudgeRatchetDelayRelease.sol:release:unstreamed-lump-backrun-mev`
- **Reconciliation:** **NEW.** Nearest ledger neighbours checked and rejected: **L-12** (`d9d8e16a…`, same contract, `release / rescueERC20 vs dispatch`) is the *pause-does-not-freeze-custody* class — different root cause, different fingerprint, do not collapse. **Q-11** (`205afcf0…`, same contract `_dispatch`) is the dropped in-contract `require` — unrelated.
- **Known-issue check:** no match. Not an owner vector — `release()` is `onlyReleaser` but the *captor* is an unprivileged same-block back-runner.
- **Cross-repo note preserved:** same MEV class as `phoenix-nft-staking` ledger `858e9e80` (wont-fix). **DO NOT collapse into it** — different contract, different repo, different fingerprint. Suppressing here on a foreign wont-fix would be exactly the cross-ledger silent closure the fingerprint scheme exists to prevent.
- **Cross-ref:** `F-03-046` is the Law-2 framing of the same root cause; it stays in spec-conformance and is **not** double-counted as a second security finding.

### S-04 · DEDUP-19-05 — retiring a stream strands one duration's donations (owner footgun)
- **Fingerprint:** `25a9ab3e73573758e591115e30f57046d1ec58f32dd6ddfbabd5a93da178d77d`
- **Basis:** `NudgeRatchet.sol:setBatchMinter:stream-retirement-stranded-buffer` (anchored on `NudgeRatchet` as the canonical donor; the finding spans all four dispatchers' `setBatchMinter`/`setRecipient`/`setNudgeStreamer` — record the siblings in the entry)
- **Reconciliation:** **NEW.**
- **Law-3 test — "would a competent, non-malicious owner be surprised by this consequence?" → YES.** **KEPT.** Rationale: no event fires at retirement, no dispatcher view exposes the buffer, and the only read is `NudgeStreamer.pendingStream(oldBatchMinter, token)` which a migration operator has no reason to call. Decisive corroboration: the project's **existing** `MigrateBatchNFTMinter.s.sol` retirement step recovers the pot via `balanceOf(oldBatchMinter)` — **structurally blind to the streamer buffer**, and it predates the streamer. An operator following the repo's own migration script trips this. That is the definition of non-obvious. **Not** suppressed under KI-1/KI-4: the owner is acting well-intentionedly and tidily, and the harm is invisible at the moment of action.
- **Sizing carries an unknown:** `B* = ρ·D` scales linearly with the live `duration`, which is not set anywhere in the reviewed repos (MR-01, remains parked).

### S-05 · DEDUP-19-06 — repoint silently arms `NudgeStreamer__NotRegistered` (owner footgun)
- **Fingerprint:** `b0aa0f58697580809a53165f05cf0c4a73225b8e7a41f2be2173eade07ea8f14`
- **Basis:** `NudgeRatchet.sol:setBatchMinter:unregistered-stream-armed-on-repoint`
- **Reconciliation:** **NEW.** Distinct fingerprint from S-04 despite the same `contract:function` — the `rootCauseClass` component separates them, which is precisely why the deduplicator's "keep both" instruction is preserved intact.
- **Law-3 test, applied to each sub-case:**
  - **Deploy-ordering sub-case → NOT surprising → SUPPRESSED** (see §3 SUB-02). It fails loudly on the very first dispatch, before any user traffic; a competent operator sees it immediately.
  - **Repoint sub-case → SURPRISING → KEPT.** `setBatchMinter(new)` / `setRecipient(new)` on a *live* dispatcher succeeds **silently** and arms a revert on every subsequent user mint. Clearing it requires `setNudgeTokenWhitelist` on the batchMinter **and then** `registerStream` on a contract in a **different repository** that may not share the owner key. No local view, no guard, no probe. Verdict: footgun, in scope, availability-only, no Law-1 escalation.
- **Author pre-declaration:** the shipped "NOT an audit finding" NatSpec is *correct* for deploy-ordering and *over-broad* for repoint. A story cannot pre-declare a hazard out of scope. Correct disposition: known, accepted, recorded as an operational hazard with safe-config guidance.
- **Kept separate from S-02/DEDUP-19-02** deliberately: here availability-only, tx-atomic, owner-recoverable with a `config.disabled` backstop at `NFTMinterV2`; on `NudgeRatchet` it additionally strands funds with no rescue. Same pattern, different consequence, different fix.

### S-06 · DEDUP-19-07 — `BalancerPoolerV2` donation-disable strands parked USDS; live `psm.gem()` read (owner footgun)
- **Fingerprint:** `79a2cd4a791fff2001793d0426aef75fc11d77fd357611b52526214d7d00dbd2`
- **Basis:** `BalancerPoolerV2.sol:_dispatch:donation-gate-recovery-and-live-gem-read`
- **Reconciliation:** **NEW.** Nearest neighbour **L-05** (`e527a712…`, `BalancerPoolerV2.setBatchDonationSize`, batchDonationSize/hook-ratio coupling) is a different class — no match.
- **Law-3 test → YES, surprising, on both sub-instances. KEPT.**
  - **(a)** The sweep-and-retry that recovers parked USDS lives **inside** `if (donationEnabled)`, while the NatSpec (`:257-261`) presents re-sweeping as *the* recovery mechanism **without noting it is conditional**. An owner turning the donation off to reduce activity would not expect to freeze an unrelated recovery loop. Recoverable only via `rescueERC20:437`, which the owner must know to call.
  - **(b)** `gem` is read **live** from `ISkyPSM(psm).gem()` on every call and `psm` is owner-settable; a `setPSM` repoint to a different-gem PSM silently yields an unregistered pair ⇒ `NotRegistered` ⇒ caught ⇒ USDS parks behind one `DonationSkipped` — and per DEDUP-19-08 that event is now the *only* signal. `BalancerPoolerV2` is the **sole live-read of the four** (`PromotionUniV2_Eth` pins USDC `constant`, `NudgeRatchet` pins a 6-dp immutable), so the asymmetry is first-party. Not suppressed as an "obvious" misconfig: the failure is silent and single-event, not loud.
  - Neither sub-instance impairs phUSD backing.

### S-07 · DEDUP-19-12 — whole test tree failed to compile at `d4cc563`
- **Fingerprint:** reconciles to **Q-17 `696cc3452e1c247e3e8eaff37e543a5ec9e9278c8379fbbf20db9d33bbc474c5`** (status `open`).
- **Reconciliation verdict:** **STILL-OPEN.** Positive re-observation this run. **Do not file a new entry; expand the existing note.**
- **NOT SUPPRESSED — this is a real process finding.** Explicitly checked against the known-invalid "common automated-tool findings" and "unused view functions" patterns: neither applies. `forge build` **failed** at `d4cc563` (`test/Tier3PromotionInvariants.t.sol:120`, 5-arg `pool()` against the current 6-arg signature) until run-19 repaired the arity in the **workspace clone only** (`lib/` untouched, per the read-only rule). The blast radius is **larger than the Q-17 entry states**: Q-17 was filed as "the reworked split/burn/WBTC flow is not fuzzed", but the correct statement at `d4cc563` is that the compile failure made the **whole suite** unrunnable — for the duration of the bit-rot the project had **zero executable regression coverage**, and every prior finding's guard test was silently not running.
- **Q-17 remains only PARTIALLY addressed:** with the arity fixed, `test_guided_sequence_holdsAllInvariants` compiles and then fails at *runtime* with `PromotionUniV2_Eth: nudgeStreamer unset` (the harness predates story-046 and uses a plain EOA as `batchMinter`). Left unrepaired deliberately — T5 covers the same property against live state. **The repair exists only in `workspace/`, not upstream.**
- **Carryover:** Q-17 is `open` ⇒ its report is copied forward in full (QA lane).

### S-08 · DEDUP-19-08 — dust branch went event-silent as `DonationSkipped` became the sole signal
- **Fingerprint:** `482cefc33e7c84cfba25ebe1425eed720e0b335886c19fd58936f28810c5f55f`
- **Basis:** `BalancerPoolerV2.sol:_psmDonate:silent-dust-skip-observability`
- **Reconciliation:** **NEW.**
- **Known-issue check:** no match. The code change is *authorised* by story-047 bullet 4, so this is not an unauthorised behaviour change — but authorisation of the change is not disposal of its consequence, and the guard itself is load-bearing and correct (it keeps `NudgeStreamer__ZeroAmount()` out of the catch). The defect is that the documented observability contract was not updated in the same commit, and doubles down by telling operators to *"watch `DonationSkipped` and the contract's USDS balance"*.
- **Impact is observability, not value:** `_psmDonate` is atomic, parked USDS is re-swept, phUSD backing is **not** impaired (see §5 / CV-07).
- **Cross-ref:** `F-01-047` is the Law-2 framing of the same root cause; stays in spec-conformance, not double-counted.

### S-09 · DEDUP-19-09 — `Uniboost` prime token unconstrained, no failure isolation
- **Fingerprint:** `9fdcb0c6b30c4f51d5c56a6aa272d6aac3f8419e8c2743cdcda5753ddec8ea58`
- **Basis:** `Uniboost.sol:constructor:unconstrained-prime-token-no-failure-isolation`
- **Reconciliation:** **NEW.** Nearest neighbours **L-09** (`563df2e6…`, `Uniboost._dispatch`, missing `hookTypeId` guard) and **Q-10** (`7c4bcba2…`, `Uniboost.setPool`) are different classes — no match.
- **Known-issue check — partial, narrowed not suppressed:** KI-2 removes the *malicious-token* vector and KI-3 + the C4 FoT rule remove the *generic FoT* claim (§3 SUB-03/SUB-04). What survives is first-party and does not depend on either: `NudgeRatchet` and `NudgeRatchetDelayRelease` enforce `decimals() == 6` at construction; `Uniboost` takes `primeToken_` free with **no guard at all** — an asymmetry against its own siblings. Post-story-046 the donation branch has **no try/catch**, so a live donation depends on **two** token movements inside a foreign contract instead of one leaf transfer, converting three premises from contract-level guarantees into **deployment policy** simultaneously (the CV-06 read-only-reentrancy hook-free-token clearance, blacklist isolation, and the streamer's shared-balance solvency invariant).
- **No exploit at the live USDC topology.** MR-02 stays parked (two tiers disagree on where the loss lands); it is **not** closed by this sanitization.

### S-10 · DEDUP-19-10 — burns against the leg output, pools against the whole balance
- **Fingerprint:** `1c1e00017b303205a6362bf9a4fde0a402e2369fbc71192b62175bdcb4fc48fe`
- **Basis:** `PromotionUniV2_Eth.sol:pool:burn-vs-pool-accounting-basis-mismatch`
- **Reconciliation:** **NEW.** Same `contract:function` as **L-15** (`e64f73d6…`, `onchain-priceless-lp-add-mev`, wont-fix) but a different `rootCauseClass` ⇒ different fingerprint ⇒ **not** matched, **not** suppressed by L-15's wont-fix. Same treatment vs **Q-15**/**Q-16**/**Q-12** (different classes).
- **⚠ Explicitly NOT folded into L-13 / DEDUP-19-04** despite the identical whole-balance shape: different asset (phUSD / promotion token, not ETH), different consequence (documentation fidelity, not slippage-floor dilution), different fix. Folding it in would silently retire it under an owner decision that was **never made about it**.
- `minLP` bounds the outcome ⇒ documentation-fidelity, not a value leak.

### S-11 · DEDUP-19-11 — streamer `forceApprove` is the sole unpaired approval
- **Fingerprint:** `11d8b8656fc82f998967512c5578f62297cf756e486ace7b99e46c08eadd5c18`
- **Basis:** `BalancerPoolerV2.sol:_psmDonate:unpaired-streamer-forceapprove` (asymmetry anchor; instances also at `NudgeRatchet:160`, `Uniboost:250`, `PromotionUniV2_Eth:396`)
- **Reconciliation:** **NEW.**
- **Known-invalid check — approve-race / `safeApprove` front-running does NOT apply** (see §1). Exploitability already refuted in-run (R-03): exact approve, exact pull, same call, atomic rollback. Retained purely as hardening because the safe-today property rests on an **external cross-repo** contract's implementation detail rather than any local invariant. Cheap fix: pair each approve with a zeroing reset, as every other `forceApprove` in these contracts already does.

---

## 3. Suppressed

### SUP-01 · DEDUP-19-04 → **L-13 `wont-fix` — SUPPRESSED FROM THE H/M SET, BUT CONTESTED. RE-TRIAGE PROPOSED.**

- **Matched ledger entry:** **L-13**, fingerprint **`ac8eadefd1bc6f30f827ca54367b979d12f83bef57e019ebe65c0a839d2923e0`**, status **`wont-fix`** (owner triage 2026-07-18). Twin **F-01-044** (`3e638eb9…`), also `wont-fix`, same date, same site.
- **Rule cited:** ledger reconciliation — a match against `wont-fix` is suppressed like a known issue. **The owner's decision stands until the owner re-decides.** No new fingerprint has been minted and no finding has been re-filed under a different label. This entry exists so the suppression is visible and reversible.

**Owner's triageReason, quoted verbatim:**

> "Owner triage 2026-07-18: finding is valid but the whole-balance ETH sweep in PromotionUniV2_Eth._legB (swaps address(this).balance) plus the open receive() is a DESIRED FEATURE the owner intends to keep, not a defect to fix. Non-theft (Tier-3 INV-4 fork-proved donated ETH only ever reaches protocol-owned LP, never a third party). Operational note retained: sweep/rescue stray ETH before authorizing a pool() call if precise per-batch ETH attribution is ever needed. wont-fix, not acknowledged, because the behavior is affirmatively wanted."

**Basis for re-opening — the new fork evidence contradicts the load-bearing clause.**

The clause the closure rests on is *"Non-theft (Tier-3 INV-4 fork-proved donated ETH only ever reaches protocol-owned LP, **never a third party**)."* Run-19 Tier-3 `Run19_T5_LegBUnboundedEth` (3/3 pass, mainnet fork @ block 25,550,000, live UniV2 router/factory, Sky PSM, sUSDS ERC-4626, Balancer V3 — **no mocked AMM**, current 6-arg `pool()`) contradicts it directly:

| arm | stray ETH | identical `minPromoOut` = 478.315e18, identical 12 ETH sandwich | outcome |
|---|---|---|---|
| **T5b** | 0 | honest floor | `pool()` **REVERTS** `UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT` — the floor does its job |
| **T5c** | 1.61794 ETH | same floor | `pool()` **SUCCEEDS**; **a third party exits +0.296774 ETH** |

Floor dilution **11.00×**; `address(disp).balance == 0` afterwards — the entire balance was swapped, not the leg output.

**Why this is material and not a re-argument of the same point.** The loss channel is *not* the donated ETH's **destination** — which is indeed protocol-owned LP, exactly as INV-4 found. It is the **11× dilution of the pooler's slippage floor**, which INV-4 never tested. T5b and T5c differ *only* in the stray balance: the same sandwich the honest floor **rejects** becomes **profitable to a third party** once the stray ETH is present. That is a third party capturing value in a scenario the closure asserted could not exist. Additionally, the stale-residual case needs **no attacker at all** — `rescueETH`'s own NatSpec concedes a partial Leg B leaves resident ETH.

**Recommended action (recommend, do not apply):** surface to the owner for re-triage of **L-13** and its twin **F-01-044**, with the T5b/T5c differential attached. If the owner reaffirms `wont-fix`, record the T5 evidence on the entry so the "never a third party" clause is corrected rather than left standing as fact. **Never silently override the owner's decision; never quietly re-file under a new fingerprint.**

### SUB-01 · Owner-driven / centralization vectors → KI-1 + KI-4 + Law 3
69 Tier-1 `centralization-risk` hits suppressed. Law 3: the owner is trusted for **knowing** actions; a self-audit cannot stop a malicious owner and such findings are pure noise. No "a malicious owner could…" vector was passed through this run.

### SUB-02 · DEDUP-19-06, deploy-ordering sub-case → Law 3 (obvious owner misconfig)
Fails loudly on the very first dispatch, before user traffic. A competent, non-malicious owner would **not** be surprised. Suppressed. **The repoint sub-case survives** (S-05).

### SUB-03 · MR-02 generic fee-on-transfer sub-claim → KI-3 + C4 FoT known-invalid
Permanently invalid on this project family. **The cross-stream shared-balance solvency claim is NOT suppressed** — different claim, stays parked at MR-02.

### SUB-04 · DEDUP-19-09, "owner deploys a hostile/dodgy prime token" vector → KI-2 + Law 3
Owner controls dispatcher registration and token selection; a knowingly hostile choice is out of scope. **The sibling-asymmetry and failure-isolation core of DEDUP-19-09 survives** (S-09).

### SUB-05 · R-03 residual-allowance exploit path → Law 3 (obvious owner action)
Requires the owner repointing `setNudgeStreamer` at a hostile under-pulling contract. Obvious ⇒ suppressed. **Style asymmetry residue survives as S-11.**

### SUB-06 · ECON-004-class unbacked-phUSD residue → **DEDUP-001 (`070fdf42…`, status `suppressed`) — suppression STANDS, RE-DERIVED THIS RUN**
Recorded explicitly because it was **re-derived, not assumed**. The econ tier re-computed the over-backing cushion against the *new* quiet-skip surface introduced by stories 046/047 and found the worst case bounded by the 15% `batchDonationSize` (the other 85% is pooled regardless), comfortably inside the **≥2:1** cushion (CV-07). R-06 independently found **no unbacked-phUSD path** in any failure mode: streamed value is relocation, caught value stays on the pooler, dust stays put. Suppression stands; **no re-escalation**; DEDUP-001 remains hard-suppressed with no carryover stub. Bump `lastSeenRun` 17→19 and record the re-derivation.

### SUB-07 · R-07 / SA-013 `abi.encodePacked` in `uri():263` → duplicate of **Q-03** (`162f28d5…`, `qa-bundled`) **and** refuted
Two independent grounds: (1) exact duplicate of an existing ledger entry — reconcile, do not re-file; (2) refuted at source — there is no hash, the site builds a JSON metadata literal, the dynamic strings are separated by non-empty delimiters, and the result is never hashed or keyed. Detector class does not apply.

---

## 4. Scope decision — DEDUP-19-01 (the OOS rule, overridden)

| | |
|---|---|
| **Rule that would exclude it** | C4 / project OOS: "Issues in parent/forked contracts where root cause is OOS". Root-cause lines are `lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol:_snapshotRewards:558` + `batchMint:479-486`, inside the project's own nested `lib/`, which `outOfScope` lists. |
| **Why it is overridden** | **Law 1.** Reachability is created entirely by first-party code: three of four in-scope dispatchers prime in USDC and feed a USDC nudge stream, and the first-party decision to keep routing through the streamer sustains it. The mechanism is PoC-confirmed (190 USDC extracted, control arm 0), so the open question is **scope, not validity**. |
| **Disposition** | **KEPT LIVE on the `yield-claim-nft` ledger as an integration hazard, with the scope caveat attached to the entry**, *and* an explicit cross-project action so the upstream root cause is filed on `phoenix-nft-staking`. |
| **Non-negotiable** | It must not disappear between the two ledgers. If a human later decides to move it rather than mirror it, the move must be recorded on both sides. Dropping it on the OOS rule alone is not an available option. |

---

## 5. Reconciliation summary against the 40-entry ledger

- **REGRESSIONS: 0.** No `fixed` entry reappeared. The only `fixed` entry touched is **L-08**, and it is an **expired closure**, not a regression — the patch is intact.
- **Incomplete fixes: 0.** No `fix-pending` entries exist on this ledger, so the `⚠ FIX-PENDING STILL LIVE` heading does not arise.
- **Expired closures: 1** — L-08 (own bucket, §S-02).
- **Still-open with positive re-observation this run:** Q-17 (via DEDUP-19-12), L-06 + L-15 (via R-02 — the `minLP` analysis leaves the L-06/L-15 calculus unchanged; `amountIn` still MEV-neutral, L-06 stays Low), L-09 + L-10 (via CV-03 — `hook.onDispatch` still fires with the gross amount, unchanged; this range neither worsens nor fixes them).
- **`fixed` entries re-confirmed still fixed (no action, record only):** **M-03** (`b41dfefd…`) via CV-01 — no new conversion on any of the four paths, the amount handed to `collectNudge` is byte-identical to the amount computed one line earlier, no `decimals()` read on the streamer path, `PRECISION = 1e18` cancels exactly; the **M-03 drift-watch (3 literals) can be marked clean for this range**. **M-04** (`c91bef81…`) via CV-02 — the `hookTypeId() == keccak256("NudgeRatchetMintDebtHook.v1")` guard is still enforced in source at `d4cc563`, so a missing/wrong hook is a loud revert, not silent zero-debt; stories 046/047 touched no hook wiring.
- **Carryover (Law 1, no silent vanishing):** all 15 `open` entries are carried forward in full — **L-04, L-05, L-06, L-07, L-09, L-10, L-11, L-12, Q-05, Q-10, Q-11, Q-16, Q-17, F-01-043, F-01-045**. All are Low/QA/informational ⇒ one carryover QA report per originating audit under `submissions/carryover/`. **Never a pointer stub.** Suppressed (`acknowledged`/`wont-fix`/`false-positive`) and `qa-bundled` entries are **not** carried over.
- **`lastSeenRun` honesty rule:** bump to `yield-claim-nft-19` **only** for entries with positive re-observation this run (Q-17, L-06, L-09, L-10, L-15, DEDUP-001, L-13). The other `open` entries are carried forward **without** a `lastSeenRun` bump and get a `run19Note` stating they were not re-examined in this range — carrying forward is a recall guarantee, not a re-observation claim, and the two must not be conflated.

---

## 6. Tool-noise reconciliation (no re-filing)

Already on the ledger — **reconcile, do not re-file**: SA-002 → **Q-02**; SA-016 → **Q-13**; SA-018 → **Q-14**; SA-015/SA-025 → **Q-12**; SA-024 → **Q-05** (`open`); SA-013 → **Q-03** (also refuted, §SUB-07). Remaining SA items and the 197 Semgrep hits route to the QA / 4naly3er bundle.

**Coverage caveat carried forward:** Semgrep produced **zero** security findings this run. Solidity security coverage rests entirely on Slither + Aderyn. Do **not** read "Semgrep clean" as coverage.

---

## LEDGER-PLAN — explicit instructions for `finding-manager`

**Preconditions.** Do not apply any mutation until you have diffed the current ledger against `/tmp/claude-1000/-home-justin-code-audits/49604d59-1c33-400a-860d-ac12d107b9b6/scratchpad/ledger-snapshot-start.json`. **Never auto-flip a human-set status** (`acknowledged`, `wont-fix`, `false-positive`, `fix-pending`, `suppressed`). Every LP below that changes a status is a **PROPOSAL** requiring a human `/ledger` action — apply only the note/`lastSeenRun`/new-entry mutations.

### New entries to create (9)

| LP | Label (suggested) | Fingerprint | fingerprintBasis | contract | function | origin | Notes |
|---|---|---|---|---|---|---|---|
| LP-01 | *(assign next, security)* | `d06e3191ca39615a9fd31804c64ec00c93abf55a7f81c190b5d03c1bd62f271a` | `BatchNFTMinterMultiToken.sol:batchMint:prime-token-nudge-token-collision-ungated-dust-sweep` | `lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol` (first-party contribution: `src/dispatchers/NudgeRatchet.sol`, `Uniboost.sol`, `PromotionUniV2_Eth.sol`) | `batchMint` | `new` | **Must carry `scopeCaveat` verbatim from consolidated-findings.json.** Set `crossProjectAction: XP-01`. **Do NOT classify as centralization.** `entryPoint: null`. |
| LP-03 | *(assign next, security)* | `e6fbf0d61ccce8fe1be4ceee4ea394e588cb279f551dba08f73dc404d20c41e4` | `NudgeRatchetDelayRelease.sol:release:unstreamed-lump-backrun-mev` | `src/dispatchers/NudgeRatchetDelayRelease.sol` | `release` | `new` | Record `siblingOf: L-12` + `doNotCollapse: phoenix-nft-staking 858e9e80`. Cross-ref `F-03-046` (spec-conformance, not a second finding). |
| LP-04 | *(assign next, footgun)* | `25a9ab3e73573758e591115e30f57046d1ec58f32dd6ddfbabd5a93da178d77d` | `NudgeRatchet.sol:setBatchMinter:stream-retirement-stranded-buffer` | `src/dispatchers/NudgeRatchet.sol` (+3 sibling dispatchers) | `setBatchMinter` | `new` | `footgun: true`. Copy `safeConfigGuidance` verbatim. Link `MR-01` (unknown live `duration` sizes it). |
| LP-05 | *(assign next, footgun)* | `b0aa0f58697580809a53165f05cf0c4a73225b8e7a41f2be2173eade07ea8f14` | `NudgeRatchet.sol:setBatchMinter:unregistered-stream-armed-on-repoint` | `src/dispatchers/NudgeRatchet.sol` (+`Uniboost`, `PromotionUniV2_Eth`) | `setBatchMinter` | `new` | `footgun: true`. **`siblingOf: LP-04` — same `contract:function`, different class. DO NOT MERGE.** Record `distinctFrom: L-08/LP-02` verbatim. |
| LP-06 | *(assign next, footgun)* | `79a2cd4a791fff2001793d0426aef75fc11d77fd357611b52526214d7d00dbd2` | `BalancerPoolerV2.sol:_dispatch:donation-gate-recovery-and-live-gem-read` | `src/dispatchers/BalancerPoolerV2.sol` | `_dispatch` | `new` | `footgun: true`. Two sub-instances (a) donation-gate, (b) live `psm.gem()` — keep both in one entry. |
| LP-07 | *(assign next, QA)* | `482cefc33e7c84cfba25ebe1425eed720e0b335886c19fd58936f28810c5f55f` | `BalancerPoolerV2.sol:_psmDonate:silent-dust-skip-observability` | `src/dispatchers/BalancerPoolerV2.sol` | `_psmDonate` | `new` | Cross-ref `F-01-047` (spec-conformance). Note story-047 bullet 4 authorises the change. |
| LP-08 | *(assign next, QA)* | `9fdcb0c6b30c4f51d5c56a6aa272d6aac3f8419e8c2743cdcda5753ddec8ea58` | `Uniboost.sol:constructor:unconstrained-prime-token-no-failure-isolation` | `src/dispatchers/Uniboost.sol` | `constructor` | `new` | Record the KI-2/KI-3 **narrowing** (SUB-03/SUB-04) on the entry so the survivor's scope is unambiguous. Link `MR-02` (unresolved). |
| LP-09 | *(assign next, QA)* | `1c1e00017b303205a6362bf9a4fde0a402e2369fbc71192b62175bdcb4fc48fe` | `PromotionUniV2_Eth.sol:pool:burn-vs-pool-accounting-basis-mismatch` | `src/dispatchers/PromotionUniV2_Eth.sol` | `pool` | `new` | **`doNotFoldInto: L-13`** — explicit. `siblingOf: L-15` (same `contract:function`, different class). |
| LP-10 | *(assign next, QA)* | `11d8b8656fc82f998967512c5578f62297cf756e486ace7b99e46c08eadd5c18` | `BalancerPoolerV2.sol:_psmDonate:unpaired-streamer-forceapprove` | `src/dispatchers/BalancerPoolerV2.sol` (+3) | `_psmDonate` | `new` | Record `exploitabilityRefuted: R-03`; hardening only. Not the approve-race pattern. |

### Existing-entry mutations

- **LP-02 · L-08 (`0b97f155…`, `fixed`) — EXPIRED CLOSURE. PROPOSE REOPEN; DO NOT APPLY.**
  - **APPLY NOW:** **append** a `run19Note` (do **not** touch `status`, and do **not** overwrite `fixNote` — append only) reading: *"Run-19 (`d4cc563`, stories 046/047): EXPIRED CLOSURE, not a regression and not an incomplete fix. The story-038 full-balance sweep is INTACT at `src/dispatchers/NudgeRatchet.sol:142-162`. What expired is the closure's rationale: the entry was closed explicitly 'on whether out-of-band USDC becomes recoverable, NOT on literal rescueERC20 presence', and story-046 made the sweep's only delivery leg an external cross-repo call that can revert. Tier-3 `test_T2c` proves the resident USDC is unreachable today (owner `rescueERC20` selector absent; positive control on `NudgeRatchetDelayRelease` returns true; the only forwarding path is itself reverting). DO NOT send reviewers to restore the sweep — it is already there."*
  - **PROPOSE (human only):** `/ledger yield-claim-nft reopen 0b97f155…` — reopen on expired rationale. See MR-07.
  - **CONTINGENCY if the reopen is DECLINED:** create a new entry for the *wedge* half — fingerprint `03864c76ccf6622211cc6427630e49aa656b2cb8fa354d14559b0a3f305fef1a`, basis `NudgeRatchet.sol:_dispatch:mandatory-streamer-liveness-wedge`, `contract: src/dispatchers/NudgeRatchet.sol`, `function: _dispatch`, `origin: new`. **Declining the reopen must not erase both halves.**

- **LP-11 · L-13 (`ac8eadef…`, `wont-fix`) — CONTESTED. PROPOSE RE-TRIAGE; DO NOT APPLY, DO NOT RE-FILE.**
  - **APPLY NOW:** `lastSeenRun` 18→19; **append** a `run19Note` carrying the T5b/T5c differential and the explicit statement that the triageReason's *"never a third party"* clause is contradicted by fork evidence (T5c: third party +0.296774 ETH; T5b: same sandwich rejected without the stray balance; 11.00× floor dilution). **Do NOT change `status`. Do NOT mint a new fingerprint. Do NOT overwrite `triageReason` or `footgunNote`.**
  - **PROPOSE (human only):** re-triage L-13 **and** its twin `F-01-044` (`3e638eb9…`, also `wont-fix`) with the T5 evidence attached. If the owner reaffirms `wont-fix`, correct the "never a third party" clause on the entry rather than leaving it standing as fact.

- **LP-12 · Q-17 (`696cc3452e…`, `open`) — STILL-OPEN, note expansion. APPLY.**
  - `lastSeenRun` 18→19; `origin: still-open`. **Status unchanged (`open`).** Do **not** file a new entry for DEDUP-19-12.
  - **Append** to `note`: *"Run-19 (`d4cc563`): blast radius is larger than originally filed. `forge build` FAILED repo-wide at `d4cc563` (`test/Tier3PromotionInvariants.t.sol:120`, 5-arg `pool()` vs the current 6-arg signature) — for the duration of the bit-rot the project had ZERO executable regression coverage and every prior finding's guard test was silently not running. Run-19 repaired the arity in the WORKSPACE CLONE ONLY (`// run-19: Q-17 bit-rot repair`); `lib/` untouched and the repair is NOT upstream. Q-17 remains only PARTIALLY addressed: with the arity fixed, `test_guided_sequence_holdsAllInvariants` compiles and then fails at RUNTIME with 'PromotionUniV2_Eth: nudgeStreamer unset' (harness predates story-046, uses a plain EOA as batchMinter); left unrepaired deliberately since Tier-3 T5 covers the same property against live state."*
  - **Carryover required** (QA lane, full copy).

- **LP-13 · DEDUP-001 (`070fdf42…`, `suppressed`) — suppression STANDS, re-derived. APPLY.**
  - `lastSeenRun` 17→19. **Status unchanged (`suppressed`). No carryover stub (hard-suppressed).**
  - **Append** `run19Note`: *"Run-19 (`d4cc563`, stories 046/047): suppression RE-DERIVED, not assumed. The ≥2:1 over-backing cushion was recomputed against the new quiet-skip surface (CV-07): worst case is bounded by the 15% `batchDonationSize`, the other 85% is pooled regardless, comfortably inside ≥2:1. R-06 independently found NO unbacked-phUSD path in any failure mode (streamed = relocation; caught = USDS stays on the pooler; dust = stays put). Suppression STANDS; no re-escalation. Re-emit only if a new unbacked-mint path appears."*

- **LP-14 · L-06 (`342075df…`, `open`) — still-open. APPLY.** `lastSeenRun` → 19; `run19Note`: *"Re-observed via R-02. `minLP` is the stronger guard (`liquidity = min(amountA·ts/reserveA, amountB·ts/reserveB)`), so ratio skew mechanically reduces LP minted and a fresh-quote `minLP` bounds the loss in the unit that matters; `pool()` is `onlyAuthorizedPooler`; the legs carry their own floors. `amountIn` still MEV-neutral ⇒ **L-06 stays Low**. Calculus unchanged, if anything better supported by the 6th param."* Status unchanged. **Carryover required.**
- **LP-15 · L-15 (`e64f73d6…`, `wont-fix`) — APPLY note only.** `lastSeenRun` → 19; same R-02 note. **Status unchanged; no carryover (human-triaged wont-fix).**
- **LP-16 · L-09 (`563df2e6…`, `open`) and LP-17 · L-10 (`e064b2de…`, `open`) — still-open. APPLY.** `lastSeenRun` → 19; `run19Note`: *"CV-03: `hook.onDispatch` still fires with the gross amount (`ATokenDispatcherV2:125`), unchanged; no new hook-side scaling anywhere. This range neither worsens nor fixes them; entries stay open on their own merits."* **Carryover required.**
- **LP-18 · M-03 (`b41dfefd…`, `fixed`) — record only, APPLY.** `run19Note`: *"CV-01 STILL-FIXED across three tiers. No new conversion on any of the four paths — the amount handed to `collectNudge` is byte-identical to the amount computed one line earlier (`NudgeRatchet:160` `bal`; `Uniboost:250` / `PromoEth:396` `donationAmount`; `BalancerPoolerV2:347` the same `gemAmt`); no `decimals()` read on the streamer path; `PRECISION = 1e18` cancels exactly; truncation would need `duration > 1e24` s. **M-03 drift-watch (3 literals) marked CLEAN for this range.** No regression."* **Status unchanged (`fixed`).**
- **LP-19 · M-04 (`c91bef81…`, `fixed`) — record only, APPLY.** `run19Note`: *"CV-02 STILL-FIXED. `NudgeRatchet:137-140` still enforces `hookTypeId() == keccak256(\"NudgeRatchetMintDebtHook.v1\")` at `d4cc563` ⇒ a missing/wrong hook is a loud revert, not silent zero-debt; `setHook` still rejects zero; stories 046/047 touched no hook wiring. No regression."* **Status unchanged (`fixed`).**
- **LP-20 · Carryover for the remaining `open` entries — APPLY.** **L-04, L-05, L-07, L-11, L-12, Q-05, Q-10, Q-11, Q-16, F-01-043, F-01-045**: copy each report forward **in full** into `reports/yield-claim-nft-19/submissions/carryover/` (QA/informational lane, one file per originating audit — **never a pointer stub**). **Do NOT bump `lastSeenRun`** for these: they were not positively re-observed in this range. Add `run19Note: "Carried forward for recall (Law 1). Not re-examined in the run-19 range (stories 046/047 dispatcher/streamer surface); no evidence of change either way. lastSeenRun deliberately NOT bumped — carryover is a recall guarantee, not a re-observation claim."`
- **LP-21 · Run-level fields — APPLY.** `lastRun` → `yield-claim-nft-19`; `lastAuditedCommit` → `d4cc563`; add a `run19Note` at the ledger root recording: 12 consolidated in, 10 survivors (9 new + 1 expired closure), 1 contested suppression (L-13), 1 still-open note expansion (Q-17), **0 regressions, 0 incomplete fixes, 1 expired closure**, and that MR-01/MR-02/MR-03/MR-04/MR-07 remain open manual-review items.

### Explicitly NOT to be done

1. **Do not** suppress DEDUP-19-01 on the OOS rule (§4).
2. **Do not** downgrade DEDUP-19-01 to a centralization finding.
3. **Do not** suppress DEDUP-19-12 / close Q-17.
4. **Do not** collapse LP-04 and LP-05 (same `contract:function`, different class).
5. **Do not** collapse LP-03 into `phoenix-nft-staking` `858e9e80`.
6. **Do not** fold LP-09 into L-13.
7. **Do not** re-file DEDUP-19-04 under a new fingerprint, and do not flip L-13's or F-01-044's `wont-fix`.
8. **Do not** overwrite L-08's `fixNote` — append only.
9. **Do not** flip any status without a human `/ledger` action.

---

## CROSS-PROJECT-ACTIONS

- **XP-01 · `phoenix-nft-staking` — DEDUP-19-01 root cause.** File the upstream root cause on the `phoenix-nft-staking` ledger: `BatchNFTMinterMultiToken.sol:_snapshotRewards:558` + `batchMint:479-486` — the **step-10 dust sweep is not gated on `qualifies`**, so with `count=1 < nudgeSize=5` the whole nudge pot leaves via the dust refund; the mint is funded out of the pot itself (step-6 unbounded allowance) so the caller needs no budget. Use the **same fingerprint `d06e3191ca39615a9fd31804c64ec00c93abf55a7f81c190b5d03c1bd62f271a`** so the two ledger entries link rather than diverge. PoC: `workspace/yield-claim-nft/test/run19-Tier3Nudge.t.sol::Run19_T1_PaymentTokenCollision` (4/4 pass). Upstream remedy: gate the step-10 dust sweep on `qualifies`, or exclude nudge-whitelisted balances from it. **This finding is live on the `yield-claim-nft` ledger as an integration hazard and must remain live on at least one ledger at all times — mirroring is required, disappearing is not an option (MR-03).**
- **XP-02 · `phoenix-nft-staking` — do NOT let `858e9e80` absorb LP-03.** The run-19 `NudgeRatchetDelayRelease.release()` back-run finding is the same MEV *class* as the `phoenix-nft-staking` `858e9e80` wont-fix but a different contract, repo and fingerprint. Record a note on `858e9e80` that a sibling instance exists on `yield-claim-nft` so a future triager does not close both with one decision.
- **XP-03 · `stable-yield-accumulator` — MR-04 carryover lead.** `StableYieldAccumulator.claim()`'s 30% `nudgeSplit` still pays the batch-minter **directly and unbuffered**, so a `claim()`-funded spike into the same nudge pot remains instantaneously capturable by the next 40-batcher. The stories 046/047 anti-burst throttle therefore covers **one of two** funding sources. Route as a lead to the `stable-yield-accumulator` ledger, or accept as intended — recorded so the streamer mitigation is not miscredited as protocol-wide.
- **XP-04 · `phoenix-nft-staking` — CV-09 mis-credit guard.** The streamer is a **rate cap (delay, not denial)**: a flush yields `min(elapsed/D, 1)·buffer` and the batchMinter then snapshots its whole balance, winner-take-all. **Do NOT read this range as closing any pre-existing `phoenix-nft-staking` nudge over-funding / aggregate-pot finding.** Story-faithfulness confirms no NatSpec, story line or CLAUDE.md text claims it is a value cap, so there is no Law-2 defect — but the mis-credit risk on the other ledger is real.
- **XP-05 · `phoenix-nft-staking` — `NudgeStreamer` has no owner rescue.** Verified exhaustively against its complete function list (`registerStream`, `collectNudge`, `pullPendingStream`, `pendingStream`, `_settle`, `_accrued`). This is the load-bearing precondition of both DEDUP-19-05 (retirement strand) and DEDUP-19-02's `test_T2d` (blacklisting the streamer permanently strands already-buffered pooled funds). Worth an entry on the `phoenix-nft-staking` ledger in its own right.
