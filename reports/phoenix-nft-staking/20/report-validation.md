# Report Validation — phoenix-nft-staking run-20 @ `0d1a0b2`

**Scope:** the 11 individual submissions (`H-01`, `M-01`…`M-08`, `REOPEN-ledger-H-01`, `REOPEN-ledger-M-01`).
`qa-report.md`, `spec-conformance.md`, `4naly3er-report.md` and `submissions/carryover/` are owned elsewhere and were not validated here.

> **Provenance note.** This file was produced by the `report-validator` agent, which was blocked by its own harness from writing report files; the orchestrator persisted its returned findings verbatim. No content was added or removed.

---

## 1. Verdicts

| Report | Format | Citations | PoC | Severity | Verdict |
|---|---|---|---|---|---|
| H-01 | ⚠ H1 heading | ✅ | ✅ 4/4 executed | ✅ High justified | **PASS** — 2 minor edits |
| M-01 | ⚠ H1 heading | ✅ (1 wide range) | ✅ 6/6 | ✅ | **PASS** — 2 minor edits |
| M-02 | ⚠ H1 heading | ✅ | ✅ 3/3 + 6/6 | ✅ | **PASS** — 1 label fix |
| M-03 | ✅ | ✅ | ✅ 10/10 | ✅ | **PASS** — 1 factual fix |
| M-04 | ✅ | ✅ | ✅ 10/10 | ✅ | **PASS** |
| M-05 | ✅ | ✅ | ✅ 2/2 | ✅ | **PASS** |
| M-06 | ✅ | ✅ (1 wide range) | ⚠ none (disclosed) | ✅ | **PASS w/ WARN** |
| M-07 | ✅ | ✅ | ✅ PASS | ⚠ ground needs re-anchoring | **PASS** — 1 required edit |
| M-08 | ✅ | ✅ | ✅ 10/10 | ✅ (R-1 raise) | **PASS** |
| REOPEN-H-01 | ✅ | ✅ (1 wrong connective) | ✅ 4/4 + 3/3 | ✅ Medium-at-HEAD | **FAIL until corrected** |
| REOPEN-M-01 | ✅ | ✅ | ✅ 2/2 + 2/2 | ✅ Medium-at-HEAD | **FAIL until corrected** |

**Every PoC claim was executed at `0d1a0b2` and every claimed count reproduced exactly.** Every named test function exists at the exact cited line. No PoC claim overstated. The two FAILs are label + invented-patch failures, not evidence failures.

---

## 2. Errors

**E-1 — LABEL ERROR, both REOPEN reports (most damaging).** Both state the mechanic *"is already filed live in this run as M-01, M-02 and **L-07** (Low)."* Run-20 final `L-07` = `368e23fb22…`, *"Fork-drift hazard escalated to REALISED defect"* on `NFTStakerPriceScaledMigrateReady` — a **staker** finding, wrong contract family. The intended referent is **`F-20-07`** (`a7dffb34c9…`, `docs/multi-token-nudge.md`, WATCH-19 nudge-premise re-derivation). Compounded: R-4 deliberately stripped that item of any `L-xx` label, so "L-07 (Low)" also reverses R-4. No fingerprint given (R-3 breach).
→ Replace with `F-20-07 (a7dffb34…, spec-conformance, no L-label per R-4)`.

**E-2 — M-02 wrong class ID.** *"(CLASS-018 / DEDUP-20-006, currently QA)"*. DEDUP-20-006 is right; CLASS-018 is `1887dbe136…` = run-20 **L-06** (BalancerPoolerMintDebtHook, a staker Low). The FoT item is CLASS-022 → **Q-03** (`bfdb50105e…`). "Currently QA" is correct; only the pointer is wrong.

**E-3 — M-07, undisambiguated ledger label (R-3).** *"ledger L-01's severity note"* — the ledger has **five** `L-01`s. Intended is `9135cf7947…` (verified: the quoted "only value-moving reentrancy paths…" is in its `severityNote`). The run's own TRAP-3 uses bare "ledger L-01" for a *different* entry (`e7bccb029f…`). Add the fingerprint.

