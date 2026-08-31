# Decision Log — phoenix-nft-staking run-21

**Run:** `reports/phoenix-nft-staking/21/`
**Date:** 2026-07-21
**Baseline:** `0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54` (run-20, story-022 Stage 6)
**HEAD:** `c881a428c87ef4ef42ba07a71be5d49101c9006d` (story-022 Stage 7-8 + story-023)
**Mode:** REGRESSION, with cold treatment of the split-out and newly-added files

This run was requested as autonomous. **Every fork below was resolved by me, not by the operator.** Each
entry records the fork, the option taken, the reasoning, and what a reversal would cost. Where two agents
disagreed, both positions are recorded rather than one being quietly adopted.

The single most consequential decision this run is **D-01** — the finding that the operator's own framing
of the change ("a rename") was factually wrong, and that acting on it as stated would have mis-filed the
live defects of a **mainnet-deployed** contract.

---

## D-01 — The BatchNFTMinter "rename" was a SPLIT, and carryover was resolved PER ENTRY, not in bulk

**Fork.** The operator's instruction was that `src/BatchNFTMinter.sol` had been renamed to
`src/BatchNFTMinterMultiToken.sol`, and that carried-over findings should therefore **move** to the
Multi version. Applying that literally is one bulk re-anchor: rewrite `contract` on every affected ledger
entry and be done.

**Decision.** **Rejected as stated.** `git` shows story-022 Stage 7 was a **split, not a rename**:
`src/BatchNFTMinter.sol` was **reverted to its pre-story-022 single-token form and frozen**, and the
multi-token work was landed in a **new sibling file**. Both files exist at HEAD. Critically,
**`src/BatchNFTMinter.sol` is the file that is actually DEPLOYED on mainnet** — confirmed this run by
codehash on both live instances (`0x0c2f553caec40226…`), while `BatchNFTMinterMultiToken` is **not
deployed at all** (selector `0xca0ced0b` absent from all five known instances).

So carryover was resolved **one entry at a time**, against source, with an explicit
**frozen-only / new-file-only / BOTH** verdict recorded for each. **13 relocations mapped**
(`dedup-results.json.relocations`). The distribution is the point:

| Verdict | Entries | Example |
|---|---|---|
| **BOTH** | `858e9e80` H-01, `521c20ad` M-01, `fcaca002` M-01, `fb17fc6d` M-06, `ad36260f` M-07, `d0ed2cf4` Q-02, `47f2dc3a` Q-04, `e35388bf` L-02, `990d8c37` L-05 | the frozen file keeps its own single-token nudge (`nudgePaymentToken` `:87`/`:149`/`:260`) verbatim |
| **NEW FILE ONLY** | `a62fe01a` M-02, `bfdb5010` Q-03 | verified: the frozen file at `c881a42` has **no** `_payRewards` and **no** `rewardTokens` |
| **FROZEN ONLY** | `9135cf79` L-01 | ⚠ the **new** file fixed it (`ReentrancyGuard` `:82`, `nonReentrant` `:300`); the omission **stayed behind on the deployed file** |
| **SHAPE CHANGED — not relocated** | `58b6c486` L-03 | the conditional nudge-token guard was **replaced**, not moved (see D-16) |

**Why.** A blanket move would have been wrong in three distinct, compounding ways:

1. It would have **re-anchored the deployed contract's live defects onto a file nobody has deployed** —
   moving `fcaca002` (the step-10 sweep) off `BatchNFTMinter.sol` when this run's PoC §8.2 **executes that
   very sweep on the frozen file** (`testA1`: +490.000000 for a zero contribution).
2. It would have read `9135cf79` L-01 as **fixed**, because the guard genuinely is present on the new
   file. The asymmetry — a `ReentrancyGuard` landing on the copy that is not deployed and not on the copy
   that is — **is this run's `M-02`**, a Medium with a measured 26.900000 USDC victim loss. A bulk move
   would have deleted the finding by bookkeeping.
3. It would have quietly transferred a **wont-fix triage** (`990d8c37` L-05) onto a materially wider
   design: the owner accepted it when the *owner* pinned one payout asset; on the sibling **any qualifying
   caller names any ERC20 the contract holds** (FORK-PARITY §B4.1). Suppression boundaries do not survive
   a relocation unexamined.

**Reversal cost.** Low and safe in the reverting direction. If the operator confirms the frozen file is to
be treated as out of scope, the frozen-side entries can be closed with one `/ledger` pass. The unsafe
direction — dropping live defects off a deployed contract — is the one that cannot be undone quietly, so
I took the recall-preserving side (Law 1).

---

## D-02 — Two `fixed` ledger entries proven still-live are filed as EXPIRED CLOSURES, not REGRESSIONS

**Fork.** `858e9e80…` (ledger H-01, value-blind nudge gate) and `521c20ad…` (ledger M-01, MEV race for
that gate) are both `fixed` in the ledger, and both are **PoC-proven live at HEAD**
(`PoC_NudgeLineage_H01.t.sol` 4/4 PASS; `PoC_NudgeLineage_MevFrontrunNudge.t.sol` 2/2 PASS). The obvious
label is **REGRESSION** — the loudest available, and this project's own convention ranks a regression at
the top.

**Decision.** Filed as **EXPIRED CLOSURES**, explicitly *not* regressions, and stated as such three times
in each write-up.

