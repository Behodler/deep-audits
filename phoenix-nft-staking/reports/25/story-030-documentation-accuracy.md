# story-030 — Documentation and comment accuracy: stop asserting guarantees the code does not provide

**Repo:** `phoenix-nft-staking`
**Baseline:** `5015f1b` (story-029)
**Source:** audit run-25 findings L-02, Q-03, Q-01, Q-02
**Type:** prose only — **no behavioural change, no ABI change, no gas change**

---

## Why this story exists

Run-25 filed a Medium (`pns25m1`) claiming a profitable extraction from the nudge pot. **That finding was withdrawn.** The pot is funded by yield derived from protocol-owned capital via external vaults, so a pot exceeding one batch's cost is an *opportunity cost and a deliberate marketing spend*, not a value leak. Empirically the pot has never reached even 50% of the qualifying cost before someone minted.

The audit reached the wrong conclusion because **the documentation states an operating norm as a construction.** `docs/multi-token-nudge.md` §1 asserts that the pot is "by construction" a fraction of the cost and that *no configuration* makes claiming profitable. No code establishes either claim. A scanner that takes the sentence at face value, finds no code enforcing it, and observes a fixture where the pot exceeds the cost, will conclude the invariant is broken — every time.

The same species of defect appears in three more places: a §4.1 heading broader than the construction it names, a code comment claiming a protection that cannot exist, and a `min` whose second, load-bearing obligation is undocumented.

**The goal is not to add bounds to the code.** The economics are intended. The goal is to make the prose say what is actually true, so that neither a future auditor nor a future author re-derives a defect that is not there — or, worse, "fixes" the economics to match an inaccurate sentence.

Each change below is independently landable. Anchors are given as quoted text plus a line number at `5015f1b`; if lines have drifted, match on the text.

---

## §1 — `docs/multi-token-nudge.md` §1: restate the nudge as subsidy policy (audit L-02)

**Anchor — `docs/multi-token-nudge.md:56-60`, current text:**

> The pot is a *nudge*: **by construction** it is a fraction of the cost of the `nudgeSize` mints required to qualify. A bot that claims it must first pay more payment-token into the protocol than it extracts in reward. **Every claim is net-positive for the protocol; there is no configuration of this mechanism under which claiming is profitable-in-isolation.**

**Why it is wrong.** `qualifies = _nudgeSize != 0 && count >= _nudgeSize` (`src/BatchNFTMinterMultiToken.sol:510`) reads `count` and `nudgeSize` and nothing else. It never reads `paymentAmount`, `price`, `budget`, or `snapshot[i]`. **No expression anywhere in the file relates the pot to the cost.** A count is compared to a count, and a value is paid out. The universally-quantified second sentence is falsified by the repo's own fixture — `test/PoC_PaymentTokenCollision.t.sol` stages a 200.000000 USDC pot against a 50.000000 USDC qualifying cost and asserts, as intended behaviour, that the batcher receives the whole pot.

The §4.6 fallback ("qualifying still costs `nudgeSize` real mints at the ramping price") does not rescue it either: it is void at `growthBasisPoints == 0`, which is how the ratchet index is configured (`setConfig(RATCHET_INDEX, RATCHET_PRICE, 0)`).

**Suggested replacement:**

> The pot is a *nudge*: a subsidy funded by yield derived from protocol-owned capital, paid to whoever performs the `nudgeSize` qualifying mints.
>
> **This relation is an operating policy, not a construction.** Nothing in the contract compares the pot to the cost of qualifying — `qualifies` (`:510`) tests `count >= nudgeSize` and nothing more. The pot *can* exceed one batch's cost, and if it does, a claimant profits in isolation.
>
> That is an accepted and intended outcome. Because the pot is funded from externally-derived yield rather than from principal or user deposits, an over-large pot is an **opportunity cost** — that yield could have gone directly into liquidity growth — and not a loss to the protocol. It is treated as a short-run cost and as marketing spend: a visible profit opportunity attracts users, and the deficit closes as the lowest-bidding marginal user takes the mint. `NudgeStreamer` meters release so the market can find a clearing price against the pot rather than racing a lump sum.
>
> In live operation the pot has not reached 50% of the qualifying cost before being claimed.
>
> **What the contract does guarantee** (story-029, invariant-proven): the pot cannot leave through the refund path (`refund <= budget <= paymentAmount`); a non-qualifying batch takes nothing; and the minter's allowance is bounded at each mint's exact price. Those three are constructions. The pot-versus-cost relation is not.

