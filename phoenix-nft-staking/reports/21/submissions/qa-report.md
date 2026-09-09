# QA Report — phoenix-nft-staking (run 21)

**Project**: `phoenix-nft-staking`
**Submodule HEAD**: `c881a42`
**Run directory**: `reports/phoenix-nft-staking/21/`
**Scope**: all 11 first-party contracts under `src/`

## Summary

| Severity | Count |
|----------|-------|
| Low Risk (new this run) | 5 |
| QA / hardening (new this run) | 2 |
| Centralization Risk | 0 reported — see §Centralization |
| **Total new** | **7** |

Additionally carried in clearly-marked sections below, **not** part of this run's `L-nn`/`Q-nn` sequence:

| Section | Count |
|---------|-------|
| Still-open carryover Low/QA (reproduced in full) | 2 |
| ⚠ Parked for human triage | 2 |
| Tool gaps (record, never read as clean) | 4 |
| Operational notes (no label, no severity) | 1 |
| Housekeeping | 1 |
| Drift watch | 1 |

---

### ⚠ Mandatory reading notes

**Label collisions are real on this project.** The ledger reuses `H-01`/`M-01`/`M-02`/`L-01`/`L-02`/`L-03`/`Q-01`… across different contracts and different runs. Every `L-nn`/`Q-nn` in the **Low Risk Findings** and **QA** sections below is a **new run-21 label**; every reference to a *ledger* label in this document is disambiguated by fingerprint. Never reconcile these by label alone — see `findings/LABEL-MAP.json`.

**Two files, one lineage.** `src/BatchNFTMinter.sol` is the **frozen, mainnet-DEPLOYED** file. `src/BatchNFTMinterMultiToken.sol` is its **new, not-yet-deployed** twin. Carryover entries below state explicitly which file each applies to.

**Faithfulness (`F-`) findings are not in this bundle.** Run-21's `F-21-01`…`F-21-06` and the still-open `F-20-07` are Law-2 spec deviations and are routed to the **spec-conformance report**, not absorbed here.

---

## Low Risk Findings

### [L-01] story-023's `require(captured <= owed)` tripwire is EXACT, not slack — one bad user reverts the entire migration slice <!-- id: pns21l1 -->

**Location**: [`src/NFTStakerMigrator.sol`](../../../../lib/phoenix-nft-staking/src/NFTStakerMigrator.sol) — `_depositForAndForward`
**Also affects**: `src/InPlaceNFTStakerMigrator.sol:311-338` — verified **line-for-line identical this run** (plan decision D-6 held, no drift)
**Fingerprint**: `d0bb05398b68…`

**Description**: `_depositForAndForward` infers the forwarded amount from a balance delta and gates it on the exact bound `require(captured <= owed)`. Any inflow that makes one user's measured capture exceed `owed` reverts the whole `migrateIn` call.

The blast radius is **batch-wide, and per-user slicing does not route around it** — the offending `pull()` is positional. Executed in Tier-3 INV-4, `test_INV4_tripwireBlastRadius_oneBadUserKillsTheWholeSlice` (**PASS**): with a dispatcher hook whose `recipient` is mispointed at the migrator and which mints on its **3rd** `pull()`, `migrateIn(0,3)` reverts and `parkedUserCount() == 3` — not 1. Users 1 and 2 would have migrated perfectly; they are untouched but **stranded**, and `totalUnforwarded() == 0` (no partial escrow).

The converse direction of the same bound is also open (CODE-003): against a correctly-paying staker the expected capture is exactly **zero**, so any foreign inflow up to `owed` is silently **forwarded to a user** instead of tripping.

**Likelihood**: low. The tripwire held **0 trips / 128,000 fuzz calls** in normal operation (`g_tripwireTrips == 0`, `g_maxOverCapture == 0`, both campaigns). The unprivileged donation-griefing variant was explicitly **refuted** by the econ tier — no attacker-reachable inflow path into `depositFor` was demonstrated.

**Recommendation**:
- Give the tripwire slack, or convert the batch-wide revert into a per-user skip with an event, so one anomalous position cannot strand a whole slice.
- Better: source the forwarded amount rather than inferring it from a balance delta — that closes **both** directions of the bound with one change.
- Apply symmetrically to **both** migrators in the same change (D-6 parity — see Drift Watch).

**Note — merged cluster**: this covers both directions of one exact-equality bound (ECON-007 "too tight" and CODE-003 "too loose"). Recorded as one finding so a downstream reader does not split them and double-count. One bound, one fix.

**Ceiling**: rises to **Medium** the moment any attacker-reachable inflow path into `depositFor` is demonstrated — at that point it is unprivileged availability griefing of the migration. ⚠ Do not re-raise it without that path (the econ tier's explicit instruction, honoured here).

---

### [L-02] Unguarded `balance - totalUnforwarded` subtraction — **with a non-standard reward token** (moves-and-returns-`false`, or fee-on-transfer) it permanently bricks `rescueERC20` **and** `claimForwarded` with no administrative remedy; **not reachable against the pinned phUSD** <!-- id: pns21l2 -->

> **⚠ Read the precondition as part of the headline.** Both executed counterexamples require a
> **non-standard ERC-20** reward token. Against today's pinned reward token (phUSD — standard OZ,
> revert-on-failure, no fee) **neither is reachable**, and no live brick is being asserted. This is filed
> as a **conditional hardening item plus a Law-3 footgun**, not as a present defect. It is deliberately
> **not** suppressed under the C4 weird-token / fee-on-transfer known-invalid rule (see the Law-3 note
> below): the unguarded subtraction is a real defect with a one-line correct fix, and no weird-token
> *support* is being requested.