**Why.** **No patch was reverted.** story-014's owner-pinning is intact at HEAD and was *proven* intact by
a negative control (`test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED`, PASS). What expired is
the **closure rationale**, by two mechanisms:

- story-022 Stage 7 **relocated** the code, minting a `contract:function` fingerprint that dedup cannot
  match — the entries would otherwise read as fixed *and* be re-minted as new in the same run;
- the sibling's **caller-supplied `rewardTokens` array removed the owner-pinning** the "owner-driven only,
  therefore invalid" judgement rested on.

Calling this a regression would send a reader to **restore a patch that is not broken** — the exact
failure mode recorded in the *expired-closure vs regression* rule. The distinction is preserved in the
filenames, the headers, and the ledger `humanReviewFlag`.

**Recorded honestly: run-20 already proposed both reopens (D-26/D-27/D-29) and the operator never applied
them.** Both entries still carry run-20's flag *"⚠ EXPIRED-CLOSURE — REOPEN PROPOSED (run-20). Status left
`fixed` pending human decision."* This run **re-proposes** them with stronger evidence (executed PoCs
against the relocated code, plus fresh mainnet reads) and **again does not apply them** — status changes
are human-only. That is now a **two-run-old unapplied proposal**, and it is called out in the ledger and
in the run summary rather than allowed to age quietly.

**Also decided:** neither reopen gets a run-21 `M-nn` label (run-20 precedent R-2/D-29). They are ledger
consequences, not new defects of this run; labelling them would inflate the run-21 count and create a
third collision on `M-01`.

**Reversal cost.** None for the framing. If the operator prefers the regression framing, it is a wording
change in two documents — but the "no patch was reverted" fact would still have to be stated, so the
expired-closure framing is strictly more informative.

---

## D-03 — `M-01` held at MEDIUM, on an ASSET ground, explicitly not the R-6-forbidden "not deployed" ground

**Fork.** `M-01` (`7a1718e9…`, `paymentAmount = 0` free-mint + whole-balance payment-token sweep) is a
fully unprivileged, zero-outlay path with an 11/11 PoC. On the face of it that is a **High**. The reason it
is not is that the sweep currently moves nothing. Two very different sentences express that, and only one
of them is legitimate:

- *(a)* "the contract where this is filed is **not deployed**" — **forbidden** under run-20 ruling R-6;
- *(b)* "the payment-token balance on the deployed instances is **zero**" — an asset fact.

The severity auditor found that `mainnet-verification-ECON-001.md` §7 listed **(a)** as fact 5 among the
reasons for holding off High, directly contradicting `M-01.md:149-150`, which disclaims it.

**Decision.** **Medium, on ground (b) only.** §7 fact 5 was **struck/relabelled as context**. The report
leads with *the attacker cannot profitably arm this, and no live inflow route arms it* (traced through all
three routes), with the balance census demoted to **corroboration**.

**Why.** The deciding facts are about assets, not deployment status: both live instances hold **0** of
their resolved payment token, durably (flat zero across six sampled blocks 25400000 → 25577241), and every
live inflow route delivers the **wrong** token (USDC into the instance whose payment token is USDS;
nothing into the instance whose payment token is USDC). And the attacker cannot create the precondition
themselves — self-funding is net-neutral, and the compound case (~634 USDS to take a 94.95 USDC pot) is
**loss-making**, i.e. the designed nudge bounty operating as intended. That is a textbook C4 Medium
external requirement.

**Quantified re-arm trigger, shipped with the finding** (this is what keeps the Medium honest — a finding
held down by a configuration must carry the condition under which it stops being one):

- **Primary:** repointing `NudgeRatchet.batchMinter()` (`0x7A4eD111…`) from `0x86866e01…` to
  `0x81896F48…`, whose payment token **is** USDC, lands the existing USDC donation stream as **sweepable
  payment token** and arms a zero-cost drain.
- **Thresholds:** USDS ≥ **15.86** reaching `0x86866e01…`; USDC ≥ **70** reaching `0x81896F48…`.
- **Compound case:** USDS ≥ ~**634** on `0x86866e01…` lets a `paymentAmount = 0`, `count = 40` caller take
  40 NFTs, the USDS remainder **and** the whole USDC nudge pot in one transaction, having contributed
  nothing.
- The operator has **repeatedly repointed sinks** between these instances
  (`FixRatchetBatchMinterSink`, `DisableNudgeAndDivertDonations`, `DispatcherReplaceSkyPoolerAtIndex4`) —
  so the arming action is an ordinary operator move with a non-obvious consequence: a **Law-3 footgun**,
  in scope, and *not* filed as a malicious-owner vector.

**Reversal cost.** Low. If the operator reads the zero balance as structural rather than configurational,
the finding drops to Low with the trigger list intact. Escalation to High is a one-line change if any
threshold above is crossed — which is precisely why the thresholds are numbers.

---

## D-04 — `M-02` held at MEDIUM; the "victim named the attacker" objection answered with a self-service variant

**Fork.** `M-02` (`c847207d…`, missing `ReentrancyGuard` on the **frozen, deployed** minter) had one
exposed flank: as originally written, the exploit needed a caller to name the attacker's contract as
`recipient`. A triager could call that a C4 **user-input-mistake** (invalid), or at best argue it is
"operationally unproven" and push it to Low. The report itself offered the exit: *"if the operator can
state that every caller is a first-party front-end naming EOA recipients, this drops honestly to Low."*

