# Validity Check — phoenix-nft-staking, run 21

**Project:** `phoenix-nft-staking`
**HEAD audited:** `c881a428c87ef4ef42ba07a71be5d49101c9006d`
**Run dir:** `reports/phoenix-nft-staking/21/`
**Checked by:** validity-checker (adversarial pass — every finding was attacked before it was passed)
**Method:** each submission read in full and re-derived against `lib/phoenix-nft-staking/` source at
`c881a42`, against `classified-findings.json`, `dedup-results.json` (`doNotCollapseRegister`),
`manual-review.json`, `findings/LABEL-MAP.json` and `mainnet-verification-ECON-001.md`.

---

## Verdict summary

| Verdict | Count |
|---|---|
| **VALID** | 17 |
| **QUESTIONABLE** (keep, but reframe / re-weigh before submission) | 4 |
| **INVALID** (pull) | 0 |
| **MUST REFRAME BEFORE SUBMISSION** (blocking) | 1 (`MR-21-001`) |

Nothing is recommended for deletion. One parked item carries a **factually false premise** that must be
corrected before the pack leaves the building, and three security-stream items carry sentences that
overstate what the evidence supports. Details below.

---

## ⚠ PULL-OR-REFRAME LIST (read this first)

1. **`MR-21-001` — BLOCKING. Its one-sentence framing is falsified by the source.** The parked framing
   reads *"`minRewards` is documented as a floor on what the recipient RECEIVES but is enforced
   pre-transfer."* The contract documents the **exact opposite**, in those words, at
   `src/BatchNFTMinterMultiToken.sol:252-256` — *"`minRewards` is a floor on the contract's pre-transfer
   balance, **not** on the amount `recipient` receives. For fee-on-transfer or rebasing tokens the
   delivered amount will be lower. Supplying such a token is at the caller's discretion."* — and
   `docs/multi-token-nudge.md:176-195` records it as an **explicit design decision** (*"Fee-on-transfer /
   rebasing tokens — documented, not defended"*, with the cost rationale and the UI mitigation). There is
   no documentation-versus-enforcement gap: the docs, the NatSpec and the code all agree. **Item stays
   parked** (per instruction and per two agents' refusal to close it), but the framing sentence must be
   rewritten before submission or a reader with the source open dismantles it in one paste.
2. **`M-01` — remove or qualify the sentence "No historical loss has occurred via this path."** It is an
   unprovable negative drawn from **six spot-block reads**, and the evidence file itself concedes this
   (`mainnet-verification-ECON-001.md` §9: *"not a full log scan … supports 'durably zero', not a proof
   that it was never non-zero for a single block"*). Worse, a **sibling line of this same contract family
   WAS drained** — 61.297674 USDC out of `0x4ef0fDe4…` on 2026-05-28 — which M-01 cites two paragraphs
   later as an aggravating factor. As written the report both asserts no loss ever happened and cites the
   loss that happened. Replace with: *"no loss via this path was observed across six sampled blocks; this
   is sampling, not a log scan."*
3. **`M-02` — add the self-service nudge variant; it removes the finding's single weakest dependency.**
   The nudge double-payment leg does **not** require a victim to name the attacker as `recipient`. An
   attacker contract can be **both caller and recipient**: it calls `batchMint(count = nudgeSize,
   recipient = itself, …)`, re-enters from its own acceptance hook with `paymentAmount = 0` (funded by its
   own in-flight balance, per M-01's mechanic), qualifies a second time and collects the **prior pot plus
   the outer batch's donations**, then the outer frame pays the snapshotted pot again. Third-party value
   (the forward-donation pool) moves, with **no third-party integration and no victim naming anyone**.
   This is the answer to the "so what" objection the finding is most exposed to, and it is currently
   absent. (It does not change the Medium: at live parameters — 94.95 USDC pot vs ~634 USDS to qualify —
   the doubled payout is still loss-making.)
4. **`M-02` — "This path requires **no pre-funding whatsoever**" is overstated.** True for the caller's-
   surplus leg. **False for the nudge leg**, which is the very leg the report uses to escape the
   *"loss confined to the caller's own surplus"* bound — that leg needs a funded pot. Qualify the sentence
   so the third-party-value claim and the no-pre-funding claim stop contradicting each other.
5. **Submission-completeness gap (not a validity defect, but it will be noticed).** Two **open ledger
   Mediums** re-derived this run with **new executed evidence** have no reproduced write-up anywhere in
   `submissions/` — they exist only as passing cross-references and inside `classified-findings.json`:
   - `a62fe01a…` (ledger `M-02`, duplicate `rewardTokens` pay the snapshot k times) — **upgraded this run
     from reasoning to executed counterexamples** (`paid = 30,000,000` vs `prePot = 15,000,000`, two cold
     corpora, `invariant_nudgeSolvency` + `invariant_nudgeNoSelfFund` BROKEN);
   - `58bd104c…` (ledger `M-03`, `depositFor` tail `_recomputeSchedule` rate drift).

   The QA report reproduces still-open carryover **Lows** in full and explains why; the carryover
   **Mediums** get less. Add a "Carryover — still-open Medium" section or two stub docs.
6. **Operational hazard buried in an evidence file.** `mainnet-verification-ECON-001.md` §8 records that
   `0x4ef0fDe4…` and `0xD3104A6e…` remain live with the legacy caller-parameter `batchMint`, i.e. *"inert
   honeypots: any ERC20 that ever lands on them is stealable by anyone"* — and explicitly files no
   finding. That is a live operational instruction (*do not route funds to these addresses*) that appears
   in **no** submission document. Surface it as an operational note in the QA report.

---

## Per-finding verdicts

### `M-01` — `paymentAmount = 0` free-mint + whole-balance sweep — **VALID** (Medium held)

Re-derived in source: `src/BatchNFTMinter.sol` `batchMint` has no lower bound on `paymentAmount`, calls
`forceApprove(nftMinter, type(uint256).max)` (not `paymentAmount`), mints from the **contract's** balance,
and sweeps `balanceOf(this)` to `msg.sender` gated only by `DUST_THRESHOLD`. Confirmed at `:283-284` and
`:305-308`. `totalPaid`'s floor-at-zero is present as described.

Known-invalid sweep: **not** a weird-token issue (works on plain USDC/USDS), **not** fee-on-transfer,
**not** an approve race, **not** a user input mistake (the attacker is the caller and supplies a legal
value), **not** an admin issue (fully unprivileged), **not** speculation (root cause is present code,
byte-equivalent on the deployed file), **not** an automated-tool finding (composition of three legs, PoC
11/11). In scope: first-party `src/`.

Law 3 handled correctly. The re-arm trigger (c) — repointing `NudgeRatchet.batchMinter()` onto the
instance whose payment token is USDC — is a **non-obvious footgun**, not a malicious-owner vector, and the
report says so explicitly and does not file it as an attack.

Severity: Medium is defensible and the report's reasoning for it is the right one (asset fact, not a
deployment fact; run-20 R-6 respected). A triager may push back that with `R = 0` and no inflow route the
present impact is nil → Low. The report pre-empts this and the pre-emption is honest. Held.

**Flags:** items 2 and 6 in the pull-or-reframe list. Also soften "The zero is **durable**" — the source
document only supports "durably zero across six samples".

### `M-02` — missing `ReentrancyGuard` on the frozen deployed minter — **VALID** (Medium held), with the reframe at item 3

**Independent verdict on the "user input mistake" question, as asked.**

*Not* a C4 user-input-mistake / phishing invalid. Three grounds, in descending strength:

1. **The self-service path exists and needs no victim at all** (item 3 above). On the nudge leg the
   attacker is caller *and* recipient, and the value taken belongs to the forward-donation pool. A finding
   with a no-victim-required variant cannot be dismissed as victim error. **This is the ground the report
   should lead with and currently does not raise.**
2. **The remaining (caller-funds-a-third-party) leg is a gift/relayer shape, not a typo.** The C4
   known-invalid targets a user entering *wrong* data — a mistyped address, a spoofed destination. Here
   the payer supplies **exactly the address they meant**; the beneficiary is the intended one and then
   steals the payer's surplus. `recipient` is a first-class parameter, `recipient != msg.sender` is
   exercised by the project's own tests, and the ERC-1155 acceptance hook exists precisely so contracts
   can be recipients.
3. **The harm is undetectable after the fact.** The transaction succeeds, no event fires, and `totalPaid`
   returns the full `paymentAmount`. Diligence cannot save the victim, so the failure is not the victim's.
   Independently, the contract's own NatSpec at `:217-220` **instructs callers to over-fund** (*"Must cover
   the dispatcher's cumulative cost … Surplus >= DUST_THRESHOLD is refunded"*) — verified in source. The
   surplus that gets stolen exists because the contract told the caller to create it.

Everything else checks: guard genuinely absent on the deployed file (`:243`, no `nonReentrant`; the twin
has it at `:300`), two independent harnesses incl. the real unmodified `NFTMinterV2`, mock vacuity pinned
as an executable fact, controls isolate the guard as root cause. Not a parent/forked-contract issue — the
file is first-party `src/`.

Severity: Medium, held on operational reachability. With the item-3 self-service variant added, the
"unproven operationally" caveat applies only to the caller's-surplus leg, and the finding gets materially
harder to argue down.

**Flags:** items 3 and 4.

### `M-03` — `NFTStakerDepletion.sol:756` `_safePay(pending)` live in the deployment template — **VALID** (Medium at the Medium/Low boundary)

Verified in source: `:756` is `pending = _safePay(pending);` with `emit Claimed(user, pending)` following;
`setMigrator` (`:750-753` at HEAD) does zero validation as described; and
`lib/phoenix-phase-2-staging/script/DeployMainnetUniboostCutover.s.sol:478` does
`new NFTStakerDepletion(` today. So this is **not** "speculation on future code without a demonstrated
root cause" — the root cause is present, in a file a live mainnet cutover script deploys from.

Law 3: a maintainer deploying from a file whose compensating control lives in a different contract, with
no banner, is **surprised** ⇒ footgun ⇒ in scope. Correctly not filed as a malicious-owner vector.

Severity note (honest): Medium rests entirely on a *latent* configuration — the three new stakers have
`migrator == address(0)`, both shipped migrators forward, so nothing is reachable today. The report states
this plainly in "Present reachability, stated honestly", which is what keeps it out of the overstatement
bucket. A triager could reasonably land it at Low. No change requested; the reasoning is exposed.

### `REOPEN-ledger-H-01-858e9e80` (value-blind nudge gate) — **VALID** as a ledger reopen

Regression-framing check, as asked: **passes**. The record states three times that no patch was reverted,
names story-014's owner-pinning as **intact and proven intact at HEAD** (negative control
`test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED`, PASS), and explicitly instructs the reader
**not** to send a fixer to restore a working guard. It carries no `M-nn` label, so the defect is not
double-counted.

Present-exposure check: **passes**. *"The mechanic is proven in code. Present drainability is NOT
claimed."* The real 94.95 USDC pot is correctly identified as the **nudge** token reachable only through
its intended `nudgeSize = 40` gate at ~634 USDS — i.e. loss-making, *"the designed bounty operating as
intended, not a drain."* Describing it as sweepable would have been the factual error, and the report
refuses to make it.

Law-3 check: the reopen's basis — that the closure's *"owner-driven only, therefore invalid"* premise died
when `rewardTokens` became **caller-supplied** — is correct and is the right way to unwind an
owner-trust-based dismissal. This is not an owner-driven finding; it is unprivileged.

### `REOPEN-ledger-M-01-521c20ad` (MEV race for the pot) — **VALID** as a ledger reopen

Same regression-framing pass: *"No patch was reverted, and no path got worse … There is no intact guard
for anyone to 'restore'."* Same present-exposure discipline (*"present profitability is NOT asserted"*).

It also discharges the **disclose-when-re-filing** obligation properly: the owner-signed 2026-06-09 triage
is quoted verbatim, the specific falsifying fact is named (the contract's own `:288-291` NatSpec says the
floor *"does NOT stop a front-runner from winning the pot"*), and the coupled 2026-05-30 `L-05` `wont-fix`
is explicitly **not** overridden. The `minReward` floor is credited for the work it genuinely does
(*"narrower than 'fully closed', not absent"*) rather than dismissed.

Not collapsed with `858e9e80…` — gate vs race — per the register.

### `FIXPENDING-ledger-H-01-1c222d5485` — **VALID**

Reads exactly as required: **"the fix is good; the closure is not earned."** story-023's migrator-side
capture-and-forward is credited in detail, traced rather than taken on the NatSpec's word, and shown to be
**stronger than the audit's own run-20 proposal in five respects**. The three inverted PoCs are presented
as good news. The proposal is **KEEP `fix-pending`** — the entry is never presented as closed, and the
`fix-pending` ≠ `acknowledged` distinction is respected. The superseded `*_HOLE_*` tests are correctly
quarantined as reference-only so a future run cannot misread their PASS.

### QA bundle

| Item | Verdict | Note |
|---|---|---|
| `L-01` tripwire is exact, not slack | **VALID** | Executed (INV-4). Ceiling honestly gated on an attacker-reachable inflow that was **refuted**; the instruction not to re-raise without it is carried. Deliberate merge of ECON-007 + CODE-003 is recorded in the register, not silent. |
| `L-02` `totalUnforwarded` desync bricks rescue + claim | **QUESTIONABLE — keep, reframe** | Both counterexamples require a **non-standard ERC-20** (moves-and-returns-`false`; 5% fee-on-transfer). Against the pinned reward token (phUSD, standard OZ) **neither is reachable**, and the report says so. This sits closest of anything in the pack to the C4 weird-token/FoT known-invalid. Keep it — the defensive clamp is cheap and the Law-3 footgun framing (the owner added `rescueERC20` *as* the remedy and the remedy can be bricked by its own floor) is sound — but retitle so the headline reads as a **conditional hardening item**, not a live brick. As written the title asserts a brick with "no administrative remedy" that cannot occur with today's token. |
| `L-03` constructor probes `rewardToken()` not `pendingReward()` | **VALID** (thin) | Deploy-time footgun, no loss, value delayed not lost. Borderline QA; Low is acceptable. |
| `L-04` NatSpec honeypot dismissal unenforced | **VALID**, but **QA-shaped** | Self-declared *"Impact: none standalone"*, with the value path deliberately routed to the `858e9e80…` reopen to avoid double-counting. That is the correct handling — but a finding with no standalone impact is a QA item. Consider demoting; do **not** collapse with ledger `F-20-07` (different artifact). |
| `L-05` forwarding covers `depositFor` only, not `batchMigrate` | **VALID with caveat** | Not "speculation on future code": the asymmetry is present in shipped code and story-023's own *"version-agnostic"* claim is broader than what shipped. The *"confirmed not live today"* caveat is stated up front. Low is right. |
| `Q-01` `migrate` doesn't assert `amounts.length == users.length` | **VALID** (QA) | Correctly pre-empts the user-input-mistake class: the array is **returned by a trusted external contract**, not typed by a user. Impact nil, fail-closed. |
| `Q-02` stale `onlyPauser` identifier | **VALID** (QA, near-noise) | Justified as a tripwire against a future misdiagnosis rather than as a defect. Acceptable; do not promote. |
| Carryover ledger `L-03`+`Q-05`, ledger `L-02` | **VALID** | Reproduced in full, suppression boundaries stated, `submitted` correctly treated as non-disposal. |
| Centralization: 66 Aderyn + 74 4naly3er instances dropped | **CORRECT under Law 3** | Suppression is **recorded with counts**, not silent, and the *"non-obvious footguns are NOT in this bucket"* carve-out is stated and honoured (`L-02`, `L-03` carry explicit `law3.surpriseTest` records). |
| Tool gaps TG-1…TG-4 | **VALID** | Medusa vacuity, Semgrep's absent Solidity security ruleset, Echidna missing, and Halmos truncation are all recorded as **zero evidential weight**, never as clean. Correct. |
| `HK-1` housekeeping, Drift Watch | **VALID** | Neither is presented as a finding. |

### Spec-conformance stream (Law 2)

| Item | Verdict | Note |
|---|---|---|
| TOP FLAG (= `M-03`) | **VALID** | Cross-referenced by fingerprint, not double-labelled. |
| `F-21-01` interface silent on the settlement trap | **VALID** (Low) | The interface is the artifact that propagates the obligation; a fourth orchestrator gets no signal. Real. |
| `F-21-02` "both branches handled" over a three-branch space | **VALID** (QA only) | The **third branch is weird-ERC20 behaviour**, a C4 known-invalid class — and the report says so and **explicitly refuses to escalate**. Valid on the documentation-accuracy framing (the code's own completeness claim is wider than its behaviour) and on that framing only. Must never be promoted above QA on the current reward token. |
| `F-21-03` disclosure omits the escrowed case | **VALID** (QA) | Credits the voluntary disclosure first. Fair. |
| `F-21-04` "references repointed" was a literal-string repoint | **VALID** (Low) | Verified as a live-doc defect; the balancing section is generous and specific. Carries the ledger `L-03` fix-trap forward. |
| `F-21-05` authoritative spec covers 1 of 11 contracts | **VALID** (Low) | Load-bearing on this audit's own suppression machinery; the circularity bar (cannot suppress a finding about the known-issues source using that source) is the correct call. |
| `F-21-06` multi-token minter unreachable end-to-end | **VALID** (QA tracking) | Explicitly forbidden from being used to discount severity (run-20 R-6), with the bounded/unbounded split stated. Correct. |
| Carryover ledger `F-20-07` | **VALID**, `open`, re-anchored | Not double-counted against `L-04`; the *"no configuration under which claiming is profitable"* claim is falsified from the document's own next paragraph. |

### Parked items

| Item | Verdict |
|---|---|
| `MR-21-001` `invariant_fotFloor` | **MUST REFRAME — remains parked, not resolved.** See item 1. |
| `MR-21-002` caller-supplied `rewardTokens` called twice | **VALID as parked.** The reentrancy framing is fully refuted from source by two agents (`balanceOf` is a `STATICCALL` before any pull/approval; `safeTransfer` runs after revocation at `:368`; `nonReentrant` at `:300`) — and the record says so plainly rather than keeping the refuted framing alive. What survives is the arbitrary-code **surface**. Note it is parked *behind* `MR-21-001`; if `MR-21-001` collapses once its premise is corrected, this collapses with it, exactly as its own text provides. |

---

## `MR-21-001` — the full answer to the specific question asked

**It is not being smuggled in as a fee-on-transfer support request.** The FoT token is the delivery
vehicle for the counterexample, the `doNotDo` list forbids the FoT re-framing in both directions, the
`doNotCollapseRegister` records the pair *(MR-21-001, the C4 known-invalid FoT class)* explicitly, and no
severity was assigned. Procedurally this is handled correctly and the item should **stay parked**.

**It is also not being dismissed as one** — and it must not be. Two agents refused to close it; the
deduplicator declined to overrule them; the QA report reproduces both sides of the argument without
picking one. Correct.

**But the narrow framing it was parked on does not survive contact with the source, and a triager must be
told that before they triage.** The claim *"documented as a floor on what the recipient RECEIVES"* is
false at three artifacts:

- `src/BatchNFTMinterMultiToken.sol:252-256` — *"`minRewards` is a floor on the contract's pre-transfer
  balance, **not** on the amount `recipient` receives … Supplying such a token is at the caller's
  discretion."*
- `src/BatchNFTMinterMultiToken.sol:280-291` (`@param minRewards`) — floors *"this contract's pre-loop
  balance"*.
- `docs/multi-token-nudge.md:176-195` — §4.4 *"Fee-on-transfer / rebasing tokens — documented, not
  defended"*, with the explicit decision *"**do not defend against this in code**"*, the gas rationale,
  and the mitigation *"the official UI will not list known fee-on-transfer tokens."*

So there is no doc-versus-code enforcement gap. What `invariant_fotFloor` actually caught is that **the
harness encoded a floor semantic the contract explicitly disclaims** — the invariant is wrong, not the
contract. Once the false premise is stripped, what remains is a documented, intentional non-defence
against an asset class the protocol does not use, already carried at QA as ledger `Q-03` (`bfdb5010…`).

**Required action:** rewrite the framing to *"the invariant asserted a delivered-amount floor that the
contract explicitly documents it does not provide; the open question is whether the intentional
non-defence deserves more than the QA note already carried at `Q-03`."* Leave the triage decision to the
human. Do **not** close it by fiat, and do **not** file it as an FoT-support request.

---

## Cross-cutting checks

**`doNotCollapseRegister` — nothing merged.** All nine pairs traced into the submissions and honoured:

| Pair | Honoured where |
|---|---|
| `DEDUP-21-008` ↔ ledger `M-08` (`6d2d6284`) | `classified-findings.json` CLASS-21-018 ledgerActions; run-20 R-1 rejection preserved |
| `DEDUP-21-003` (`a62fe01a`) ↔ `DEDUP-21-002` (`c847207d`) | `M-02.md` §Ledger hygiene item 5 |
| `DEDUP-21-002` ↔ ledger `L-01` (`9135cf79`) | `M-02.md` header ("linked to but not merged"); QA carryover table |
| ledger `H-01` (`858e9e80`) ↔ ledger `M-01` (`521c20ad`) | §4 of **both** reopen records |
| `DEDUP-21-007` (`b3243f42`) ↔ ledger `H-01` (`1c222d5485`) | `M-03.md` §5 and `FIXPENDING…md` §4, both directions |
| `DEDUP-21-006` (`7af123b5`) ↔ `F-21-04`/final `F-21-02` | QA `L-02` ledger note; spec-conformance `F-21-02` remediation |
| ECON-003 (`75305ec0`, code site) ↔ ledger `F-20-07` (`a7dffb34`, doc site) | QA `L-04` note; spec-conformance carryover §"Do not collapse with L-04" |
| `MR-21-001` ↔ the FoT known-invalid class | `manual-review.json` `doNotDo`; QA parked section |
| ECON-007 ↔ CODE-003 | **Deliberately merged** into `L-01` — the merge is declared in the register itself *and* in the finding ("one bound, one fix"), so it is not a silent collapse |

**Label disambiguation — clean.** Every colliding label reference in every submission is qualified by
fingerprint. Spot-checked and correct: run-21 `M-01` = `7a1718e9…` vs ledger `M-01` `521c20ad…` /
`fcaca002…` / `b58b172e…`; run-21 `M-02` = `c847207d…` vs ledger `M-02` `a62fe01a…`; run-21 `M-03` =
`b3243f42…` vs ledger `M-03` `58bd104c…`; ledger `H-01` `858e9e80…` vs ledger `H-01` `1c222d5485…`. The
spec-conformance report additionally publishes the input-ID → `classId` → final-label table for the
**resequenced** `F-21-nn` numbers and names the two traps that table exists to prevent. `LABEL-MAP.json`
agrees with `classified-findings.json` on all 28 entries. The `dedup-results.json` label correction
(ledger `M-03` = `58bd104c…`, not `a0967cce…` which is ledger `M-04`) is carried into the classified
output.

**No dropped-finding suppression abuse.** `manual-review.json` records that all 128 dropped dedup entries
were tool-noise, refuted-from-source by ≥2 agents, or self-flagged superficial, each with a reason, and
that no security-relevant item was dropped. The Law-1 visible-parked-channel requirement is satisfied:
parked items appear in `manual-review.json`, in `classified-findings.json`, **and** in the QA report body.

**Scope.** Every finding lands in first-party `lib/phoenix-nft-staking/src/**`. No finding's root cause
sits in `lib/` third-party or forked code. The two references outside `src/` — the
`phoenix-phase-2-staging` deploy scripts (`M-03`) and the OZ `ERC1155Utils` path (`M-02` PoC) — are cited
as **evidence of reachability**, not as the defect location. Correct.

**C4 known-invalid sweep, per category:**

| Category | Detected | Disposition |
|---|---|---|
| Non-standard / weird ERC-20 | Yes — `L-02` (both counterexamples), `F-21-02` (third branch) | Neither escalated; both explicitly caveated as unreachable against the pinned standard token. `L-02` retitle requested. |
| Fee-on-transfer | Yes — `MR-21-001`, `L-02` counterexample B, 4naly3er M-1 | Parked / caveated / labelled as tool output. `MR-21-001` framing must be corrected. No FoT-support request is being made. |
| CryptoPunks | No | — |
| Approve race / `safeApprove` front-run | No | The `forceApprove` findings are about an **uncapped** allowance, not a race. Distinct. |
| User input mistake / phishing | Tested against `M-02` and `Q-01` | Both survive — see the `M-02` verdict and `Q-01`'s trusted-external-array note. |
| Reckless admin / malicious owner | Yes — 140 tool instances | Suppressed under Law 3 **with counts recorded**. The four owner-adjacent findings kept (`M-01` re-arm trigger, `M-03`, `L-02`, `L-03`) each pass the surprise test and are framed as footguns with safe-config guidance, never as malicious-owner vectors. Correct application of Law 3. |
| Unused view functions | No | — |
| Speculation on future code | Tested against `M-03` and `L-05` | Both survive: root cause is present in shipped code today (`:756` + a live deploy script; the shipped one-legged snapshot). |
| Parent/forked root cause OOS | No | — |
| Automated-tool finding without an H/M path | No | Bot tables are explicitly quarantined as *"an automated baseline, not a reviewed finding set"*, and nothing was promoted from them without independent derivation. |

---

## Bottom line

**Nothing here should be pulled.** Every High/Medium survived a deliberate attempt to break it, including
the one most exposed to a "so what" — `M-02` — which is *stronger* than filed once the self-service nudge
variant is added. Before submission: fix the `MR-21-001` framing (blocking), delete `M-01`'s unprovable
"no historical loss" sentence, add `M-02`'s self-service variant and qualify its no-pre-funding claim,
retitle `L-02` as conditional, and give the two carryover Mediums a written home.