**Also update `docs/multi-token-nudge.md:299-302`**, which offers the same claim as the ground for the 2026-07-25 owner acceptance:

> That is intended: the pot is by construction a fraction of the cost of the qualifying mints, so every claim is net-positive for the protocol. Making the comparison legible does not change the economics.

Replace the justification with the funding-source argument — the acceptance is sound, but it should rest on *"the pot is yield-funded, so over-payment is opportunity cost, and the streamer meters release for price discovery"*, not on a bound that does not exist. **This matters beyond tidiness:** the sentence is quoted verbatim into the project's known-issues list as the justification of a suppression rule, so an inaccurate premise is currently propagating into what future audits are told not to report.

---

## §2 — `docs/multi-token-nudge.md` §4.1: scope the heading to the construction actually built (audit Q-03)

**Anchors — `:200` and `:213`:**

> ### 4.1 The payment token MAY be a reward token — **SAFE BY CONSTRUCTION** (story 029)

> **The construct is now permitted and safe, not forbidden.**

**Why it is wrong.** Story-029 established exactly **two** properties by construction, both real and both invariant-proven at 128,000 calls: `refund <= budget <= paymentAmount`, and the minter's allowance bounded at the exact per-mint price. The section *body* scopes itself correctly to those two. The heading and the standalone sentence do not — they read as an unconditional blessing, while the payout path at `:790` is bounded by funding discipline rather than by any construction.

This section is otherwise a model of honest revision (it deletes a previously false claim and says so); the heading simply did not get the same treatment.

**Suggested replacement:**

> ### 4.1 The payment token MAY be a reward token — refund path safe by construction (story 029)

> The construct is permitted. **The refund path is safe by construction; the payout path is governed by the funding policy in §1, not by a code bound.**

---

## §3 — `src/BatchNFTMinterMultiToken.sol:647-661`: the `available` cap does not do what its comment claims (audit Q-01)

**Anchor — the comment at `:647-655`**, which justifies retaining the cap:

> …only so an unforeseen shortfall degrades into a smaller refund rather than a revert.

**Why it is wrong.** `available` is an **absolute** balance read:

```solidity
uint256 available = paymentToken.balanceOf(address(this));   // :660
uint256 refund = budget > available ? available : budget;    // :661
```

so `available == P + (credited − C) + D`. A shortfall in the caller's own credit cannot make it bind until the standing pot `P` **and** this batch's donations `D` have already been consumed in full. In precisely the scenario the comment names, the shortfall is absorbed by the pot rather than degrading the refund. A cap that behaved as the prose claims would have to be caller-scoped, and no caller-scoped quantity is tracked after `:581`.

It is also **provably non-binding today**: `budget <= credited` (the `:580` `min`) and `available >= credited − C >= budget`, so `refund == budget` on every constructible path. It is dead code that reads as a safety net — and it sits at the one site the file elsewhere explicitly forbids absolute reads (`:585-605`).

**Pick one:**

- **(a) Delete the cap.** `refund = budget;` — an impossible shortfall then reverts honestly instead of being silently absorbed. Preferred: it removes the dead branch and the false claim together.
- **(b) Keep it, fix the comment.** State that it is a defence-in-depth floor against an erosion mechanism that does not currently exist (e.g. a negative-rebase prime token), that it is non-binding today, and that it cannot degrade a caller-credit shortfall because it is not caller-scoped.

**Worth recording either way**, since it is the durable residual: `budget` is a one-shot measurement pinned at `:581` and never re-validated, so **any** post-`:581` erosion of this contract's payment-token holdings is charged to the pot, silently. This needs no exotic token — a negative-rebase prime token suffices.

