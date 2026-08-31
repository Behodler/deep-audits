# Tier-2 Code Scan — phoenix-nft-staking run-25 (story-029)

- **Target**: `lib/phoenix-nft-staking/src/BatchNFTMinterMultiToken.sol` @ `5015f1b` (baseline `d75229d`)
- **Scan type**: `code` (interaction-level). Economics deferred to econ-scanner.
- **Inputs consumed**: `profiles/BatchNFTMinterMultiToken.md`, `pattern-matches.md`, `static-analysis.md`
- **Source read to verify**: `src/BatchNFTMinterMultiToken.sol` L130-200, L440-800; `src/BatchNFTMinter.sol` L280-310; `src/NudgeStreamer.sol` L164-190; cross-repo `lib/mutable/yield-claim-nft/src/NFTMinterV2.sol` L158-200; `test/PoC_PaymentTokenCollision.t.sol`
- **Delta confirmed**: `git diff --stat d75229d..5015f1b` — the only `src/` file changed is `BatchNFTMinterMultiToken.sol`.

Nothing below is suppressed for severity or "probably known". KI #15 (same-denomination
nudge arbitrage, owner-accepted 2026-07-25) is honoured: the arbitrage itself is **not**
re-filed — see §C.

---

## A. Fix-completeness verdicts (ranked first, per Law 1)

### A-1. `ad36260fc91f` (M-07, fix-pending) — **COMPLETE. Closed at the root.**

Ledger root cause: *"`forceApprove(nftMinter, type(uint256).max)` lets an under-funded batch
silently spend the contract's own payment-token balance."*

Verified at source, not from the profile:

| Requirement for the old exploit | Status at `5015f1b` |
|---|---|
| A standing allowance wider than one mint | **gone** — L624 `forceApprove(address(nftMinter), price)`, an absolute write of the exact next charge |
| The minter able to draw beyond the caller's credit | **gone** — L623 `if (price > budget) revert BatchMint__PaymentBudgetExhausted(i, price, budget)` executes *before* the approval is written |
| Any residual allowance after the call | **gone** — L631 `forceApprove(minter, 0)`, unconditional on every non-reverting path |

Quantified closure. `NFTMinterV2._executeMint` (yield-claim-nft `src/NFTMinterV2.sol:183`)
performs exactly one debit per `mint`:

```solidity
IERC20(token).safeTransferFrom(msg.sender, config.dispatcher, price);   // price == config.price
```

`msg.sender` there is `BatchNFTMinterMultiToken`. Grep of `NFTMinterV2.sol` returns **one**
`transferFrom` site in the whole file, so aggregate outflow over the loop is `Σ price_i`,
and L623+L625 force `Σ price_i ≤ budget ≤ credited`. The pot `P` (this contract's pre-pull
balance) is therefore **structurally unreachable by the minter**, not merely harder to reach.

I could construct **no residual path**. Specifically ruled out:
- Non-decrementing payment token leaving `price` standing after the debit — harmless, because
  the only spender is `nftMinter` and its only `transferFrom` sources `msg.sender`; a callback
  cannot make `msg.sender == address(this)`. L624's next absolute write and L631 both correct it.
- Under-funded batch reaching the loop — `count == 0` rejected at L468; `price == budget`
  correctly admitted at L623 (`>` not `>=`).
- Revert paths not reaching L631 — harmless: a revert unwinds the `approve` storage write with
  everything else. Confirmed there is no `try`/`catch` and no low-level call in `batchMint`.

The imported PoC agrees and is not merely testing the symptom: `test_PaymentTokenAsNudge_
underFundedBatchRevertsWithBudgetExhausted` (L289) pins the *new* revert, and
`test_PaymentTokenAsNudge_nonQualifyingBatchTakesNothing` (L256-277) asserts
`usdc.balanceOf(address(batch)) == potAtAttack` — the 190-from-200-for-1-wei extraction is
zero, and the batch reverts rather than silently drawing on the pot.

**Recommendation: propose `fixed`.** Human applies per CLAUDE.md; do not auto-flip.
Carry CODE-004 and CODE-006 below as the two things that could un-fix it.

