<!--
Spec-Conformance / Law-2 Report
Project: phoenix-nft-staking @ 5015f1b (run-25)
Baseline: d75229d
Story in range: story-029 (commits 8f3b982 RED, 0318089 GREEN, 9bef5a6 invariants, 5015f1b measured budget)
Sources: scan-faithfulness.md (F-25-01..04), findings-deduped.md (DEDUP-25-05, DEDUP-25-11)
Scope note: this report is SEPARATE from the QA bundle. Faithfulness is Law 2, not gas/style noise.
-->

# Spec-Conformance Report (Law 2) — phoenix-nft-staking run-25

> ## ⚠ SUPERSEDED IN PART — M-01 AND M-02 WITHDRAWN (2026-07-26)
>
> **Run-25 `M-01` (`pns25m1` / `DEDUP-25-01` / ledger `96823199d298…`) and `M-02` (`pns25m2` /
> `DEDUP-25-02` / ledger `c7a410602b29…`) were WITHDRAWN by owner correction on 2026-07-26 and are
> now ledger status `false-positive`.** Every reference below that treats M-01 or M-02 as a live
> Medium — including cross-references, re-weigh recommendations, KI-scope determinations and
> "value is priced in M-01" pointers — is **superseded**. See `submissions/M-01.md` for the full
> reasoning.
>
> **In one line:** the nudge pot is funded by *externally-derived yield on protocol-owned capital*,
> never principal and never user deposits, so a pot exceeding one qualifying batch's cost is an
> accepted **subsidy rate / marketing spend** (opportunity cost), not a value leak. `NudgeStreamer`
> meters release so the market finds a clearing price; empirically the pot has never once reached
> 50 % of the qualifying cost before someone minted. Recorded as `registered-projects.json` **KI #16**.
>
> **Still reportable (Law 1 — narrow suppression):** (a) the pot leaving without `nudgeSize` real
> mints paid; (b) `refund > paymentAmount`; (c) a non-qualifying batch extracting pot-sized value;
> (d) **a claimant taking other users' money** — which is why **M-03 survives** (forfeited sub-dust
> residue is other callers' money), re-weigh to **Low** *proposed*, not applied.
>
> **Run-25's reading of KI #15 carve-out (d) was too broad** — (d) covers *accidental* over-funding,
> not a deliberately-set subsidy rate. Every MR-05 / "re-weigh" / "acceptance-scope drift"
> recommendation below that rests on that reading is **withdrawn**.
>
> **Ledger entries `43e8c48626ee…` and `858e9e807abe…` are untouched** — run-25's re-weigh of them
> is **withdrawn**; their `wont-fix` rationale stands unchallenged. The **surviving accurate residue**
> of M-01 is the documentation mismatch already filed as **L-02** (`75305ec0…` / `a7dffb34…`), whose
> correct fix is to **restate the sentence as a subsidy policy, not to add a code bound** — and no
> value claim attaches to it.

---

- **Project**: `phoenix-nft-staking` @ `5015f1b`
- **Baseline**: `d75229d`
- **Story in range**: `story-029`, the sole story in the audited range, delivered over four commits — `8f3b982` (RED), `0318089` (GREEN), `9bef5a6` (invariants), `5015f1b` (measured budget)
- **Spec sources**: the four commit bodies; `lib/phoenix-nft-staking/docs/multi-token-nudge.md` (rewritten this range); `lib/phoenix-nft-staking/CLAUDE.md`; `registered-projects.json` KI #15

**Why this report is not part of the QA bundle.** Faithfulness to stories is Law 2 of the audit charter. A deviation between what a story says and what the code does is a defect of intent, not a style nit, and it is read by a different audience — the person who wrote the story. Bundling it with gas and hardening notes buries it. Findings here carry no `L-xx` security label unless they also have asset/value/availability impact, in which case that impact is filed and priced **once**, in the security stream, and cross-referenced from here.

---

