# Story-Faithfulness Scan (Law 2) — phoenix-nft-staking run-25

- **Project**: `phoenix-nft-staking` @ `5015f1b`
- **Baseline**: `d75229d`
- **Mode**: regression (story-029 only — the sole story in the audited range)
- **Story**: `story-029`, delivered over 4 commits — `8f3b982` (RED), `0318089` (GREEN), `9bef5a6` (invariants), `5015f1b` (measured budget)
- **Stories checked**: `["story-029"]`
- **Spec sources**: the four commit bodies; `lib/phoenix-nft-staking/docs/multi-token-nudge.md` (rewritten this range); `lib/phoenix-nft-staking/CLAUDE.md`; `registered-projects.json` KI #15
- **Inputs consumed**: `profiles/BatchNFTMinterMultiToken.md`, `scan-code.md`, `scan-econ.md`
- **Empirical work**: full suite + both invariant campaigns + 3 mutation experiments, run from `workspace/phoenix-nft-staking` (never `lib/`); all mutations reverted, workspace restored clean

---

## A. Conformance verdict on each claimed property

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | `budget = min(delta, paymentAmount)` brackets ONLY the step-5 transfer; bracketing the mint loop is prohibited | **CONFIRMED** | `src/BatchNFTMinterMultiToken.sol:575-581` |
| 2 | Per-mint `forceApprove(minter, price)` absolute, price re-read from `configs()` every iteration, allowance zeroed after the loop | **CONFIRMED** | `:621-627`, `:631` |
| 3 | Steps 9/10 swapped (refund before payout) AND `totalPaid`'s `>` floor guard absent | **CONFIRMED** | `:659-668` (refund) precedes `:678` (`_payRewards`); `:664` is bare `paymentAmount - refund` |
| 4 | Runtime payment-token skip removed from `_snapshotRewards`, floor live; `setNudgeTokenWhitelist` revert retained as defence-in-depth only | **CONFIRMED** | `:749-765` (no `continue`, no `paymentToken` comparison, floor at `:760`); `:315-327` + NatSpec `:300-307` |
| 5 | `src/BatchNFTMinter.sol`, `test/BatchNFTMinter.t.sol`, `test/BatchNFTMinterNudge.t.sol` byte-identical to `d75229d` | **CONFIRMED** | identical blob hashes at both commits (`eb8cf65f`, `af2d812e`, `86983422`); `git diff --stat` over those paths is empty |
| 6 | "531 tests green; invariants 128k calls per run"; reverting step 5 turns the taxed run red and leaves baseline green | **CONFIRMED, reproduced** | see §B |
| 7 | `afterInvariant` tripwires prevent vacuous passes | **CONFIRMED, mutation-proven load-bearing** | see §C |

### 1 — bracket span

```solidity
575:        uint256 budget;
576:        {
577:            uint256 heldBeforePull = paymentToken.balanceOf(address(this));
578:            paymentToken.safeTransferFrom(msg.sender, address(this), paymentAmount);
579:            uint256 credited = paymentToken.balanceOf(address(this)) - heldBeforePull;
580:            budget = credited < paymentAmount ? credited : paymentAmount;
581:        }
```

Exactly one operation sits between the two reads — the `safeTransferFrom` at `:578`. The snapshot (`:535`) and streamer flush (`:525-533`) are above `:577`; the mint loop starts at `:621`. The commit's prohibition —

> "In particular DO NOT bracket this loop the same way. The mints themselves generate `D` … so a delta taken around an iteration reads `-price + D`"

— is honoured: no `balanceOf` call exists anywhere between `:581` and `:631`. The one remaining `balanceOf` in the tail (`:660`) is the refund *ceiling*, never its source, and is documented as such at `:647-655`.

### 2 — absolute approval, no local ramp

`:622` re-reads `INFTMinterV2(address(nftMinter)).configs(_dispatcherIndex)` inside the loop body. No local ramp arithmetic (`growthBasisPoints` extrapolation) exists anywhere in the file — the commit's "the optimisation of computing the ramp locally was NOT taken" is literally true. `:624` writes an absolute `price`, not a delta or `type(uint256).max`; `:631` zeroes unconditionally on every non-reverting path.

### 3 — swap and the missing guard

Old (`d75229d`): `_payRewards` then a `balanceOf` sweep. New: refund block `:659-668`, `_payRewards` at `:678`. Genuinely transposed. `totalPaid = paymentAmount - refund;` at `:664` carries no `paymentAmount > refund ?` ternary. Per the commit, *"the guard's absence is the marker"* — recorded here so a future run does not "fix" it back in. Underflow-freedom rests on the `:580` `min`, which is why claims 1 and 3 must be reviewed as a pair.