### A-2. `1c222d548523` (H-01, fix-pending) — **NOT TOUCHED by this change.**

Root cause is `src/NFTStakerDepletion.sol :: depositFor` paying the migrator. `git diff --stat
d75229d..5015f1b` lists exactly one `src/` file, and it is not that one. The entry is neither
fixed nor regressed by story-029; it remains `fix-pending` untouched. No action.

---

## B. Findings

All six are **DELTA** (introduced or materially changed by story-029) unless stated.

### CODE-001 — Sub-dust refund forfeiture became *permanent* and *pot-directed* — Low (Medium argument recorded)

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Line**: 662 · **lineStart**: 659 · **lineEnd**: 668 (constant at L146)
- **Type**: value-routing / owner footgun (Law 3 — non-obvious consequence)
- **Confidence**: high (mechanism), medium (impact sizing)
- **Delta**: yes

```solidity
uint256 internal constant DUST_THRESHOLD = 1e6;                     // L146
...
uint256 available = paymentToken.balanceOf(address(this));          // L660
uint256 refund = budget > available ? available : budget;           // L661
if (refund / DUST_THRESHOLD != 0) {                                 // L662  == refund >= 1e6
    paymentToken.safeTransfer(msg.sender, refund);
    totalPaid = paymentAmount - refund;
} else {
    totalPaid = paymentAmount;                                      // L666  surplus kept, silently
}
```

**Root cause.** Two independent facts compose into a defect neither has alone:

1. `DUST_THRESHOLD` is a raw-wei constant with **no decimals normalisation**, while the payment
   token is not fixed — it is `ITokenDispatcherV2(dispatcher).primeToken()` (`_resolvePaymentPath`,
   L705), owner-repointable. At 18 decimals `1e6` is ~10⁻¹² of a unit (genuine dust, as the
   NatSpec at L143-145 claims). At **6 decimals it is 0.999999 of a whole token**. This is not
   hypothetical: the project's own story-029 PoC harness stages the prime token as USDC
   (`test/PoC_PaymentTokenCollision.t.sol:196`, `assertEq(ratchet.primeToken(), address(usdc), "TRIPWIRE: derived payment token is now USDC")`).
2. Story-029 changed the **source** of the transfer at L663 from `balanceOf` to the tracked
   `budget`. That is the correct fix for `ycn19h1`, but it has an unremarked side effect on the
   *sub-threshold* branch.

**Why it is a delta, precisely.** Pre-029 (`d75229d` old-step-10) the sweep read the absolute
`balanceOf`, so forfeited residue was **recoverable**: it accumulated in the contract and the
next caller whose total residual crossed `1e6` swept the accumulation back out to themselves.
Post-029 the refund can never exceed `budget`, which is this call's credit only. Residue from a
prior call is invisible to every subsequent refund. It is therefore **permanently unreachable
by any refund path** and can only leave the contract via (a) `_payRewards` as a nudge payout to
a qualifying batcher, or (b) `rescueERC20`. Profile §8 path table confirms these are the only
two remaining exits.

**Failure path with concrete inputs.** Prime token = USDC (6 dp), `price = 25_000000`,
`nudgeSize = 10`. Caller batches `count = 4` with `paymentAmount = 100_500000` (a 0.5 USDC
frontend margin over the 4 ramped mints). `credited = 100_500000`, `Σ price = 100_000000`,
`budget = 500000` at L661. `500000 / 1e6 == 0` → the `else` branch runs, no transfer, and
`totalPaid = 100_500000`. The caller is reported as having spent their full `paymentAmount`,
0.5 USDC stays behind, and it is now part of `P`. Repeat across every non-qualifying batcher
who over-quotes by under one whole token.

**Impact.** A repeatable, caller-funded, silent subsidy of up to 0.999999 payment-token units
per batch, routed from non-qualifying batchers to whoever next satisfies the count-only nudge
gate. Bounded per call and small relative to a batch's mint cost, hence **Low** — but the
Medium argument to record for severity-classifier is that it is (i) systematic rather than
edge-case on a 6-decimal prime token, (ii) invisible in the return value (`totalPaid` reports
the full `paymentAmount`, so no off-chain consumer can detect it), and (iii) self-feeding into
the pot that KI #15's accepted arbitrage draws on.