## 1. Verdict — story-029's implementation is faithful, and the evidence is empirical

**This is the headline result of the range and it should not be read past.**

Story-029's implementation was checked against **seven** enumerated claims drawn from the four commit bodies. **All seven confirmed at source**; the two that make empirical assertions were **reproduced**, not taken on trust.

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | `budget = min(delta, paymentAmount)` brackets **only** the step-5 transfer; bracketing the mint loop is prohibited | **CONFIRMED** | `src/BatchNFTMinterMultiToken.sol:575-581`; no `balanceOf` call exists anywhere between `:581` and `:631` |
| 2 | Per-mint `forceApprove(minter, price)` is **absolute**, `price` re-read from `configs()` every iteration, allowance zeroed after the loop | **CONFIRMED** | `:621-627`, `:631`; no local ramp arithmetic exists in the file — the commit's "the optimisation of computing the ramp locally was NOT taken" is literally true |
| 3 | Steps 9/10 swapped (refund before payout) **and** `totalPaid`'s `>` floor guard absent | **CONFIRMED** | refund `:659-668` precedes `_payRewards` `:678`; `:664` is a bare `paymentAmount - refund` |
| 4 | Runtime payment-token skip removed from `_snapshotRewards`, floor live; `setNudgeTokenWhitelist` revert retained as defence-in-depth only | **CONFIRMED** | `:749-765` (no `continue`, no `paymentToken` comparison, floor at `:760`); `:315-327`, with the in-code demotion at `:319-323` |
| 5 | `src/BatchNFTMinter.sol`, `test/BatchNFTMinter.t.sol`, `test/BatchNFTMinterNudge.t.sol` byte-identical to `d75229d` | **CONFIRMED** | identical blob hashes at both commits (`eb8cf65f`, `af2d812e`, `86983422`) |
| 6 | "531 tests green; invariants 128k calls per run"; reverting step 5 turns the taxed run red and leaves baseline green | **CONFIRMED, reproduced** | §1.1, §1.2 |
| 7 | `afterInvariant` tripwires prevent vacuous passes | **CONFIRMED, mutation-proven load-bearing** | §1.3 |

### 1.1 Test and invariant evidence — measured, not asserted

Run from `workspace/phoenix-nft-staking` @ `5015f1b` (never `lib/`), excluding audit-authored untracked files:

```
Ran 36 test suites: 535 tests passed, 0 failed, 0 skipped (535 total)
```

531 unit tests + 4 invariant tests = **535**. The commit's counts are accurate.

Both invariant contracts, full campaign:

```
BatchNFTMinterMultiTokenTaxedBudgetInvariantTest
  [PASS] invariant_PotOnlyLeavesViaQualifyingPayout   (runs: 256, calls: 128000)
  [PASS] invariant_RefundNeverExceedsPaymentAmount    (runs: 256, calls: 128000)
BatchNFTMinterMultiTokenBudgetInvariantTest
  [PASS] invariant_PotOnlyLeavesViaQualifyingPayout   (runs: 256, calls: 128000)
  [PASS] invariant_RefundNeverExceedsPaymentAmount    (runs: 256, calls: 128000)
```

**128,000 calls per run per invariant, in both configurations, both green.**

### 1.2 The fix is mutation-proven load-bearing

Replacing `:577-580` with the pre-`5015f1b` shape `budget = paymentAmount;`:

```
BatchNFTMinterMultiTokenTaxedBudgetInvariantTest
  [FAIL: the nudge pot moved by something other than 0 (non-qualifying) or -P (qualifying)]
  [FAIL: refund exceeded paymentAmount (or totalPaid disagreed with it) for some fuzzed batch]
BatchNFTMinterMultiTokenBudgetInvariantTest
  [PASS] ... [PASS]
```

Exactly as the commit claims: the measured-credit step 5 is load-bearing, and the taxed configuration is the witness that proves it. Source restored after the experiment.

### 1.3 The invariant harness is **not** vacuous — and this project has a history that made that worth checking

