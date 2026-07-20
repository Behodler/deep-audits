# Validity Check — phoenix-nft-staking run-20

- **Project:** phoenix-nft-staking
- **Run:** `reports/phoenix-nft-staking-20/`
- **Commit:** `0d1a0b2187bb980f1ac6c6b54d0b01e6410a2e54` (baseline `321d0a9`)
- **Stage:** validity-check (C4 known-invalid filtering), post-severity-classification
- **Input:** `classified-findings.json` — 24 classified findings (of which 2 are the EXPIRED-CLOSURE
  reopen candidates, CLASS-009 / CLASS-010) + 2 `notClassifiedForReport` items (carryover, disclosure)
- **Evidence read:** `DECISION-LOG.md` (D-01..D-25), `sanitized-findings.json`,
  `tier3-and-poc-validation.md`, `nudge-lineage-poc-replay.md`, `faithfulness-notes.md`,
  `registered-projects.json` → `projects["phoenix-nft-staking"]`

---

## 1. Headline

| Disposition | Count |
|---|---|
| **VALID** (no known-invalid pattern matches) | **16** |
| **VALID — BOUNDARY, flagged for human review** | **8** |
| **INVALID** (matched a known-invalid pattern, carve-outs do not rescue) | **0** |
| **Total classified findings adjudicated** | **24** |
| Additional non-report items adjudicated (carryover + disclosure) | 2 (both valid routings) |