**Location**: [`src/NFTStakerMigrator.sol`](../../../../lib/phoenix-nft-staking/src/NFTStakerMigrator.sol) — `rescueERC20` / `claimForwarded`
**Also affects**: `src/InPlaceNFTStakerMigrator.sol:394` — identical
**Fingerprint**: `7af123b56a49…`

**Description**: `rescueERC20` computes `balance - totalUnforwarded` as an unguarded subtraction. Tier-3 **INV-2 (`rewardToken.balanceOf(migrator) >= totalUnforwarded`) is BROKEN**, with two independently executed counterexamples:

- **Counterexample A** — `test_INV2_BROKEN_movesAndReturnsFalse_bricksBothRecoveryPaths` (**PASS**). A reward token whose `transfer` *moves* the tokens and returns `false` creates a full escrow entry while the balance is gone:
  ```
  balanceOf(migrator) = 0
  totalUnforwarded    = 27,397.260273972602304e18   // == owed, credited in full
  ```
  `rescueERC20(rewardToken, owner, 1)` then reverts with **Panic 0x11 (arithmetic underflow), permanently**; `claimForwarded` reverts too; and a donation of `totalUnforwarded - 1` does **not** un-brick it.
- **Counterexample B** — a 5% sender-side fee-on-transfer reward token under-backs later escrow; shortfall `747.198e18`.

The second half of the same root cause (CODE-005): the forward leg tolerates a `false`-returning token via `try`/`catch`, but `claimForwarded` uses `safeTransfer` — so the very token behaviour that **creates** the escrow makes it **permanently unclaimable**. Aderyn `SAST-149`/`SAST-150` corroborate the deliberate raw `transfer` inside the try/catch that creates the asymmetry.

**Likelihood**: low. phUSD is a standard ERC20 (revert-on-failure, no fee), so **neither counterexample is reachable against today's reward token**. The fuzzer found no inversion over 128,000 calls × 2 seeds with a standard token.

**Law 3 — footgun (DS-06, upheld)**: the owner *added* the rescue path in story-023 **as** the remedy; the finding is that the remedy can itself be bricked by the accounting it is floored against, with no administrative fallback. A competent, non-malicious owner would be surprised. This is **not** a centralization finding and **not** a reckless-admin invalid.

**Recommendation**:
```solidity
// clamp instead of unguarded subtraction — apply to BOTH migrators
uint256 surplus = balance > totalUnforwarded ? balance - totalUnforwarded : 0;
```
Also make the escrow-**out** path tolerate exactly what the escrow-**in** path tolerates — the `safeTransfer` / raw-`transfer` asymmetry is the trap.

**Ledger notes**:
- The rescue function whose floor is the subject here is the very one that closes ledger `L-02` (`cb1b52790cf1…`). **Closing that ledger L-02 does not close this.**
- ⚠ **Do not collapse** with spec-conformance `F-21-02` (classified label; input `F-21-04`): same mechanism, **different fixes** — arithmetic clamp vs SafeERC20 adoption/documentation. Applying one leaves the other's gap.

**Escalate to Medium** only if the reward token is ever changed to a non-revert-on-failure or fee-charging token.

---

### [L-03] Migrator constructor cross-checks only `IStakerViews.rewardToken()`, never `pendingReward()` — a non-conforming staker deploys cleanly and fails mid-migration <!-- id: pns21l3 -->

**Location**: [`src/InPlaceNFTStakerMigrator.sol`](../../../../lib/phoenix-nft-staking/src/InPlaceNFTStakerMigrator.sol) — `constructor`
**Also affects**: `src/NFTStakerMigrator.sol:133` — same constructor shape
**Fingerprint**: `afa520008e32…`

**Description**: The constructor validates `IStakerViews.rewardToken()` against the migrator's own immutable reward token — **one** interface member. It never probes `pendingReward()`, on which the entire settlement-capture leg depends. A staker missing or mis-typing `pendingReward()` therefore **deploys cleanly**, and the failure surfaces mid-migration — *after* `initiateMigration` has flipped the pool to `Migrating` and frozen emissions, with users' ERC1155 already parked.

story-023's "version-agnostic across every staker exposing `depositFor`" claim is over-stated by exactly one unvalidated getter.

**Impact**: no direct loss. Positions are parked mid-migration behind the timeout hatch while emissions are frozen; recovery is via the hatch, so value is **delayed, not lost**.

**Likelihood**: low — requires deploying against a non-conforming staker, and all current stakers conform.

**Law 3 — footgun (DS-07, upheld)**: the constructor *does* cross-check one interface member, which reasonably signals to a competent deployer that conformance was validated. Being surprised mid-migration — at the worst possible moment — is the textbook footgun test.

**Recommendation**: probe `pendingReward()` (and any other member the forwarding leg depends on) in the constructor with a staticcall-and-decode check, so a non-conforming target fails at **deploy** time rather than mid-migration.

**Ledger note**: **adjacent to, not the same as** ledger `L-01` (`e7bccb029f77…`, immutable `stakedId` live-parity gap). Same constructor, different root-cause class, different fix. **Link, do not merge.**

---

### [L-04] The NatSpec honeypot dismissal is asserted as an invariant but enforced nowhere <!-- id: pns21l4 -->

**Location**: [`src/BatchNFTMinterMultiToken.sol:56-61`](../../../../lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol) — NatSpec; gate at `:352`, payout at `:452-461`
**Fingerprint**: `75305ec0242b…`