This project has previously shipped a harness whose mock never failed, so its invariants passed as `0 == 0`. That shape was specifically hunted for here and is **absent**. Two further mutation experiments confirmed the tripwires fire:

| Mutation | Observed |
|---|---|
| `c.nudge = 0` always (`:151`) — qualifying branch unreachable | `[FAIL: TRIPWIRE: the qualifying payout branch was never exercised: 0 <= 0]` on **all 4** tests |
| `c.paymentAmount = c.cost + quoteDelta` always (`:163-164`) — no under-quote | `[FAIL: TRIPWIRE: an under-quoted batch never reverted, so the budget bound was never hit: 0 <= 0]` on the baseline contract |

Structurally, too: violations are recorded into **sticky booleans** (`:73`, `:76`) so a bad sequence cannot be masked by a later good one; pot integrity is asserted **exactly** (`:210-214`, reconstructing `pot + D − refund` from outside and comparing for equality) rather than as a bound — a bound-only assertion is the classic vacuous shape; `totalPaid != paymentAmount - refundSent` is checked alongside the refund bound (`:201`) so "refund nothing" cannot satisfy it; and the revert branch asserts **atomicity** (`:181-182`), proving a reverted batch moves nothing rather than merely reverting.

### 1.4 `ycn19h1` is genuinely closed at its root

The refund's source of truth moved from `balanceOf` to a tracked budget. The non-qualifying 1-wei drain is **dead** — `test_PaymentTokenAsNudge_nonQualifyingBatchTakesNothing` and `test_control_beforeRepoint_count1_capturesNothing` both pass, and the outcome is structurally excluded by `invariant_PotOnlyLeavesViaQualifyingPayout` across 128,000 calls.

KI #15's carve-outs (a), (b) and (c) are correspondingly clean: no path lets the pot leave without `nudgeSize` real mints; `refund > paymentAmount` is invariant-proven impossible; a non-qualifying batch takes nothing.

### 1.5 No regression of earlier stories

| Check | Verdict |
|---|---|
| Contradicts any explicit story acceptance criterion? | **No** — all 7 claims confirmed |
| Silently regressed an earlier story's guarantee? | **No** — §4.2 donate-forward (story-022/025) intact and pinned by `test_OwnDonationsDoNotRefundToBatcher`; snapshot-before-pull ordering intact at `:535` → `:578` |
| Did the frozen twin `BatchNFTMinter.sol` move? | **No** — blob-identical. (Its *divergence by omission* is a security watch-note, filed as QA `L-04`, not a Law-2 deviation.) |
| CLAUDE.md Critical Invariants affected? | **No** — they govern `NFTStaker`, untouched this range |
| Undocumented intent? | **None.** story-029 is unusually well specified — four commit bodies, a rewritten design-doc section, and an owner decision record. No acceptance criteria were invented. |

---

## 2. Deviations

Four entries follow. **One is a defect in a story's own justification; three are defects in the design document.** None is a code deviation — that is the point of §1.

---

### F-25-01 — Unsafe story: story-029's safety rationale is an invariant no code enforces (Law 1 over Law 2)

- **Type**: `story-unsafe` · **faithfulness**: **true (the code matches the story)** · **securityEscalation**: **true** · **law impacted**: **1**
- **Story**: `story-029` · **Location**: `src/BatchNFTMinterMultiToken.sol` :: `_snapshotRewards` `:749-765`, gate `:507-511`, payout `:790`
- **Cross-reference**: ~~**M-01 (`pns25m1`)**~~ — ⛔ **M-01 WAS WITHDRAWN 2026-07-26 (false-positive).** The value consequence this deferred to **no longer exists**; it is not merely deferred, it is **vacated**. What survives is the documentation-versus-code discrepancy only, at Low. ⚠ **This is the story-side framing of that Medium and MUST NOT be counted as a separate finding.** The value consequence is priced once, in `M-01`.

