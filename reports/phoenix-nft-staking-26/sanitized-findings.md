# Sanitization Report — `phoenix-nft-staking` run-26

- **Target**: `lib/phoenix-nft-staking` @ `9611312` (read-only)
- **Date**: 2026-07-30
- **Input**: `reports/phoenix-nft-staking-26/dedup-report.md` — 13 entries `D-26-01` … `D-26-13` (0 High, 0 Medium)
- **Known issues**: 16 entries, cached in `registered-projects.json` → `projects["phoenix-nft-staking"].knownIssues`, nominal source `lib/phoenix-nft-staking/CLAUDE.md`, extracted 2026-07-26
- **Ledger**: `reports/ledgers/phoenix-nft-staking.json` — **read-only this step, not written**

## Headline

**13 in → 13 KEPT. 0 suppressed as known-issue. 0 suppressed as out-of-scope.**

One **limb-level narrowing** applied (D-26-02: one framing limb is KI-covered and must be struck from the report text; the finding itself survives on its other grounds). Four suppressions were **considered and explicitly DECLINED** (§3). One KI provenance defect and two stale KI line-citations found (§4) — neither blocks anything, because **no suppression this run rests on a KI**.

The reason the suppression count is zero is structural and worth stating plainly rather than reading as leniency:

> **KIs #1–#14 are entirely about the `NFTStaker` family** (APY/emission math, `emergencyWithdraw`, empty-pool setter guards, `ScheduleRecomputed`, solvency, `_safePay`). **Every one of this run's 13 findings lives in the `BatchNFTMinterMultiToken` / `NudgeStreamer` nudge subsystem**, about which KIs #1–#14 say nothing at all. Only **KI #15 and KI #16** reach the nudge subsystem, and both are narrowly scoped to *pot-size economics* — a claim class this run does not make (0 High, 0 Medium; the run's economic limb was already withdrawn or re-framed upstream at dedup).

---

## 1. Per-finding disposition

### D-26-01 — Unisolated cross-contract flush loop can brick `batchMint` — **KEEP** (Low)

- **KI check**: no match. Nearest candidates: KI #15/#16 (nudge pot) — both are about the pot being *large/legible*, i.e. **economics**. D-26-01 is **availability**: a revert inside `NudgeStreamer.pullPendingStream` propagates through the un-`try/catch`'d loop at `:531-534` and reverts the whole `batchMint`. KI #15/#16 contain no availability, DoS, or isolation claim in any framing, and neither DO-NOT-FILE list mentions reverts, bricking, or external-call isolation.
- **Carve-out audit (required by run instruction)**. KI #15/#16 carve-outs, quoted: *"(a) any path where the pot leaves without the caller paying for `nudgeSize` real mints; (b) any path where refund > paymentAmount; (c) any path where a NON-QUALIFYING batch extracts pot-sized value…; (d) [#15] the aggregate over-funding class … / [#16] ANY CLAIMANT TAKING OTHER USERS' MONEY."* D-26-01 sits **outside all four** — nothing leaves at all (that is the finding), and the non-qualifying batch here is the **victim** of the brick, not an extractor, so (c) is inverted rather than triggered. Since the finding is outside the *suppression* too, the carve-out analysis is belt-and-braces, not load-bearing.
- **OOS check**: sites `src/BatchNFTMinterMultiToken.sol`, `src/NudgeStreamer.sol` — first-party, not under `lib/**`, not in `outOfScope` (`test/`, `lib/`, `lib/mutable/`, `lib/immutable/`, `src/INFTSupply.sol`).
- **Weird-ERC20 note (not a suppression)**: dedup already killed the token-side legs itself and holds the finding on the availability/isolation leg plus the *new* exposure of non-qualifying batches. Nothing left for me to cull; re-culling the already-killed Leg B would be double-counting.
- **Carried forward**: the verbatim REOPEN TRIGGER, and the §7.1 symbolic-coverage contingency (a Halmos counterexample to INV-1 revives Leg B ⇒ reopen at Medium). Sanitization must not be read as closing that door.

### D-26-02 — `nudgeSize == 0` disables payout but not inflow or flush — **KEEP with a NARROWING** (Low/QA)

