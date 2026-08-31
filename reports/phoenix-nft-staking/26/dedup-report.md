# Deduplication Report — `phoenix-nft-staking` run-26

- **Target**: `lib/phoenix-nft-staking` @ `9611312` (read-only)
- **Mode**: REGRESSION. Ledger present: `reports/phoenix-nft-staking/ledger.json`, **78 entries** (read-only this step; not written)
- **Date**: 2026-07-30
- **Inputs consumed**: `tier1/static-analysis.md`, `tier1/pattern-matches.md`, all 6 `profiles/`, `tier2/{code-findings,econ-findings,faithfulness}.md`, `tier3/invariants.md`
- **Input MISSING**: `tier3/symbolic.md` — **does not exist** at dedup time (symbolic run still in flight). Recorded as a coverage gap with a live consequence; see §7.

## Headline

**0 High, 0 Medium.** 9 unique root causes survive, all Low/QA, plus 3 intentional spec-conformance mirrors and 1 informational process note = **13 output entries**. **No REGRESSION.** The run's lead High/Medium candidate was killed twice independently (tier-2 exhaustive write-site enumeration, then tier-3 452k+ fuzzed calls on two engines with a mutation-verified harness), and what survives of it is an availability-only Low carrying a written reopen trigger.

---

## 1. Output findings — deduplicated list

Fingerprint tuple is `contract:function:rootCauseClass` (`entryPoint` empty — contract scan, so the legacy hash reproduces byte-for-byte). Fingerprints are the finding-manager's to compute; tuples are proposed here.

### D-26-01 — Unisolated cross-contract flush loop can brick `batchMint` (availability/isolation leg only)

- **Merges (upstream decision 1, applied not re-litigated)**: `LOCAL-NS-01` (consequence-chain limb), `S-01`, `PATTERN-001`, `CODE-01`
- **Site**: `src/BatchNFTMinterMultiToken.sol:533` (loop `:531-534`, block `:528-536`), inside `batchMint` (`:464-727`); reverting line `src/NudgeStreamer.sol:243` via `pullPendingStream:224`
- **Tuple**: `src/BatchNFTMinterMultiToken.sol:batchMint:unisolated-external-call-loop`
- **Classification**: **NEW**
- **Proposed severity**: **Low**
- **Root cause**: an unbounded, unisolated loop of external calls into a semi-trusted contract, on a path where every iteration is optional for the caller's own outcome, with no `try/catch`, **not gated on `qualifies`**.
- **Leg B is KILLED and must not be restated as a mechanism.** No plain-ERC20 path to an over-stated `Σ buffer_i` exists; every enumerated mechanism is token-side (negative rebase, burn-on-hold, clawback, blacklist-zeroing) and therefore C4-invalid standalone. The USDT carve-out does not rescue it (a blacklisted streamer cannot `transfer` at all, so the blacklist is the brick, not the buffer sum). Machine-confirmed: tier-3 INV-1 PASS at 200,000 calls/invariant (Foundry) + 200,310 calls / 2,001 sequences (Medusa), anti-vacuity measured (600/600 non-trivial checks, 3 simultaneous funded streams on one token), harness proven able to fail against a 1-wei over-credit mutant.
- **What the finding stands on**: the availability/isolation leg, plus the genuinely new and plainly-reachable increment — **non-qualifying batches lost their structural immunity**. `_snapshotRewards:801` short-circuits `balanceOf` behind `qualifies`, `_payRewards:831` skips zero amounts, so before the flush loop a `count < nudgeSize` caller had **zero** nudge-token exposure. The flush loop is now that caller's only exposure, for zero benefit.
- **Held at Low because**: every trigger is individually owner-obvious, third-party-extraordinary (Circle/Tether pause or blocklist), C4-permanently-invalid, or owner-observable; nothing is lost; and the owner holds **two** single-transaction escapes (`setNudgeStreamer(0)`, `setNudgeTokenWhitelist(token,false)`).
- **REOPEN TRIGGER (must be carried verbatim into the ledger entry)**: *reopens at Medium if a plainly-reachable trigger is found — the impact side already qualifies ("protocol function/availability impacted"); only the precondition side is holding it down.*
- **Fix is behaviour-neutral and that was verified**: `_settle` never recomputes `rewardPerSecond` (write sites `:139`, `:206` only) and `_accrued` derives from `block.timestamp - lastUpdate`, so gating the loop on `qualifies` loses no accrual — the same amount settles at the next qualifying batch.
- **Cross-references, do NOT collapse**: `D-26-02` (same code site, different consequence — see decision 2), `D-26-03`/`D-26-04` (the NatSpec limb of the same profile finding), `D-26-05` (same isolation class, different consumer and wider blast radius).
- **Disclosures owed**: see §4.1 (`bfdb50105e`, wont-fix) and §4.2 (`966e717669`, open sibling precedent), plus §4.3 (`4a1d8edc92` — the escape *is* the trigger; they compound).

### D-26-02 — `nudgeSize == 0` disables the payout but not the inflow or the flush: value migrates into an un-metered container with no return path

- **From**: `ECON-26-02`
- **Site**: `src/BatchNFTMinterMultiToken.sol` — `qualifies` `:510-514`, flush loop `:528-536` (does not read `qualifies`), `_snapshotRewards:801`, `_payRewards:831`; NatSpec `:40-41`, `:269-270`
- **Tuple**: `src/BatchNFTMinterMultiToken.sol:setNudgeSize:disable-lever-asymmetry`
- **Classification**: **NEW**
- **Proposed severity**: **Low (QA)**
- **KEPT SEPARATE from D-26-01 per upstream decision 2 — not re-litigated.** Shared code site `:528-536`, different consequence: value migration (a "disabled" nudge accumulates ~30,000 units over a 30-day disable at 1,000/day inflow, delivered as one un-metered lump to whoever wins the first re-enabled qualifying batch, with no return path — the streamer has no withdrawal, pause or deregistration) vs availability. One fix (gate the loop on `qualifies`) closes both. A reader who only saw the availability framing would never learn the accumulation happens.
- **Law-3**: non-obvious footgun ⇒ in scope. Two NatSpec sites say "disables the feature"; `_snapshotRewards` gates its own balance read on `qualifies`; the flush sits immediately above doing the opposite.
- **Honest limit carried forward**: no value is lost (yield-funded, stays in protocol-controlled contracts), and the flush is not the *cause* of the lump — a quiet period > `duration` makes `_accrued` hit its `buffer` cap anyway. The flush's distinct contribution is that accumulation happens **during** the disabled period, in the wrong container, invisibly.
- **Disclosure owed**: §4.4 (`43e8c48626`, wont-fix — adjacent, different subject).