**Spec text** — commit `0318089` §3.2, verbatim:

> "Removes the runtime payment-token skip from `_snapshotRewards` and drops the now-unused `paymentToken` parameter. **The payment token is snapshotted, floor-checked and paid out like every other whitelisted token**, and its `minRewards` floor is live instead of silently ignored."

Corroborated by `docs/multi-token-nudge.md:200` (*"The payment token MAY be a reward token — SAFE BY CONSTRUCTION (story 029)"*) and by the repo's own passing test `test/PoC_PaymentTokenCollision.t.sol:354-368`, which asserts `assertEq(usdc.balanceOf(nftRecipient), pot)` — the **whole pot** to the recipient.

**Actual behaviour**: exactly what the story asks for. `:758` snapshots the payment token's pre-pull balance; `:790` transfers it in full to a caller-chosen `recipient` on any batch satisfying the count-only gate at `:510`.

**Did the implementation overshoot the intent? No.** This was the explicit question put to the scan and the answer is negative on three independent readings: the commit says "paid out like every other whitelisted token"; the falsified test was **renamed** `RuntimePaymentTokenCollisionIsSkippedNotReverted` → **`IsPaidNotSkipped`**; and the repo ships a test asserting the whole pot is paid. The story wanted both the floor live **and** the full pot payable.

**Where the deviation actually is**: not in the code — in **the story's own justification**. story-029 is safe only under the premise it inherits from `docs/multi-token-nudge.md:56-60` and KI #15: *"the pot is by construction a fraction of the cost of the `nudgeSize` mints required to qualify."* No code establishes that relation (see **L-02** below). The story therefore adds a pool to Σ(pots) while relying on a bound the codebase does not contain, and that pool is re-fed by `NudgeRatchet._dispatch` forwarding 100 % of every mint's payment back into it, so the inequality re-arms itself. At the project's own fixture, Σ(pots)/cost = **200 / 50 = 4×**.

> ⚠ **"Faithful" must not be read as "blessed."** Law 2 says implement the story; the implementation did, exactly and demonstrably. Law 1 overrides Law 2: an unsafe *intent* is **escalated, not blessed**. A future reader who takes §1 of this report as an all-clear and stops there will have inverted the law hierarchy. The correct summary of story-029 is: *the code does what the story said, and the story said something whose safety argument is unsupported.*

**Scope discipline vs KI #15** — this is filed **inside** KI #15's own carve-out, not against its suppression:

- **NOT filed**: "batching is profitable", "the pot is sniped by MEV bots", "payment token should not be whitelisted as a nudge token", "`setNudgeTokenWhitelist` no longer rejects the payment token". All four are suppressed and none appears anywhere in this report.
- **Filed under carve-out (d)**: *"the aggregate over-funding class … which is about the pot being too LARGE relative to cost — a different claim from the comparison being easy."* The delta story-029 supplies is exactly a new pool entering Σ.

**Remediation** (shared with L-02): cap the total nudge payout against the payment actually charged this batch — `paymentAmount - refund` is already computed at `:664`. That turns the sentence in §1 of the design doc into an actual construction.

---

### L-02 (`pns25l2`) — `docs/multi-token-nudge.md` states a security guarantee the contract does not implement

- **Type**: `invariant-violation` · **faithfulness**: true · **securityEscalation**: false · **law impacted**: **2**
- **Severity**: **Low / QA** · **Location**: `docs/multi-token-nudge.md:56-60` and `:299-302` ↔ `src/BatchNFTMinterMultiToken.sol:507-511`
- **Sources**: ECON-006 + F-25-02, converged; filed once, here.
- ⚠ **STILL-OPEN RECURRENCE, NOT A NEW FINDING.** This is `DEDUP-25-05` reconciling to two **existing open ledger entries** — `75305ec0242b…` (L-04, the **code** site) and `a7dffb34c990…` (F-20-07, the **doc** site). No new fingerprint was minted; only `lastSeenRun` was bumped. Both prior reports are carried forward **in full** under `submissions/carryover/`.