---

## §4 — `src/BatchNFTMinterMultiToken.sol:562-581`: the `min` carries two obligations, one undocumented (audit Q-02)

**Anchor — `:580`, and its consequence at `:664`:**

```solidity
budget = credited < paymentAmount ? credited : paymentAmount;   // :580
...
totalPaid = paymentAmount - refund;                             // :664  — guard deliberately removed
```

**Why it matters.** At `d75229d` this read `totalPaid = paymentAmount > remaining ? paymentAmount - remaining : 0`. Story-029 removed the `>` guard deliberately — commit `0318089` §3.3 names its *absence* as the marker of the fix, and that is correct. But the removal is safe **only** because `refund <= budget <= paymentAmount`, which holds **only** because of the `min` at `:580`. The 20-line comment at `:562-571` justifies that `min` almost entirely as a donation-routing defence; the underflow obligation appears in a single clause.

A future author reasoning only about donation routing — relaxing the cap to a floor, or substituting the measured `credited` on the grounds that measuring is strictly more honest — reintroduces an **underflow revert DoS** at `:664`, with no local warning and no test name pointing at it.

**Suggested addition at the `min` site:**

```solidity
// This min carries TWO independent obligations. Both must survive any future edit:
//   1. Donation routing — a transfer landing inside the pull window must not be
//      credited to msg.sender (see the discussion above).
//   2. Underflow safety at :664 — `totalPaid = paymentAmount - refund` is bare, with
//      no floor guard, because story-029 removed it as the marker of this fix. It is
//      safe solely because refund <= budget <= paymentAmount, which this min establishes.
//      Relax this cap to a floor, or substitute the measured `credited`, and :664
//      underflows and reverts.
```

**Add a regression test named for obligation 2**, so the coupling is discoverable by grep — e.g. `test_MinIsLoadBearing_totalPaidCannotUnderflow`.

---

## §5 — OPTIONAL: disclose the sub-dust `totalPaid` misreport (audit F-25-04)

**Include only if you want it.** The audit finding this belongs to (M-03 / L-01, sub-dust refund forfeiture) was triaged **won't-fix** — dust shuffling is acceptable. This is the *disclosure* half only, and it costs one paragraph.

**Anchor — `docs/multi-token-nudge.md:305-310`**, which describes where sub-threshold residue goes ("they stay behind as pot — which is the correct owner for them") but omits the accounting consequence:

```solidity
} else {
    totalPaid = paymentAmount;   // :666
}
```

When a refund falls below `DUST_THRESHOLD` it is dropped **whole**, and `totalPaid` reports the caller spent their entire `paymentAmount`. An integrator therefore has no signal to reconcile `totalPaid` against an observed balance delta. Note also that `DUST_THRESHOLD = 1e6` is a raw-wei constant: on a 6-decimal prime token — which `NudgeRatchet`'s constructor *requires* — that is very nearly one whole token, not dust in the 18-decimal sense the NatSpec at `:142-145` describes.

One sentence in the docs closes the disclosure gap without changing behaviour.

---

## Acceptance

- [ ] §1 — §1 and the acceptance rationale at `:299-302` restate the pot as yield-funded subsidy policy; no claim of a code-enforced bound remains
- [ ] §2 — §4.1 heading and blessing sentence scoped to the refund path
- [ ] §3 — `available` cap either deleted or its comment corrected; the one-shot-`budget` residual recorded
- [ ] §4 — both obligations pinned at the `:580` `min`; regression test added and named for obligation 2
- [ ] §5 — optional, include or drop
- [ ] `forge test` still green (535/535 at `5015f1b`) — **no behavioural change is intended by this story**
- [ ] `.gas-snapshot` unchanged

## Out of scope

Do **not** add a value-aware cap to the payout in response to this story. Run-25 proposed one; it was withdrawn. The economics are intended, and the correct remedy is accurate prose, not a new bound.