**Decision.** **Medium held**, and that sentence **struck** — not softened, not caveated. Replaced with the
**self-service variant**, which needs no victim at all.

**Why.** The sentence is **refuted by this run's own PoC**. `test_Exploit_NudgeSnapshotPaidTwice` proves an
attacker can be **both caller and recipient**: `batchMint(count = nudgeSize, recipient = own hostile
contract, …)`, re-enter from its own ERC-1155 acceptance hook, re-snapshot a pot inflated by the outer
batch's own donations, collect it, and let the outer frame pay the snapshot again (Mallory +25,000,000 NDG
against an honest 5,000,000; pot left at 10,000,000 instead of 15,000,000). The value that moves belongs to
the **forward-donation pool** — third-party value, no third-party integration, **no victim naming anyone**.
A finding with a no-victim-required variant cannot be dismissed as victim error, and the sentence offering
the downgrade was a **live downgrade trap** licensing a future error.

Two supporting grounds were also recorded rather than assumed: the remaining caller-funds-a-third-party leg
is a **gift/relayer shape, not a typo** (the payer supplies exactly the address they meant), and the harm is
**undetectable after the fact** (the tx succeeds, no event fires, `totalPaid` affirms the full amount) — so
diligence cannot save the payer. The contract's own NatSpec at `:217-220` **instructs callers to over-fund**;
the stolen surplus exists because the contract told the caller to create it.

**Also struck:** *"This path requires **no pre-funding whatsoever**"* — true for the caller's-surplus leg,
**false for the nudge leg**, which is the very leg the report uses to escape the "loss confined to the
caller's own surplus" bound. As written the report contradicted itself.

**Reversal cost.** None in the safe direction. The Medium now rests on a leg that needs no cooperating
third party, so a downgrade would require refuting an executed PoC.

---

## D-05 — `M-03` held at MEDIUM (borderline, kept higher), and its pivot fact VERIFIED rather than left inferred

**Fork.** `M-03` (`b3243f42…`, `NFTStakerDepletion.sol:756` still `_safePay(pending)` in the live
deployment template) sits genuinely on the Medium/Low boundary, and its severity pivoted on a fact that was
**inferred from script source and never read from chain**: that the three new mainnet stakers have
`migrator == address(0)`. The auditor flagged it as *unpaid, and it points unsafe if wrong*. The cheap
options were to file at Low, or to ship the Medium with the caveat standing.

**Decision.** **Medium held, and the fact measured.** Read-only mainnet verification at block **25577673**
(D-07): `migrator() == address(0)` on all three, **plus** a lifetime `MigratorSet` log scan (creation block
25490911 → head) showing `setMigrator` has **never** been called — with a **positive control**
(`PauserChanged` hits at 25490915/25490923/25490932) so the empty result is load-bearing rather than a
silent RPC failure. **The pivot fact holds and resolves the safe way.** The caveat in `M-03.md` was
replaced with the verified result; mitigation step 5 is marked **discharged**.

**Why it stays Medium anyway — and this is the substantive point.** The verification did not *weaken* the
finding; it **moved the Medium onto better ground and removed one wrong ground**:

- **The "pre-launch state" framing was withdrawn as factually wrong.** All three stakers are
  `poolState == Active` and hold real user value — **2 / 117 / 13** staked units and
  **4.94 / 582.77 / 55.01 phUSD**. The scheduled `setMigrator` call will be made against **populated live
  pools**, not an empty shell. That is now the strongest argument for Medium over Low.
- **`migrator()` is owner-mutable at any time.** The read bounds *present* reachability at one block; it
  does not bound the defect. `setMigrator` is `onlyOwner`, accepts any address, has no code-size check and
  — by its own NatSpec — **no empty-pool gate**. Wiring a migrator is the scheduled entry point of the
  migration API these contracts exist to serve. The one-off read was therefore converted into a **standing
  obligation** (re-read before/after any `setMigrator`), not deleted.
- **The template claim was upgraded from assertion to byte equality.** The deployed runtime was diffed
  against a local rebuild (solc **0.8.30** — read from the deployed metadata trailer, *not* the repo's own
  `0.8.20` pin, because staging pins no solc and `^0.8.20` floats): **0 differing bytes outside the 15
  declared immutable slots**, on all three, with constructor args decoding to exactly
  `(NFTMinterV2, idx, PHUSD, OWNER, NFTMinterV2, idx)`. Stated caveat kept: the chain is **source ⇒
  bytecode**; `depositFor` was **not** independently disassembled to read `CALLER`.
- **The `pauser()` framing was NOT carried over from ECON-001.** These stakers have a **real** Pauser
  (`0x7c5A8EeF…85a3`), unlike the batch minters — reusing the "no break-glass" line would have been false.
  But it is not mitigation either: `depositFor` is deliberately `whenNotPaused`-exempt (`:743-747`). Both
  halves are stated.

**Reversal cost.** Low. A triager who reads "unreachable today" as decisive can drop it to Low; the
verified block-height fact and its expiry condition are both on the page, so nothing is hidden either way.

---

## D-06 — The fix-pending High was NOT closed, despite three PoCs inverting

**Fork.** Ledger `1c222d5485…` (run-20 H-01, `NFTStakerDepletion.depositFor` pays the migrator) is
`fix-pending`. story-023 (`f3b92c0`) landed a measure-and-forward capture leg on the migrator side, and
**three PoCs inverted**: `testC` now pays alice `+8,219.178082191780691200e18`, `testD` leaves the migrator
holding 0, and the `testA` control is no longer unpatched. The obvious read is **fixed**.