**Spec text** (`docs/multi-token-nudge.md:56-60`, verbatim):

> "The pot is a *nudge*: **by construction** it is a fraction of the cost of the `nudgeSize` mints required to qualify. A bot that claims it must first pay more payment-token into the protocol than it extracts in reward. **Every claim is net-positive for the protocol; there is no configuration of this mechanism under which claiming is profitable-in-isolation.**"

and `:299-302` — offered as the **ground for the 2026-07-25 owner acceptance**:

> "That is intended: the pot is by construction a fraction of the cost of the qualifying mints, so every claim is net-positive for the protocol. Making the comparison legible does not change the economics."

**Actual behaviour**:

```solidity
qualifies = _nudgeSize != 0 && count >= _nudgeSize;   // :510
```

`qualifies` reads `count` and `nudgeSize` and **nothing else**. It never reads `paymentAmount`, `price`, `budget`, or `snapshot[i]`. **No expression anywhere in the file relates the pot to the cost.** Stated plainly: **a count is compared to a count, and a value is paid out** — the two quantities never appear in the same expression.

"By construction" therefore names a construction that does not exist, and the universally-quantified clause — *"there is no configuration … under which claiming is profitable-in-isolation"* — is refuted twice over from inside the repository:

1. by the project's **own fixture** (`test/PoC_PaymentTokenCollision.t.sol`: pot **200.000000** USDC against a qualifying cost of **50.000000** USDC) and its own passing assertion at `:354-368`;
2. by **INV-25-01**, this run's invariant campaign.

**Aggravating**: the §4.6 fallback backstop — *"qualifying still costs `nudgeSize` real mints at the ramping price"* — is **void at `growthBasisPoints == 0`**, which is precisely how the project's own ratchet index is configured (`setConfig(RATCHET_INDEX, RATCHET_PRICE, 0)`, `PoC_PaymentTokenCollision.t.sol:112`; the test comments confirm *"growth is 0 on this index"*). The stated fallback does not fall back.

> ⚠ **No value claim is made here, deliberately.** ~~The value consequence of the unenforced bound is priced in **M-01 (`pns25m1`) only**.~~ ⛔ **UPDATED 2026-07-26: M-01 is WITHDRAWN (false-positive), so there is no value consequence anywhere — the pot is a funded subsidy, not a leak. The value claim is VACATED, not relocated. Do not re-attach it here or re-rate this entry upward.** Ledger `75305ec0…`'s note records that this anti-double-counting split is load-bearing and forbids re-adding a value claim to it; that instruction is honoured. This entry asserts a documentation-versus-code discrepancy and nothing more.

**Deviation**: the documentation asserts an **enforced** invariant; the code enforces nothing of the kind. An operator curating the nudge-token whitelist against these docs will believe a bound exists that does not. A doc that misstates a security property is a Law-2 deviation in its own right.

**Remediation** — ⛔ **CORRECTED 2026-07-26: the value-aware-cap option is WRONG and must not be implemented** (a code bound on the payout would break the intended subsidy mechanism; M-01 is withdrawn). **The correct fix is documentation-only: restate the sentence as a subsidy policy** — e.g. *"the pot is funded from protocol yield and is sized as a subsidy; it is expected to be claimed, and `NudgeStreamer` meters release so the market clears it."* ~~(single shared fix with F-25-01 / M-01): either make the payout value-aware — cap the total nudge payout against `paymentAmount - refund`, already computed at `:664`, which *turns the sentence into a construction* — **or** rewrite the sentence to say what is true: *the relation is an operational funding discipline, unenforced by the contract, and must be monitored, with a named owner.*

---

### Q-03 (`pns25q3`) — §4.1's "SAFE BY CONSTRUCTION" heading is broader than the construction story-029 actually built