**Description**: The contract's NatSpec at `:56-61` dismisses the honeypot framing by asserting that *"the pot is by construction a fraction of the cost of the `nudgeSize` mints."* Nothing in the code establishes that relation:

- the gate at `:352` is purely numeric (`count >= nudgeSize`);
- the payout at `:452-461` is winner-take-all against a pre-loop `balanceOf` snapshot.

The asserted invariant is therefore an **off-chain funding-discipline property presented as a structural one**. It holds only while whoever funds the pot keeps it small relative to `nudgeSize × price`. At mainnet parameters today it *does* hold (94.95 USDC pot vs ~634 USDS to qualify) — which is precisely why the reopened `H-01` nudge lineage is not presently profitable.

**Impact**: none standalone. This is the **unenforced premise** beneath the value-blind nudge lineage: if the pot ever exceeds the cost of `nudgeSize` mints, farming the nudge becomes net-profitable. The value path itself is carried by the ledger `H-01` reopen (`858e9e80…`) and is deliberately **not** double-counted here.

**Recommendation**: either enforce the claimed relation on-chain (bound the payout by a function of `nudgeSize × price`), or strike the claim from the NatSpec and state plainly that pot sizing is an operational responsibility **with a named owner**. The second is cheap and honest; the first is what would let the `H-01` lineage be closed structurally rather than by configuration.

**Ledger note**: ⚠ **Do not collapse** with spec-conformance `F-21-04` (classified label; input `F-21-06` / ledger `F-20-07` `a7dffb34…`). The **same claim exists at two artifacts** — `src/BatchNFTMinterMultiToken.sol:56-61` (this finding, the code site) and `docs/multi-token-nudge.md:42-46` (the doc site). Collapsing loses whichever site is not chosen as canonical.

---

### [L-05] story-023's settlement-capture forwarding covers the `depositFor` leg only — `batchMigrate` is called with no snapshot <!-- id: pns21l5 -->

**Location**: [`src/NFTStakerMigrator.sol`](../../../../lib/phoenix-nft-staking/src/NFTStakerMigrator.sol) — `migrate`
**Fingerprint**: `3a5fcb333e04…`

**Description**: story-023 added a measure-and-forward snapshot around the `depositFor` leg. `batchMigrate` is invoked with **no such snapshot**. If the source staker settles pending reward to `msg.sender` during `batchMigrate`, the migrator receives it and nothing forwards it onward; it accumulates as surplus above `totalUnforwarded`, recoverable only by the owner's `rescueERC20` — i.e. the **pns20h1 shape reproduced on the sibling leg**.

**Impact**: the settled reward is **misdirected rather than destroyed**, but is not credited to the user who earned it.

**Likelihood**: low — no currently-shipped source staker was shown to settle to `msg.sender` on this leg.

⚠ **Scope caveat, stated plainly**: this is confirmed **not live today**. It is reported because story-023's stated "version-agnostic" protection is **broader than the protection actually shipped**, and the gap is on the leg with no compensating control.

**Recommendation**: apply the same measure-and-forward snapshot around the `batchMigrate` call, symmetrically on both migrators (D-6 parity).

**Ceiling**: rises to **Medium** if any source staker in a planned migration chain is shown to settle to `msg.sender` on `batchMigrate` — at that point it is the same class as run-20 `H-01` on a leg with no compensating control.

**Ledger note**: related in class to the `1c222d5485…` pns20h1 lineage, but on a **different leg with a different fix**; deliberately not reconciled into it.

---

## QA / Hardening Notes

### [Q-01] `migrate` consumes an externally-returned array without asserting `amounts.length == users.length` <!-- id: pns21q1 -->

**Location**: [`src/NFTStakerMigrator.sol`](../../../../lib/phoenix-nft-staking/src/NFTStakerMigrator.sol) — `migrate`
**Fingerprint**: `fb3fd4baacdf…`

**Description**: `migrate` takes an array returned by an external contract it trusts by construction, makes no `amounts.length == users.length` assertion, and then uses the two lengths interchangeably as loop bound and index.

**Impact**: none. A length mismatch produces an out-of-bounds revert (fail-closed) or, on a longer array, silently ignored trailing elements.

**Not suppressed as a "user input mistake"**: the array is **returned by an external contract** the migrator trusts by construction, not typed by a user. The C4 known-invalid class does not reach it.

**Recommendation**: add the explicit length-equality check so a drifting interface fails loudly at the boundary instead of silently mid-loop.

---

### [Q-02] Rename missed one identifier — cosmetic, recorded as a tripwire <!-- id: pns21q2 -->

**Location**: [`src/BatchNFTMinterMultiToken.sol`](../../../../lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol) — `onlyPauser`
**Fingerprint**: `cf882d8ff06e…`

**Description**: Cosmetic identifier staleness left behind by the story-022 Stage 7 rename. No attack path.

**Why it is here at all**: its value is as a **tripwire against a future misdiagnosis** — so a later reader does not misread the stale identifier as a wiring defect, i.e. as evidence that the wrong contract was invoked. It is not a defect.

**Recommendation**: complete the rename.

---

## Carryover — still-open Low/QA from prior runs

Reproduced **in full**, not as pointer stubs. These retain their **ledger** labels and mint **no** new run-21 label; they are deliberately kept out of this run's `L-nn`/`Q-nn` sequence so the sequence covers only new defects.

### [Ledger L-03 + Q-05] Read-only-reentrancy / CEI ordering on `unstake` — the outbound ERC1155 transfer precedes the tail `_recomputeSchedule`