### 4 — skip removed, admin check demoted

`_snapshotRewards(uint256[] calldata minRewards, bool qualifies)` at `:749` — the `paymentToken` parameter is gone and the body has no skip. The whitelist revert survives at `:324-327` under an explicit in-code demotion (`:319-323`: *"DEFENCE IN DEPTH, NOT A SAFETY REQUIREMENT … Removing this branch is safe"*). Both halves of the claim hold.

---

## B. Test evidence (measured, not taken on trust)

Run from `workspace/phoenix-nft-staking` @ `5015f1b`, excluding audit-authored (untracked) test files:

```
Ran 36 test suites: 535 tests passed, 0 failed, 0 skipped (535 total)
```

- **531 unit tests + 4 invariant tests = 535.** The commit's "531 tests green; invariants 128k calls per run" reports the two counts separately and is **accurate**.
- Both invariant contracts, full campaign:

```
BatchNFTMinterMultiTokenTaxedBudgetInvariantTest
  [PASS] invariant_PotOnlyLeavesViaQualifyingPayout   (runs: 256, calls: 128000)
  [PASS] invariant_RefundNeverExceedsPaymentAmount    (runs: 256, calls: 128000)
BatchNFTMinterMultiTokenBudgetInvariantTest
  [PASS] invariant_PotOnlyLeavesViaQualifyingPayout   (runs: 256, calls: 128000)
  [PASS] invariant_RefundNeverExceedsPaymentAmount    (runs: 256, calls: 128000)
```

128,000 calls per run per invariant, both configurations. **CONFIRMED.**

- A whole-workspace run additionally shows 5 failures, **all in audit-authored untracked PoC files** (`PoC_Drift01_*`, `PoC_EconMigrateReady`, `PoC_Local001_*`). None is a repo test. Per `never-file-audit-authored-test-files`, these are not filed and do not bear on the commit's claim.

### Mutation A — "reverting step 5 turns the taxed run red and leaves the baseline green"

Replaced `:577-580` with `budget = paymentAmount;` (trusting the quote, i.e. the pre-`5015f1b` shape):

```
BatchNFTMinterMultiTokenTaxedBudgetInvariantTest
  [FAIL: the nudge pot moved by something other than 0 (non-qualifying) or -P (qualifying)]
  [FAIL: refund exceeded paymentAmount (or totalPaid disagreed with it) for some fuzzed batch]
BatchNFTMinterMultiTokenBudgetInvariantTest
  [PASS] invariant_PotOnlyLeavesViaQualifyingPayout   (runs: 16)
  [PASS] invariant_RefundNeverExceedsPaymentAmount    (runs: 16)
```

**Exactly as claimed.** The measured-credit step 5 is load-bearing and the taxed run is the witness that proves it. Source restored.

---

## C. Tripwire audit (`vacuous-invariant-harness` history)

`test/BatchNFTMinterMultiTokenBudgetInvariant.t.sol:276-284` + the two per-contract overrides at `:296-299` / `:317-320`.

The tripwires are **real, and they fire**. Two mutation experiments:

| Mutation | Expected | Observed |
|---|---|---|
| `c.nudge = 0` always (`:151`) — qualifying branch unreachable | qualifying tripwire fails | `[FAIL: TRIPWIRE: the qualifying payout branch was never exercised: 0 <= 0]` on **all 4** tests |
| `c.paymentAmount = c.cost + quoteDelta` always (`:163-164`) — no under-quote | revert tripwire fails | `[FAIL: TRIPWIRE: an under-quoted batch never reverted, so the budget bound was never hit: 0 <= 0]` on the **baseline** contract |

The second result is worth recording: the **taxed** contract still passed that mutation, because a 500 bp skim makes `credited < cost` even on an honestly-quoted batch, so its revert branch is exercised structurally rather than by fuzz luck. That is a strength, not a gap.

Additional structural checks:

- Violations are recorded into **sticky booleans** (`refundBoundHeld`, `potIntegrityHeld`, `:73/:76`) rather than asserted inline, so a bad sequence cannot be masked by a later good one.
- Pot integrity is asserted **exactly** (`:210-214`), not as a bound — the `expected` expression reconstructs `pot + D − refund` from the outside and compares for equality. A bound-only assertion is the classic vacuous shape; this is not one.
- `totalPaid != paymentAmount - refundSent` is checked alongside the refund bound (`:201`), so "refund nothing" cannot satisfy the invariant.
- The revert branch asserts atomicity (`:181-182`), so a reverted batch is proven to move nothing rather than merely to have reverted.
- The mock is **not** a never-failing mock: the handler observed 128,000 calls with a live mix of qualifying / non-qualifying / reverting outcomes, enforced by the tripwires themselves.

