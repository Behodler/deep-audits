# Plan — Make `paymentToken ∈ nudgeWhitelist` structurally safe in `BatchNFTMinterMultiToken`

**Target repo:** `phoenix-nft-staking` (audited here as `lib/phoenix-nft-staking` and
`lib/yield-claim-nft/lib/phoenix-nft-staking`, both **read-only** — implement upstream)
**Audited commit:** `d75229d` (`d75229df902b5e53e5e6b55a34db76d687fc1a52`)
**Primary file:** `src/BatchNFTMinterMultiToken.sol` (the **undeployed twin**; the frozen mainnet
`src/BatchNFTMinter.sol` is explicitly out of scope and unchanged)
**Author/decision:** owner (justin), 2026-07-25
**Supersedes:** `docs/phoenix-nft-staking-batchminter-approval-cap-plan.md` — that plan's single-line cap
is subsumed by §3.1 here, in a strictly tighter form. Do not implement both.

**Ledger entries affected:** `ad36260f…` (M-07, approval — **raised to `fix-pending`**, see §7) ·
`fcaca0025…` (M-01, step-10 sweep, `wont-fix`) · `7a1718e9a…` (M-01, composition, `wont-fix`) ·
`2d34673536…` (L-04, streamer-flush leak, open) · `fb17fc6d07…` (M-06, `setDispatcherIndex` guard, open) ·
`a62fe01a…` (M-02, dedupe, `fix-pending`) · yield-claim-nft submission **`ycn19h1`** (CONDITIONAL High,
`reports/yield-claim-nft-19/submissions/H-01.md`)

---

## 1. Decision

**The payment token is permitted to be a nudge-whitelisted token.** The construct becomes safe — not
merely tolerated — by replacing the balance-derived refund with a **locally-tracked budget**, and by
holding the minter's allowance at an **absolute, per-mint exact amount** rather than
`type(uint256).max`.

Consequently the runtime payment-token *skip* in `_snapshotRewards` (`:558`) is **removed**: the payment
token is paid out through the normal reward path like any other whitelisted token, and the admin-time
rejection in `setNudgeTokenWhitelist` (`:250-256`) is **relaxed**.

This closes `ycn19h1` at its root rather than gating a symptom.

---

## 2. Why the collision is unsafe today, and why ordering alone does not fix it

`batchMint` already runs in the right order:

```
3.5  flush NudgeStreamer          → pot lands
4    _snapshotRewards             → balanceOf read  (:453)
5    safeTransferFrom(caller, …)  → paymentAmount arrives  (:456)
7    mint loop                    → cost leaves, donations arrive
9    _payRewards                  → snapshot paid out  (:477)
10   whole-balance sweep          → residual → msg.sender  (:479-486)
```

Because step 4 precedes step 5, `paymentToken.balanceOf(address(this))` at snapshot time is the
**uncontaminated pot**: the caller's budget has not arrived, and this batch's own donations have not
happened. That reading is exactly as clean as any other whitelisted token's. `_snapshotRewards` then
throws it away with `if (rewardToken == paymentToken) continue;`.

**The defect is not ordering — it is step 10.** The refund is derived from `balanceOf`, and after the
loop that single number conflates three pools that no reordering can separate after the fact:

| Pool | Belongs to | Size |
|---|---|---|
| `P` — the standing nudge pot | the next qualifying batch | streamer-fed, unbounded |
| `A − C` — unspent caller budget | `msg.sender` | ≤ `paymentAmount` |
| `D` — this batch's own donations | the *next* claimant (donate-forward, §4.2) | per-batch |

Step 10 hands `P + (A − C) + D` to `msg.sender`. With `count = 1 < nudgeSize` the batch does not
qualify, `_payRewards` pays nothing, and the entire pot exits as "residual". That is `ycn19h1`: **190
USDC extracted from a 200 USDC pot for a 1 wei payment**, repeatable on every refill.

Fixing the *refund source* removes the conflation. Everything else follows.