**Applies to**: `src/NFTStaker.sol` **+ 3 clones** — `NFTStakerDepletion`, `NFTStakerPriceScaled`, `NFTStakerPriceScaledMigrateReady`.
**Fingerprint**: `d37ab4bb9bf2` (+ ledger `Q-05` `aabf6b89d2e1`) · **Ledger status**: `open` · **Severity at HEAD**: low — **unchanged** (the `Q-05` leg remains QA).

**Description**: `unstake` transfers the ERC1155 out; the recipient's acceptance hook can read the staker's views; the tail `_recomputeSchedule` has not yet run, so the observed rate/runway is **inflated**.

**Impact**: none demonstrated. No integrator consuming that view for value was identified.

**Not suppressed because**: the cached `designDecision` blesses **where the recompute sits relative to the `totalStaked` mutation**; this finding concerns the **outbound transfer sitting before it** — a different proposition (DS-03). Independently, the entries are `open`, and open entries are never suppressed.

**Ledger action (PLA-10)**: **extend** the clone coverage of the two existing entries to `NFTStakerDepletion.unstake` and `NFTStakerPriceScaled.unstake` rather than minting two low-value fingerprints.

---

### [Ledger L-02] Unbounded loops — self-DoS only

**Applies to**: **BOTH files, and widened on the new file.**
- Frozen deployed `src/BatchNFTMinter.sol:batchMint` — uncapped `count` loop (as originally filed).
- New `src/BatchNFTMinterMultiToken.sol:batchMint:363` — re-anchored, **plus two NEW unbounded loops the original entry did not cover**: the `rewardTokens` snapshot at `:424` and the payout at `:454`.

**Fingerprint**: `e35388bfa2b5` · **Ledger status**: `submitted` · **Severity at HEAD**: low — **unchanged**.

**Description**: `count`, the `rewardTokens` snapshot loop and the payout loop are unbounded. An over-large call runs out of gas and reverts. No other party is affected.

**Impact**: none. The caller can only exhaust their own gas.

**Ledger action**: `submitted` is **not** a disposal status — it is neither `acknowledged`, `wont-fix`, `false-positive` nor `fixed` — so it is treated exactly like `open` and is **not** suppressed. Record the scope widening.

---

### Carryover routed elsewhere — recorded so the omission is visible

- **Ledger `F-20-07`** (`a7dffb34…`, `open`, low, unchanged at HEAD) — *"the 'why the honeypot framing does not apply' claim is an off-chain funding-discipline property presented as a structural one."* This is a **Law-2 spec deviation** and is carried in the **spec-conformance report**, not here. It is the doc-site twin of [L-04] above; ⚠ **do not collapse the two** (re-anchor: `docs/multi-token-nudge.md:41` → `:42-46`, and add `src/BatchNFTMinterMultiToken.sol:56-61` as a second site).

### Carryover relocations affecting the frozen-vs-new split (Low/QA relevant)

| Ledger entry | Applies to | Note |
|---|---|---|
| `L-01` `9135cf7947c2` (`submitted`) | **FROZEN ONLY** | ⚠ **Non-relocation.** The **new** file fixed it (`ReentrancyGuard :82`, `nonReentrant :300`); the omission **stayed behind on the deployed file**. *This asymmetry is itself the finding* — recorded because a naive fingerprint reconciliation would read the new file's guard as "L-01 fixed". Filed at Medium this run as `M-02` (`c847207d…`), not here. |
| `L-03` `58b6c4860570` (`submitted`) | Frozen as filed | ⚠ **NEEDS RE-DERIVATION.** The new file **replaced** the conditional nudge-token equality guard with an unconditional `BatchMint__RewardTokenIsPaymentToken` exclusion (§4.1). **Do NOT auto-close as fixed and do NOT auto-carry** — no tier settled whether the change closes it or merely moves it (PLA-08). |
| `L-05` `990d8c37b457` (`wont-fix`) | **BOTH** | ⚠ **SUPPRESSION BOUNDARY.** The owner's acceptance was granted against the **narrower** design (owner pins ONE payout asset). On the sibling, any qualifying **caller** names **any** ERC20 the contract holds (FORK-PARITY §B4.1). **Do NOT auto-suppress the class on the sibling under the old triage.** Also §B4.2: `rescueERC20` degraded from *"the missing escape hatch"* (frozen `:173-180`) to *"not a reliable escape hatch … a race the owner will usually lose"* (sibling `:191-201`) — a reduction in owner recourse the prior triage did not contemplate. |
| `Q-03` `bfdb50105ed2` (`open`) | **NEW FILE ONLY** — verified: the frozen file at `c881a42` has no `_payRewards` and no `rewardTokens` | Pure relocation. See ⚠ MR-21-001 below. |
| `Q-02` `d0ed2cf440cf` (`open`) | **BOTH** | ⚠ **Premise expired** — Q-02's recorded premise *"the guard holds"* was true at run-20 and is **FALSE for the frozen file** at `c881a42`. |
| `Q-04` `47f2dc3addf7` (`open`) | **BOTH** — frozen `:308`, new `:384` | Straight relocation. |

**Also open, unresolved (`L-05` `990d8c37…` related)**: the front-end obligation to pass a non-zero, pot-based `minReward` for every nudge-qualifying batch has **never been verified by any run and has no identified owner**. It is load-bearing under the `H-01` reopen.

---

## Centralization Risk

**No centralization findings are reported for this run — and that is a deliberate suppression, recorded here so it is visible rather than silent.**