**Law-3 test.** *Would a competent, non-malicious owner repointing `dispatcherIndex` at a
6-decimal prime token be surprised that per-batch refunds under one whole token vanish into the
nudge pot?* Yes. Surprise ⇒ footgun ⇒ in scope.

**Safe-config guidance.** Scale the threshold off `IERC20Metadata(paymentToken).decimals()`, or
lower the constant to a value that is dust at 6 decimals (e.g. `1e2`); or make the branch
partial rather than all-or-nothing.

---

### CODE-002 — The `available` cap cannot do what its comment says it does — QA / Low

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Line**: 660 · **lineStart**: 647 · **lineEnd**: 661
- **Type**: false safety claim in a load-bearing comment
- **Confidence**: high (the claim is demonstrably false); **not currently exploitable**
- **Delta**: yes (the comment block is new)

The comment at L647-655 retains the cap *"only so an unforeseen shortfall degrades into a
smaller refund rather than a revert."* It cannot serve that purpose. `available` is an
**absolute** `balanceOf` and therefore equals `P + (credited − C) + D`. A shortfall in the
caller's own credit does not make `available` bind until `P` **and** this batch's donations `D`
have *already* been consumed in full. In exactly the scenario the comment names, the shortfall
is silently absorbed by the pot instead of degrading the refund. A cap that did what the prose
claims would have to be caller-scoped, and no such quantity is tracked after L581.

Separately, the cap is **provably non-binding today**: `budget ≤ credited` (L580 `min`) and
`available = P + (credited − C) + D ≥ credited − C ≥ budget`, so `refund == budget` on every
constructible path. It is dead code that reads as a safety net.

**Impact today: none** — this is why it is QA and not Medium. It is filed because the residual
is the same `balanceOf` conflation story-029 was written to eliminate, sitting at the one site
the file elsewhere explicitly forbids absolute reads (L585-605), with a comment that would
mislead the next author into believing a protection exists.

**Also record**: an incorrect defence claim on the refund's ceiling is exactly the shape that
lets a future erosion mechanism (negative-rebase prime token) pass review. Recommendation:
either delete the cap and let an impossible shortfall revert honestly, or track a caller-scoped
quantity and cap on that.

---

### CODE-003 — The L580 `min` is a single point of failure for two unrelated properties, only one of which is documented — QA

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Line**: 580 · **lineStart**: 562 · **lineEnd**: 581 (consequence at L664)
- **Type**: undocumented coupling / future-regression trap
- **Confidence**: high · **Delta**: yes

```solidity
budget = credited < paymentAmount ? credited : paymentAmount;   // L580
...
totalPaid = paymentAmount - refund;                             // L664  — guard REMOVED
```

`d75229d` had `totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0`. Story-029
deliberately removed the `>` guard (commit `0318089` §3.3 names it as the marker of the fix).
The removal is **safe**, but *only* because `refund ≤ budget ≤ paymentAmount`, which holds
*solely* because of the `min` at L580. The 20-line comment at L562-571 justifies that `min`
entirely as a **donation-routing** defence and mentions underflow in one clause of one sentence.

A future author reasoning only about donation routing — e.g. relaxing the cap to a floor, or
replacing `min` with the measured `credited` on the grounds that "measuring is strictly more
honest" — reintroduces an underflow **revert DoS** at L664 with no local warning and no test
name pointing at it. The two obligations should be pinned at the `min` site.

Profile §9 note 2 and pattern near-miss NM-06 both reached this independently; recorded here as
the reportable form.

---

### CODE-004 — Budget/charge lockstep is a silent cross-repo invariant; a non-decrementing payment token leaves a live `price` allowance across two external callbacks — Low (watch-note)

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Line**: 625 · **lineStart**: 621 · **lineEnd**: 627
- **Type**: cross-contract trust assumption / regression fragility on the A-1 fix
- **Confidence**: medium (as a hazard); the escape is verified sound **today**
- **Delta**: yes (the invariant is newly load-bearing — pre-029 nothing depended on it)