**No finding is dropped by this stage.** Every item that touches a known-invalid boundary is kept at
its filed severity with the boundary named explicitly, per Law 1 ("never silently drop a plausibly
security-relevant finding"). Eight items are flagged for human confirmation — six of them because the
*severity ceiling*, not the existence of the finding, depends on how the operator reads a carve-out.

The upstream sanitizer already suppressed **zero** of 24 and recorded four `declinedSuppressions` with
reasons. I re-derived each declined suppression independently and **concur with all four**; none of
them is a known-invalid match dressed up as a carve-out.

---

## 2. Known-invalid pattern sweep

Checked every finding against the repo `CLAUDE.md` "Known Invalid Findings" list. Pattern-by-pattern:

| C4 known-invalid pattern | Hits | Disposition |
|---|---|---|
| Non-standard / weird ERC-20 (except USDT) | 2 partial (CLASS-022, CLASS-023 leg b) | Held at QA — see §4 |
| Fee-on-transfer (unless explicitly in scope) | 2 (CLASS-022, CLASS-023 leg b) | **Explicitly in scope** via story-022 §4.4 — see §4 |
| CryptoPunks support | 0 | — |
| Approve race / `safeApprove` front-running | 0 | See §6 — CLASS-010 is MEV, not an approve race |
| User input mistakes / phishing | 0 | See §5 |
| Reckless-admin / malicious-owner | 0 asserted | 8 footguns re-tested under Law 3 — see §3 |
| Unused view functions (QA at best) | 1 (CLASS-024) | Already filed at QA — correct ceiling, see §7 |
| Speculation on future code without demonstrated root cause | 1 (CLASS-021) | Already filed at QA — correct ceiling, see §7 |
| Root cause in OOS parent/forked contract | 0 outright; 3 partial | In-scope root cause in all three — see §8 |
| Automated-tool finding without a demonstrated H/M path | 0 | 57 Aderyn centralization instances dropped at D-12; SAST-008 promoted only to QA |

**Zero findings are invalidated.** There is therefore no per-finding "why the carve-out does not
rescue it" section to write — the requested inverse (why each boundary finding *is* rescued) is below.

---

## 3. Carve-out 1 — Law 3 is not a blanket owner-suppression

### 3.1 The 8-item footgun register, re-tested individually

The Law-3 test applied to each: *would a competent, non-malicious owner or maintainer be **surprised**
by this consequence?* Surprise ⇒ footgun ⇒ in scope. Obvious ⇒ trusted ⇒ suppress.

| Class | Surprise claim | Verdict | Note |
|---|---|---|---|
| CLASS-007 (M-06) | Repointing a dispatcher **in a different repo** (`yield-claim-nft`) kills the nudge and arms a pot sweep | **GENUINE — strongest in the register** | The coupling is invisible from the side where the repoint is actually performed. story-022 *removed* the deploy-time assertion and replaced it with a per-call revert that warns the **caller**, never the operator. 2 of 3 live dispatcher candidates are unsafe. |
| CLASS-004 (M-03) | Slice ordering silently decides who gets paid from a shared budget | **GENUINE** | Non-obvious specifically because on `NFTStakerDepletion` the rate is **independent of `totalStaked`** — slice-1 users take the whole pool-wide stream. That decoupling is exactly the thing an operator would not predict. |
| CLASS-005 (M-04) | Ditto on the in-place migrator; harmed users have no visibility and no agency | **GENUINE** | The migrate-on-behalf primitive means the *user* cannot opt out. Harm falls on a party who took no action at all. |
| CLASS-011 (L-01) | Leaving the pauser slot unset makes the contract's OWN documented recovery inexecutable | **GENUINE (weakest of the eight)** | Rescued by two specifics: `DeployBatchNFTMinter.s.sol:38` lists "unset pauser" as an *expected intermediate state*, and the NatSpec prescribes "pause first, then rescue" without flagging that the sequence silently becomes unrunnable. Verified live: `pauser()==0` on **both** deployed instances. Absent the deploy-script normalisation this would be closer to an obvious misconfig; with it, it is a surprise. **Keep.** |
| CLASS-014 (L-04) | The documented "pause first" step is an **ecosystem-wide** halt; the workaround disables the circuit breaker | **GENUINE** | The blast radius is the surprise, not the pause. |
| CLASS-015 (L-05) | Rotating a pointer orphans N users' parked ERC1155 | **GENUINE** | Second-order effect a full step removed from the action. |
| CLASS-018 (L-08) | Wiring the hook before flipping its recipient bricks every user interaction on the target staker | **GENUINE** | The ordering constraint is undocumented *and* untested — the in-repo orchestrator tests never wire a recipient-guarded hook to the target. |
| CLASS-019 (L-09) | Fixing a bug in one staker clone leaves it live in three others | **GENUINE — and realised, not hypothetical** | Maintainer footgun, not owner. Materialised inside story-021's own commit. |

**8 / 8 are genuine surprise-footguns.** None is disguised malicious-owner noise.

### 3.2 No malicious-owner vector is asserted anywhere

Independently verified across all 24 findings. Every owner-touching finding is framed by the *impact
it unlocks* under a non-malicious operator. `severityDistribution.centralization == 0`. The
`footgunFraming` fields on CLASS-007, 011, 014, 015, 018, 019 each carry an explicit "no
malicious-owner vector is asserted" clause, and the framings hold up against the finding bodies.

### 3.3 Nothing valid was dismissed *as* owner-trusted

Checked in the other direction, which is the failure mode Law 1 actually cares about:

- **D-12** dropped 57 Aderyn "Centralization Risk" instances (owner control of `setTargetAPY`,
  `setDispatcherHook`, `topUp`, …). These are the *obvious* class — registry known-issue #1 states
  centralization is by design — and the count and rationale are preserved in the output JSON rather
  than in a silent log. **Correct suppression, correctly made visible.** I spot-checked that the
  non-obvious owner setters that Aderyn also touches (`setMigrator`, `setPauser`, `setDispatcherIndex`)
  were **not** swept up with them — each survives as a filed finding (CLASS-015, CLASS-014,
  CLASS-007 respectively). No footgun was lost in the D-12 drop.
- **CLASS-009 leg 2** is the most important instance of Law 3 being applied *correctly in reverse*: a
  prior closure read "residual value-blindness only exploitable via owner misconfiguration ⇒
  owner-driven ⇒ invalid". At HEAD, over-funding is not an owner action at all — `BatchNFTMinter.sol:45-46`
  documents that **anyone** can seed the pot with any ERC20 and no owner transaction is involved. Law 3
  cannot reach a facet a permissionless third-party stream reaches without the owner. This is not a
  re-litigation of Law 3; the predicate it was applied to is simply false. **Validity-checker concurs.**

---

## 4. Carve-out 2 — Fee-on-transfer (CLASS-022 / DEDUP-20-006)

**Verdict: VALID at QA. Not invalid-and-dropped, and not escalated.**

The C4 rule is "fee-on-transfer tokens **unless explicitly in scope**". story-022's
`docs/multi-token-nudge.md` §4.4 documents FoT behaviour explicitly, which places it on the spec
surface — it is no longer an undeclared token assumption. The known-invalid predicate therefore does
not fire, and dropping it would be the wrong call.

Equally, documenting a risk does not manufacture an attack path the value flow does not support. D-19's
reasoning is sound and I adopt it: the caller chooses **both** the token and the recipient, the fee
accrues to the token's own sink (no extraction by anyone), and there is **no path where A's token
choice costs an unrelated B**. That is the exact structural test that separates a real FoT finding
from the known-invalid class, and it resolves to QA.

**On the failing Tier-3 `invariant_fotFloor`** (delivered 95e18 vs declared floor 100e18;
`fotListedWithFloor: 11` in the census, so the path was genuinely exercised — not a vacuous harness):
this is precisely why **suppression would have been the wrong outcome**. A proven-broken invariant with
no finding to live in is a Law-1 violation waiting to happen next run. The executed failure is
correctly recorded on the finding as a `tier3Rider` **without** changing the disposition — the
invariant measures a payout-vs-delivered gap that is real, on an asset the protocol does not use,
borne by a recipient the caller selected. Broken-invariant ≠ automatic Medium.

Noted for the fix stage, not for validity: the D-16 clamp
`min(snapshot[i], balanceOf(this) - paidThisPass)` that fixes CLASS-003 **also** closes this gap, so
the two must be evaluated jointly.

---

## 5. Carve-out 3 — CLASS-020 / DEDUP-20-008 and the `test/` exclusion

**Verdict: VALID at QA. `outOfScope: ["test/"]` does NOT reach it.** Flagged for human confirmation,
consistent with the sanitizer's own recommendation.

Reasoning, stated as a rule rather than a one-off:

> `test/` in an `outOfScope` array excludes **hunting for vulnerabilities located inside test code**.
> It does not immunise the **assurance claim** the suite makes about in-scope code.

A finding whose subject is "`src/` contract X is unsafe, and here is the bug in `test/Y.t.sol` that
lets an attacker exploit the test harness" is out of scope — nobody deploys the harness. A finding
whose subject is "**the certification is false** — the witness for §4.5 passes without ever exercising
§4.5's premise" is a finding **about in-scope code's assurance status**, and its file path is
incidental. The blast radius is entirely in `src/`.

The concrete facts make this unambiguous rather than a judgement call:

- `test_DuplicateRewardTokenFailsClosed` calls `_fundPots()` only and never calls
  `nftMinter.setPerMintDonations(...)`, so it runs at **D == 0** — the single configuration in which
  the "fails closed" claim happens to be true.
- It passes green **while CLASS-003 (Medium) is live** on exactly the property it claims to certify.
- The omission is **inconsistent within the same file**: the sibling §4.2 witnesses *do* configure
  donations. This is not a deliberate scoping choice by the author.
- This project has a recorded prior instance of exactly this failure mode (the "vacuous invariant
  harness" memory: a test that passes `0 == 0`).

Suppressing it would also destroy a real property of the fix: merging it into CLASS-003 lets the
**coverage regression vanish the moment the code fix lands**, leaving the suite permanently unable to
catch the class again. The `doNotCollapseWith: ["DEDUP-20-001"]` marker is correct and must survive.

**Same reading applies to CLASS-021 (Q-02)**, which is filed against `src/` but is likewise a
test-coverage defect (`MockERC1155.mint()` is a bare balance write that skips
`_checkOnERC1155Received` entirely, so §4.3 is certified by a witness that never reaches the hook it
was written for). Adjudicate both under the same rule.

**Human confirmation asked for:** ratify the narrow reading of `outOfScope: ["test/"]` above. If the
operator instead intends the broad reading ("nothing in `test/` is ever reportable"), CLASS-020 drops
to a non-finding — but say so explicitly, because it also drops the §4.5 tripwire and CLASS-021's.

---

## 6. Carve-out 4 — the two EXPIRED-CLOSURE reopen candidates

**CLASS-009 (ledger H-01 `858e9e80…`, currently `fixed`) — VALID and reportable.**
**CLASS-010 (ledger M-01 `521c20ad…`, currently `fixed`, owner-triaged 2026-06-09) — VALID and reportable.**

Three known-invalid patterns could plausibly have reached these. None does:

1. **"Speculation on future code without demonstrated root cause" — does not fire.** These rest on
   **11/11 passing PoCs at HEAD** (`PoC_NudgeLineage_H01` 4/4, `PoC_NudgeLineage_NudgeDrain` 3/3,
   `PoC_NudgeLineage_MevFrontrunNudge` 2/2, `PoC_NudgeLineage_M01PriceInflation` 2/2), all at
   `0d1a0b2`, with source lines read verbatim from `lib/`. The root cause is demonstrated by
   execution, not projected. The premises they falsify are falsified **empirically** (pot-vs-cost at
   9.5× and 20,000×; realizability at 12.58 phUSD claimed in 30 days from ratchet-minted NFTs).
2. **"Issues already in the project's known issues section" — does not fire.** Both entries are
   `fixed`, not `acknowledged` and not `wont-fix`. Per the repo's own `fix-pending` vs `acknowledged`
   distinction, only a **human disposal** suppresses; `fixed` is an assertion that the defect is gone,
   and an assertion of fact is falsifiable. Both are falsified here.
3. **"Reckless admin" / owner-driven — does not fire**, and for CLASS-009 this is the whole point.
   See §3.3: the closure's own "⇒ owner-driven ⇒ invalid" inference fails on its premise at HEAD.

Two further properties I checked and confirm:

- **No double-counting.** CLASS-009 explicitly mints no new finding — the mechanic is already filed
  live as CLASS-002, CLASS-003 and CLASS-019. It is a **ledger-side** consequence: an entry whose
  `fixed` status is no longer supported. Both artefacts are genuinely needed; fixing the report
  without touching the ledger leaves two entries reading as done. This is not report padding.
- **Bounding honesty is present and correct.** Neither asserts a code regression. story-014's
  owner-pinning of the minter and `dispatcherIndex` is **intact and proven intact**
  (`test_AttackerCannotChooseACheapDispatcher_VariantA_IS_CLOSED`), and both entries say so and warn
  against disturbing it. Present on-chain exposure is zero per D-22's read-only mainnet reads. No
  principal theft appears in any of the 11 tests. The findings are honest about all of this.

**CLASS-010 additionally carries an owner-signed 2026-06-09 triage.** That raises the disclosure bar,
not the validity bar, and the disclosure obligation is discharged: all four premises are enumerated,
P1 is conceded as still holding, and the P4 mitigation is bounded honestly rather than dismissed
(`test_M01_minRewardsFloorDoesNotStopTheFrontRun` shows the floor *does* spare the loser's capital —
it is narrower than "fully closed", not absent). This meets the standing "disclose when re-filing an
owner wont-fix" rule.

**Not an approve race.** CLASS-010 is MEV front-running of a public incentive pot in an ordinary gas
auction. The C4 known-invalid is specifically the ERC-20 approve/`safeApprove` race, which has no
bearing here. Do not conflate them.

Both correctly carry `humanMustPick: true`. As the classifier notes and I endorse: **leaving either
entry `fixed` is wrong under either reading** — if the residual is acceptable, re-close it as
`acknowledged`/`wont-fix` with a rationale written against HEAD's premises.

---

## 7. Carve-out 5 — findings resting on hostile / weird ERC-20s

The multi-token nudge lets the caller supply an arbitrary token list, so this needed a
finding-by-finding split. **D-21's refutation is load-bearing and I adopt it:** `IERC20.balanceOf` is
`view`, so solc emits a **STATICCALL** at `BatchNFTMinter.sol:429` — the pre-loop snapshot read cannot
mutate state (proven by execution: a storage-writing `balanceOf` bricks the batch). The only mutative
hostile-token hook is `safeTransfer` at `:458`. This halves the hostile-token surface the contract
profile had assumed and kills any finding that would have needed a reentrant snapshot.

| Finding | Needs a weird token? | Verdict |
|---|---|---|
| CLASS-002 (M-01, whole-balance sweep) | **No** — plain USDC; mainnet-verified `primeToken() == canonical USDC` | VALID |
| CLASS-003 (M-02, duplicate rewardTokens) | **No** — plain USDC on the real mainnet shape (BalancerPoolerV2, USDS prime, USDC cut) | VALID |
| CLASS-008 (M-07, max-allowance under-funded batch) | **No** — plain payment token | VALID |
| CLASS-009 / CLASS-010 (reopen candidates) | **No** — value-blind count gate and MEV; token-agnostic | VALID |
| CLASS-022 (Q-03) | **Yes** — FoT / negatively-rebasing | VALID at QA under §4 carve-out |
| CLASS-023 (Q-04) leg (b), `NudgePaid` over-reports delivery | **Yes** — FoT / rebasing | Rides the same §4 carve-out; QA |
| CLASS-023 (Q-04) leg (a), `totalPaid` floors at 0 | **No** — fires on plain USDC whenever the contract holds a prior balance | VALID independently |
| CLASS-021 (Q-02) | **No** — the surface is the **ERC1155 receiver hook**, not a hostile ERC-20 | VALID at QA |

Nothing High or Medium in this run depends on a weird ERC-20. Both Mediums on the batch minter work
with plain USDC. **CLASS-023 is explicitly kept whole** — leg (a) is FoT-independent, so the finding
survives even under the strictest reading of the FoT rule; do not let leg (b) drag the whole item into
the invalid bucket.

---

## 8. Scope check — root cause location

Three findings have a trigger or a dependency that lives outside `src/`. In **all three the root cause
is in in-scope first-party code**, so the "root cause in an OOS parent/forked contract" rule does not
reach them. Flagged so the reasoning is on the record rather than assumed.

| Finding | External element | Where the root cause actually is | Verdict |
|---|---|---|---|
| CLASS-007 (M-06) | The repoint is performed in the **sibling repo** `yield-claim-nft` (`NFTMinterV2.replaceDispatcher`) | `src/BatchNFTMinter.sol` — the **removed** deploy-time guard and the live-derived `primeToken()` exclusion key. The missing operator-facing assertion is owed *here*. | VALID |
| CLASS-014 (L-04) | The ecosystem-wide `Pauser` contract is in `lib/` (OOS) | `src/NFTStakerPriceScaledMigrateReady.sol` — the ungated `setPauser` leg and the runbook step this contract's own documentation prescribes. | VALID (boundary — see below) |
| CLASS-017 / CLASS-018 (L-07 / L-08) | The reverting hook (`BalancerPoolerMintDebtHook`) lives in `yield-claim-nft` | The in-scope staker's **un-try/catch'd dependence** on it inside the only path back to `Active` (`finalizeAndReset`) and on every `_syncBudget` path. The defect is the unguarded dependence, not the hook. | VALID |

**Boundary flag on CLASS-014:** one leg — "breaks the `Pauser`'s register/unregister invariant
(`Pauser.register` validates `pausable.pauser() == address(this)`)" — describes an invariant that lives
in OOS code. The *violating action* (`setPauser` on the in-scope staker) is in scope, so the finding
stands, but if a reviewer wants to trim it, that clause is the trimmable part. The availability leg
(ecosystem-wide halt) is unaffected and is the finding's real weight.

Also confirmed: `src/INFTSupply.sol` is in `outOfScope` and no finding is filed against it. No finding
is filed against `lib/`, `lib/mutable/` or `lib/immutable/`. `docs/multi-token-nudge.md` (CLASS-012)
is **not** in any exclusion list.

---

## 9. Boundary calls — the 8 flagged for human review

None of these is a proposal to drop a finding. Each is a place where a known-invalid boundary sets a
**ceiling** the operator should ratify.

| # | Class | Boundary | Ask |
|---|---|---|---|
| 1 | CLASS-020 (Q-01) | `outOfScope: ["test/"]` vs false-certification | Ratify the narrow reading (§5). **Recommend: narrow.** |
| 2 | CLASS-021 (Q-02) | Same scope rule + "speculation on future code" | Valid **as QA only**. The exposure is explicitly future ("any change dropping `nonReentrant` re-opens the surface"), and the guard is *proven* to hold today by execution. As a missing-regression-tripwire item it is legitimate; **if it is ever escalated above QA it becomes invalid** under the speculation rule. Ceiling: QA. |
| 3 | CLASS-024 (Q-05) | "Unused view functions (QA at best)" | The finding's own text concedes a grep of `src/` finds **no on-chain consumer** of the inflated `pendingReward` / `currentRewardRate` / `runwaySeconds` reads. That is the unused-view pattern squarely. It is already filed at QA, which is exactly the ceiling the rule permits — and the remedy is free and behaviour-preserving. **Valid at QA; invalid at Low or above.** Ceiling: QA. |
| 4 | CLASS-022 (Q-03) | Fee-on-transfer | §4. Valid at QA; do not escalate on `invariant_fotFloor` alone (binding constraint 1b). |
| 5 | CLASS-023 (Q-04) | FoT leg (b) | Keep whole; leg (a) is FoT-independent (§7). |
| 6 | CLASS-012 (L-02) | Documentation-vs-code discrepancy | Valid, but its correct home is the **spec-conformance report** (F-20-07), not a security Low. It claims no standalone loss and explicitly avoids double-counting CLASS-002/003. If it were reframed as an independent security Low it would become an overstatement. **Routing, not validity.** |
| 7 | CLASS-014 (L-04) | Partial OOS root cause on the registry-invariant leg | §8. Finding stands; that one clause is trimmable. |
| 8 | CLASS-011 (L-01) | Weakest of the 8 footguns — is "unset pauser" an *obvious* misconfig? | §3.1. Rescued by the deploy script listing it as an expected intermediate state and by the NatSpec not flagging the consequence. **Recommend: keep.** It is also the run's one **live-mainnet operator action item** (`pauser()==0` on both instances; `0x86866e01…` holds 219.99 USDC), so the cost of wrongly dropping it is asymmetric. |

---

## 10. Non-report items

| Item | Routing | Validity verdict |
|---|---|---|
| DEDUP-20-022 (carryover, ledger L-02 `e35388bf…`, status `submitted`) | finding-manager only — carryover stub, not re-reported | **VALID routing.** Unbounded caller-sized loops, self-DoS only, now spec-blessed by §4.5. `submitted` is an awaiting-triage status, not a human disposal, so it is treated as `open` and gets a stub — correct. Not a known-invalid match. |
| DEDUP-20-023 (disclosure against ledger M-02 `911c54fd…`, `wont-fix`, owner-acked 2026-06-09) | finding-manager only — ledger note; neither a suppression nor a re-file | **VALID routing, and the only defensible one.** Prong (b) of the owner's rationale ("there is no `depositFor` / migrator role / batch") is **factually false on copy #4**, which adds both. Assigning a severity here would be the silent override the standing "disclose when re-filing an owner wont-fix" rule forbids; suppressing it under M-02 would hide a dead premise. Withholding severity is deliberate and correct. The unresolved econ-scanner-vs-pattern-matcher conflict is preserved verbatim for arbitration. |

---

## 11. Findings for the record

1. **Zero invalid findings.** Unusual, and worth stating plainly: this run's upstream stages (dedup →
   sanitize → classify) had already applied the known-invalid list, and the two places where a
   suppression was genuinely tempting — FoT (D-19) and the `test/` witness — were both reasoned in
   both directions and recorded rather than resolved by default. I re-derived both independently and
   reached the same answers.
2. **The Law-3 register is clean in both directions.** 8/8 footguns are genuine surprises; 0
   malicious-owner vectors; the 57 obvious-centralization instances were dropped visibly (D-12) and
   the non-obvious setters were **not** swept up with them.
3. **Three findings carry an explicit QA ceiling that is load-bearing** (CLASS-021, CLASS-024, and
   CLASS-022). Each is valid where it sits and would become a known-invalid match if escalated. If a
   later stage proposes escalating any of the three, that proposal must come back through validity.
4. **CLASS-023 must not be collapsed on its FoT leg.** Leg (a) survives on plain USDC.
5. **Nothing High or Medium depends on a weird ERC-20.** D-21's STATICCALL refutation should be
   inherited by future runs rather than re-derived.

---

*Stage verdict: **24 / 24 findings PASS validity.** 16 clean, 8 boundary-with-ceiling, 0 invalid,
0 dropped. Proceed to report-writing; carry the 8 boundary notes into the human-arbitration queue.*