**Two agents disagreed, and both positions are recorded:**

- **Position A — poc-replay §5: propose `fixed`.** The inversions are real, confirmed in source, and green
  in the 412-test baseline.
- **Position B — story-faithfulness (F-21-01): keep `fix-pending`.** The migrator-side mechanism is
  correct and **complete for the paths it covers**, but `src/NFTStakerDepletion.sol:756` is **unchanged**,
  and **four residual reach-paths survive**: (1) a direct EOA/multisig wired as migrator — unclosable from
  the migrator side *by construction*; (2) any pre-`f3b92c0` migrator already deployed and wired (the fix
  requires redeploy **plus** re-running `setMigrator`, a prerequisite the commit body never states);
  (3) any future third orchestrator written against `INFTStakerMigratable`, which is silent about the trap;
  (4) every future `NFTStakerDepletion` deployment — and
  `DeployMainnetUniboostCutover.s.sol:478` deploys fresh mainnet instances from that file **today**.

**Decision.** **Sided with position B. Not flipped.** The entry stays `fix-pending`; the migrator-side work
is recorded on it as **LIKELY-FIXED-FOR-COVERED-PATHS**; the residual source-tree hazard is carried as its
own finding (`M-03`, D-05) so that a later `fixed` flip cannot orphan it. **The human decides via
`/ledger`** — this run only proposes (PLA-03).

**Why.** `fix-pending` is never auto-closed, and **a fix that merely stops tripping the scanner is not a
verified fix**. The PoCs that inverted all measure the **migrator-side outcome**; the two that measure
`:756`'s raw behaviour (`testA_DepositForPaysMigratorNotUser`, `testB_BatchMigratePaysUserCorrectly`)
**still PASS at `c881a42`**. Flipping on the strength of tests that do not touch the unchanged line is the
**incomplete-fix trap**, which is ranked second only to a regression precisely because it reads as done.

**Hard constraint attached to the entry:** whatever is decided, this must **not** be reported as *"the
defect is gone"*.

**Reversal cost.** Low and reversible: `/ledger phoenix-nft-staking fixed 1c222d5485…` applies position A
in one command if the operator disagrees. The opposite error — flipping it here and finding out later that
an EOA migrator was wired — is not recoverable from the report.

---

## D-07 — Read-only mainnet verification authorised twice, on the run-20 D-17 precedent

**Fork.** Two separate questions this run could only be settled from chain: `M-01`'s exposure (are the
deployed minters actually holding sweepable payment token?) and `M-03`'s pivot fact (is `migrator` really
zero?). Neither is answerable from source. Reaching for the network is a decision an audit run should not
make silently.

**Decision.** Authorised, **twice**, strictly read-only: block **25577241** (ECON-001) and block
**25577673** (M-03). **No transaction was sent, signed, broadcast or simulated. No key was used. No script
in `phoenix-phase-2-staging/script/` was run. `lib/**` was not modified** (`git status --porcelain` clean;
the M-03 rebuild wrote to the scratchpad via `FOUNDRY_OUT`).

**Why.** Precedent is **run-20 D-17**, which established that read-only `cast call` / `cast logs` against
mainnet is in bounds for settling a severity-pivotal fact. Both uses cleared the bar: each fact was
**load-bearing on a label**, and each **pointed unsafe if assumed wrong**. `RPC_MAINNET` came from the
repo-root `.envrc`; both runs passed a liveness probe first, so a stale key would have alerted rather than
silently degraded.

**Both verifications are written up as standalone evidence files with their own limits sections** —
`mainnet-verification-ECON-001.md` and `mainnet-verification-M-03.md` — including what they do **not**
establish (no fork execution of the sweep; explicit-token-list balance enumeration; six spot blocks rather
than a full log scan for ECON-001; source⇒bytecode rather than an independent disassembly for M-03).

**Reversal cost.** None. Read-only reads change nothing; the worst case is wasted tokens.

---

## D-08 — PoC bit-rot was REPAIRED, and a non-compiling PoC was never read as a fix

**Fork.** The audit-authored PoC suite did not compile at HEAD. A non-compiling exploit test is superficially
indistinguishable from a fixed bug, and the cheap resolution — "the PoC no longer builds, so treat the
finding as closed" — was available for **16 files**.

**Decision.** **Repaired, then replayed.** A PoC that fails to compile is **INCONCLUSIVE bit-rot, never
evidence of a fix.** Nothing was closed on a build failure.

**Two independent bit-rot axes were found and are recorded separately** — conflating them would have hidden
one behind the other:

- **Axis A — the multi-token split (`fba4991`, story-022 Stage 7): 11 files** repointed to
  `BatchNFTMinterMultiToken`, or deliberately **left** on the frozen `BatchNFTMinter` where the finding is
  about the deployed file (D-01).
- **Axis B — the migrator constructor gained a 6th parameter (story-023): 5 files** repaired by inserting
  the `IERC20 _rewardToken` constructor argument.

**Why it matters that the axes are named.** Axis B is the one that would have produced the false "fixed":
`PoC_Drift01_DepositForPaysMigrator.t.sol` stopped compiling for a reason **entirely unrelated to the
defect it tests**, and after repair `testA`/`testB` **still PASS at `c881a42`** — which is exactly the
evidence D-06 rests on. Had the compile failure been read as a fix, the fix-pending High would have been
closed on a constructor signature change.