### D-26-03 — Falsely-exhaustive NatSpec on a load-bearing pooled-custody invariant

- **Merges**: `CODE-03`, `LOCAL-NS-01` (documentation limb)
- **Site**: `src/NudgeStreamer.sol:55-62` (contract NatSpec), `:250-265` (`_accrued` NatSpec); claim introduced at `2ba764e`
- **Tuple**: `src/NudgeStreamer.sol:_accrued:natspec-overclaim-custody-invariant`
- **Classification**: **NEW** (new claim, new site, authored by story-031 — attribution verified by `git log -S`)
- **Proposed severity**: **QA**
- **Split note (not a silent drop)**: `LOCAL-NS-01` had two limbs. Its consequence chain ("⇒ `batchMint` bricked") is not independently reachable and merged into **D-26-01**; its documentation claim is this entry. The split is stated so neither limb is lost.
- Per repo policy, in-source NatSpec carries no suppression authority, and a falsely-exhaustive claim on a load-bearing invariant **raises** rather than lowers severity: a future editor reading `:258` ("established at ONE site") will believe the aggregate is structurally guaranteed and will not add the clamp that is not there.
- **Disclosure owed**: §4.5 (`6f46ec80f1`, open — a *different* overclaim, burst-capture).

### D-26-04 — spec-conformance mirror of D-26-03 (Law 2)

- **From**: `F-02`
- **Route**: `spec-conformance.md` — **NOT** the QA bundle
- **Classification**: **NEW**
- **Proposed severity**: **Low** — *I am recommending a walk-back from the faithfulness agent's `potential-medium`.* Its Medium read was predicated on the DoS chain, which is now killed (Leg B) and separately carried at Low by D-26-01. The residual is documentation accuracy. Classifier's call, but the Medium premise no longer exists.
- **Dual routing is intentional per upstream decision 3, not a duplicate.** Same underlying text as D-26-03, different channel: F-02 is the Law-2 finding that story-031's own acceptance criterion (`031-…md:168`) *instructed* the unconditional wording and its review pass caught the defect (Issue 1, `:421-427`) without amending the shipped NatSpec. Cross-reference both ways.
- **Law-1 override applied upstream and confirmed**: story-031's intended mechanism (`min(received, amount)`, snapshot after `_settle`, revert on zero receipt) is strictly safety-improving. No `story-unsafe`.

### D-26-05 — Cross-contract failure-isolation asymmetry: a streamer revert bricks the *mint*, not just the flush

- **From**: `CODE-02`
- **Sites (in scope here)**: `src/NudgeStreamer.sol:158` (`NudgeStreamer__NotRegistered`), `:199` (`NudgeStreamer__ZeroReceived`, new at story-031), `:243`. **Fix site is cross-repo**: `yield-claim-nft/src/dispatchers/NudgeRatchet.sol:157-160`
- **Tuple**: `src/NudgeStreamer.sol:collectNudge:unisolated-donor-hop`
- **Classification**: **NEW**
- **Proposed severity**: **Low**
- **KEPT SEPARATE from D-26-01.** Same isolation *class*, but: different contract and entry point, different consumer (`NudgeRatchet.dispatch` → `NFTMinterV2._executeMint` → `mint`, not the flush loop), **wider blast radius** (reverts the mint itself for every minter on that dispatcher, batched or single), and a **different fix site in a different repo** ⇒ separate mitigation ⇒ separate finding. Merging would send the fix to the wrong repo.
- The asymmetry is what makes it reportable: `BalancerPoolerV2._dispatch` wraps the *same* hop to the *same* contract in an explicit, documented, story-047-mandated `try/catch` envelope ("streamer unset, stream not registered" named among the swallowed reverts); `NudgeRatchet` leaves it bare. Story-031 widened the un-isolated leg's revert surface. Law-3: surprise ⇒ report.
- **Handoff (do not suppress on the grounds that the fix site is elsewhere)**: cross-file the missing `try/catch` to the `yield-claim-nft` ledger, adjacent to the run-19 stories 046/047 streamer-routing entries.
- Plainly-reachable trigger exists here where D-26-01 has none: `NudgeStreamer__NotRegistered` fires whenever the documented wiring order (`registerStream` then `setNudgeStreamer`) is performed in reverse — no weird token needed. It fails **closed** and is one-owner-transaction recoverable, which is what holds it at Low.

### D-26-06 — story-032 removed the precondition that made "fund the streamer before wiring the minter" impossible (deployment-ordering footgun)