---

## 3. The change

All line numbers are against `d75229d`.

### 3.1 Track the budget locally; hold the allowance at an absolute per-mint exact amount

Replace steps 6–8 (`:458-467`).

```diff
-        // --- 6. Approve the pinned minter for the loop. ---
-        paymentToken.forceApprove(address(nftMinter), type(uint256).max);
-
-        // --- 7. Mint loop. ---
-        for (uint256 i; i < count; ++i) {
-            nftMinter.mint(_dispatcherIndex, recipient);
-        }
-
-        // --- 8. Revoke the approval. ---
-        paymentToken.forceApprove(address(nftMinter), 0);
+        // --- 6 + 7. Mint loop, allowance held at the EXACT next mint price. ---
+        //
+        // `budget` is THIS CALLER'S money and nothing else. It is decremented by
+        // the authoritative price the minter is about to charge, so it never
+        // observes the pot, never observes this batch's own donations, and is
+        // the ONLY source of the refund in step 10. Do not re-derive it from
+        // `balanceOf` — that is the exact conflation this design removes.
+        //
+        // Every `forceApprove` below sets an ABSOLUTE target, never a delta.
+        // For a well-behaved ERC20 that decrements allowance on `transferFrom`
+        // the write is idempotent; for one that does NOT decrement it is
+        // corrective. Correctness therefore does not depend on the token's
+        // allowance-decrement behaviour at all.
+        uint256 budget = paymentAmount;
+        for (uint256 i; i < count; ++i) {
+            (, uint256 price,,) = INFTMinterV2(address(nftMinter)).configs(_dispatcherIndex);
+            if (price > budget) revert BatchMint__PaymentBudgetExhausted(i, price, budget);
+            paymentToken.forceApprove(address(nftMinter), price);
+            budget -= price;
+            nftMinter.mint(_dispatcherIndex, recipient);
+        }
+
+        // --- 8. Revoke. Absolute and idempotent: zeroes any allowance a
+        //        non-decrementing token left standing after the final mint. ---
+        paymentToken.forceApprove(address(nftMinter), 0);
```

Why the per-iteration `configs` read: `NFTMinterV2._executeMint` charges exactly `config.price`
(`yield-claim-nft/src/NFTMinterV2.sol:183`) and then ramps it —
`config.price = price + (price * growthBasisPoints) / 10000` (`:188`). The price therefore changes under
us on every iteration and must be re-read, not extrapolated. Computing the ramp locally with the same
floor-rounding is a valid gas optimisation but makes the batcher's arithmetic a *convention* that must
track the minter; re-reading keeps it **by construction**. Take the optimisation only with a differential
test pinning the two against each other across ≥ 32 iterations.

A new error is required:

```solidity
/// @dev Reverted when the caller's remaining budget cannot cover the next
///      mint's price. Replaces the opaque ERC20 allowance/balance revert that
///      an under-funded batch used to produce.
error BatchMint__PaymentBudgetExhausted(uint256 mintIndex, uint256 price, uint256 remaining);
```

### 3.2 Remove the runtime payment-token skip

In `_snapshotRewards` (`:549-566`):

```diff
         for (uint256 i; i < tokenCount; ++i) {
             address rewardToken = _nudgeTokens[i];
-            if (rewardToken == paymentToken) continue;
             uint256 available = qualifies ? IERC20(rewardToken).balanceOf(address(this)) : 0;
```

The `paymentToken` parameter becomes unused and should be dropped from the signature and from the call
site at `:453`.

The snapshot is taken **before** the pull, so the payment token's reading is the clean pot. Its
`minRewards[i]` floor becomes live instead of silently ignored — a strict improvement, and the reason
the `@param minRewards` NatSpec (`:370-387`) must lose the "*including any entry currently equal to the
derived payment token, whose floor is ignored*" clause.

### 3.3 Refund before payout, from `budget` only

Swap steps 9 and 10 and rewrite the sweep (`:469-486`):