**Verdict: not vacuous.** This harness is materially better than the one that produced the earlier `0 == 0` incident, and the tripwires are the reason.

---

## D. Findings

### F-25-01 — `story-unsafe` — story-029's safety rationale is an invariant no code enforces (Law-1 override)

- **type**: `story-unsafe` · **faithfulness**: false · **securityEscalation**: **true** · **lawImpacted**: 1
- **storyTag**: `story-029`
- **severity**: **potential-medium** (ceiling High on deployment)
- **contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `_snapshotRewards` / `batchMint`
- **line**: 758 · **lineStart**: 749 · **lineEnd**: 765 (gate at `:507-511`)
- **confidence**: high
- **DEDUP**: this is the **story-side framing of ECON-001/ECON-002**, not an additional finding. It must be **merged into ECON-001** downstream and must not be counted as a separate Medium.

**specText** (commit `0318089` §3.2, verbatim):

> "Removes the runtime payment-token skip from `_snapshotRewards` and drops the now-unused `paymentToken` parameter. **The payment token is snapshotted, floor-checked and paid out like every other whitelisted token**, and its `minRewards` floor is live instead of silently ignored."

**specSource**: git commit `0318089ede8a5e47ed209e488f1fa56f48a17ee8` body, §3.2. Corroborated by `docs/multi-token-nudge.md:200` (*"The payment token MAY be a reward token — SAFE BY CONSTRUCTION (story 029)"*) and by the repo's own passing test `test/PoC_PaymentTokenCollision.t.sol:354-368` asserting `assertEq(usdc.balanceOf(nftRecipient), pot)`.

**actualBehavior**: exactly what the story asks for. `:758` snapshots the payment token's pre-pull balance and `:790` transfers it in full to a caller-chosen `recipient` on any batch satisfying the count-only gate at `:510`.

**Did the implementation overshoot the intent?** **No.** This was the explicit question put to this scan, and the answer is negative on three independent readings of the spec: the commit says "paid out like every other whitelisted token"; the falsified-test rewrite renamed `RuntimePaymentTokenCollisionIsSkippedNotReverted` → **`IsPaidNotSkipped`**; and the repo ships a test asserting the *whole pot* is paid. The story wanted both the floor live **and** the full pot payable. The implementation is **faithful**.

**deviation**: none at the code level — the deviation is **in the story's own justification**. The story is safe only under the premise it inherits from `docs/multi-token-nudge.md:56-60` and KI #15: *"the pot is by construction a fraction of the cost of the `nudgeSize` mints required to qualify."* No code establishes that relation (see F-25-02). Story-029 therefore **adds a pool to Σ(pots) while relying on a bound the codebase does not contain**, and per ECON-002 that pool is fed by `NudgeRatchet._dispatch` forwarding 100 % of every mint's payment back into it, so the inequality re-arms itself. At the project's own fixture, Σ(pots)/cost = 200/50 = **4×**.

**Law-1 over Law-2**: Law 2 says implement the story; the implementation did. Law 1 says an unsafe *intent* is escalated rather than blessed. That is this entry.

**Scope discipline vs KI #15** — this is filed **inside** KI #15's own carve-out, not against its suppression:

- **NOT filed**: "batching is profitable", "the pot is sniped by MEV bots", "payment token should not be whitelisted as a nudge token", "`setNudgeTokenWhitelist` no longer rejects the payment token". All four are suppressed and none appears here.
- **Filed under** carve-out **(d)**: *"the aggregate over-funding class … which is about the pot being too LARGE relative to cost — a different claim from the comparison being easy."* The delta story-029 supplies is exactly a new pool entering Σ.
- Carve-outs (a)/(b)/(c) are **clean**: no path lets the pot leave without `nudgeSize` real mints, `refund > paymentAmount` is invariant-proven impossible, and a non-qualifying batch takes nothing (`test_PaymentTokenAsNudge_nonQualifyingBatchTakesNothing`, passing). **`ycn19h1` is genuinely closed at the root the story names.**

---

### F-25-02 — `invariant-violation` — `docs/multi-token-nudge.md` states a security guarantee the contract does not implement