- **Merges**: `LOCAL-BM-01`, `ECON-26-M2` (magnitude input)
- **Sites**: `src/BatchNFTMinterMultiToken.sol:328-336` (gate removed), `NudgeStreamer.sol:127` (now the only registration gate), `:479` (where `batchMint` reverts instead), `:532-534` (the flush that never runs)
- **Tuple**: `src/BatchNFTMinterMultiToken.sol:setNudgeTokenWhitelist:removed-config-completeness-precondition`
- **Classification**: **NEW**
- **Proposed severity**: **Low**
- Before `9611312`, `isNudgeToken(token) == true` transitively witnessed `tokenMinter != 0 && dispatcherIndex != 0 && dispatcher != 0`, because no entry could be added without `_resolvePaymentPath()` succeeding. `registerStream` gates on nothing else. Now: whitelist → register → **permissionless** `collectNudge` funds the buffer (production `NudgeRatchet` does it on schedule) → `batchMint` reverts `BatchMint__MinterNotConfigured` at `:479` *before* the flush loop → nothing drains it, and the streamer has no rescue.
- **Magnitude (ECON-26-M2)**: both production donors are **stateless sweepers** forwarding their entire balance on every dispatch, so the amount at risk is all donor throughput between `registerStream` and completed minter configuration — not a fixed sum. Fully recoverable by completing configuration ⇒ runbook hazard, not a loss.
- **Disclosure owed**: §4.3 — **must not** be collapsed into `4a1d8edc92` (that entry is "the streamer has no rescue"; this is "story-032 opened a new route into needing one" — the pre-commission mirror of that entry's decommission case). They compound.

### D-26-07 — spec-conformance mirror of D-26-06 (Law 2)

- **From**: `F-04`
- **Route**: `spec-conformance.md`
- **Classification**: **NEW**
- **Proposed severity**: **Low**
- Dual-routed for the same reason as D-26-03/D-26-04. The Law-2 deviation is narrow and specific: story-032's wider four-revert blast radius is **authorised, disclosed and faithful** (`032-…md:155-178`, Concerns §1 — the intake hypothesis was REFUTED), but the story twice ships a false "`NudgeStreamer` … is unaffected" claim (`:126-128`, `:383-385`). The mechanism claim ("reads `_nudgeTokenIndex`") is true; the conclusion is false, because what changed is what a `true` from `isNudgeToken` transitively witnesses. "Only what is refused" *is* the change to the reachable state set.
- Remediation lands while the story is still open (see D-26-12), so it can be folded in rather than filed as a follow-up.

### D-26-08 — `setNudgeStreamer` accepts any address with no structural probe: a mis-point is a permanent silent no-op

- **From**: `PATTERN-002`
- **Site**: `src/BatchNFTMinterMultiToken.sol:297-300`
- **Tuple**: `src/BatchNFTMinterMultiToken.sol:setNudgeStreamer:unvalidated-setter-silent-brick`
- **Classification**: **NEW** (not present in this project's ledger)
- **Proposed severity**: **Low**
- Asymmetric with its counterparty: `NudgeStreamer.registerStream` deliberately probes the batchMinter with `isNudgeToken` (`:127`, documented `:10-17`) precisely to confirm the target type; the reverse direction has no equivalent check. Aggravating: the event is emitted *before* assignment (`:298-299`), so a mis-point reads as a clean success in logs.
- **Partial defeat carried forward honestly (do not overclaim)**: for an **EOA** the pattern is DEFEATED — solc 0.8.20 retains the `extcodesize` check for void-returning external calls, so the flush reverts loudly. The reachable residual is a **contract with a permissive fallback** (a Safe, a proxy with an unset implementation, another Phoenix contract): the flush then succeeds and does nothing, forever, while donor buffers accumulate unreachably.
- **Disclosure owed**: §4.6 — cross-project class precedent (phStaging run-21 M-02, stable-yield-accumulator `setRewardToken` brick `0xd62cbfe8`), and §4.7 (`cf332bf46c` is *not* this).

### D-26-09 — `NudgeCollected.amount` repointed from request to receipt under a byte-identical ABI

- **Merges**: `ECON-26-03`, `LOCAL-NS-02`
- **Site**: `src/NudgeStreamer.sol:106-114` (declaration), `:211` (emit); documented at `INudgeStreamer.sol:14-18`
- **Tuple**: `src/NudgeStreamer.sol:collectNudge:event-semantics-repoint`
- **Classification**: **NEW**
- **Proposed severity**: **QA**
- **No on-chain desync, verified not assumed**: no sibling contract consumes the event (`grep -rn "NudgeCollected" lib/yield-claim-nft/src` → 0 hits); `NudgeRatchet.dispatch` keeps no cumulative sent-amount counter; the mint-debt ledger that *does* accumulate (`NudgeRatchetMintDebtHook.onDispatch:122-130`) derives from the NFTMinter's `amount`, never the streamer credit; and both production donors forward **USDC**, for which receipt ≡ request.
- Residual is off-chain only and is a silent **under**-count — the direction an operator is least likely to investigate — with no compile-time, ABI-level or topic-level signal, and no on-chain way to learn the credited value (`collectNudge` returns `void`).

### D-26-10 — spec-conformance mirror of D-26-09 (Law 2)

- **From**: `F-03`
- **Route**: `spec-conformance.md`
- **Classification**: **NEW**
- **Proposed severity**: **Low (QA)**, confidence medium
- Narrow gap, and the intake hypothesis was partly refuted: story-031 **does** address the semantic change squarely as a named accepted consequence (Concerns §3) and swept the five downstream call sites. The residual is (a) the event *declaration* — the line an indexer author reads first — is unamended (the story's own review Issue 3, not actioned), and (b) the "Not ABI-breaking" analysis is scoped to calldata/returndata and never asks whether a donor keeps a sent-amount-derived counter.

### D-26-11 — story-030 left an unenforced ordering guarantee standing inside the comment block it rewrote, and its own new text contradicts it

- **From**: `F-01`
- **Site**: `src/BatchNFTMinterMultiToken.sol:659-665` (claim 2, "and vice versa")
- **Tuple**: `src/BatchNFTMinterMultiToken.sol:batchMint:selfcontradicting-ordering-guarantee`
- **Route**: `spec-conformance.md` **and** QA bundle (same pattern as decision 3)
- **Classification**: **NEW** (the block was rewritten by story-030 in this run's range)
- **Proposed severity**: **Low (QA)**
- The block asserts a **symmetric** mutual-non-interference guarantee and attributes it to *ordering*. Neither half survives: independence comes from **sourcing** (`budget` vs `snapshot`), not sequence; and in the one case where ordering binds (erosion between step 5 and step 9), refund-first charges the shortfall to `D` then `P` — so "a refund funded out of a payout that is owed" is what the ordering *causes*, not what it prevents. Story-030's own Anchor E addition 20 lines below (`:695-700`, "charged to the pot, silently") states the contradicting fact.
- In scope despite sitting outside the anchor's enumerated line range, because story-030's own review pass (`:375-378`) explicitly disowns "it wasn't in my anchor list" as a defence.
- **Disclosure owed**: §4.8 — in-source-overclaim cluster (`181e444c40`, `b7d8c5d5f5`, `dacaba6ef5`, `51aed27661`, `75305ec024`, `a7dffb34c9`), all different sites/claims; kept separate.

### D-26-12 — story-032 landed at HEAD while its story document sits in `review` (process note)

- **From**: `F-05`
- **Route**: `spec-conformance.md`, **informational**
- **Classification**: **NEW**, informational — not a security finding, kept because CLAUDE.md calls a landed-but-unclosed story worth surfacing
- `9611312` is HEAD and the deliverable is wired, but `032-remove-payment-token-whitelist-gate.md` remains under `review/whitelist-liberation/`. Its own Review Results record PASSED (47/47) with two deferred items (the `phStaging2:072` six-row stale-claim reconciliation, whose phase-0 assertion of the now-deleted `BatchMint__RewardTokenIsPaymentToken` tripwire would fail if 072 were run as written — 072 is on ice and unbroadcast, owner-confirmed 2026-07-30; and the unpushed `sprint/whitelist-liberation` branch).

### D-26-13 — Duck-typed structural guard with no compiler enforcement

- **Merges**: `CODE-04`, `S-02`
- **Site**: `src/BatchNFTMinterMultiToken.sol:159` / `:289` vs `src/NudgeStreamer.sol:15-17`, `:127`
- **Tuple**: `src/BatchNFTMinterMultiToken.sol:isNudgeToken:unenforced-interface-coupling`
- **Classification**: **NEW**
- **Proposed severity**: **QA**
- Normally pure tool noise (`missing-inheritance`), kept because the duck-typed `isNudgeToken` call is **load-bearing by design**: it is `registerStream`'s single admission check, proving whitelist membership *and* MultiToken-batchMinter identity at once. Coupling by convention rather than inheritance means a signature change on either side compiles clean.
- **Not a security finding, and the reason is stated**: drift **fails closed** (`registerStream` reverts on empty returndata, `onlyOwner`, no funds in motion), and `external view` ⇒ `STATICCALL` ⇒ cannot reenter or mutate. The only false-accept path needs an owner-supplied address with a permissive fallback = obvious owner error (Law 3, suppressed). Fix: declare the interface and move it out of `NudgeStreamer.sol` into its own file.
- **Disclosure owed**: §4.7 (`cf332bf46c` is the *interface documentation* gap, not the missing declaration).

---

## 2. Parked to `manual-review.json` (Law-1 visible channel — routed, NOT dropped)

Written to `reports/phoenix-nft-staking/26/manual-review.json`. These are uncertainty about whether the pattern *applies*, not about severity.

| ID | Subject | Why parked |
|---|---|---|
| `MR-26-01` | Sub-wei truncation forfeiture: `NudgeStreamer.sol:240` sets `lastUpdate` unconditionally including when `settled == 0`, discarding fractional accrual on every flush | Dust (≤1 wei/stream/call, ≤~50k wei over a 7-day window at 12s blocks) and each call costs a real paid mint. **Per upstream decision 4, must NOT be collapsed into `aaebb4b9b0`** — truncation and window-reset are different mechanisms; collapsing loses one. |
| `MR-26-02` | `registerStream` lacks `nonReentrant` while `_settle` (`:134`) makes an outbound transfer, unlike its two siblings | Mechanism **cleared** by tier-2 (state written after `_settle` reads the post-reentry `s.buffer` at `:139`, so a reentrant credit folds in correctly; `onlyOwner` + hook-token precondition). Parked rather than killed because the guard **asymmetry** itself is unexplained and a future edit could make it live. |
| `MR-26-03` | `recipient` unvalidated beyond non-zero (`:472`); `recipient == address(this)` would route `_payRewards` to self | **Genuinely unresolved.** Tier-2 confirmed the ERC1155 receive-hook fires on a caller-chosen `recipient` (correcting the profile, which denied the surface exists) but did not adjudicate the self-recipient case. Needs confirmation of whether `BatchNFTMinterMultiToken` implements `onERC1155Received`. |
| `MR-26-04` | `rewardPerSecond * elapsed` overflow (`:268`) at absurd `buffer` with `duration == 1` | Needs ~1e50 buffer. Parked for the **coupling** only: an overflow would brick `collectNudge` *and* `pullPendingStream` for the pair, hence `batchMint` via D-26-01's loop. |

---

## 3. Removals — every one with its reason

### 3.1 KILLED (mechanism disproven from source, not merely unsupported)

| ID | Kill reason |
|---|---|
| `S-03` — discarded `nftMinter.mint()` bool (`BatchNFTMinterMultiToken.sol:650`, legacy `BatchNFTMinter.sol:287`) | **Per upstream decision 5.** Read at top-level `lib/yield-claim-nft@d4cc563`, `NFTMinterV2._executeMint` has exactly **one** `return`, a literal `true` on the sole success path; there is no `return false` anywhere in the contract. Every failure mode is a hard revert (3 `require`s, `safeTransferFrom`, the dispatcher's own `whenNotPaused` `dispatch`, OZ `_mint`'s acceptance check). The discarded bool carries zero information and can never mask a no-op debiting `budget` at `:649`. Corroborated by 2 tools (Slither `unused-return` Medium, Aderyn `Unchecked Return` Low) and killed anyway — this is exactly the "common finding from automated tools without a demonstrated exploit path" C4 excludes. Bonus: closes profile `BatchNFTMinterMultiToken.md` §6 items 1 and 2 (charge-then-ramp CONFIRMED at `:183`/`:188`; `mint` charges exactly `price`, allowance-capped, fails closed). |
| Leg B of the merged lead (`Σ buffer_i` over-statement) | Killed upstream (decision 1) and machine-confirmed by tier-3. Recorded here so no later run re-derives it: the kill rests on exhaustive write-site enumeration (one state variable, four write sites) plus 452k+ fuzzed calls, and the tier-3 scope limits are explicit — the campaign says nothing about fee-on-transfer, rebasing, clawback, blocklist or hook-bearing tokens, which is precisely the C4-invalid set. |

### 3.2 Culled as tool noise (with reason)

| Input | Cull reason |
|---|---|
| `S-05` / Slither `timestamp` class, **67 instances** | **Per upstream decision 7 — reconciled and culled here, as instructed.** The 2 `NudgeStreamer` instances (`:241` `settled > 0`, `:270` `accrued > buffer`) are Slither **mis-attribution**: both operands derive transitively from `block.timestamp - s.lastUpdate` but neither is a timestamp threshold. The remaining 65 sit in the unchanged staker family (`windowEnd`/`lastRewardTime` window arithmetic), pre-existing and outside regression focus. The load-bearing Linear-Depletion class they brush against is **already tracked in visible ledger entries** (`aaebb4b9b0` open, `6f46ec80f1` open, `b58b172e2a` fixed), so nothing is lost by culling the detector class — no manual-review park needed. |
| 13 noise-labelled classes, **623 raw tool results** → 8 retained → 5 distinct | Slither `reentrancy-no-eth` (38) / `reentrancy-benign` (8) / `reentrancy-events` (5 of 6) — all on `nonReentrant`-carrying functions in unchanged code. Aderyn HIGH "state change after external call" (16) — same class from another angle, includes two **constructors** (definitionally noise) and the *deliberate* `balanceOf`-bracketed delta measurement pinned by a project test; Aderyn's HIGH label is not a severity signal. `incorrect-equality` (5) — all zero/sentinel guards. `uninitialized-local` (10) — style. `unused-return` (6 of 8) — deliberate partial tuple destructuring. `costly-loop` (20) + Aderyn (6) — gas. `calls-loop` (17 of 18) — architecturally mandatory reads. `missing-zero-check` (12) + Aderyn (19) — Law-3 obvious-misconfig, **and a zero-check on `setNudgeStreamer` would be actively wrong** (`address(0)` is a deliberate disable path). `cyclomatic-complexity` (1). Semgrep's **253 results are 100% `severity: INFO`** gas/style with **0 security rules loaded** — Semgrep is not a passing security check in either direction. Full enumeration retained in `tier1/static-analysis.md` Appendices A–C; "noise" is a label there, not a deletion. |
| 14 `DEFEATED` pattern classes + `FRONTRUN-APPROVE` (skipped) | Each names the defeating guard and quotes the line; none rests on "looks fine". Not findings by construction. `FRONTRUN-APPROVE` is C4 known-invalid and shows no HM twist (`forceApprove` sets an absolute per-mint target, revoked at `:655`). |

### 3.3 Duplicates of existing ledger entries — do NOT re-file

| Input | Ledger entry | Status | Disposition |
|---|---|---|---|
| `S-04` — no `ReentrancyGuard` on legacy `BatchNFTMinter` (`:62`), while its successor has one | **`c847207db2`** (M-02, medium) | **open** | **DUPLICATE.** Per upstream decision 6 — pre-existing legacy V1, outside regression focus, reconciled not presented as new. `c847207db2` is exactly this asymmetry ("`BatchNFTMinterMultiToken` got ReentrancyGuard; the DEPLOYED `BatchNFTMinter` did not"), is exploit-backed (26.900000 USDC measured, dual-harness), and remains **open**. Also related to `9135cf7947` (L-01, submitted) — see the hygiene alert in §5, and **do not merge the two** per `c847207db2`'s own note. |
| `ECON-26-01` — the streamer is a first-order low-pass filter, not a linear drain; needs no griefer | **`aaebb4b9b0`** (L-02, low) | **open** | **DUPLICATE + mandatory RE-FRAME.** Explicitly a re-weigh input, not a re-file. Severity **COMMITTED at Low** by the econ tier and I concur — the two limbs cancel rather than compound (precisely because no griefer is needed, the permissionless surface adds nothing: 0.11 pp marginal attacker contribution; precisely because nothing is lost and the error direction *favours* the protocol, the certainty has no impact to attach to). See §6 for the note text the finding-manager must apply. |
| `ECON-26-M1` — the permanently-buffered float is `duration × inflow`, structurally and always | **`4a1d8edc92`** (L-01, low) | **open** | **Magnitude input, not a finding.** Re-sizes that entry from "leftover dust" to `7 × daily inflow × registered pairs` at the pinned mainnet `duration` of 7 days. Apply as a note. |
| `ECON-26-M2` — pre-commission stranding is bounded in practice by donor throughput | — | — | **Merged into D-26-06** as its magnitude paragraph. |

### 3.4 Re-confirmed present, explicitly not re-filed (per run instruction)

`6b8faaf6dc`, `bfdb50105e`, `51aed27661`, `38ea47b14c`, `990d8c37b4`, `43e8c48626`, `4a1d8edc92`, `aaebb4b9b0`, `6f46ec80f1`, `cf332bf46c`, `966e717669`, `858e9e807a`, `521c20ad48`, `b58b172e2a`. `cf332bf46c` is **partially addressed — do NOT close.** `2d34673536` is **still fixed — no regression** (independently re-verified through *two* paths this run: the `:533` flush and the newly-cheap mid-mint-loop settle).

Also not re-filed, settled: `paymentToken == nudgeToken` collision and its arbitrage (owner-PERMITTED 2026-07-25), caller-supplied `rewardTokens` (structurally impossible), NFT redemption value (none), `911c54fd6d` class (no `emergencyWithdraw`-shaped path in either in-scope contract), `d0ed2cf440` (the ERC1155 mid-loop surface is already recorded as real-but-held), fee-on-transfer / weird-ERC20 standalone (C4 known-invalid).

### 3.5 Tier-3

- **`tier3/invariants.md`**: **0 findings**, as that tier itself states. Its outputs are (a) the machine confirmation of the Leg-B kill folded into D-26-01, and (b) one **report-affecting correction**: the econ note's "~36.7% of a burst remains buffered at the nominal window end" has the **orientation inverted** — `1/e ≈ 36.8%` is the *released* share, the *retained* share is `1 − 1/e ≈ 63.2%` (measured 61.59% under 28 discrete deposits). Report text must quote **~63% retained**. This matches the 63.26% run-18 depletion PoC figure. Every downstream agent quoting the low-pass numbers must use the corrected orientation.
- **Harness hygiene (MEMORY: never file audit-authored test files)**: `test/Invariant_Run26_BufferConservation.t.sol`, `test/MedusaTarget_Run26_BufferConservation.sol`, `test/patched/MutantNudgeStreamer.sol`, `medusa-run26.json` are **audit-authored, in `workspace/`** — never cite them as project tests or file them as evidence of project coverage.

---

## 4. Disclosure statements owed (Law-1 duty — a new fingerprint will NOT trip normal dedup)

### 4.1 D-26-01 vs `bfdb50105e` (Q-03, qa, **wont-fix**) — REQUIRED

Prior entry, `src/BatchNFTMinterMultiToken.sol:_payRewards:429`. Its recorded reason, quoted:

> "[phoenix-nft-staking-20] NEW QA @0d1a0b2 — SETTLED BY D-19 AND CARRIED FORWARD UNCHANGED; do not re-litigate. `minRewards` floors the contract's PRE-TRANSFER balance, not the delivered amount … and on a negatively-rebasing or otherwise shrinking token `safeTransfer(snapshot[i])` reverts and the WHOLE batch rolls back (one-token self-DoS). Held at QA: story-022 §4.4 documents FoT explicitly, so the C4 known-invalid predicate does not fire … but documenting a risk does not manufacture an attack path the value flow does not support. The caller chooses BOTH the token AND the recipient, the fee accrues to the token's own sink (no extraction by anyone)…"

**Re-file basis**: same *class* (a misbehaving token reverting the batch), **different site and materially wider blast radius**. `_payRewards` is skipped for zero amounts *and* for non-qualifying batches (`_snapshotRewards:801` short-circuits behind `qualifies`); the flush loop at `:528-536` is skipped for **neither**. The prior entry's core suppression argument — "the caller chooses BOTH the token AND the recipient", so exposure is self-inflicted — **does not transfer**: the flush loop iterates the **owner's** whitelist, not the caller's argument, and it fires on a `count < nudgeSize` batch that touches no nudge token at all. That is the incremental harm, it is new at story-028's wiring, and it is not covered by `bfdb50105e`'s settlement. Filing D-26-01 does **not** re-litigate `bfdb50105e`, which stays wont-fix and unchanged.

### 4.2 D-26-01 vs `966e717669` (L-02, low, **open**) — sibling precedent, REQUIRED

> "`_syncBudget` calls `dispatcherHook.pull()` without try/catch; a reverting/unauthorized hook propagates the revert and bricks every `_syncBudget` caller — staker interactions and `initiateMigration`. Availability-only, owner-recoverable (re-point/clear the hook); no theft. … Recommend wrapping `pull()` in try/catch and skipping (with an event) on failure."

**Re-file basis**: identical root-cause class (un-`try/catch`'d external call to a semi-trusted contract on a load-bearing path) **one contract over**, distinct contract and entry point ⇒ distinct fingerprint. This is the **third** occurrence of the class in this project's ledger (`966e717669` on `NFTStakerDepletion._syncBudget`, `1887dbe136` on copy #4 via a different trigger — itself DISCLOSED-not-collapsed at run-20 D-15, and now D-26-01 on the flush loop). The recommended remediation is the same shape in all three. Note the pattern: the project keeps re-introducing bare external calls on paths whose availability matters; that recurrence is worth stating to the owner as a class, even though each entry stays separate.

### 4.3 D-26-01 and D-26-06 vs `4a1d8edc92` (L-01, low, **open**) — compounding, REQUIRED

> "No owner rescue exists … Recoverable under supported ops … permanent stranding only on batchMinter decommission with a non-empty buffer or owner abandonment. … severity-auditor ARBITRATED Low (recoverable; no-rescue is defensible pass-through design; a rescue would let the owner divert donor funds). Safe config: drain the streamer before decommissioning / permanent-repoint."

Two distinct compositions, neither a duplicate:
- **D-26-01**: the owner's escape from the brick (`setNudgeTokenWhitelist(token,false)`) **is the action that triggers** `4a1d8edc92` — it converts an availability outage into permanently stranded value. The escape is what holds D-26-01 at Low, so the composition must be stated or the Low reads as costless.
- **D-26-06**: the **pre-commission mirror** of `4a1d8edc92`'s decommission case. That entry says "the streamer has no rescue"; D-26-06 says "story-032 opened a new route into needing one". Do not collapse.

### 4.4 D-26-02 vs `43e8c48626` (M-01, medium, **wont-fix**) — REQUIRED

> "story-025's whole-whitelist payout pays the qualifying recipient the PRIOR-accumulated pot of EVERY whitelisted nudge token in one event for a SINGLE qualifying cost … break-even shifts from 'each pot < qualifying cost' to 'SUM(pot_i) < qualifying cost'."

**Re-file basis**: `43e8c48626` is about the **size of a paid pot** while the feature is **on**. D-26-02 is about **accumulation while the feature is nominally off**, in the wrong container, with no return path — a different lever (`setNudgeSize(0)`), a different operator expectation, and a different fix (gate the flush on `qualifies`). Adjacent, not the same; do not collapse.

### 4.5 D-26-03 / D-26-04 vs `6f46ec80f1` (L-03, low, **open**) and the `858e9e807a` / `521c20ad48` suppression basis

`6f46ec80f1` is a **different NatSpec overclaim** on the same contract (burst-capture / time-throttle-not-value-cap, WATCH-23 resolution). D-26-03 is a new claim at a new site introduced at `2ba764e` (pooled-custody invariant "by construction"). Keep separate.

**And a note the classifier must not miss**: story-030's metering sentence is the stated suppression basis behind `858e9e807a` (H-01, wont-fix) and `521c20ad48` (M-01, wont-fix). The econ tier looked for this specifically and reports the ground **SURVIVES** — nobody can *accelerate* release (`rate = buffer/D`, accrual capped at `buffer`, fastest full drain is still "wait `duration`"), and the failure direction is *slower* release, i.e. a smaller instantaneous pot, which under story-030's own clearing-price argument is *better* price discovery. **Those two wont-fixes therefore stand; nothing here reopens them.** Stated so a reader of D-26-03 does not infer otherwise.

### 4.6 D-26-08 — cross-project class precedent, REQUIRED

Same root-cause class as **phStaging run-21 M-02** (silent `setNudgeStreamer`) and the **stable-yield-accumulator `setRewardToken` brick** (`0xd62cbfe8`, Medium — whose guard was later found ONE-DIRECTIONAL with 3 residual paths). Those live in **different project ledgers**, so no fingerprint collision exists and normal dedup cannot see them. Re-file basis: new contract, new project ledger, and the phoenix instance is narrower than the SYA one (EOA case is defeated by `extcodesize`; only a permissive-fallback contract reaches the silent no-op). Disclosed so the owner sees it as a **recurring class across three repos**, not a one-off.

### 4.7 D-26-08 and D-26-13 vs `cf332bf46c` (Q-01, qa, **open**, *partially addressed — do NOT close*)

> "Interface silent on (a) `pullPendingStream` no-ops on an unregistered token — `batchMint` loops blindly relying on this; (b) `registerStream` onlyOwner + whitelist guard; (c) recompute-on-deposit-only. Doc-only; impl correct; a re-implementer could brick `batchMint`'s flush by reverting on an unregistered token."

Neither new finding is this. `cf332bf46c` is the **documentation** gap on `INudgeStreamer`; D-26-13 is the **missing interface declaration** on the batchMinter (compiler enforcement of a duck-typed guard), and D-26-08 is an **unvalidated setter**. All three are adjacent and all three should be fixed together, but they are distinct root causes with distinct fixes. Keep `cf332bf46c` open.

### 4.8 D-26-11 vs the in-source-overclaim cluster

`181e444c40` (Q-01, the `available` cap at `:647`), `b7d8c5d5f5` (Q-02, the `:580` min at `:562`), `dacaba6ef5` (Q-03, docs §4.1 "SAFE BY CONSTRUCTION"), `51aed27661` (L-01, merged — decimals-blind `DUST_THRESHOLD` misreported, also at `:659`), `75305ec024`, `a7dffb34c9`. **Same class** (a falsely-exhaustive in-source guarantee on a load-bearing property), **different sites and different claims** in every case; `51aed27661` shares the line region `:659` but is about the dust threshold's decimals-blindness, not the ordering guarantee. D-26-11 is additionally **new at this commit** (story-030 rewrote the block). Keep separate; disclose the cluster so the owner can see that the in-source-overclaim class now has **seven** live members and consider a documentation-accuracy sweep as one remediation rather than seven.

---

## 5. Ledger-hygiene alert (NOT a finding, NOT a regression) — `9135cf7947`

I found and resolved a contradiction between the ledger and source, and it needs a human decision before any `/ledger` write.

`9135cf7947` (L-01, low, **submitted**, `src/BatchNFTMinter.sol:batchMint`) carries a run-20 **PROPOSED → `fixed`** (D-09, proposal only) whose evidence is:

> "Re-derived from source at 0d1a0b2 … `BatchNFTMinter.sol:11` imports OZ ReentrancyGuard, `:82` `contract BatchNFTMinter is Ownable, Pausable, ReentrancyGuard, IPausable`, `:300` `external whenNotPaused nonReentrant`…"

**At `9611312` that is false**: `src/BatchNFTMinter.sol:62` is `contract BatchNFTMinter is Ownable, Pausable, IPausable` and the file contains **zero** occurrences of `ReentrancyGuard`/`nonReentrant` (verified directly). The quoted line numbers match `BatchNFTMinterMultiToken.sol` (`:11` import, `:159` declaration, `:467` `nonReentrant`).

**But it is not a regression, and the git history says why.** The guard genuinely was present at `0d1a0b2` (added by `2bf13cb`, story-022 stages 3-5, when `BatchNFTMinter.sol` itself still carried the multi-token nudge) and was then removed by `fba4991`, "[story-022] Stage 7: split multi-token nudge out of the deployed BatchNFTMinter" — i.e. V1 was **deliberately restored to its frozen deployed shape**. This is the "expired closure vs regression" shape from MEMORY: the closure premise evaporated by intentional revert, not by a re-break.

**Actions for the human / finding-manager:**
1. **Do NOT apply the run-20 proposed `fixed` on `9135cf7947`.** Its premise does not hold at HEAD.
2. Record the corrected reason on that entry (deliberate Stage-7 revert, not a re-break) so a later run does not file it as a REGRESSION.
3. The live condition is already correctly tracked by **`c847207db2`** (M-02, medium, **open**, exploit-backed) as realised fork drift. Keep the two **unmerged** per `c847207db2`'s own note.
4. Status here is `submitted`, so nothing was silently closed — no Law-1 breach occurred. Flagged per the standing rule to diff every delegated ledger write.

---

## 6. Ledger-note text to apply (finding-manager input; no writes made here)

**`aaebb4b9b0` (L-02, open) — RE-FRAME, keep Low.** The griefing frame must stop being the primary characterisation: a griefer's entire marginal contribution is **0.11 pp** (36.79% vs routine 36.68% at `t = D`). Filed as griefing, a reader fixes it by permissioning `collectNudge` — which changes nothing and would **break both production donors** (`NudgeRatchet.dispatch`, `BalancerPoolerV2._donate`). Promote the intent-gap limb: `NudgeStreamer.sol:19-23` (and story-028 `:19`, `docs/multi-token-nudge.md:463`, `:568-572`) claim "streams linearly to zero over a configured `duration`", which is unachievable under any repeated-deposit regime; the streamer is a first-order low-pass filter with time constant `duration`. **99% delivery takes `D·ln 100` = 32.2 days against a configured 7 days — a 4.6× stretch.** Steady-state throughput is *correct* (`B* = i·D`, release rate `= i`); what is wrong is a permanent float. Remediation is **documentation plus a runbook note** that `duration` sizes a *time constant*, not a drain time. Quote retention as **~63% retained / ~37% released** at the nominal window end (tier-3 orientation correction; measured 61.59%/38.40% under 28 discrete deposits). Behaviour is **Law-2 faithful** — story-028 §Concerns explicitly blessed window-reset-on-deposit as intended phlimbo behaviour.

**`4a1d8edc92` (L-01, open) — magnitude.** Steady-state buffer is `duration × inflow_rate`, structurally and permanently. At the pinned mainnet `duration = 7 days`, the streamer holds seven days of aggregate nudge inflow at all times across `{USDC, phUSD, Kendu}` per registered batchMinter. Size the stranding risk at `7 × daily inflow × registered pairs`, not "leftover dust".

**`cf332bf46c` (Q-01, open) — partially addressed; do NOT close.**

---

## 7. Coverage gaps (recorded, not silently absorbed)

1. **`tier3/symbolic.md` absent at dedup time.** Consequence, stated explicitly because it is load-bearing: tier-3 recommends **INV-1** (`Σ buffer_i <= balanceOf(streamer)`) as a good Halmos candidate, and INV-1 *is* the killed Leg B. A passing fuzz campaign is "no counterexample found in N sequences", not proof. **If the symbolic run returns a counterexample to INV-1 under a plain ERC20, Leg B revives and D-26-01 must reopen at Medium under its own written reopen trigger** — the impact side already qualifies. If Halmos returns `[PASS]`, that is a proof and the Leg-B kill hardens. A Halmos `TIMEOUT` is **not** a proof either way (MEMORY). This dedup must be revisited on either outcome; do not let the symbolic result land after the report is written.
2. **4naly3er not run this pass** (Slither + Aderyn cover its detector set). Recorded as a gap, not a silent skip. No symlink workaround was created (avoids the known broken-remappings trap).
3. **Semgrep is not a security check here** — 0 security rules loaded for Solidity, 253/253 results `INFO`-severity gas/style. Its silence is not evidence of cleanliness.
4. **Live configuration unverifiable from the repo**: actual `nudgeSize`, whitelist contents, `nudgeStreamer` address, per-pair inflow rates, and `duration` on any deployed instance. Per this family's standing note, deploy records have been unreliable and **addresses must be resolved from chain** before acting on D-26-02 or D-26-06.
5. **Whether any off-chain indexer sums `NudgeCollected.amount`** — D-26-09's entire residual is contingent on this; on-chain consumers are ruled out, off-chain ones cannot be.

---

## 8. Count reconciliation — every input accounted for

**Named candidate inputs: 28.**

| Source | IDs | Count |
|---|---|---|
| `tier1/static-analysis.md` | S-01 … S-05 | 5 |
| `tier1/pattern-matches.md` | PATTERN-001, PATTERN-002, MR-26-01 … MR-26-04 | 6 |
| `profiles/` | LOCAL-NS-01, LOCAL-NS-02, LOCAL-BM-01 | 3 |
| `tier2/code-findings.md` | CODE-01 … CODE-04 | 4 |
| `tier2/econ-findings.md` | ECON-26-01, -02, -03, -M1, -M2 | 5 |
| `tier2/faithfulness.md` | F-01 … F-05 | 5 |
| `tier3/invariants.md` | — (0 findings, 1 figure correction) | 0 |
| `tier3/symbolic.md` | — (file absent) | 0 |

**Disposition ledger (28 inputs → 13 outputs + 4 parked + 11 accounted removals/redirects):**

| Input | Disposition | Output |
|---|---|---|
| LOCAL-NS-01 | **SPLIT** (both limbs preserved) | DoS limb → **D-26-01**; doc limb → **D-26-03** |
| S-01 | merged | **D-26-01** |
| PATTERN-001 | merged | **D-26-01** |
| CODE-01 | merged (carries the fullest analysis — preserve its text) | **D-26-01** |
| ECON-26-02 | kept, separate per decision 2 | **D-26-02** |
| CODE-03 | kept | **D-26-03** |
| F-02 | kept, dual-routed per decision 3 | **D-26-04** (spec-conformance) |
| CODE-02 | kept, separate (different repo fix site) | **D-26-05** |
| LOCAL-BM-01 | kept | **D-26-06** |
| ECON-26-M2 | merged as magnitude | **D-26-06** |
| F-04 | kept, dual-routed | **D-26-07** (spec-conformance) |
| PATTERN-002 | kept | **D-26-08** |
| ECON-26-03 | merged | **D-26-09** |
| LOCAL-NS-02 | merged (same site, same root cause) | **D-26-09** |
| F-03 | kept, dual-routed | **D-26-10** (spec-conformance) |
| F-01 | kept | **D-26-11** |
| F-05 | kept, informational | **D-26-12** (spec-conformance) |
| CODE-04 | kept | **D-26-13** |
| S-02 | merged (adjudicated up into CODE-04) | **D-26-13** |
| MR-26-01 | **parked** — decision 4, never collapse into `aaebb4b9b0` | `manual-review.json` |
| MR-26-02 | **parked** — mechanism cleared, asymmetry unexplained | `manual-review.json` |
| MR-26-03 | **parked** — genuinely unresolved | `manual-review.json` |
| MR-26-04 | **parked** — coupling only | `manual-review.json` |
| S-03 | **KILLED** — decision 5, single `return true`, all failures revert | §3.1 |
| S-04 | **DUPLICATE** of `c847207db2` (open) — decision 6 | §3.3 + §5 alert |
| S-05 | **CULLED** as tool noise — decision 7, class tracked elsewhere | §3.2 |
| ECON-26-01 | **DUPLICATE** of `aaebb4b9b0` (open) + mandatory re-frame | §3.3, §6 |
| ECON-26-M1 | **magnitude input** to `4a1d8edc92` (open), not a finding | §3.3, §6 |

**Arithmetic**: 28 inputs = 19 folded into 13 outputs (LOCAL-NS-01 counted once though it split two ways) + 4 parked + 1 killed + 1 culled + 3 redirected to existing ledger entries. **0 silent drops.**

**Bulk tool results**: 623 raw (194 Slither + 176 Aderyn + 253 Semgrep) → 8 retained → 5 distinct after cross-tool merge → 3 survive into outputs (S-01→D-26-01, S-02→D-26-13, S-05 culled, S-03 killed, S-04 duplicate). All 623 remain enumerated in `tier1/static-analysis.md` Appendices A–C.

**Classification totals**: **NEW 13** (D-26-01 … D-26-13) · **DUPLICATE 3** (S-04, ECON-26-01, ECON-26-M1) · **REGRESSION 0**. `2d34673536` still fixed. No finding matches a `fixed` ledger entry going live; the one apparent contradiction (`9135cf7947`) is an expired closure premise by intentional revert, not a regression — §5.

**Severity distribution of outputs**: High 0 · Medium 0 · Low 6 (D-26-01, -02, -05, -06, -07, -08 · with D-26-04/-10/-11 at Low(QA)) · QA 3 (D-26-03, -09, -13) · Informational 1 (D-26-12). Ledger would go **78 → 87** entries if all 9 unique root causes are upserted (the 3 spec-conformance mirrors are channel routings of findings already counted; the finding-manager decides whether mirrors get their own entries — prior runs have filed `F-NN-NN` entries separately, which would make it 78 → 91).