```diff
-        _payRewards(recipient, snapshot);
-
-        // --- 10. Dust sweep of residual payment token back to msg.sender. ---
-        uint256 remaining = paymentToken.balanceOf(address(this));
-        if (remaining / DUST_THRESHOLD != 0) {
-            paymentToken.safeTransfer(msg.sender, remaining);
-            totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0;
-        } else {
-            totalPaid = paymentAmount;
-        }
+        // --- 9. Refund the caller's UNSPENT BUDGET. Not a balance sweep. ---
+        //
+        // ORDER IS LOAD-BEARING: the caller's own money is returned BEFORE the
+        // pot is distributed, so a payout can never be funded out of a refund
+        // that is owed, and vice versa.
+        //
+        // `refund <= paymentAmount` HOLDS BY CONSTRUCTION, because `budget`
+        // starts at `paymentAmount` and only ever decreases. The `available`
+        // cap is a fail-safe for fee-on-transfer / rounding shortfall ONLY: it
+        // can lower the refund, never raise it, and is never the source.
+        uint256 available = paymentToken.balanceOf(address(this));
+        uint256 refund = budget > available ? available : budget;
+        if (refund / DUST_THRESHOLD != 0) {
+            paymentToken.safeTransfer(msg.sender, refund);
+            totalPaid = paymentAmount - refund;
+        } else {
+            totalPaid = paymentAmount;
+        }
+
+        // --- 10. Payout pass (see the §4.2 note on `_snapshotRewards`). ---
+        _payRewards(recipient, snapshot);
```

`totalPaid` loses its `> ` floor guard: `refund <= budget <= paymentAmount` makes
`paymentAmount - refund` unconditionally safe. That guard existing at all (`:483`) was the contract
admitting the refund could exceed the contribution; its removal is the visible marker that the property
now holds.

---

## 4. Why it holds

Let `P` = pot at snapshot, `A` = `paymentAmount`, `C` = Σ mint prices, `D` = this batch's own donations.

| Step | Payment-token balance |
|---|---|
| after flush + snapshot (`P` captured) | `P` |
| after pull | `P + A` |
| after loop | `P + A − C + D` |
| after refund of `A − C` | `P + D` |
| after payout of `P` (qualifying) | `D` |

- **Solvency.** The refund needs `A − C`; the balance holds `P + A − C + D ≥ A − C`. Always solvent.
- **Pot integrity.** `refund ≤ budget ≤ A`. The pot can never leave through the refund, for any `count`,
  any `nudgeSize`, any dispatcher index.
- **`ycn19h1` is dead.** `count = 1`, `qualifies == false` ⇒ snapshot `0`, no payout; `refund = A − C`;
  pot untouched. The `paymentAmount = 1 wei` call now reverts at
  `BatchMint__PaymentBudgetExhausted(0, price, 1)` — the allowance is capped at the *exact* price and
  cannot be topped up out of the pot.
- **Donate-forward (§4.2) survives.** `D` arrives after the snapshot and is not part of `budget`, so it
  stays behind for the next claimant. Unchanged for the payment token and every other whitelisted token.
- **No self-funding.** The caller's `A` arrives after the snapshot, so it can never be paid back to them
  as a reward.
- **`ad36260f…` is closed strictly tighter than the superseded plan.** That plan capped the allowance at
  `paymentAmount` for the whole loop; this caps it at a single mint's price at a time and re-asserts it
  absolutely on every iteration.

---

## 5. Consequences to accept before implementing

1. **`setNudgeTokenWhitelist`'s payment-token rejection (`:250-256`) may be relaxed.** Keep
   `BatchMint__RewardTokenIsPaymentToken` for a release or two behind a comment marking it defence in
   depth, or remove it — but the *reason* for it is gone. Relaxing it is the point of this plan.