- **KI #16 considered — the single closest call of the run.** Quoted DO-NOT-FILE items: *"'aggregate/whitelist-sum pots exceed one qualifying cost'"* and *"'NudgeStreamer fails to cap the payout'"*. D-26-02's *magnitude illustration* ("~30,000 units over a 30-day disable, delivered as one un-metered lump") reads onto that second phrase.
- **Ruling: the finding is KEPT; one framing limb is struck.** D-26-02's claim is a **disable-lever asymmetry** — a lever documented twice in-source as "disables the feature" (`:40`, `:271`, both verified present at `9611312`) leaves inflow and the flush running, so value migrates into a container with no withdrawal, pause, or deregistration. That is a Law-3 footgun about **operator expectation and custody location**, not a claim about subsidy rate. Dedup already disclaims value loss in the finding's own text ("no value is lost… yield-funded, stays in protocol-controlled contracts"), which is exactly the posture KI #16 demands.
  - **STRIKE from the report text**: any argument that the resulting lump is *too large relative to the qualifying cost*, or that *the streamer fails to cap the payout*. Those are KI #16 verbatim, and KI #16's funding-source reasoning (externally-derived Tokemak yield ⇒ opportunity cost, never loss) is authoritative and re-verified.
  - **RETAIN**: the asymmetry, the wrong-container custody, the absent return path, the invisibility during the disabled period, and the one-line fix (gate the loop on `qualifies`).
- **Carve-out audit**: outside (a) — the eventual recipient *is* a qualifying batch paying for real mints; outside (b) — no refund path involved; outside (c) — the payout goes to a **qualifying** batch, which is the negation of (c); outside (d) — the accumulating funds are protocol-directed incentive money from externally-derived yield, not other callers' money. **Note the asymmetry of that last point**: it is precisely *because* the value is protocol-owned that (d) does not fire and the honest severity stays Low.
- **Law-3 test applied explicitly** (per run instruction, in place of reaching for the reckless-admin exclusion): *would a competent, non-malicious owner be surprised?* **Yes.** Two in-source sites promise "disables the feature"; `_snapshotRewards:801` gates its own balance read on `qualifies` while the flush ten lines above does the opposite. An owner reading either NatSpec line would not predict that a "disabled" feature keeps accreting. Surprise ⇒ footgun ⇒ in scope. **Not** the C4 admin-mistake exclusion: the harm is non-obvious, which is the exclusion's own boundary condition.
- **OOS check**: clean.

### D-26-03 — Falsely-exhaustive NatSpec on a pooled-custody invariant — **KEEP** (QA)

- **KI check**: no match. No KI addresses `NudgeStreamer` documentation. KI #12 is the *only* documentation-flavoured KI and is subject-specific (see §3.2).
- **NatSpec has no suppression authority, and here it is the subject.** The text at `NudgeStreamer.sol:55-62` — verified present at `9611312`, reading *"The resulting invariant — `Σ buffer_i <= balanceOf(this)` over every pair on one token — is what makes the per-stream cap in `_accrued` affordable"*, asserted **"by construction rather than by convention"** — is exactly the pre-emptive-suppression shape the repo policy names. It is **evidence for** the finding. A falsely-exhaustive claim on a load-bearing invariant **raises** severity; it cannot sanitize.
- Held at QA on dedup's own reasoning (the aggregate claim happens to hold today under plain ERC20s, machine-confirmed) — the defect is that the *guarantee* is asserted structurally while resting on token behaviour. That distinction is what a future editor will lose.
- **OOS check**: clean.

### D-26-04 — spec-conformance mirror of D-26-03 (Law 2) — **KEEP** (Low)

- **Not KI-eligible, by rule.** A known issue is the project's statement about its own **security** posture; it carries no authority over whether shipped code matches its story. D-26-04 is a Law-2 faithfulness finding (story-031's acceptance criterion at `031-….md:168` instructed the unconditional wording; its own review pass caught the defect as Issue 1 at `:421-427` and shipped anyway). No KI is even a candidate.
- Routed to `spec-conformance.md`, **not** the QA bundle. Dual routing with D-26-03 preserved per dedup decision 3.
- Dedup's recommended walk-back to Low is passed through untouched — severity is the classifier's call, not sanitization's.

### D-26-05 — Streamer revert bricks the *mint*, not just the flush — **KEEP** (Low)

- **KI check**: no match, on the same grounds as D-26-01 (isolation, not economics).
- **OOS check — the one entry where OOS was genuinely arguable, and it fails.** The tempting rule is *"issues in parent/forked contracts where root cause is OOS."* It does not apply:
  1. The in-scope root-cause sites are first-party and in this submodule: `src/NudgeStreamer.sol:158` (`NudgeStreamer__NotRegistered`), `:199` (`NudgeStreamer__ZeroReceived`, new at story-031), `:243`.
  2. The **fix** site is `yield-claim-nft/src/dispatchers/NudgeRatchet.sol` — a **first-party sibling audit project with its own ledger**, not a third-party or forked dependency. Nothing about it is OOS.
  3. **Verified at the correct source** (per the standing nested-pin-staleness rule): read at **top-level `lib/yield-claim-nft` @ `d4cc563`**, not `lib/mutable/**`. `_dispatch` calls `INudgeStreamer(streamer).collectNudge(batchMinter, _token, bal)` bare, with no `try/catch` — the claim holds at the live sibling HEAD.