- **Type**: `faithfulness` · **faithfulness**: true · **securityEscalation**: false · **law impacted**: **2**
- **Severity**: **QA** · **Location**: `docs/multi-token-nudge.md:200`, `:213` · **Source**: F-25-03 / `DEDUP-25-11`

**Spec text** (verbatim):

> "### 4.1 The payment token MAY be a reward token — **SAFE BY CONSTRUCTION** (story 029)"
>
> "**The construct is now permitted and safe, not forbidden.**"

**Actual behaviour**: what story-029 established *by construction* — and what §1 of this report independently verified and invariant-proved — is precisely **two** properties:

1. `refund <= budget <= paymentAmount` — the pot cannot leave through the **refund** path;
2. the minter's allowance bounded at the **exact per-mint price**, written absolutely each iteration and zeroed after the loop.

Both are real. Both are proven. The section **body** scopes itself correctly to those two. The **heading and the standalone sentence do not**: they read as an unconditional blessing of the collision configuration, while the residual exposure lives in the **third** exit path — the qualifying payout at `:790` — which **no construction bounds** (that is L-02 / M-01).

This is the *mirror image* of the same section's own self-correction, which deletes a previously false claim and says so. The section is otherwise a model of honest revision; the heading simply did not receive the same treatment.

**Suggested rewording** (from `findings-deduped.md`):

> "the payment token MAY be a reward token — **the refund path** is safe by construction (story 029); **the payout path** remains bounded only by funding discipline (§1)."

---

### F-25-04 — The sub-threshold dust paragraph omits that `totalPaid` misreports the residue

- **Type**: `faithfulness` · **faithfulness**: true · **securityEscalation**: false · **law impacted**: **2**
- **Severity**: **QA (disclosure gap only)** · **Location**: `docs/multi-token-nudge.md:305-310` ↔ `src/BatchNFTMinterMultiToken.sol:659-668`, misreport at `:666`
- **Cross-reference**: **the value consequence and its 6-decimal magnitude are owned by QA `L-01` (`pns25l1`)** (CODE-001 / ECON-005). This entry records **only** the disclosure gap.

**Spec text** (verbatim):

> "**Sub-threshold dust.** Payment-token residue below `DUST_THRESHOLD`, and any third-party donation of payment token, are no longer swept to the next caller. They are not that caller's budget, so they stay behind as pot — which is the correct owner for them, and which is what the `DUST_THRESHOLD` floor was achieving in spirit all along."

**Actual behaviour**: correct as far as it goes — but the same branch also executes

```solidity
totalPaid = paymentAmount;      // :666
```

so the return value reports the caller spent their **full quote** when up to `DUST_THRESHOLD - 1` of it was retained. On the intended `NudgeRatchet` path — where the constructor *mandates* a 6-decimal token — that is up to **`0.999999` whole USDC per batch**, invisible to any off-chain consumer of `totalPaid`.

**Deviation**: the doc describes the **destination** of the residue but not the **accounting misreport**, so an integrator reading §4.1 has no reason to reconcile `totalPaid` against an observed balance delta. This is not a code deviation — the behaviour matches the story — it is a **disclosure** deviation.

**Remediation**: add one sentence to the paragraph stating that `totalPaid` reports the quoted amount and not the amount net of retained residue, and that integrators must reconcile against a balance delta if they need the true figure.

---

## 3. ⚠ Prominent flag — a false premise has propagated into a suppression rule

This is the item to act on, and it is a **Law-1 recall concern**, not a style complaint.

The sentence quoted in **L-02** — *"by construction it is a fraction of the cost … there is no configuration of this mechanism under which claiming is profitable-in-isolation"* — is not decorative prose and is not new. Three facts compose:

1. It was **re-asserted in this range**. `docs/multi-token-nudge.md` was rewritten by `0318089` / `5015f1b`, and the claim survived the rewrite **verbatim** at `:56-60`, with a second restatement added at `:299-302`.
2. It is now the **stated basis of the 2026-07-25 owner acceptance** (`:299-302` is written as the justification for it).
3. It is quoted verbatim into `registered-projects.json` **KI #15** as that known-issue's justification — and KI #15 **suppresses findings from future scans**.