2. **`fb17fc6d07…` (`setDispatcherIndex` has no reciprocal guard) stops being a security finding.** A
   repoint now moves a token between roles instead of opening an unguarded exit. The entry should be
   re-weighed to QA once this lands. **Do not close it before then** — it is live at `d75229d`.
3. **`ad36260f…` must come off `wont-fix`.** This design does not work without §3.1: without the
   allowance bound, `C` can exceed `A` and eat `P`, and the whole budget-tracking argument collapses.
   Applied in §7.
4. **Gas.** One `configs` staticcall + one `forceApprove` SSTORE per mint, replacing two SSTOREs per
   batch. For `count = 20` this is roughly `20 × (2.1k + 5k)` extra. Deliberate: the batcher is a
   convenience wrapper, not a hot path, and the cost buys token-behaviour independence.
5. **Under-quoting front-ends now revert loudly.** A batch that previously drew silently on contract
   balance gets `BatchMint__PaymentBudgetExhausted` naming the failing mint index and the shortfall. This
   is the intended regression and the reason the error carries all three values.
6. **Arbitrage — accepted, see §6.**

---

## 6. Accepted trade-off — same-denomination nudge arbitrage (DO NOT RE-FILE)

**Owner decision, 2026-07-25: accepted.**

Once the payment token is a nudge token, the qualifying cost and the reward are denominated in the
**same asset**, so profitability becomes directly comparable rather than requiring a cross-asset price:
a batcher profits whenever `pot > Σ(nudgeSize mint prices)`. Where that condition previously needed an
oracle to evaluate, it is now arithmetic any bot can do in one `eth_call`, so the pot will be taken
promptly and predictably whenever it exceeds the qualifying cost.

**This is intended behaviour and must not be reported as a finding.** The rationale is the contract's own,
already on the record at `:62-70`:

> *"The 'honeypot' framing does not apply, because the pot is by construction a fraction of the cost of
> the `nudgeSize` mints required to qualify — every claim is net-positive for the protocol. If someone
> over-funds this contract beyond the mint cost and a bot snipes it, that is still correct behaviour;
> the error was in the sender."*

Making the arithmetic legible does not change the economics; it only removes the friction that was
accidentally protecting a misconfiguration. The sizing obligation — keep `nudgeSize × price` above the
expected steady-state pot — was always the owner's and is unchanged.

**Scope of this acceptance.** It covers *only* the observation that same-denomination pot-vs-cost
arbitrage is legible and promptly executed. It does **not** cover, and these remain reportable:

- any path where the pot leaves **without** the caller paying for `nudgeSize` real mints;
- any path where `refund > paymentAmount`;
- any path where a **non-qualifying** batch extracts pot-sized value (i.e. an `ycn19h1` recurrence);
- the aggregate over-funding class (`858e9e80…`, and the run-22 Σ-pots Medium) — those are about the
  *pot being too large relative to cost*, a different claim from *the comparison being easy*.

Recorded in `registered-projects.json` → `phoenix-nft-staking.knownIssues` / `designDecisions` so the
sanitizer suppresses re-filings, and cross-noted on the `yield-claim-nft` side, which supplies the
USDC-prime dispatchers that make the same-denomination case reachable.

---

## 7. Ledger consequences (applied 2026-07-25)