- Dedup's explicit instruction — *"do not suppress on the grounds that the fix site is elsewhere"* — is honoured. The cross-file handoff to the `yield-claim-nft` ledger is preserved as an obligation, not discharged here.

### D-26-06 — story-032 removed the config-completeness precondition — **KEEP** (Low)

- **KI check**: no match. KI #3 and KI #4 are the empty-pool-guard KIs (*"setStakedId / setDispatcherIndex / setNFTMinter only callable while totalStaked == 0 … do NOT flag the empty-pool guard as a DoS"*, and *"setDispatcherHook has NO empty-pool guard — hook rotation is intentionally a live operation"*). Both are about **`NFTStaker` setter gating**. D-26-06 is about `BatchNFTMinterMultiToken.setNudgeTokenWhitelist` losing a **transitive witness** — a different contract, a different mechanism, and the opposite direction (a guard *removed*, not a guard the auditor is told to stop flagging).
- **Predicate re-verified in source at `9611312`**, which matters because this finding turns on a removal: `setNudgeTokenWhitelist` now performs **no payment-path derivation**, and its own NatSpec confirms the change — *"story-032 removed the admin-time rejection of the dispatcher's prime token … adding works while `tokenMinter`/`dispatcherIndex` are unset — symmetric with removal, and no longer an ordering constraint on deployment scripts."* The code says the ordering constraint is gone; D-26-06 says a runbook hazard replaced it. Both are true, and the NatSpec is the receipt.
- **Law-3 test applied explicitly**: *surprised?* **Yes.** Before `9611312`, `isNudgeToken(token) == true` transitively witnessed a configured minter path, so "fund the streamer before wiring the minter" was structurally impossible. Now permissionless `collectNudge` funds a buffer that `batchMint` reverts before ever reaching (`BatchMint__MinterNotConfigured` at `:479`, ahead of the flush), and the streamer has no rescue. The NatSpec advertises the removal as a *convenience for deployment scripts* — an owner following that advice would be actively steered into the hazard. That is the definition of non-obvious. **Not** the admin-mistake exclusion.
- Fully recoverable by completing configuration ⇒ runbook hazard, correctly Low. Magnitude (donor throughput, both production donors being stateless full-balance sweepers) retained.
- Compounding disclosure vs `4a1d8edc92` preserved; **must not** be collapsed into it.

### D-26-07 — spec-conformance mirror of D-26-06 (Law 2) — **KEEP** (Low)

- **Not KI-eligible, by rule** (same as D-26-04). Additionally note the shape: the deviation is that story-032 twice ships a false *"`NudgeStreamer` … is unaffected"* claim (`032-….md:126-128`, `:383-385`). **A false in-document safety claim is the one thing that can never sanitize a finding** — it is the finding. Suppressing D-26-07 under any KI would let the erroneous claim launder itself.
- Story is still open (D-26-12), so remediation can fold in rather than becoming a follow-up. Preserved.

### D-26-08 — `setNudgeStreamer` accepts any address, no structural probe — **KEEP** (Low)

- **KI check**: no match. KI #1 (*"Owner trust assumptions: owner controls setTargetAPY … setDispatcherIndex, setNFTMinter, setDispatcherHook, setStakedId, topUp, pullAndRefresh — centralization is by design"*) was considered and **declined** — see §3.1. `setNudgeStreamer` is not in that enumeration, is on a different contract, and KI #1 blesses *centralization*, not *silent failure*.
- **Law-3 test applied explicitly**: *surprised?* **Yes, twice over.** (i) The counterparty direction deliberately probes — `NudgeStreamer.registerStream` calls `isNudgeToken` on the batchMinter specifically to confirm the target type, documented in-source as *"a non-multitoken address does not implement this and the call reverts"* (verified at `9611312`). An owner who has read that asymmetric-by-design comment reasonably expects the reverse direction to be guarded too. (ii) The event is emitted **before** assignment (`emit NudgeStreamerChanged(nudgeStreamer, newStreamer); nudgeStreamer = newStreamer;` — verified verbatim), so a mis-point reads as clean success in logs. A footgun that *also* suppresses its own diagnostic signal is the far end of non-obvious. Surprise ⇒ in scope.
- **Partial defeat preserved honestly, and it is not a suppression**: for an **EOA** the pattern is DEFEATED (solc 0.8.20 retains `extcodesize` for void-returning external calls ⇒ the flush reverts loudly). The reachable residual is a **contract with a permissive fallback** — a Safe, a proxy with unset implementation, a sibling Phoenix contract. Narrower than the sibling-project precedent, and stated as such.
- **Not the missing-zero-check tool class.** Dedup already culled that (`missing-zero-check`, 12 + 19 instances) and correctly noted a zero-check here *would be actively wrong* — `address(0)` is the deliberate disable path. D-26-08 is a **structural probe**, not a zero-check; the OOS "common automated-tool finding" rule does not reach it.
- Cross-project class precedent (phStaging run-21 M-02; stable-yield-accumulator `setRewardToken` `0xd62cbfe8`) is a **disclosure duty across three ledgers**, not a duplicate — different projects, no fingerprint collision, normal dedup structurally cannot see it.