**E-4 — M-03 mischaracterises `PoC_DepletionRateDrift`.** The caveat says it *"covers the `unstake` path only"*. The file **never calls `unstake`** (the word appears only in a comment at `:30`); it exercises `stake` + repeated `claim()`, mint-restart, and a zero-inflow no-op. **The load-bearing half is TRUE** — it imports only `NFTStakerDepletion` and never calls `migrateIn`/`depositFor`, so it genuinely does not cover the migration path. Fix to *"the `stake`/`claim` accrual path"*, and correct the same mislabel upstream in `tier3-and-poc-validation.md` (summary row 9 and the §9 caveat).

**E-5 — H1 heading in H-01/M-01/M-02.** The other eight lack it, as does run-18 precedent. Title already in the metadata `Title:`. Delete.

**E-6 — REOPEN-H-01:** "Five lines below" → ten (`:49`→`:59`). Both citations resolve; only the connective is wrong.

**E-7 — three over-wide ranges:** M-01 `:63-70` (text at `:63-68`); M-06 `#L159-L172` (`setDispatcherIndex` is `:159-162`); REOPEN-M-01 `:285-291` (quote at `:287-291`).

**E-8 — H-01 imprecision:** *"exposes exactly two functions"* — it **declares** two; it inherits `ERC1155Holder`/`Ownable` externals. The permanence claim is fully verified (all 112 lines read: no rescue, no `receive`, no `fallback`, nothing inherited can move an ERC20). Say "declares".

**Not independently verified** (flagged, not validated): the mainnet/archive reads (internally consistent with `mainnet-verification-ECON-001.md`), the Medusa run, invariant BROKEN/PASS statuses (corroborated by `tier3-and-poc-validation.md` §10), and git story attributions.

---

## 3. Rulings on the three flagged items

### 3.1 Invented fix shape in the REOPEN reports → **DROP IT**

**(a) Marked as the writer's construction? NO — a real defect.** Neither record signals the patch is authored and unvalidated. REOPEN-M-01 calls it **"The durable fix"**. Subordination to the ledger disposition is correctly done, but subordination is not attribution — a reader cannot distinguish it from H-01's genuinely source-derived `_safePayTo` swap.

**(b) Trap collision? Not D-16 literally — but unsound on three grounds, two of them this run's own findings.** The cap reads no `balanceOf`, so TRAP-1 is escaped on the letter. However:

1. **It does not work: `totalPaid` is zero at the point of use.** `totalPaid` is `batchMint`'s named return, assigned **only at step 10** (`:384`/`:386`), *after* `_payRewards` at `:378`. Applied literally, `cap == 0` and **every nudge payout clamps to zero** — the patch disables the feature it bounds.
2. **Wrong basis even reordered.** Run-20 **Q-04** (`47f2dc3a…`) *is* "totalPaid floors at 0 on a net-positive call", and **M-01** shows the sweep setting `totalPaid = … : 0` — so the cap is smallest exactly where the pot is largest, and is caller-manipulable through a door this run files as Medium.
3. **Contradicted by M-07 in the same set:** "totalPaid under-reports the true dispatcher cost" whenever the contract's own balance funds an under-funded batch.

Plus it introduces an undeclared `maxNudgeBps` and converts winner-take-all into spend-proportional payout — a design change, PoC'd by nothing.

**Ruling: remove the Solidity block from both records.** Keep the ledger disposition (with its `alternativeIfYouDisagree` branch) and the NatSpec correction — the latter is independently sound, since `:51-61` states as a structural guarantee something this run measured counterexamples to at 9.5× and 20,000×. If a direction is kept, state it as a *property to establish* ("relate payout to realised spend"), explicitly marked unvalidated and carrying the `totalPaid` caveat. As written it would have shipped a nudge-disabling one-liner.

### 3.2 M-07's severity → **R-5 substantially satisfied; one sentence must be re-anchored**

The struck M-06 ground was pure report-management. **Upstream, R-5 was never applied to CLASS-008** — the classifier's `justification` still says *"Filing this Low beside a Medium twin creates exactly the failure this project warns about…"*, and `severity-audit.md:141-144` repeats it.

**But the writer deleted that sentence from `M-07.md`.** Two grounds remain: a standalone C4 header ground (*"permissionless, executed, PoC-proven value leak with stated assumptions and an external requirement"* — sufficient alone, references M-01 nowhere), and the bounds sentence *"The Medium rests on it being an independent surviving route to a Medium-rated pot."*