**Discipline recorded:** no `lib/**` was touched, no upstream tracked test was modified, and **no PoC was
"made to pass" by weakening it** — repairs were signature/import-level only.

**Reversal cost.** None. Repairs are in `workspace/`, which is disposable and gitignored.

---

## D-09 — Mock vacuity REFUSED: a faithful port plus a real-`NFTMinterV2` run were built instead

**Fork.** The `M-02` reentrancy exploit needed an ERC-1155 acceptance hook to fire. The project's own
`test/mocks/MockERC1155.mint()` **never calls `_checkOnERC1155Received`** — it writes the balance, emits
`TransferSingle`, and returns. Running the PoC on that mock would have produced a green result on a stack
where the mechanism under test **cannot execute**: a **vacuous witness**, and a Medium resting on nothing.

**Decision.** **Refused the vacuous harness.** Built **two** harnesses instead: a faithful port that
actually fires the acceptance hook, and a run against the **real, unmodified `NFTMinterV2`**. Both produced
**identical literals** (26.900000 USDC victim loss), which is what makes the result a measurement rather
than a fixture artefact.

**And the vacuity itself was pinned as an executable fact**, not left as prose:
`test_Q01_MockERC1155_IsVacuous_NeverFiresTheHook` **PASSES** — after `MockERC1155.mint()` the probe
recipient's balance is credited **1** and its acceptance-hook counter is **exactly 0**.

**Why.** This is the *vacuous invariant harness* failure mode: a mock that can never fail turns a test
suite into 0 == 0. A finding that would have been a false negative on the project's own mock is exactly the
kind Law 1 exists to catch.

**Boundary held deliberately:** this discharges the question *"did our evidence reach the real
mechanism?"* — **yes**. It does **not** discharge ledger `Q-01` (`cabd4a3d…`), which asks whether **the
project's own suite** reaches it. **That stays OPEN as a test-suite defect.** Nothing in the shipped suite
was changed and the project's mocks remain vacuous.

**Reversal cost.** None — strictly more evidence than the alternative.

---

## D-10 — Medusa's "22 passed" recorded as VACUOUS with LCOV proof; Semgrep's silence recorded as a tool gap

**Fork.** Medusa completed **100,085 calls / 577 sequences** and reported **"22 test(s) passed, 0 failed"**.
That is a citable-looking result, and citing it would have strengthened the run's coverage story at zero
cost.

**Decision.** **Recorded as VACUOUS. Zero weight. Must not be cited.**

**Why, with the proof rather than a suspicion.** Medusa does not drive Foundry's
`targetContract`/`targetSelector` handler machinery — it fuzzes the target contract's own external
functions. The **LCOV report** (`medusa-corpus/coverage/lcov.info`) confirms **not one `ForwardingHandler`
function was ever called**: no `doMigrateInOne`, no `stakeDirect`, no `doInitiate`, no `unblockAndClaim`.
All 100,085 calls re-evaluated the invariants against the **frozen post-`setUp` state**. Retried with
`testing.testAllContracts: true`; the handler was still never reached. **22 × (0 == 0) is not evidence.**
Driving the migrator under Medusa needs a purpose-built constructor-argument-free harness; not built this
run, and recorded as owed.

**Companion gaps recorded in the same breath, so silence is never read as clean:**

- **Echidna: not installed** (`which echidna` → not found). Not run. **Foundry is the only stateful-fuzz
  evidence in this report.**
- **Semgrep produced nothing security-relevant for a THIRD consecutive run** (206 INFO-style hits, all
  dropped). Semgrep has **no Solidity security ruleset** — its silence is a **TOOL GAP**, not an all-clear.
  This is the third run in a row it has been recorded as such (run-20 D-11).
- **Halmos: one truncated path** (`SymbolicNudgePayout::check_noOverPay_threeTokens_withDonation`) recorded
  as **INCONCLUSIVE**, not as a pass. A `TIMEOUT` carries zero weight.

**Reversal cost.** None. The only cost of this decision is a less impressive-looking coverage table.

---

## D-11 — ZERO suppressions applied; 11 declined suppressions documented individually

**Fork.** 28 findings entered the sanitizer against 14 cached known issues and a set of prior triage
decisions. Suppression is the cheapest way to a clean report, and **11 candidate suppressions were
available** — several of them superficially well-founded.

**Decision.** **`suppressions: []` — none applied.** All 11 declines are documented with their grounds as
`DS-01` … `DS-11` in `sanitized-findings.json`, so a reader can see exactly what was *not* hidden and
overturn any of them.

**Why, by class.** The load-bearing hard constraint (run-20 D-04, tightened this run) is that the cached
KIs were extracted **2026-04-27** from a `CLAUDE.md` with **no Known Issues section**, describing only
`NFTStaker` + `BatchNFTMinter`, and **rewritten by story-022 inside this audit range** — with two cached
`designDecisions` **actively contradicted at HEAD** (they assume the removed `nudgePaymentToken` /
`setNudgePaymentToken`). So `DS-09` declines suppression of **everything** on
`BatchNFTMinterMultiToken`, both migrators and `IStakerViews` outright, and `DS-08` adds the **circularity
bar**: you cannot suppress a finding *about* the staleness of the known-issues source *using* that source.