A premise that is false **inside the project's own test fixture** (200.000000 vs 50.000000) is therefore now doing load-bearing work in a rule that removes findings from view. That is the circularity Law 1 forbids: suppressing findings under the authority of a claim those very findings falsify. If it is left standing, future runs will suppress the recurrence of this class *because* of the sentence this run just refuted, and each successive run will look cleaner than the last for a reason unrelated to the code.

**What this argues for — and what it does not.** It does **not** argue for minting a new finding: the class is already represented, twice, by open ledger entries. It argues for **escalating the two entries that already exist**:

| Fingerprint | Ledger label | Site | Status | Why it should be re-weighed |
|---|---|---|---|---|
| `75305ec0242b…` | `L-04` (run-21) | **code** — `src/BatchNFTMinterMultiToken.sol` NatSpec / gate | `open` | The premise it falsifies is now cited as the ground of an owner acceptance **and** of a suppression rule; its consequence has widened from "an unenforced NatSpec claim" to "the justification a scan-suppression rests on" |
| `a7dffb34c990…` | `F-20-07` (run-20) | **doc** — `docs/multi-token-nudge.md` §1 | `open` | Same, at the doc site — and this is the artefact the KI text is quoted **from** |

⚠ **Do not collapse the two.** They are the code site and the doc site of one claim: different artefacts, different fixes (a code cap versus a prose rewrite). Collapsing loses whichever site is not chosen as canonical. Both prior reports are carried forward in full under `submissions/carryover/`.

**The cheapest correct action** is the prose fix in L-02's remediation: rewrite the sentence to describe an operational funding discipline with a named owner rather than a structural guarantee, and update KI #15's justification text in the same change so the suppression rule no longer rests on a refuted premise. The structural fix (cap the payout against `paymentAmount - refund`) is what would let the whole lineage be closed **structurally** rather than by configuration.

---

## 4. Cross-reference register

| This report | Security stream | Rule |
|---|---|---|
| `F-25-01` | **M-01 (`pns25m1`)** | Same defect, two framings. **Counted once, as M-01.** F-25-01 is the story-side record and carries no independent severity. |
| `L-02 (pns25l2)` | **M-01 (`pns25m1`)** owns the value claim | L-02 asserts the doc/code discrepancy **only**. Ledger `75305ec0…`'s note forbids re-adding a value claim here; honoured. |
| `L-02 (pns25l2)` | ledger `75305ec0…` **and** `a7dffb34c990…` | Recurrence of both, not a new finding. **Do not collapse the two ledger entries** — code site vs doc site. |
| `Q-03 (pns25q3)` | — | Candidate merge with L-02 was considered and **declined**: different artefacts within the doc (§1's economic claim vs §4.1's scope-of-safety heading) and different rewrites. |
| `F-25-04` | **QA `L-01` (`pns25l1`)** | L-01 owns the value and the 6-decimal magnitude. F-25-04 records the disclosure gap only. |

## 5. Coverage and limitations

- Source read selectively (`:300-345`, `:461-700`, `:700-794`) to confirm suspected deviations; the contract profile was trusted for the remainder.
- Mutation experiments ran in `workspace/phoenix-nft-staking` and were reverted; `git status` clean at scan end. `lib/` was never written to.
- Mutation campaigns used reduced runs/depth for turnaround; the **unmutated** campaign ran at full 256 runs / 128,000 calls on both contracts.
- Five failing tests in a whole-workspace run are **audit-authored untracked PoCs** (`PoC_Drift01_*`, `PoC_EconMigrateReady`, `PoC_Local001_*`), excluded from every count above and not filed.
- **No fork access this scan.** Live-deployment arming conditions for F-25-01 / M-01 are inherited from `scan-econ.md` §9 and are **stated, not verified**.