```solidity
paymentToken.forceApprove(address(nftMinter), price);   // L624
budget -= price;                                        // L625  (quoted, never measured)
nftMinter.mint(_dispatcherIndex, recipient);            // L626
```

The outflow leg is **quoted, not measured** — the deliberate inverse of the inbound bracket at
L577-579. Correctness therefore rests on a property of a **different repository**:
`NFTMinterV2._executeMint` debiting this contract exactly `config.price`, exactly once, per
`mint` call. I verified that at source (`yield-claim-nft/src/NFTMinterV2.sol:183`, the sole
`transferFrom` in the file) — it holds today, including under the standard fee-on-transfer
model, because the fee is skimmed from what the *dispatcher receives* (measured there at
L182-184) and the batcher is still debited the full `price`.

The hazard is what happens if it stops holding, and how invisible that would be here:

1. `_executeMint` makes **two** external calls after the debit and before returning —
   `ATokenDispatcherV2(config.dispatcher).dispatch(...)` (L191) and `_mint(recipient, ...)`
   (L196), the latter firing `onERC1155Received` on a **caller-chosen `recipient`**.
2. With a payment token that does **not** decrement allowance on `transferFrom`, the
   `forceApprove(minter, price)` written at L624 is **still standing** during both callbacks.
3. It is unexploitable today for one reason only: the minter's single `transferFrom` sources
   `msg.sender`, so a callback cannot make it spend *this contract's* allowance. Any future
   `mintOnBehalf(address from, ...)`, batching inside `_executeMint`, or a second charge would
   immediately re-open `ad36260f` against `P` — and there is **no local signal** in
   phoenix-nft-staking, because `budget` would simply be wrong rather than reverting.

**Not a bug today. Filed as a watch-note** so the A-1 `fixed` proposal is not read as
unconditional. Recommendation: either measure the outflow leg (`balanceOf` bracket around the
single `mint`, which is a legitimate narrow bracket by the file's own L597-599 rule, *provided*
the payment token is not itself donated back as `D` inside the same call — it may be, so this
is not free), or add an explicit post-loop assertion that the aggregate debit equals `Σ price`.

**Also cleared while checking this (NM-02 escape confirmed at source, thin margin):** the
`onERC1155Received` hook fires on a caller-chosen contract **inside** the mint loop. It escapes
for three independent reasons, all verified in source, all of which must continue to hold:
(1) `nonReentrant` at L464 blocks re-entering `batchMint`; (2) `budget -= price` at L625
executes *before* the mint at L626, so the hook cannot observe an un-decremented budget — CEI
holds *within* the iteration; (3) the standing allowance is exactly one mint's price and is
spender-locked as above. The margin on (2) and (3) is thin: moving the decrement after the mint,
or widening the approval, makes this live. The per-iteration absolute approval is
**load-bearing, not a cosmetic tidy-up**.

---

### CODE-005 — FoT + transfer-hook payment token: a third-party push inside the pull window can top `credited` back up to `paymentAmount`, and the fee is then drawn from `P` — Low (likely C4-invalid, filed for completeness)

- **Contract / function**: `src/BatchNFTMinterMultiToken.sol` :: `batchMint`
- **Line**: 579 · **lineStart**: 576 · **lineEnd**: 581
- **Type**: budget over-statement under a doubly-weird token
- **Confidence**: medium (mechanism sound), low (reachability) · **Delta**: yes

The prompt asks specifically about the **under** side of `min(balanceAfter − balanceBefore,
paymentAmount)`. The `min` blocks a mid-pull donation from *raising* `budget` above
`paymentAmount` — but it does **not** stop a mid-pull donation from *restoring* `budget` to
`paymentAmount` when the caller's real credit was lower.

Requires the payment token to be **both** fee-on-transfer **and** to expose a transfer hook
(ERC777 `tokensToSend` on the sender, or an ERC1363-style callback). Path with inputs:

1. Attacker calls `batchMint(count=1, recipient=attacker, paymentAmount=100e6, ...)`; token fee
   is 10%.
2. Inside `safeTransferFrom` (L578) the sender-side hook fires with the attacker in control.
   `nonReentrant` blocks re-entering `batchMint` — but **not an inbound transfer landing inside
   the window**, as the file's own comment at L563-565 acknowledges.
3. The attacker (or a confederate account) pushes `10e6` of the payment token in during the
   window. `credited = 90e6 + 10e6 = 100e6 == paymentAmount`, so `budget = 100e6`.
4. `Σ price = 25e6`. `refund = 75e6`, but the contract only ever received `90e6` net of fee and
   paid `25e6` out: `90 − 25 = 65e6` is the caller's true credit. The extra `10e6` — which the
   attacker themselves supplied, so no direct gain — plus the `10e6` fee **shortfall** is
   absorbed by `P`. Net: the pot shrinks by the fee on every such call, and where the attacker
   controls the token's fee sink, the fee is extractable.

`credited` cannot exceed the sum of *all* inbound transfers in the window, so the caller is
never credited a third party's standing balance directly; the leak is precisely the fee, and it
lands on `P` because `budget` is pinned once at L581 and never re-validated (this is the live
core of pattern-match P-03's "one-sided in time" argument, in its only constructible form).

**Filed, not suppressed** — but flagged for the sanitizer: C4 known-invalid list covers
non-standard/weird ERC-20s and fee-on-transfer tokens unless explicitly in scope, and this needs
**two** weird properties simultaneously. The genuine takeaway is the residual, not the exploit:
`budget` is a one-shot measurement that is never reconciled, so any post-L581 erosion of this
contract's payment-token holdings is charged to `P`, silently.

**Interaction tail (records pattern-match P-04's margin):** because the step-9/10 swap makes the
refund leave *before* `_payRewards`, once such an erosion exceeds `P + D` the failure mode
changes from a silent pot shrink to a **`batchMint` revert on the payout leg**. Worth one line
in any write-up; not separately reportable.

---

### CODE-006 — Fork drift: the V1 twin `BatchNFTMinter.sol` did not receive the story-029 fix and still carries `ad36260f`'s root cause — Low (fork-drift watch-note)

- **Contract / function**: `src/BatchNFTMinter.sol` :: `batchMint`
- **Line**: 284 · **lineStart**: 284 · **lineEnd**: 308
- **Type**: unpatched fork · **Confidence**: high · **Delta**: no (pre-existing shape, newly divergent)

Grep-confirmed at `5015f1b`:

```
src/BatchNFTMinter.sol:284:  paymentToken.forceApprove(address(nftMinter), type(uint256).max);
src/BatchNFTMinter.sol:290:  paymentToken.forceApprove(address(nftMinter), 0);
src/BatchNFTMinter.sol:305:  uint256 remaining = paymentToken.balanceOf(address(this));
src/BatchNFTMinter.sol:306:  if (remaining / DUST_THRESHOLD != 0) {
src/BatchNFTMinter.sol:307:      paymentToken.safeTransfer(msg.sender, remaining);
```

This is the **exact pre-029 shape**: unbounded approval (the `ad36260f` root cause) plus a
`balanceOf`-sourced sweep (the `ycn19h1` root cause), with `nudgeAmount` likewise taken from
`balanceOf(address(this))` at L280. If this contract is deployed and holds a nudge pot, both
closed issues are live on it.

Consistent with this project's existing fork-drift tracking (`NFTStakerPriceScaled` /
`DepletionV2` clones), this is the **fourth** clone under drift watch. It is flagged, not
filed as a new Medium, because it is presumed covered by the existing `ad36260f` / `858e9e80`
entries against the pre-029 design — **but only if V1 is not separately deployed with a pot.**
That is a question for the human triager, not something this scan can resolve.

---

## C. KI #15 echo — recorded, deliberately NOT re-filed

Story-029 deletes the runtime payment-token skip in `_snapshotRewards` (the old
`if (rewardToken == paymentToken) continue;`, diff line 489). Consequently, when the owner
repoints `tokenMinter`/`dispatcherIndex` so the derived `primeToken()` is a whitelisted nudge
token, the payment token's standing pot `P` is snapshotted, floor-checked and paid to a
caller-chosen `recipient` on the unchanged count-only gate at L510. The project's own test
asserts this as intended behaviour: `test_PaymentTokenAsNudge_qualifyingBatchStillEarnsThePot`
(L354-367) — `assertEq(usdc.balanceOf(nftRecipient), pot, "a qualifying batcher is paid the whole pot as a nudge")`.

**This is the same-denomination nudge arbitrage covered by KI #15 (owner-accepted 2026-07-25),
and it is not re-filed.** I found **no distinct root cause on those lines** — the mechanism is
identical to the accepted one, only the denomination of one more pool has changed.

One disclosure obligation is nonetheless discharged here rather than dropped, per
`disclose-when-refiling-owner-wontfix`: ledger `43e8c48626ee` (M-01, wont-fix) was triaged on an
aggregate-pot argument (*"Σ pots < 1 batch cost"*) computed over a pot set that **did not
include the payment token**, because at triage time the runtime skip excluded it. Story-029
adds a pool to that aggregate, and CODE-001 makes that pool **self-feeding** without any owner
funding action. The prior arithmetic is therefore no longer a statement about the current code.
Whether KI #15's acceptance was intended to cover the enlarged aggregate is a **human
re-weigh**, not something a scanner should inherit or override. Flagged to the triager; no
finding minted.

---

## D. Checks run and cleared (no finding)

| Question | Verdict | Evidence |
|---|---|---|
| Order swap (refund L659-668 before `_payRewards` L678) leaves the snapshot unbacked? | **No, sound.** | Balance at payout = `P + (credited − C) + D − refund`; `refund ≤ budget ≤ credited − C`, so at least `P + D` remains and `_payRewards` needs `P`. Holds under FoT (`credited < paymentAmount` shrinks `budget` in lockstep), under donation (`D` only adds), and under pre-call donation (folded into `P` by the pre-pull snapshot). The **reverse** order would have been the dangerous one. |
| Snapshot-before-pull ordering unconditional? | **Yes, unconditional.** | L535 → L577 with **zero** intervening operations of any kind — no external call, no branch, no storage write. Verified by reading L535-581 contiguously. Holds identically when `paymentToken ∈ whitelist`: `heldBeforePull` (L577) and `snapshot[pt]` (L758) read the same value `P`, so the caller's payment provably cannot inflate the snapshot. |
| Mint-loop TOCTOU: can `configs` change between the L510 gate and an L622 read? | **Yes, but harmlessly.** | `price` ramps globally on every mint by anyone (`_executeMint` L188), and the `onERC1155Received` hook can call `NFTMinterV2.mint` mid-loop to ramp it. It is not a correctness issue: L622 re-reads immediately before the mint that charges it, and `_executeMint` charges the **pre-ramp** `config.price`, so the read is exact by construction. `qualifies` depends only on `count` and `nudgeSize` (owner-set, unreachable during the call), never on price. Residual is liveness only — a front-runner can push `price > budget` and revert the batch via `BatchMint__PaymentBudgetExhausted`. **Not a regression**: pre-029 the same shortfall also reverted (on allowance/balance), and could instead silently spend `P`, which *was* `ad36260f`. Story-029 strictly improves this. |
| `nonReentrant` actually covers the ERC1155 hook path? | **Yes** — plus two independent backstops. | See CODE-004's closing paragraph. Thin margin recorded there rather than silently passed. |
| Cross-function / read-only reentrancy | **Absent.** | Every sibling reachable during any callback (`setNudgeTokenWhitelist`, `setNudgeSize`, `setTokenMinter`, `setDispatcherIndex`, `setNudgeStreamer`, `rescueERC20`) is `onlyOwner`; `pause`/`unpause` are `onlyPauser`. `batchMint` writes **no storage at all**, so there is no transiently-inconsistent state and no sibling shares state with it. The contract exposes no price/share/NAV view an integrator could read mid-callback — the only public views are `isNudgeToken`/`getNudgeTokens` and plain config getters, none value-reporting. |
| ERC777 `tokensReceived`/`tokensToSend` on the payout leg | **Escapes.** | `_payRewards` (L784-792) runs last, after the refund, with all state settled and `nonReentrant` still held. |
| `NudgeStreamer.pullPendingStream` reachable as an attack primitive from inside a callback? | **No.** | `streams[msg.sender][token]` (`NudgeStreamer.sol:165`) — it settles only the **caller's own** stream, and returns a no-op for `duration == 0`. A third party calling it directly moves nothing. The batch minter's own flush at L525-533 is inside `nonReentrant` and precedes the snapshot, so it can only *seed* the pot. |
| L579 subtraction (`balanceAfter − heldBeforePull`) revert on a balance **drop** across the pull — DoS? | **Revert-only, self-inflicted, not a DoS.** | Reachable only for a token whose `transferFrom` can *decrease* this contract's balance (hook-driven outbound transfer, negative rebase). Failure mode is a clean revert of the caller's own transaction, not a wrong value and not a wedge — no state is written before L579 and nothing is left behind. Griefing a *third party* would require moving this contract's balance down during **their** transaction, which needs a hook the attacker can fire inside the victim's `transferFrom` — possible only with an already-weird payment token, at which point CODE-005 is the sharper issue. |
| Unbounded `count`: griefing / block-gas DoS / half-written state? | **No finding.** | ~47k gas per iteration (project snapshot: `batchMintN_25` 1,170,867). An out-of-gas reverts the whole transaction — `batchMint` writes no storage, so there is **no** half-written state, no partial mint accounting, and no stranded allowance (the L624 write unwinds with the revert). The gas is paid by the caller and the pot is untouched, so the only victim is the caller. The doubled per-iteration cost lowers the max viable `count` from ~1150 to ~600 at a 30M limit — a UX/liveness note for the frontend, not a security finding. |
| `forceApprove(minter, price)` not fully consumed / non-decrementing token / L631 unreachable on revert? | **Clean.** | `_executeMint` consumes exactly `price` (single `transferFrom`, sole site in the file). Every `forceApprove` (L624, L631) is an **absolute** target, so it is idempotent for a decrementing token and corrective for a non-decrementing one — correctness is independent of the token's allowance semantics. L631 is unconditional on all non-reverting paths; on a revert path the approve write unwinds with everything else, so a stale allowance cannot survive the transaction. No `FRONTRUN-APPROVE` exposure: this contract is the approver and the approve→spend window is atomic within one call. |
| `configs().disabled` read and discarded (L622, L703) | **No finding.** | Pre-existing, unchanged by story-029. `_executeMint` enforces `require(!config.disabled)` itself, so a disabled dispatcher reverts the batch cleanly rather than mis-charging. |
| Streamer flush loop unbounded in whitelist length (L529), plus two more full-length passes (L756, L786) | **Law-3 footgun, not a permissionless DoS.** | Array is owner-sized. Records as a gas/liveness ceiling on whitelist growth. Pre-existing; story-029 only block-scoped it. |

---

## E. Coverage / errors

- All targeted source read; the cross-repo `NFTMinterV2.sol` read succeeded, so CODE-004's
  escape and A-1's closure argument are evidence-backed rather than assumed.
- Reentrancy-class checklist walked in full: classic (cleared, no value transfer before state —
  contract writes no state), cross-contract (cleared, §D), cross-function (cleared, §D),
  read-only (cleared — no value-reporting view exists), ERC721 receive-hook (n/a — no ERC721),
  ERC1155 receive-hook (**live inbound surface, escapes on three verified grounds — CODE-004**),
  ERC777 hooks (payout leg cleared §D; pull leg is CODE-005). No row silently passed.
- `src/BatchNFTMinter.sol` was **not** fully rescanned (delta-scoped by instruction); the
  targeted grep behind CODE-006 is the extent of coverage there.
- Errors: none.