### D-26-09 — `NudgeCollected.amount` repointed from request to receipt — **KEEP** (QA)

- **KI #12 considered and DECLINED** — the most seductive semantic match in the set. See §3.2 for the full reasoning.
- **OOS check**: clean. Not a weird-ERC20 finding: dedup verifies both production donors forward **USDC**, for which receipt ≡ request, and holds the finding on the off-chain indexer residual, which is a silent **under**-count with no ABI-level or topic-level signal.
- QA is the right channel; the on-chain desync was ruled out by verification (`grep` for `NudgeCollected` consumers → 0 hits; the mint-debt ledger derives from the NFTMinter's `amount`), not by assumption.

### D-26-10 — spec-conformance mirror of D-26-09 (Law 2) — **KEEP** (Low/QA)

- **Not KI-eligible, by rule.** Note in particular that KI #12 — a project statement that a *previous* semantic repoint was intentional — has no authority over whether *this* repoint matches *its* story. Reading KI #12 across the Law-2 channel would be the exact error the "KIs cannot suppress faithfulness findings" rule exists to prevent.
- Dedup's honest partial-refutation is preserved: story-031 *does* name the semantic change as an accepted consequence (Concerns §3) and swept five call sites; the residual is the unamended **declaration** (its own review Issue 3, unactioned) plus an ABI analysis scoped to calldata/returndata that never asks about donor-side counters.

### D-26-11 — Unenforced ordering guarantee, self-contradicted by its own new text — **KEEP** (Low/QA)

- **KI check**: no match, and **NatSpec cannot suppress** — again the finding *is* the NatSpec. The block at `:659-665` asserts a **symmetric** mutual-non-interference guarantee and attributes it to *ordering*; story-030's own Anchor E addition ~20 lines below (`:695-700`, "charged to the pot, silently") states the contradicting fact. A guarantee refuted by its author's own adjacent paragraph is evidence, not authority.
- **Carve-out flag — this one runs TOWARD a carve-out, which is a reason to KEEP and to look harder.** The underlying mechanism dedup describes ("in the one case where ordering binds — erosion between step 5 and step 9 — refund-first charges the shortfall to `D` then `P`") is adjacent to **KI #16 carve-out (d): *"ANY CLAIMANT TAKING OTHER USERS' MONEY"***, and to **carve-out (b): *"any path where refund > paymentAmount"***. `D` is donate-forward money belonging to the next claimant and `P` is the standing pot — the contract's own header table at `:64-72` says so explicitly. D-26-11 is filed only as documentation accuracy, which is the conservative read, and I am **not** escalating it. But the carve-outs exist precisely to keep this class visible, so I am flagging it rather than letting a QA label bury it.
  - **Action for the severity-classifier (not a sanitization ruling)**: confirm whether the step-5→step-9 erosion path can be *reached without a misbehaving token*. If it can, KI #16 explicitly does **not** cover it — carve-out (d) preserves it at full severity — and it is a finding in its own right rather than a documentation defect. If it cannot, the QA framing stands. Either way, **suppression is unavailable**.
- In-source-overclaim cluster disclosure (`181e444c40`, `b7d8c5d5f5`, `dacaba6ef5`, `51aed27661`, `75305ec024`, `a7dffb34c9`) preserved. Seven live members of one class is itself a signal to surface.

### D-26-12 — story-032 landed at HEAD while its story sits in `review` — **KEEP** (informational)

- **KI check**: no match — no KI addresses process or story state. Nor is this OOS: it is not a vulnerability claim at all, and the repo's `storyPolicy` **mandates** surfacing it (*"a landed feature whose story sits in `incomplete` is itself worth noting"*). Suppressing it would contradict the policy that generated it.
- Routed to `spec-conformance.md`, informational. Not counted toward any severity bucket.
- The `phStaging2:072` deferred item (phase-0 assertion of the now-deleted `BatchMint__RewardTokenIsPaymentToken` tripwire) is a **live cross-project trap** and stays visible. Owner-confirmed 2026-07-30 that 072 is on ice and unbroadcast — that mitigates urgency, it does not sanitize the note. Verified: the tripwire is indeed gone at `9611312` (no `RewardTokenIsPaymentToken` anywhere in `src/`).

### D-26-13 — Duck-typed structural guard with no compiler enforcement — **KEEP** (QA, weakest entry)

- **KI check**: no match.
- **OOS considered and DECLINED** — see §3.3. The rule *"common findings from automated tools without demonstrated HM exploit path"* has real pull here (the seed was Slither `missing-inheritance`), and this is the run's marginal entry. It survives because dedup gave a **non-tool reason**: the duck-typed `isNudgeToken` call is `registerStream`'s single admission check, proving whitelist membership *and* MultiToken-batchMinter identity at once — confirmed in source at `9611312`, where the interface NatSpec states it *"enforce[s], in one check, both 'the token is on that batchMinter's whitelist' and 'the target is actually a MultiToken batchMinter'."* A load-bearing guard coupled by convention rather than inheritance is a legitimate QA note.
- Dedup's own Law-3 suppression of the false-accept path (owner-supplied address with permissive fallback = obvious owner error) is **upheld** — that limb is correctly already gone, and I am not reviving it.
- **Flagged for the QA-bundler**: if the bundle is crowded, this is the first candidate to drop on "non-critical issues are discouraged" grounds. Sanitization keeps it; bundling economics are not my call.

---

## 2. Findings inside a KI carve-out (would be un-suppressible even if a KI matched)

| Finding | Carve-out proximity | Effect |
|---|---|---|
| D-26-11 | KI #16 **(d)** "any claimant taking other users' money"; KI #16/#15 **(b)** "refund > paymentAmount" — via the step-5→step-9 erosion path charging shortfall to `D` then `P` | **Un-suppressible.** Flagged to the classifier for a reachability check (§1, D-26-11) |
| D-26-01 | KI #15/#16 **(c)** inverted — the non-qualifying batch is the victim of the brick, not an extractor | Outside the carve-out **and** outside the suppression |

No finding was suppressed under #15 or #16, so no carve-out determination is load-bearing for a removal. Recorded because the run instruction requires the audit trail either way.

---

## 3. Suppressions CONSIDERED and DECLINED

### 3.1 D-26-08 under KI #1 (owner-trust / centralization-by-design) — DECLINED

KI #1, quoted in full: *"Owner trust assumptions: owner controls `setTargetAPY` (bounded by MAX_TARGET_APY = 0.5e18), `setDispatcherIndex`, `setNFTMinter`, `setDispatcherHook`, `setStakedId`, `topUp`, `pullAndRefresh` — centralization is by design."*

Declined on three independent grounds, any one sufficient:
1. **Enumerated, and `setNudgeStreamer` is not in the enumeration.** KI #1 lists seven specific setters; this is a closed list, not a blanket owner-setter amnesty.
2. **Wrong contract.** All seven live on the `NFTStaker` family; `setNudgeStreamer` is on `BatchNFTMinterMultiToken`.
3. **Wrong proposition.** KI #1 blesses *centralization* — "the owner can change this, and that is intended." D-26-08 does not dispute that. It reports that the change **fails silently and permanently**, with the event emitted before assignment so the logs read clean. Consenting to owner control is not consenting to undetectable misconfiguration. Under Law 3 that is a footgun, and footguns are in scope.

### 3.2 D-26-09 / D-26-10 under KI #12 (event field meaning shifted, ABI preserved) — DECLINED

KI #12, quoted: *"`ScheduleRecomputed` event: on-chain field name `totalNFTValue` is preserved for off-chain consumer compatibility but its meaning shifted in audit M-03 from aggregate `T` to staked-subset `S = totalStaked * latestPrice` — do NOT flag as misleading naming."*

This is a genuine **structural** match — same shape in every respect: an event field whose meaning changed while name and ABI stayed byte-identical, with off-chain consumers as the exposed party. Declined anyway:

1. **KI #12 is a ruling about one decision, not a policy about a class.** It records that *this specific* repoint, on *this specific* event, made during *audit M-03*, was deliberate and should not be re-litigated. It is re-derivable verbatim from `CLAUDE.md:53` at `9611312` — and that line is inside the `NFTStaker` feature spec, discussing `ScheduleRecomputed(S, budget, newRate, newWindowEnd)`. Nothing in it generalises.
2. **Different contract, different event, different origin.** `NudgeCollected` on `NudgeStreamer` is a story-028/031 artefact that did not exist when KI #12 was written. Reading KI #12 forward onto it would let a single accepted decision pre-authorise every future event-semantics change in the repo — precisely the widening Law 1 forbids.
3. **KI #12 has a disclosed off-chain rationale; D-26-09 has an undisclosed off-chain residual.** KI #12 preserved the name *deliberately, for consumer compatibility*, a decision made with consumers in mind. D-26-09's residual is that story-031's "Not ABI-breaking" analysis was scoped to calldata/returndata and **never asked** whether a donor keeps a sent-amount-derived counter — the opposite posture.
4. **The direction is adverse.** Silent **under**-count, the direction an operator is least likely to investigate, with no compile-time, ABI-level or topic-level signal and no on-chain way to learn the credited value (`collectNudge` returns `void`).

Kept at QA. Confidence in the *decline* is high; confidence in the finding's *impact* remains contingent on §7.5 (whether any off-chain indexer sums the field), which is honestly recorded upstream.

### 3.3 D-26-13 as OOS "common automated-tool finding without HM path" — DECLINED

The C4 exclusion applies to findings whose *entire content* is a detector hit. D-26-13's content is an argued property of the design: the duck-typed call is the **sole** admission gate on `registerStream` and carries two distinct proofs at once, so a signature change on either side compiles clean. Dedup states the non-security reasoning honestly (drift **fails closed** — reverts on empty returndata, `onlyOwner`, no funds in motion; `external view` ⇒ `STATICCALL` ⇒ cannot reenter or mutate) and files at QA accordingly. QA is where such a note belongs; the exclusion governs HM submissions. Kept, with the bundling flag in §1.

### 3.4 D-26-02 in full under KI #16 — DECLINED (narrowed instead)

Full reasoning in §1, D-26-02. Summary: one framing limb ("un-metered lump", pot size) is KI #16 verbatim and is **struck**; the disable-lever asymmetry, wrong-container custody, absent return path, and invisibility are outside every DO-NOT-FILE item and outside all four carve-outs, and are independently supported by the two in-source "disables the feature" claims. Where the boundary was ambiguous I kept the finding, per the standing rule that **recall beats report-tidiness**.

---

## 4. KI health check (run-instruction constraint 6)

Every KI was re-derived against `lib/phoenix-nft-staking` @ `9611312`. Result: **no KI is substantively stale**, but three defects are recorded.

### 4.1 KIs #1–#14 — VERIFIED re-derivable, and all NON-APPLICABLE this run

All fourteen map to live text in `CLAUDE.md` at `9611312` (118 lines, unchanged in substance):

| KI | Anchor | KI | Anchor |
|---|---|---|---|
| #1 | `:43-50` (setter list, `MAX_TARGET_APY 0.5e18`) | #8 | `:39` (`R = 0` edge cases) |
| #2 | `:51` (global Pauser / `IPausable`) | #9 | `:59` (APY-as-floor, no participation multiplier) |
| #3 | `:42`, `:64` (`totalStaked == 0` gating) | #10 | `:60` (no retroactive rewards) |
| #4 | `:47` (`setDispatcherHook`, no empty-pool guard) | #11 | `:61` (emissions stop at `windowEnd`) |
| #5 | `:37`, `:66` (`emergencyWithdraw` escape hatch) | #12 | `:53` (`totalNFTValue` name preserved) |
| #6 | `:48` (`topUp` skips `_syncBudget`) | #13 | `:35`, `:65` (single active ID) |
| #7 | `:39` (OZ `Math.mulDiv` floor rounding) | #14 | `:67` (`_safePay` reverts on shortfall; dust escape) |

**The material observation is scope, not staleness**: `CLAUDE.md` at `9611312` contains **no mention whatsoever** of `BatchNFTMinter`, `BatchNFTMinterMultiToken`, `NudgeStreamer`, the nudge pot, or the whitelist. Its Feature Specification and Critical Invariants sections are wholly about the `NFTStaker` family. Since all 13 findings live in the nudge subsystem, **KIs #1–#14 cannot reach any of them** — this is a structural non-overlap, not a judgement call.

### 4.2 KI #15 / KI #16 — predicates VERIFIED, two line-citations STALE, provenance MISLABELLED

**Predicates hold at `9611312`:**
- KI #15's factual basis — that `paymentToken ∈ nudgeWhitelist` is now creatable — is confirmed in source: `BatchNFTMinterMultiToken.sol:95` states the admin-time gate *"has been deleted, so `paymentToken ∈ nudgeWhitelist` is now creatable in a [single call]"*, and `setNudgeTokenWhitelist` performs no payment-path derivation. `BatchMint__RewardTokenIsPaymentToken` is absent from `src/` entirely.
- KI #15's quoted contract position survives: *"…behaviour; the error was in the sender."*
- KI #16's mechanism premise — that `NudgeStreamer` meters release so the market finds a clearing price — holds: the streamer exists, is wired, and `BatchNFTMinterMultiToken.sol:198` describes it as the *"Optional linear streamer that meters bursty donations into this [contract]."* The **suppression basis behind `858e9e807a` and `521c20ad48`** (nobody can *accelerate* release) was re-verified by the econ tier this run and **SURVIVES**; those two wont-fixes stand and nothing here reopens them, exactly as the run instruction requires.

**Defects recorded (none blocking, because no suppression rests on these KIs):**
1. **Stale line citation.** KI #15 cites the contract's own position at `":62-70"`. At `9611312` that text is at **`:130`** (and the `:58-72` region now holds the three-pool custody table). The claim is intact; only the pointer drifted. Any future run quoting KI #15 by line number will quote the wrong lines.
2. **Provenance mislabelled.** `knownIssuesSource` says all 16 were *"extracted from the Feature Specification and Critical Invariants sections"* of `CLAUDE.md`. **KIs #15 and #16 are not in `CLAUDE.md` at all** — they are registry-authored **owner decisions** dated 2026-07-25 and 2026-07-26 (KI #16 additionally carries a correction *to* KI #15's carve-out (d)). Their authority is the owner's dated ruling, which is stronger than a doc extraction, so this is a **labelling** defect, not a validity one. But it must be fixed: a future sanitizer that "re-derives KIs from CLAUDE.md" per the stated source would **silently lose the only two KIs that reach the nudge subsystem** — including both sets of Law-1 carve-outs. That is a real Law-1 hazard in waiting.
3. **Count drift risk.** `knownIssuesCount = 16` with `knownIssuesExtractedAt = 2026-07-26`, while `scopeUpdatedAt` is 2026-07-25 and the code has advanced through stories 029–032 since. The KI *set* remains valid; nobody has re-run extraction against the nudge subsystem post-story-032.

**Recommendation to project-manager (not applied here — registry is not mine to write this step):** split `knownIssuesSource` to record two provenances — `#1–#14: lib/phoenix-nft-staking/CLAUDE.md` and `#15–#16: owner decision, dated, registry-authored, DO NOT DROP ON RE-EXTRACTION` — and refresh KI #15's `:62-70` citation to `:130`.

### 4.3 No KI found substantively stale

No suppression was declined on staleness grounds. Every decline in §3 rests on **scope** (wrong contract / wrong proposition / enumerated list), which is the stronger reason.

---

## 5. Ledger reconciliation note

Reconciliation was performed upstream at the dedup step and is passed through unchanged; the ledger was **read only** and **not written** here.

- **NEW: 13** (D-26-01 … D-26-13). **REGRESSION: 0.** `2d34673536` still fixed, independently re-verified via two paths.
- **No finding matched an `acknowledged` / `wont-fix` / `false-positive` ledger entry**, so no ledger-based suppression fired. The wont-fix entries in the neighbourhood (`bfdb50105e`, `43e8c48626`, `858e9e807a`, `521c20ad48`, `911c54fd6d`) each carry a **disclosure duty** in §4 of the dedup report rather than a suppression — correct, since a new fingerprint will not trip normal dedup and the re-file bases are argued site-by-site.
- **No `fix-pending` entry was matched or suppressed.** Restating the standing rule for the audit trail: `fix-pending` is never a known issue and never suppressed, in cold or regression runs.
- **`9135cf7947` (§5 of the dedup report) is a ledger-hygiene item, not a sanitization item.** I concur with the disposition — do **not** apply the run-20 proposed `fixed`; its premise is false at `9611312` (`BatchNFTMinter.sol:62` carries no `ReentrancyGuard`), and the cause is a deliberate Stage-7 revert (`fba4991`) restoring V1 to its frozen deployed shape. That is an **expired closure premise, not a regression**. Status is `submitted`, so nothing was silently closed. Keep unmerged from `c847207db2` per that entry's own note.
- **Carryover**: nothing to carry. There are no `still-open`/`fix-pending` reconciliation matches this run; the 14 re-confirmed-present entries in dedup §3.4 were explicitly not re-filed per the run instruction and remain the finding-manager's bookkeeping.

---

## 6. Structured summary

```json
{
  "sanitizationReport": {
    "timestamp": "2026-07-30T00:00:00Z",
    "project": "phoenix-nft-staking",
    "run": "phoenix-nft-staking-26",
    "commit": "9611312",
    "inputFindings": 13,
    "removedFindings": 0,
    "passedFindings": 13,
    "flaggedForReview": 2,
    "limbNarrowings": 1,
    "removals": [],
    "narrowings": [
      {
        "findingId": "D-26-02",
        "reason": "partial_known_issue",
        "matchedTo": "KI #16: 'NudgeStreamer fails to cap the payout' / 'aggregate/whitelist-sum pots exceed one qualifying cost'",
        "strike": "any argument that the accumulated lump is too large relative to qualifying cost, or that the streamer fails to cap it",
        "retain": "disable-lever asymmetry; wrong-container custody; absent return path; invisibility during the disabled period; the gate-the-loop-on-qualifies fix",
        "confidence": "high"
      }
    ],
    "declinedSuppressions": [
      { "findingId": "D-26-08", "candidateKI": 1,  "reason": "setter not in KI #1's closed enumeration; wrong contract; KI blesses centralization, not silent failure" },
      { "findingId": "D-26-09", "candidateKI": 12, "reason": "structural match but KI #12 rules on ONE prior decision (ScheduleRecomputed on NFTStaker), not a class; would pre-authorise all future event repoints" },
      { "findingId": "D-26-10", "candidateKI": 12, "reason": "Law-2 faithfulness finding; KIs carry no authority over story conformance" },
      { "findingId": "D-26-13", "candidateRule": "C4 OOS: common automated-tool finding without HM path", "reason": "content is an argued design property (sole admission gate), not a bare detector hit; QA channel is correct" },
      { "findingId": "D-26-02", "candidateKI": 16, "reason": "declined in full; narrowed at limb level instead (ambiguous boundary => keep)" }
    ],
    "flagged": [
      {
        "findingId": "D-26-11",
        "reason": "carve_out_adjacent",
        "note": "step-5 -> step-9 erosion path charges refund shortfall to D then P, adjacent to KI #16 carve-out (d) 'any claimant taking other users' money' and (b) 'refund > paymentAmount'. Un-suppressible. Classifier should test whether the path is reachable without a misbehaving token; if yes it is a finding in its own right, not a documentation defect."
      },
      {
        "findingId": "D-26-01",
        "reason": "reopen_contingency",
        "note": "Sanitization does not close the symbolic-coverage gap. A Halmos counterexample to INV-1 under a plain ERC20 revives Leg B and reopens this at Medium under its own written trigger."
      }
    ],
    "kiHealth": {
      "kiCount": 16,
      "substantivelyStale": 0,
      "applicableToThisRun": [15, 16],
      "structurallyNonApplicable": "1-14 (all NFTStaker family; every finding is in the BatchNFTMinterMultiToken/NudgeStreamer nudge subsystem)",
      "defects": [
        "KI #15 cites ':62-70' for the contract's own position; at 9611312 that text is at :130 (claim intact, pointer stale)",
        "PROVENANCE MISLABEL: knownIssuesSource claims all 16 were extracted from CLAUDE.md, but #15/#16 are registry-authored dated owner decisions absent from CLAUDE.md. A re-extraction per the stated source would silently drop both sets of Law-1 carve-outs.",
        "knownIssuesExtractedAt 2026-07-26 predates stories 029-032; no re-extraction has covered the nudge subsystem post-story-032"
      ]
    },
    "ledger": { "written": false, "newFindings": 13, "regressions": 0, "suppressedByLedger": 0, "fixPendingSuppressed": 0 }
  }
}
```

## 7. Output routing (unchanged from dedup)

| Route | Findings |
|---|---|
| H/M individual submissions | — (0 High, 0 Medium) |
| QA bundle | D-26-01, D-26-02*, D-26-03, D-26-05, D-26-06, D-26-08, D-26-09, D-26-11, D-26-13 |
| `spec-conformance.md` | D-26-04, D-26-07, D-26-10, D-26-11 (dual), D-26-12 (informational) |
| `manual-review.json` | MR-26-01 … MR-26-04 (untouched by sanitization) |

\* D-26-02 with the §3.4 narrowing applied to its text.

**13 in → 13 kept. 0 removed. Every input accounted for; no silent drops.**