**Two declines deserve naming individually:**

- **`DS-04` — a prior FALSE-POSITIVE whose grounds have since become FALSE.** The value-blind nudge
  lineage carried a four-ground suppression; **two of the four are falsified at `c881a42`**. Ground (1)
  ("owner-driven only") does not apply — `DEDUP-21-001`'s demonstrated path is **unprivileged and
  zero-outlay** (`paymentAmount = 0`), requiring no misconfiguration at all. Ground (3) is falsified by
  FORK-PARITY §B4.2: `rescueERC20` **degraded** from *"the missing escape hatch"* on the frozen file to
  *"NOT a reliable escape hatch … a race the owner will usually lose"* on the sibling. A same-lineage
  suppression is exactly what a naive semantic match reaches for, which is why it is documented rather
  than silently skipped.
- **`DS-11` — a wont-fix whose load-bearing premise is now factually false, DISCLOSED but NOT re-filed.**
  Ledger `M-02`'s wont-fix rests on premise (b), quoted verbatim: *"NFTStaker exposes NO migrate-on-behalf
  mechanism — every position-moving entrypoint is keyed to `msg.sender`… so a migration would force every
  staker to self-exit and re-stake."* That is **false** on
  `src/NFTStakerPriceScaledMigrateReady.sol`, which has exactly such a mechanism. **No run-21 finding was
  minted from this** — a new contract would mint a new fingerprint that dedup cannot flag, and re-filing
  over an owner's signed triage without disclosure is the failure mode the *disclose-when-re-filing* rule
  exists to prevent. It is carried as a **disclosure only**, naming the prior entry and quoting the
  premise, for the human to re-triage.

Also declined: `DS-01`/`DS-02` (the FoT token is the **delivery vehicle** of `MR-21-001`, not the finding —
the pre-transfer-vs-delivered enforcement gap exists independently of token class, so the known-invalid
fee-on-transfer rule does not reach it); `DS-03` (KI scope + subject mismatch); `DS-05` (the `minRewards`
acceptance was granted against a **narrower** design — see D-01); `DS-06`/`DS-07` (Law-3 **footgun**
exceptions: a competent non-malicious owner would be surprised, so they are in scope, not
reckless-admin-invalid); `DS-10` (the `test/` out-of-scope glob excludes *hunting for bugs inside test
code*, not the **assurance claim** the suite makes about in-scope code).

Separately, **66 aderyn "Centralization Risk" hits were dropped under Law 3 with the count preserved**, not
silently discarded — and the non-obvious owner footguns in that same surface are carried at honest severity
(`DEDUP-21-005`, `DEDUP-21-008`).

**Reversal cost.** Low and in the safe direction: every declined suppression is a documented finding the
operator can suppress with one `/ledger` call. The opposite — an over-suppression — is invisible and
cannot be undone by a reader.

---

## D-12 — Both final reviews confirmed all 28 severities but disputed 3 GROUNDS; corrections applied without moving a label

**Fork.** The severity auditor and the validity checker both came back with **0 label moves** —
**28/28 severities confirmed**, 0 invalid, 0 recommended for deletion. The temptation is to read that as a
clean pass and ship.

**Decision.** **Treated the disputes, not the count, as the result.** Three **stated grounds** were disputed
at unchanged labels (`M-01`, `M-02`, `M-03`), plus one cross-cutting consistency dispute. All corrections
were applied. **No label moved.**

**Why.** The auditor's own summary is the reason: *"one of the three grounds (M-02's) is not merely
stylistically weak — it is factually wrong in a direction that invites an unjustified future downgrade to
Low."* The direction of pressure across both reviews was **understatement**, not overstatement — which under
Law 1 is the more expensive kind of error, because it is the kind that gets a finding dismissed later.

**The four report-damaging sentences that were caught and struck:**

1. **`M-02`** — *"if the operator can state that every caller is a first-party front-end naming EOA
   recipients, this drops honestly to Low."* **Struck.** Refuted by this run's own
   `test_Exploit_NudgeSnapshotPaidTwice` (D-04). A live downgrade trap.
2. **`M-02`** — *"This path requires **no pre-funding whatsoever**."* **Struck/qualified.** True for the
   caller's-surplus leg, **false for the nudge leg** — the very leg the report uses to reach third-party
   value. The two claims contradicted each other.
3. **`M-01`** — *"No historical loss has occurred via this path."* **Struck.** An unprovable negative drawn
   from **six spot-block reads**, which the evidence file itself concedes — and, worse, a **sibling of this
   contract family WAS drained** (61.297674 USDC out of `0x4ef0fDe4…`), which M-01 cites two paragraphs
   later as an aggravating factor. Replaced with *"no loss via this path was observed across six sampled
   blocks; this is sampling, not a log scan."* (*"The zero is durable"* was softened to *"durably zero
   across six samples"* on the same ground.)
4. **`mainnet-verification-ECON-001.md` §7 fact 5** — *"`BatchNFTMinterMultiToken` — where the finding is
   filed — is **not deployed**"*, listed as a reason for holding off High. **Struck/relabelled as
   context.** It is the **R-6-forbidden ground** and it contradicted `M-01.md:149-150` (D-03).