| Fingerprint | Was | Now | Basis |
|---|---|---|---|
| `ad36260f…` (M-07, approval) | `wont-fix` | **`fix-pending`** | The 2026-07-21 closure's own rider: *"IF THE TWO FIXES ARE EVER SPLIT INTO SEPARATE COMMITS, RAISE `ad36260f…` BACK TO `fix-pending`."* This plan splits them — the approval leg now ships as part of a larger budget-tracking change, no longer alongside the `a62fe01a…` dedupe. `fix-pending` is never suppressed and never auto-closed, so the fix stays rescanned until a human verifies it. |
| `fcaca0025…`, `7a1718e9a…` | `wont-fix` | **unchanged** | Their closure is scoped to the frozen deployed `src/BatchNFTMinter.sol`, which this plan does not touch. §3 lands the twin-side remedy those closures explicitly left open. |
| `d06e3191…` (`ycn19h1`, yield-claim-nft H-01, CONDITIONAL High) | open | **`fix-pending`** | Accepted on the merits; the remedy in §3 is broader than either mitigation the submission proposed. Never suppressed, never auto-closed. |
| `2d34673536…` (L-04, the phoenix-side twin `ycn19h1` was re-weighed from) | open | **`open`, annotated** | One fix closes both. Left at `open` rather than mirrored to `fix-pending` because `open` is equally never-suppressed — the distinction is cosmetic, the obligation is not. **Neither may be closed until the other is** (Law 1, MR-03). Propose `fixed` only after §8 passes. |
| `fb17fc6d07…` (M-06) | open | **unchanged** | Re-weigh to QA *after* this lands (§5.2), not before. |

> ⚠ **`fix-pending`, not `acknowledged`.** A fix is owed here. Filing it `acknowledged` would suppress it
> from every future scan precisely while someone depends on the fix landing correctly.

---

## 8. Verification (TDD — red → green → refactor, Foundry only)

Per `lib/phoenix-nft-staking/CLAUDE.md`: TDD, Foundry only, **no `script/` directory**.

**Red first — the `ycn19h1` arm.**

1. `test_PaymentTokenAsNudge_nonQualifyingBatchTakesNothing` — port
   `Run19_T1_PaymentTokenCollision` from
   `reports/yield-claim-nft-19/pocs/run19-Tier3Nudge.patch`. 20 honest mints seed a 200 USDC pot via the
   real `NudgeStreamer`; `setDispatcherIndex` to the USDC-prime index; attacker calls
   `batchMint(1, attacker, 1, …)`. **Must fail before the change** (extracts 190 USDC) and revert
   `BatchMint__PaymentBudgetExhausted` after. PoC convention is **PASS = defect reproduced**, so these
   must flip; a PoC that stops *compiling* is inconclusive bit-rot, not a fix.

**Core properties.**

2. `test_RefundEqualsUnspentBudgetExactly` — over-supply `paymentAmount` against a fat pot on a
   `growthBasisPoints > 0` dispatcher; assert `refund == paymentAmount − Σprices` **exactly** and pot
   delta `== −P` (qualifying) or `== 0` (non-qualifying).
3. `test_PaymentTokenAsNudge_qualifyingBatchIsPaidThePot` — `count >= nudgeSize` pays `P` to `recipient`
   through `_payRewards`, emitting `NudgePaid` for the payment token. Pins §3.2.
4. `test_OwnDonationsDoNotRefundToBatcher_paymentTokenArm` — the §4.2 property extended to the colliding
   token: `D` stays in the contract, is not refunded and is not paid to `recipient`.
5. `invariant_RefundNeverExceedsPaymentAmount` — Foundry invariant over fuzzed
   `count`/`paymentAmount`/`nudgeSize`/pot. This is the property run-20 D-35 required to be *established
   and tested* rather than shipped as an unvalidated patch; §3.3 makes it structural, and this pins it.
6. `invariant_PotOnlyLeavesViaQualifyingPayout` — pot delta is `0` or `−P`, never partial.

**Token-behaviour independence (§3.1).**

7. `test_NonDecrementingAllowanceToken_refundUnaffected` — mock ERC20 whose `transferFrom` does **not**
   decrement allowance. Assert the refund is identical to the well-behaved case and that
   `allowance(batch, minter) == 0` on exit. This is the test that would fail under an
   allowance-*reading* design and is the reason for the absolute-approval rule.
8. `test_ApprovalIsAbsoluteNotDelta` — assert `allowance(batch, minter) == price_i` immediately before
   each inner mint (via a recording mock minter), and `== 0` after the loop.
9. `test_FeeOnTransferPaymentToken_refundCapsAtAvailable` — pins the `available` fail-safe as a *cap*:
   the refund shrinks, the pot is not touched, and nothing reverts.