| Tool | Detector | Instances | Disposition |
|------|----------|-----------|-------------|
| Aderyn | `Centralization Risk` (low_issues) | **66** | Dropped under Law 3 |
| 4naly3er | `M-2 — Centralization Risk for trusted owners` | **74** | Dropped under Law 3 |

**Rationale (Law 3)**: the owner is assumed **non-malicious**. "A malicious owner could…" is not a finding a self-audit can act on — the owner is not their own adversary — so these instances are noise in this context. The counts are preserved so a future reader can see the suppression happened and re-derive it if the trust model ever changes.

⚠ **Non-obvious owner *footguns* are NOT in this bucket.** They are in scope and are filed at honest severity elsewhere in this report. This run produced two, both filed as Low with an explicit `law3.surpriseTest` record: **[L-02]** (the owner added `rescueERC20` *as* the remedy in story-023, and the remedy can itself be bricked by the accounting it is floored against — DS-06) and **[L-03]** (the constructor cross-checks one interface member, signalling a conformance validation it does not actually perform — DS-07).

---

## ⚠ Parked for human triage (2)

**These are not findings and not dismissals.** They are items the deduplicator declined to drop *and* declined to forward as clean findings. Nothing here was removed from the run. Source: `manual-review.json`.

### MR-21-001 — `invariant_fotFloor` BROKEN: our invariant encoded a floor semantic the contract explicitly disclaims

**Contract**: `src/BatchNFTMinterMultiToken.sol` — `_payRewards` / `minRewards`
**Severity**: **NOT ASSIGNED** — explicit human triage requested. **STAYS PARKED — not resolved here.**

> ### ⚠ CORRECTED FRAMING — the previous one was factually false
>
> This item was previously parked on the claim *"`minRewards` is documented as a floor on what `recipient` **RECEIVES**, but is enforced pre-transfer."* **That claim is false — the contract documents the exact opposite, in those words.** The corrected framing below is the only one on which this item may be presented.

**There is no documentation-versus-enforcement gap.** The code, the NatSpec and the docs all agree, at three artifacts:

- **`src/BatchNFTMinterMultiToken.sol:252-256`** — *"`minRewards` is a floor on the contract's pre-transfer balance, **not** on the amount `recipient` receives. For fee-on-transfer or rebasing tokens the delivered amount will be lower. Supplying such a token is at the caller's discretion."*
- **`src/BatchNFTMinterMultiToken.sol:280-291`** (`@param minRewards`) — floors *"this contract's pre-loop balance"*.
- **`docs/multi-token-nudge.md:176-195`** — §4.4 *"Fee-on-transfer / rebasing tokens — documented, not defended"*, recording the explicit design decision *"**do not defend against this in code**"*, with the gas rationale and the mitigation *"the official UI will not list known fee-on-transfer tokens."*

**What `invariant_fotFloor` actually caught is a defect in the INVARIANT's premise, not a contract defect.** Our harness asserted a **delivered-amount** floor that the contract explicitly documents it does not provide. The invariant is **BROKEN and reproducing across cold corpora** (`delivered = 95.0e18` vs declared floor `100.0e18`) — but the "declared floor" it measures against is the harness's semantic, not the contract's.

**The triage question, restated correctly**: once the false premise is stripped, what remains is a **documented, intentional non-defence** against an asset class the protocol does not use. Does that intentional non-defence deserve more than the QA note already carried at ledger `Q-03` (`bfdb5010…`, `open` — *"minRewards floors the contract's pre-transfer balance, not the delivered amount"*)? **That decision is left to the human and is not taken here.**

**Argument each way** (preserved without a side being taken):
- **Stays QA** — run-20 D-19 reasoned this both ways and landed on QA: the caller chooses **both** the token and the recipient, the fee accrues to the token's own sink, and there is no path where A's token choice costs an unrelated B. The non-defence is documented, deliberate, and already carried at `Q-03`.
- **Promotes** — a documented non-defence is still a non-defence, and the decision was recorded against a narrower surface than HEAD ships. The one fact that would settle it upward is a **non-FoT delivery route to the same gap** — none was demonstrated this run. ⚠ This is a materially **weaker** promotion argument than the one previously recorded here, which rested on the now-falsified doc-versus-code gap.

**Also fix the invariant** (independent of the triage decision): re-state `invariant_fotFloor` against the semantic the contract actually declares — a pre-transfer *balance* floor — or retire it. A harness asserting a guarantee the code disclaims will report BROKEN forever without ever meaning anything.

**⚠ `doNotDo` — carried verbatim**:
1. **Do NOT** suppress under the known-invalid fee-on-transfer rule — the FoT token is the **delivery vehicle**, not the finding.
2. **Do NOT** auto-close into `Q-03` without deciding the promotion question.
3. **Do NOT** re-frame as an FoT-support request.
4. **Do NOT** dismiss it *as* one either. ⚠ The framing correction above narrows this item; it does **not** resolve it. No FoT support is being requested, and the corrected premise is not grounds for closing it by fiat — the promotion question is still open and still belongs to a human.

**Why no severity was assigned**: two agents (poc-replay §4.4, tier3 §4) refused to close it in either direction and both asked for human triage; the deduplicator recorded it in the `doNotCollapseRegister` specifically against the fee-on-transfer suppression. Assigning a severity would settle by fiat a question three tiers deliberately left open.

**Non-binding sanitizer view, recorded for the triager**: ledger `Q-03` may already dispose of this. That view is **not** treated as dispositive here, precisely because two agents declined to close it.