The independence claim **is** structural and verifiable — the sweep bound is at `:381-383`, the allowance bound at `:360`; patching one provably does not touch the other. That makes it a legitimate **rebuttal** to "M-01's fix will cover it", i.e. a claim about impact *durability*, which is severity-relevant in a way "a triager might skip the remedy" never is. The actor has moved from *the report* to *the code*. **This is not the old argument in a new coat.**

It still overreaches twice: saying the Medium *"rests on"* a relational property contradicts the report's own standalone header ground, and *"to a **Medium-rated** pot"* borrows severity from a sibling. **Required edit (label unchanged):**

> "The Medium rests on the standalone C4 ground above — a permissionless, PoC-proven value leak with stated assumptions and a cross-repo external requirement — not on the present balance. Independence from M-01's fix is recorded below as a do-not-collapse constraint, not as a severity ground."

Also strike the report-management shape from CLASS-008's `justification` and `severity-audit.md:141-144`, so the pipeline record stops contradicting the shipped report.

### 3.3 Label integrity → **canonical mapping upheld; 11/11 primary labels correct; 3 cross-ref errors**

**The transposition did not propagate.** `M-01 = fcaca002…` (step-10 sweep) and `M-02 = a62fe01a…` (duplicate `rewardTokens`) hold in `LABEL-MAP.json`, the ledger, `classified-findings.json`, the `findings/medium/` filenames, and both submission bodies. Every one of the 11 reports' own fingerprint matches LABEL-MAP and the ledger — verified individually, including both REOPENs against ledger `858e9e80` / `521c20ad` (both `fixed`).

**No report confuses run-20 `H-01`/`M-01` with the ledger entries of those names.** All three colliding ledger entries are fingerprinted wherever they appear; nine of eleven carry a collision banner. M-03 — which argues an incomplete fix *against* ledger `b58b172e…` — uses the full 64-char fingerprint in both body and `/ledger` commands. **M-05 deserves credit**: it names a run-20 `L-03` and a ledger `L-03` in one sentence and disambiguates both inline (verified: ledger `a18927e1` = NFTStakerDepletion; run-20 `L-03` = `b48e5bec`).

Verified-correct cross-refs: H-01→L-02 `cb1b5279…`; M-01→L-01 `919b71fd…`; M-06→ledger L-04 `d1cf8ef7…`; REOPEN-M-01→ledger L-05 `990d8c37…`; H-01→Q-02; M-02→Q-01. Errors are E-1, E-2, E-3 above — **E-1 being exactly the "fix sent to the wrong contract" outcome D-30/R-3 exists to prevent.**

---

## 4. Quality

No overstatement found; no LLM patterns. All brief-specified framing survived: H-01's four bounds + Medium-conversion condition + the L-02 re-weigh note; M-01's D-18 provenance and two-directional mainnet evidence including "no historical loss occurred via this path"; M-02's R-7 bound with an explicit instruction *against* the retracted one; M-03's D-24 both-sides arbitration with the green-replay caveat prominent; M-04/M-08's reciprocal "independent fix required" cross-refs with concrete divergences; both REOPENs' "code did not regress / story-014 pinning intact and PROVEN intact / do not revisit" framing.

**WARN:** M-06 has no PoC. It discloses this, grounds itself on a cross-repo census independently verified by the validator (`PromotionUniV2_Eth.primeToken()`→USDC `:189`, donates USDC `:340`), states the Low reading, and pre-flags itself as the trim candidate. Honest, and the most trimmable item in the run.

---

## 5. Required before submission

**Blocking:**
1. E-1 in both REOPEN reports.
2. §3.1 — delete the `totalPaid` cap block from both REOPEN reports.
3. E-2 in M-02.
4. E-4 in M-03 *and* `tier3-and-poc-validation.md`.
5. §3.2 re-anchor in M-07.

**Non-blocking:** E-3, E-5, E-6, E-7, E-8, plus striking the struck-shape language from `classified-findings.json` CLASS-008 and `severity-audit.md:141-144`.

With items 1–5 applied, all eleven reports pass.