**Also actioned from the reviews:** the cross-cutting dispute — both expired-closure reopens held a Medium
on the **same shape of ground as M-01** (a configuration relation asserted in NatSpec and enforced nowhere)
but shipped **no re-rate trigger at all**; a quantified trigger was added to both. And `MR-21-001`'s framing
sentence was corrected: it claimed a documentation-versus-enforcement gap on `minRewards`, but the NatSpec
(`BatchNFTMinterMultiToken.sol:252-256`) and `docs/multi-token-nudge.md:176-195` say **exactly what the code
does** — the item stays **parked**, but on a framing a reader cannot dismantle in one paste.

**Reversal cost.** None. Every change strengthened an already-confirmed label; no severity moved, so nothing
downstream needs re-deriving.

---

## D-13 — ORCHESTRATOR ERROR: I killed a healthy classifier agent on a bad liveness signal

**What happened.** I was monitoring the severity-classifier by the **mtime of its transcript file**. The
file was not being flushed, so the mtime looked stale and I concluded the agent had hung. **I killed it. It
was healthy and had already finished its work.**

**Consequence, stated precisely.** The agent had **already written `classified-findings.json`** — the
complete classification, intact. What was lost was **only `findings/LABEL-MAP.json`**, which it had not yet
emitted.

**Decision.** **Regenerated `LABEL-MAP.json` from the existing `classified-findings.json`. Did NOT
re-classify anything.** The provenance is recorded **in the file itself**, not only here:

> *"Rebuilt verbatim from `classified-findings.json` after the severity-classifier was interrupted before
> writing this file. No finding was re-classified and no severity or label was changed. `classifierLabel`
> and `finalLabel` are identical for every entry because no orchestrator relabelling ruling was issued this
> run."*

Truncated 12-hex fingerprints were expanded from the ledger; entries with **no** fingerprint anywhere carry
`null` **with a stated reason** rather than an invented hash.

**Why it is recorded rather than quietly fixed.** **No finding was affected** — the classification survived,
the labels are the classifier's own, and the severity auditor independently confirmed all 28 afterwards. But
an orchestrator that kills healthy agents on a bad signal will do it again at a worse moment, and a
regenerated artifact that looks hand-authored is a provenance hazard for every future run that reads it. The
honest record is cheaper than the alternative.

**Process fix owed.** Transcript-file mtime is **not** a liveness signal — it measures the writer's flush
behaviour, not the agent's. Liveness must be judged by process state or by an explicit heartbeat.

**Reversal cost.** Already paid: one regenerated artifact, zero re-classification, zero token spend on
re-derivation.

---

## D-14 — TOOLING CORRECTION: 4naly3er's recurring failure was misdiagnosed in a stored note

**Fork.** 4naly3er has failed on this project (and on `yield-claim-nft` and `phStaging`) for several runs.
A stored note attributed the failure to **missing `remappings.txt`** on foundry.toml-only projects, and
prescribed a workaround: stage a `remappings.txt` plus a `src` **symlink** in the scratchpad using absolute
submodule paths. The obvious move was to apply the recorded workaround again.

**Decision.** **Applied it, watched it fail, and re-diagnosed from the tool's own source.** The stored note
is **wrong on both halves**.