### MR-21-002 — `rewardTokens` are caller-supplied addresses this contract CALLS TWICE

**Contract**: `src/BatchNFTMinterMultiToken.sol` — `batchMint` / `_snapshotRewards` / `_payRewards` (`balanceOf` at `:429`, `safeTransfer` at `:458`)
**Severity**: **NOT ASSIGNED** — parked behind MR-21-001.

**What is refuted (completely and correctly, from source, by two agents)**: the **reentrancy** framing. `balanceOf` is a `STATICCALL` running before any pull and before the max approval; `safeTransfer` runs after the approval is revoked at `:368`; and `nonReentrant` at `:300` blocks re-entry into `batchMint` on this file.

**What survives**: the arbitrary-code **surface** itself, which is the delivery mechanism for MR-21-001 and shares a trust boundary with the reopened ledger `H-01` at value-extraction severity. Suppressing the surface on the strength of a refutation of a **different** framing would discard the premise of two live items.

**Disposition**: parked until MR-21-001 is triaged. If MR-21-001 closes, this can close with it.

---

## TOOL GAPS — record, never read as clean

⚠ **A missing or vacuous tool result is not a verified-clean result.** None of the following may be cited as assurance.

### TG-1 — Medusa: ran at scale, but the campaign was VACUOUS. **Zero evidential weight.**

`medusa fuzz --config medusa.json` completed **100,085 calls / 577 sequences** and reported **"22 test(s) passed, 0 failed"**. **That result carries no evidence and must not be cited.**

Medusa does not drive Foundry's `targetContract` / `targetSelector` handler machinery — it fuzzes the *target contract's own* external functions. The LCOV report (`medusa-corpus/coverage/lcov.info`) confirms **not one `ForwardingHandler` function was ever called**: no `doMigrateInOne`, no `stakeDirect`, no `doInitiate`, no `unblockAndClaim`. Every one of those 100,085 calls **re-evaluated the invariants against the frozen post-`setUp` state** — i.e. the harness proved `0 == 0`, 22 times, 100,085 times over. Retried with `testing.testAllContracts: true`; the handler was still never reached.

This is the recorded **vacuous-invariant-harness** failure mode recurring.

**Required before any future run cites Medusa as corroboration**: fix the harness wiring — seed guarded state and add an **abort-on-empty tripwire**. Driving the migrator under Medusa needs a purpose-built constructor-argument-free harness; not built this run.

### TG-2 — Semgrep: 0 security findings for the **third consecutive run**. Vacuous.

All **206** hits are `INFO`-severity style rules (verified: `Counter({'INFO': 206})` over `semgrep-output.json`). Semgrep has **no Solidity security ruleset** in this pipeline, so its silence is **not** an all-clear and carries **zero** evidential weight. Three consecutive vacuous runs is itself the signal: this tool is currently contributing nothing to the security case.

### TG-3 — Echidna: **not installed** (`which echidna` → not found). Not run.

**Consequence of TG-1 + TG-3 together**: the Foundry campaign is the **only** stateful-fuzzing evidence in this run.

### TG-4 — Halmos: one path truncated — **unexplored, not proven**; and the harness is a transcription.

- `check_noOverPay_threeTokens_withDonation` was **truncated by a loop-unrolling bound of 2**. An unexplored path carries **zero weight in either direction** — a truncation is **not** a proof.
- `NudgeHarness` is a hand **TRANSCRIPTION** of the contract, not an import. A mock-inlined harness proves a property of the **mock**, not of the code under audit. All its counterexamples are **corroborating only**, and `SymbolicNudgeBound`'s two `PROVEN` results are subject to the same caveat — **they must not be cited as proofs about `src/`.**

**Nothing is lost**: the same defect **is** authoritatively proven against real source in `CLASS-21-017` (ledger `M-02` `a62fe01a…`) via `PoC_DuplicateRewardWithDonations` and `invariant_nudgeSolvency`.

### Coverage gaps — one carried, one discharged

- **CARRIED (genuine).** `src/NFTStakerPriceScaledMigrateReady.sol` was **NOT re-read this run** for the `DEDUP-21-008` tail-recompute line — the clone-drift watch is **UNPAID** on that file.
- ~~Run-21 `M-02` (`c847207d…`) owes a PoC against the **real** `NFTMinterV2` acceptance path.~~ **DISCHARGED** — see below. (A stale gap list carried this forward; it is resolved.)

**Discharged this run — run-21 `M-02` (`c847207d…`) real-`NFTMinterV2` PoC debt.** Evidence in `poc-replay.md` §9 / §9.1:

- `workspace/phoenix-nft-staking/test/PoC_DeployedMinterReentrancy.t.sol` — **10/10 PASS**, in-suite (solc 0.8.20), driving the **genuine OpenZeppelin `ERC1155Utils.checkOnERC1155Received`** — the exact function the real `ERC1155` calls, same `operator = msg.sender` / `from = address(0)` arguments, imported from `lib/immutable/openzeppelin-contracts` and not re-implemented — via the statement-for-statement port `test/poc/FaithfulNFTMinterV2.sol`.
- `workspace/phoenix-nft-staking/pocs/PoC_DeployedMinterReentrancy_RealMinter.t.sol` — **5/5 PASS** against the **real, unmodified `NFTMinterV2`** (`lib/mutable/yield-claim-nft/src/NFTMinterV2.sol`, imported through the project's own `yield-claim-nft/` remapping) wired to a real `ATokenDispatcherV2`. Nothing is simulated: `_executeMint:196` → OZ `ERC1155._updateWithAcceptanceCheck` → `ERC1155Utils.checkOnERC1155Received` → `recipient.onERC1155Received`; `test_Real_HookFiresOncePerMint` measures **3 hook invocations for a 3-mint batch**.
- It lives in `pocs/` rather than `test/` **for one reason only**: `foundry.toml` pins `solc = "0.8.20"` while OZ `ERC1155.sol` requires `^0.8.24` (and `Bytes.sol` needs cancun `mcopy`), so importing it into `test/` would break compilation of the whole 508-test suite. `FOUNDRY_TEST=pocs` keeps the default `forge test` byte-for-byte unaffected.
- **No harness artefact is doing the work**: the two harnesses produce **identical literals** on every shared assertion — 13_590_000 swept, 4 NFTs, 46_410_000 to the dispatcher, 25_000_000 NDG double-paid, and the same `ERC20InsufficientAllowance(minter, 0, 12_100_000)` on the early-fire control.

⚠ **This does NOT discharge ledger `Q-01` (`cabd4a3d…`), which stays OPEN as a *test-suite* defect.** The two are separate propositions and must not be conflated:

| | Proposition | Status |
|---|---|---|
| **The audit's** evidence for run-21 `M-02` | Did *our* PoC reach the real acceptance-check mechanism? | **DISCHARGED** — yes, on both harnesses above. |
| Ledger `Q-01` (`cabd4a3d…`) | Does *the project's own* suite reach it? | **OPEN, unchanged.** |

`test/mocks/MockERC1155.mint()` still writes the balance, emits `TransferSingle`, and returns — it **never** performs `_checkOnERC1155Received`. Any reentrancy verdict reached on that stack would be a **vacuous witness**. This is now pinned as an *executable fact* by `test_Q01_MockERC1155_IsVacuous_NeverFiresTheHook` (**PASS**): after a `MockERC1155.mint()`, the probe recipient's balance is credited **1** and its acceptance-hook counter is **exactly 0**. Per `poc-replay.md` §9.9, `Q-01` is discharged **as an audit-harness concern only** — nothing in the shipped suite was changed, and the project's own mocks remain vacuous.

---

## Operational Notes

**Not findings. No label, no severity.** Recorded here because they are live operational instructions that otherwise appear only inside an evidence file.

### OP-1 — ⚠ `0x4ef0fDe4…` and `0xD3104A6e…` are inert honeypots — do not route funds to them

Source: `mainnet-verification-ECON-001.md` §8 (chainid 1, block 25577241, read-only). **No finding is filed and none is requested** — the instruction is the deliverable.

- `0x4ef0fDe49360ed31c68ED442Ff263CC6291041f3` and `0xD3104A6e6D53b37061856fe1f31296D8962f9e01` **still have code** and **still expose the legacy caller-parameter `batchMint` (`0xf466eb7c`)** — the signature whose caller-supplied `paymentToken` the project's own incident doc (`lib/phoenix-phase-2-staging/docs/batch-nft-minter-nudge-drain-fix.md`) identifies as an alternative drain line: *"a caller can pass `paymentToken = USDC` and the end-of-batch dust sweep hands the whole USDC balance to any caller."*
- Both currently hold **0 of every token probed** (USDC, USDS, PhUSD, sUSDS, Flax, AutoUSDC, ETH), and `0x4ef0fDe4…` has its nudge disabled (`nudgePaymentToken == 0`, `nudgeSize == 0`, applied by `DisableNudgeAndDivertDonations` at blocks 25196736–25196740, all receipts `0x1`).
- **Consequence: any ERC20 that ever lands on either address is stealable by anyone.** `0x4ef0fDe4…` has already been drained once on this line — **61.297674 USDC in 14 blocks** (same incident doc).

**Action**: do not route funds to these addresses; treat any accidental transfer to them as lost; and if a new drain line is ever needed to be closed, prefer decommissioning them outright over relying on their being empty.

### OP-2 — ⚠ The mainnet deployment records are STALE and assert the OPPOSITE of the truth

Source: `mainnet-verification-M-03.md` §1.1 (chainid 1, block 25577673, read-only). **No finding is filed and none is requested** — but this is an *audit-process* hazard, not a typo, and it is recorded as an **unpaid records-hygiene item**.

- `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts:96-98` still lists `UniboostStakerEYE` / `UniboostStakerSCX` / `UniboostStakerFLX` as `0x0000000000000000000000000000000000000000`, under a comment at `:76-80` reading *"These are **NOT yet deployed on mainnet** — zero-address placeholders … Patch by hand when they ship."*
- **They have shipped.** All three are live, `poolState == Active`, and hold staked user value: `0x66989bb99c1569bf2540f3bB16975801df05864B` (EYE, 2 units / 4.94 phUSD), `0x39e85E62d0Ccb83fb87fb525aA259F8f79A70637` (SCX, 117 / 582.77), `0x6E8cA0E37AadF35Df19F5064f279d9CC96a3403b` (FLX, 13 / 55.01). Deployed by the operator EOA at blocks 25490911 / 25490919 / 25490928.
- `server/deployments/progress.uniboost-cutover.1.json` (written by `DeployMainnetUniboostCutover.s.sol:157`) **does not exist** in the repo, and neither does `broadcast/DeployMainnetUniboostCutover.s.sol/`. The `uniboost-cutover:broadcast` chain ends in `node scripts/patch-mainnet-addresses-uniboost-cutover.js`; **that post-broadcast patch step never landed in the audited commit.**
- The only `UniboostStaker*` addresses anywhere in the tree are the **anvil 31337 mocks** in `progress.31337.json` / `local-addresses.ts` — which must never be used for mainnet reasoning.

**Why this matters beyond hygiene.** This run's `M-03` reasoning turns on the state of these three contracts. It could only be settled by resolving them **from chain** — `NFTMinterV2.configs(1/2/3)` → `targetPool` → `hook.recipient()`, closed in both directions via `hook.dispatcher()` — because the repo's own records would have produced the **wrong answer**: *"not deployed, so the finding is hypothetical."* Any future audit run, or any operator, trusting `mainnet-addresses.ts` would conclude these stakers do not exist while they hold user funds.

**Action**: run the patch step (or hand-patch `mainnet-addresses.ts:96-98`) and commit the progress/broadcast artifacts. Until then, treat `mainnet-addresses.ts` as **non-authoritative for the Uniboost cutover** and resolve staker addresses from chain.

---

## Housekeeping

### HK-1 — `PoC_Drift01_MigratorSidePatch::testE2_HOLE_*` / `testG_HOLE_*` are MOOT — relabel as reference-only

**Location**: workspace test assets, `test/patched/`
**Severity**: none assigned — assigning one would overstate a housekeeping item.

These tests **still PASS**, but they construct `PatchedNFTStakerMigrator` from **run-20's own superseded patch proposal** in `test/patched/` — **not** from shipped `src/`. Upstream shipped a different and stronger design that closes both holes.

**Action**: retire or relabel as **reference-only**, so a future run does not misread a passing `*_HOLE_*` test as a live finding against `c881a42`.

**Why this is recorded rather than dropped (DS-10)**: the `test/` `outOfScope` glob (read narrowly per run-20 D-32) excludes *hunting for vulnerabilities inside test code*. This is neither — it is a tripwire preventing a **future misreading**, and the reversal cost is asymmetric in the safe direction.

---

## Drift Watch

### SAST-ESC-3 — the story-023 forwarding sequence is duplicated VERBATIM across both migrators

**Location**: `src/NFTStakerMigrator.sol:214-241` / `src/InPlaceNFTStakerMigrator.sol:311-338`
**Status at `c881a42`**: **parity HELD** — confirmed line-for-line identical this run (plan decision D-6). **Not a finding today.**

**Why it is kept visible**: ledger `L-07` (`368e23fb…`) records that the fork-drift hazard on **this project has already materialised once** (run-20 D-14 — and again this run as `M-02` / `c847207d…`, where a `ReentrancyGuard` landed on the new file and not the deployed one). Any future fix applied to one copy and not mirrored **re-creates the pns20h1 class**.

**⚠ Actions**:
1. The **next run MUST diff both forwarding bodies line-for-line.**
2. Any fix arising from **[L-01]**, **[L-02]** or **[L-05]** must land on **BOTH** files in the **SAME** change.

---

## Appendix A — Automated report (4naly3er)

**Status: RAN CLEAN.** All **11** first-party `src/*.sol` files compiled and analyzed; **0** import-resolution failures.

Full output: [`4naly3er-report.md`](./4naly3er-report.md)

> Tooling note for future runs: 4naly3er takes `<basePath> <scopeFile.txt>` — the second argument is a **scope list of `.sol` paths**, *not* a remappings file, and passing remappings there fails with `Error: Scope is empty`. It resolves `remappings.txt` **relative to `basePath`**, so pointing `basePath` at the submodule root works directly and the absolute-path/symlink staging workaround is unnecessary for this project. `lib/` was not modified.

### Medium

| | Issue | Instances |
|-|:-|:-:|
| M-1 | Contracts are vulnerable to fee-on-transfer accounting-related issues | 6 |
| M-2 | Centralization Risk for trusted owners | 74 |
| M-3 | Return values of `transfer()`/`transferFrom()` not checked | 2 |
| M-4 | Unsafe use of `transfer()`/`transferFrom()` with `IERC20` | 2 |

⚠ **Read these as tool output, not as audit findings.** M-2 is suppressed under Law 3 (see §Centralization). M-3/M-4 are the raw `transfer` inside the story-023 try/catch — the deliberate construct whose consequence is analysed at **[L-02]**, where it is filed at honest severity rather than at the tool's label. M-1 overlaps the **MR-21-001** parked item and must **not** be used to close it.

### Low

| | Issue | Instances |
|-|:-|:-:|
| L-1 | Use a 2-step ownership transfer pattern | 7 |
| L-2 | Some tokens may revert when zero value transfers are made | 26 |
| L-3 | Missing checks for `address(0)` when assigning values to address state variables | 9 |
| L-4 | Division by zero not prevented | 16 |
| L-5 | Owner can renounce while system is paused | 6 |
| L-6 | Possible rounding issue | 8 |
| L-7 | Loss of precision | 51 |
| L-8 | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 8 |
| L-9 | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 8 |
| L-10 | Sweeping may break accounting if tokens with multiple addresses are used | 8 |
| L-11 | Unsafe ERC20 operation(s) | 2 |
| L-12 | A year is not always 365 days | 4 |

### Non-Critical — 22 categories, 536 instances

Full table in the appendix file. Per C4 convention non-critical issues are not promoted into the body of this report.

### Gas Optimizations — 14 categories, 783 instances

Full table in the appendix file.

⚠ These bot tables are an **automated baseline**, not a reviewed finding set. Nothing in them was promoted to Low or QA in this report without independent derivation, and no item in this report is downgraded on the strength of the bot's silence.