**Boundaries and regression.**

10. Cumulative charge exactly equal to `paymentAmount` succeeds; one wei short reverts
    `BatchMint__PaymentBudgetExhausted` at the correct `mintIndex`.
11. Ramping-price control (`growthBasisPoints > 0`) — the caller must pass the true cumulative amount;
    confirm the surplus refund still returns the excess.
12. `PoC_EconZeroPaymentSweep.t.sol` — the 4 `PoC_ZeroPaymentSweep_MultiToken` tests must **no longer
    reproduce**. The 7 `PoC_ZeroPaymentSweep_DeployedBatchNFTMinter` tests **must still reproduce**;
    that file is frozen and unfixed, and their continuing to pass is the correct result.
13. Full upstream suite stays green.

---

## 9. Documentation changes (mandatory — the NatSpec currently states the opposite)

The contract tells the owner the exclusion is guaranteed *by construction*. Once §3 lands, three claims
are wrong and one is inverted. All must change in the same commit.

| Site | Current text | Required change |
|---|---|---|
| `:44-49` | *"Vetting the token set at admin time (1) makes a payment-token/nudge-token conflict structurally impossible to exploit"* | Rewrite: the conflict is **permitted and safe**, because the refund derives from a tracked budget rather than a balance. |
| `:335-343` | *"**The derived payment token can never be whitelisted**… the snapshot loop SKIPS that entry at runtime… while still keeping the payment-token balance out of the payout (that balance follows the normal dust-sweep path)."* | Delete. The skip is gone; the payment token **is** part of the payout, and there is no dust-sweep path for it any more. This sentence is the one that was affirmatively false at `d75229d`. |
| `:370-387` (`@param minRewards`) | *"…including any entry currently equal to the derived payment token, whose floor is ignored"* | Delete the clause — the floor is now live for that entry. |
| `:489-493` (`_resolvePaymentPath`) | *"the admin-time payment-token exclusion is checked against exactly the token `batchMint` would derive — by construction, not by convention"* | Rewrite or delete along with the relaxed admin check (§5.1). |
| `:531-541` (`_snapshotRewards`) | *"…skipping keeps `batchMint` live instead of bricking it, while the payment-token balance stays out of the payout"* | Delete. This is the property `ycn19h1` proved does not hold; it must not survive as a stale comment. |
| `:17-20` (contract header) | *"pre-approves the minter for `type(uint256).max`"* | Update to the per-mint exact approval. |
| new, at the loop | — | Add the **DO NOT re-derive `budget` from `balanceOf`** warning verbatim from §3.1, in the style of the existing §4.2 `DO NOT "SIMPLIFY" THIS` block. |
| new, at step 9 | — | Add the **ORDER IS LOAD-BEARING** note: the snapshot must stay before the pull, and the refund before the payout. Two ordering constraints now hold this function up, not one. |

`docs/multi-token-nudge.md` §4.1 (the payment-token exclusion) and §4.2 (donate-forward) need the
matching edit; §4.2's substance is unchanged and should say so explicitly.

---

## 10. What this plan does NOT do

- **The frozen deployed `src/BatchNFTMinter.sol`** is untouched and unfixable. Compensating operational
  controls stand: do not route payment token to either live instance, and set a non-zero `pauser`
  (ledger `919b71fd…`, still open — free and immediate, `pauser() == address(0)` on both live instances).
- **`858e9e80…` (value-blind nudge gate)** and **`521c20ad…` (MEV race)** remain accepted `wont-fix` and
  are not addressed. §6 does not re-open or re-close them.
- **The live-configuration question `ycn19h1` raises stays open until answered on-chain.** Before any
  code ships: read `dispatcherIndex` on the deployed instance, resolve that index's dispatcher
  `primeToken()`, and test it with `isNudgeToken(...)`. A whitelisted result means the pot is drainable
  *now*, and operational action precedes the code change.