**The actual contract.** 4naly3er takes `<basePath> <scopeFile.txt>` — and **argument 3 is a scope list of
`.sol` paths, not a remappings file.** Passing remappings there fails with the tool's own error, **`Error:
Scope is empty`**, which is what every prior run was actually seeing. Separately, 4naly3er resolves
`remappings.txt` **relative to `basePath`**, so pointing `basePath` at the submodule root works **directly**.

**Consequence: the old workaround was unnecessary AND broken.** The absolute-path symlink staging solved a
problem that did not exist while leaving the real one (an empty scope list) in place — which is why it kept
failing and kept being re-attempted.

**Result.** 4naly3er **ran clean on all 11 first-party `src/*.sol` files, 0 import-resolution failures.**
`lib/` was not modified. The corrected invocation contract is recorded **in the QA report's Appendix A**,
where the next run will actually read it, not only in this log.

**Why this is a decision and not a footnote.** A stored note that confidently names the wrong cause is worse
than no note: it converts a five-minute diagnosis into a repeated ritual, and its repeated failure gets
attributed to the project rather than to the note. The old note should be **superseded, not amended**.

**Reversal cost.** None. Worst case the next run re-derives the invocation from the tool's source, as this
one did.

---

## D-15 — The mainnet deployment records are STALE and assert the OPPOSITE of the truth

**Fork.** Resolving `M-03`'s three staker addresses (D-05) started, correctly, from the project's own
deployment records. Those records say the contracts **do not exist**. The cheap resolution was to believe
them and file `M-03` as hypothetical.

**Decision.** **Did not believe them. Resolved the addresses from chain, and filed the records defect as an
operational note (`OP-2`) in the QA bundle** — no label, no severity — plus an **unpaid records-hygiene
item** carried in the ledger.

**The defect.** `lib/phoenix-phase-2-staging/server/deployments/mainnet-addresses.ts:96-98` still lists
`UniboostStakerEYE` / `SCX` / `FLX` as `0x0000…0000`, under a comment at `:76-80` reading *"These are **NOT
yet deployed on mainnet** — zero-address placeholders … Patch by hand when they ship."* **They shipped.**
All three are live, `Active`, and holding staked user funds (2 / 117 / 13 units; 4.94 / 582.77 /
55.01 phUSD), deployed by the operator EOA at blocks 25490911 / 25490919 / 25490928. Neither
`server/deployments/progress.uniboost-cutover.1.json` (which `DeployMainnetUniboostCutover.s.sol:157`
writes) nor `broadcast/DeployMainnetUniboostCutover.s.sol/` exists in the audited commit: the
`uniboost-cutover:broadcast` chain ends in `node scripts/patch-mainnet-addresses-uniboost-cutover.js`, and
**that post-broadcast patch step never landed.** The only `UniboostStaker*` addresses anywhere in the tree
are the **anvil 31337 mocks**.

**Why this is an AUDIT-PROCESS hazard, not a typo.** `M-03`'s severity turns on the state of these three
contracts. The addresses had to be recovered from chain — `NFTMinterV2.configs(1/2/3)` → `targetPool` →
`hook.recipient()`, **closed in both directions** via `hook.dispatcher()` so the EYE/SCX/FLX labelling is
not inferred from ordering — **precisely because the repo records would have produced the wrong answer**:
*"not deployed, so the finding is hypothetical."* That is the opposite of the true state. Any future audit
run, or any operator, trusting `mainnet-addresses.ts` reaches the same wrong conclusion about contracts
that hold user funds.

**Why an operational note and not a finding.** The stale file is in `phoenix-phase-2-staging`, not in this
project, and it is a records defect rather than a code defect — filing it as a security finding here would
overstate it. But burying it in an evidence file would repeat the exact failure it describes, so it is
surfaced in the QA bundle alongside `OP-1` and flagged in the run summary.

**Action owed (unpaid).** Run the patch step or hand-patch `:96-98`, and commit the progress/broadcast
artifacts. Until then, treat `mainnet-addresses.ts` as **non-authoritative for the Uniboost cutover**.

**Reversal cost.** None.

---

## D-16 — `58b6c486…` (ledger L-03) left UNSETTLED rather than auto-closed or auto-carried

**Fork.** The nudge-token equality guard that ledger `L-03` describes was **replaced** on the new file — not
moved — by an unconditional `BatchMint__RewardTokenIsPaymentToken` exclusion (§4.1). Two tidy options
existed: close it as fixed by the new design, or carry it forward unchanged.

**Decision.** **Neither. Flagged for re-derivation, no action** (`PLA-08`). The behaviour changed; **no tier
settled whether the change closes L-03 or merely relocates it.**

**Why.** Auto-closing would dispose of an open finding on an unexamined assumption; auto-carrying would
assert it still applies to code that no longer exists in that shape. Both are silent claims. The visible
option is to record it as **unsettled and owed to the next run**, which is what a "park it in a visible
channel" obligation means.

**Reversal cost.** One re-derivation next run.

---

## Summary of what was decided without the operator

- **The operator's own description of the change was overruled on evidence** (D-01). "Rename" was a
  **split**; the frozen file is the **mainnet-deployed** one; carryover was resolved **per entry**, 13
  relocations mapped, with a `BOTH` / `NEW-FILE-ONLY` / `FROZEN-ONLY` verdict each. A blanket move would
  have mis-filed the deployed contract's live defects — and would have read this run's `M-02` as fixed.
- **No status was auto-flipped, in either direction.** Two `fixed` entries proven live are **proposed** for
  reopen (D-02) — for the **second run running**, the first proposal having never been applied. One
  `fix-pending` High with three inverted PoCs is **not** closed (D-06). All ledger status changes remain
  human-only via `/ledger`.
- **Every hard severity call was held, and the three disputed *grounds* were replaced** (D-03, D-04, D-05,
  D-12). 28/28 severities confirmed by two independent reviews; **four report-damaging sentences struck**,
  including one that would have licensed a wrong future downgrade.
- **Nothing was suppressed** (D-11). 11 declined suppressions documented individually, including a prior
  false-positive whose grounds have since become false (`DS-04`) and an owner wont-fix whose premise is now
  factually false, **disclosed but not re-filed** (`DS-11`).
- **Tool output was never allowed to launder silence into assurance** (D-09, D-10). Medusa's "22 passed" is
  recorded as **vacuous with LCOV proof**; Echidna is absent; Semgrep has been silent for a **third
  consecutive run** and is recorded as a **tool gap**; one Halmos path is **INCONCLUSIVE**. Mock vacuity was
  refused and pinned as an executable fact.
- **Two facts were read from mainnet rather than assumed** (D-07), read-only, at blocks 25577241 and
  25577673 — and one of them exposed a **records defect that would have misled any future run** (D-15).
- **An orchestrator error is recorded in full** (D-13): I killed a healthy classifier on a bad liveness
  signal. `classified-findings.json` survived; only `LABEL-MAP.json` was lost and was **regenerated without
  re-classifying**. **No finding was affected.**
- **A stored tooling note was corrected, not patched around** (D-14): 4naly3er's argument 3 is a **scope
  list**, not a remappings file, and `remappings.txt` resolves relative to `basePath`. The old symlink
  workaround was unnecessary **and** broken. Ran clean on all 11 files.

**Flagged for the operator, in priority order:**

1. **Two reopen proposals are now two runs old and unapplied** (`858e9e80…`, `521c20ad…`) — D-02.
2. **The fix-pending High needs a human decision** (`1c222d5485…`) — two agents disagreed; D-06.
3. **`mainnet-addresses.ts` is factually wrong about three live, funded contracts** — D-15.
4. **`58b6c486…` (ledger L-03) is unsettled** and owed to the next run — D-16.