- **type**: `invariant-violation` · **faithfulness**: **true** · **securityEscalation**: false · **lawImpacted**: 2
- **storyTag**: `story-029` (docs rewritten in `0318089` / `5015f1b`)
- **severity**: **potential-low** (QA / spec-conformance; the *value* consequence is priced in ECON-001, not here)
- **contract / function**: `docs/multi-token-nudge.md` §1 and §4.1 ↔ `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **line**: 510 · **lineStart**: 507 · **lineEnd**: 511 (doc sites: `docs/multi-token-nudge.md:56-60` and `:299-302`)
- **confidence**: high
- **Cross-reference**: ECON-006 reaches the same conclusion from the economic side; **file once**, with this entry supplying the Law-2 framing.

**specText** (`docs/multi-token-nudge.md:56-60`, verbatim):

> "The pot is a *nudge*: **by construction** it is a fraction of the cost of the `nudgeSize` mints required to qualify. A bot that claims it must first pay more payment-token into the protocol than it extracts in reward. **Every claim is net-positive for the protocol; there is no configuration of this mechanism under which claiming is profitable-in-isolation.**"

and (`:299-302`, the ground offered for the 2026-07-25 acceptance):

> "That is intended: the pot is by construction a fraction of the cost of the qualifying mints, so every claim is net-positive for the protocol. Making the comparison legible does not change the economics."

**specSource**: `lib/phoenix-nft-staking/docs/multi-token-nudge.md`, rewritten in this range; the same sentence is quoted verbatim into `registered-projects.json` KI #15 as its justification.

**actualBehavior**:

```solidity
510:        qualifies = _nudgeSize != 0 && count >= _nudgeSize;
```

`qualifies` reads `count` and `nudgeSize` and nothing else. It never reads `paymentAmount`, `price`, `budget`, or `snapshot[i]`. **No expression anywhere in the file relates the pot to the cost.** The phrase "by construction" names a construction that does not exist; the universally-quantified clause "there is no configuration … under which claiming is profitable-in-isolation" is refuted by the project's **own fixture** (`test/PoC_PaymentTokenCollision.t.sol`: pot 200.000000 USDC, qualifying cost 50.000000 USDC) and by its own passing assertion at `:354-368`.

Two aggravating specifics:

1. The doc's fallback backstop at §4.6 — *"qualifying still costs `nudgeSize` real mints at the ramping price"* — is void at `growthBasisPoints == 0`, which is how the project's own ratchet index is configured (`setConfig(RATCHET_INDEX, RATCHET_PRICE, 0)`, `PoC_PaymentTokenCollision.t.sol:112`).
2. The claim is not merely decorative prose: it is the **stated basis of an owner acceptance** and of KI #15's suppression. A false premise propagated into a suppression rule is a Law-1 concern about future recall, which is why it is surfaced here rather than in the QA bundle silently.

**deviation**: documentation asserts an enforced invariant; the code enforces nothing of the kind. A reader — or an operator curating the whitelist against these docs — will believe a bound exists that does not. Per the audit charter, *a doc that misstates the security property is a Law-2 deviation in its own right*.

**Remediation (single shared fix with F-25-01 / ECON-001)**: either make the payout value-aware — cap the total nudge payout against the payment actually charged this batch (`paymentAmount - refund`, already computed at `:664`) — which turns the sentence into a construction; or rewrite the sentence to say what is true: *the relation is an operational funding discipline, unenforced by the contract, and must be monitored.*

---

### F-25-03 — `faithfulness` — §4.1's "SAFE BY CONSTRUCTION" heading is broader than the construction story-029 actually built

- **type**: `faithfulness` · **faithfulness**: true · **securityEscalation**: false · **lawImpacted**: 2
- **storyTag**: `story-029` · **severity**: **potential-low** (QA)
- **line**: `docs/multi-token-nudge.md:200`, `:213`
- **confidence**: medium
- **Candidate merge** with F-25-02 at report time.

**specText** (`docs/multi-token-nudge.md:200`, `:213`):

> "### 4.1 The payment token MAY be a reward token — **SAFE BY CONSTRUCTION** (story 029)"
>
> "**The construct is now permitted and safe, not forbidden.**"

**actualBehavior**: what story-029 established by construction, and what this scan independently verified, is precisely two properties — `refund <= budget <= paymentAmount` (the pot cannot leave through the **refund**), and the minter's allowance bounded at the exact per-mint price. Both are real, both are invariant-proven (§B/§C). The section body scopes itself correctly to those two. The **heading and the standalone sentence do not**: they read as an unconditional blessing of the collision configuration, and the residual exposure lives in the third exit path — the **qualifying payout** at `:790`, which no construction bounds.

**deviation**: the doc's scope of the safety claim exceeds the scope of the mechanism it describes. Note this is the *mirror image* of the same section's own self-correction, which deletes a previously false claim and says so — the section is otherwise a model of honest revision; the heading simply did not get the same treatment.

**Suggested wording**: "the payment token MAY be a reward token — the refund path is safe by construction (story 029); the payout path remains bounded only by funding discipline (§1)."

---

### F-25-04 — `faithfulness` — sub-threshold dust paragraph omits that `totalPaid` misreports it

- **type**: `faithfulness` · **faithfulness**: true · **securityEscalation**: false · **lawImpacted**: 2
- **storyTag**: `story-029` · **severity**: **potential-low** (QA)
- **line**: 666 · **lineStart**: 659 · **lineEnd**: 668 (doc site `docs/multi-token-nudge.md:305-310`)
- **confidence**: high
- **Cross-reference**: CODE-001 / ECON-005 own the *value* consequence and the 6-decimal magnitude. This entry records only the **disclosure gap**.

**specText** (`docs/multi-token-nudge.md:305-310`):

> "**Sub-threshold dust.** Payment-token residue below `DUST_THRESHOLD`, and any third-party donation of payment token, are no longer swept to the next caller. They are not that caller's budget, so they stay behind as pot — which is the correct owner for them, and which is what the `DUST_THRESHOLD` floor was achieving in spirit all along."

**actualBehavior**: correct as far as it goes, but `:666` also sets `totalPaid = paymentAmount` on that branch, so the return value reports the caller spent their *full quote* when up to `DUST_THRESHOLD - 1` of it was retained. On the intended `NudgeRatchet` path that is up to `0.999999` whole USDC per batch, silently invisible to any off-chain consumer of `totalPaid`.

**deviation**: the doc describes the destination of the residue but not the accounting misreport, so an integrator reading §4.1 has no reason to reconcile `totalPaid` against an observed balance delta. Not a code deviation — the behaviour matches the story; a **disclosure** deviation.

---

## E. Checked and clean (no finding)

| Check | Verdict |
|---|---|
| Does the implementation contradict any explicit story acceptance criterion? | **No.** All 7 enumerated claims confirmed at source and, for 6 and 7, reproduced empirically. |
| Did story-029 silently regress an earlier story's guarantee? | **No.** §4.2 donate-forward (story-022/025) is intact and pinned by `test_OwnDonationsDoNotRefundToBatcher`; the snapshot-before-pull ordering is intact at `:535` → `:578`. |
| Did the frozen twin `BatchNFTMinter.sol` move? | **No** — blob-identical. The pre-existing fork-drift watch-note is unchanged by this range and is not re-filed here. |
| Is `ycn19h1` closed at the root the story names? | **Yes.** The refund's source of truth moved from `balanceOf` to a tracked budget; the non-qualifying 1-wei drain is dead (`test_PaymentTokenAsNudge_nonQualifyingBatchTakesNothing`, `test_control_beforeRepoint_count1_capturesNothing`, both passing) and structurally excluded by `invariant_PotOnlyLeavesViaQualifyingPayout`. |
| Are the CLAUDE.md Critical Invariants affected? | **No.** They govern `NFTStaker`, which this range does not touch. |
| Conflicting spec sources (commit vs design doc)? | **One**, filed as F-25-02/F-25-03: the docs' §1 economic guarantee conflicts with the code, and §4.1's heading conflicts with its own body. The four commit bodies are mutually consistent and consistent with the code. |
| Undocumented intent? | **None.** story-029 is unusually well specified — four commit bodies, a rewritten design-doc section, and an owner decision record. No acceptance criteria were invented. |

## F. Coverage and limitations

- Source read selectively (`:300-345`, `:461-700`, `:700-794`) to confirm suspected deviations, per scope discipline; profile §§1-4, 7-8 trusted for the remainder.
- Mutation experiments were run in `workspace/phoenix-nft-staking` (writable clone) and reverted; `git status` on `src/` and the invariant test is clean at scan end. `lib/` was never written to.
- Mutation campaigns used reduced `FOUNDRY_INVARIANT_RUNS`/`DEPTH` for turnaround; the **unmutated** campaign was run at full 256 runs / 128,000 calls on both contracts.
- The 5 failing tests in a whole-workspace run are audit-authored untracked PoCs and are excluded from every count reported here.
- No fork access this scan; live-deployment arming conditions for F-25-01 are inherited from `scan-econ.md` §9 and are stated, not verified.
