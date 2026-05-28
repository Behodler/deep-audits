# Code Scan (Tier 2, interaction-level) - StableYieldAccumulator

- **Contract:** `lib/stable-yield-accumulator/src/StableYieldAccumulator.sol` @ 71abe3e
- **Interface:** `src/interfaces/IStableYieldAccumulator.sol`
- **Scanner:** code-scanner (interaction-level, profile-first)
- **Inputs:** `profile.md`, `static-analysis.md`
- **Date:** 2026-05-27

Consumer context (from submodule `CLAUDE.md`): a `ClaimArbitrage` contract flash-borrows,
calls `claim()`, and reconciles `usdcBorrowed - phlimboPayment + usdcFromStrategies`. SYA's
`rewardToken` payment leg and the strategy-yield leg therefore both feed a downstream atomic
accounting check, which raises the stakes on payment-rounding correctness.

---

## Findings

### CODE-001 — `claim()` can deliver skimmed yield while charging 0 payment (payment floors to zero)
- **Severity:** Low (QA-leaning; bounded to sub-unit dust per claim, gated by NFT burn)
- **Type:** rounding / value-conservation
- **Location:** `claim()` L494, L497-498, L509; `_denormalizeAmount` L617-639
- **Status:** CONFIRMED (seed #1), but impact is dust-bounded — see numbers.

**Root cause.** The zero-amount guard at L494 checks only the 18-decimal aggregate
`totalNormalizedYield == 0`. After applying the discount (L497) and denormalizing to the
reward token's decimals (L498, which **floors** in `_denormalizeAmount`), `actualPayment` can
be `0` while the strategy skim at L484 has already delivered non-zero native yield to the
claimer. L509 then executes `safeTransferFrom(msg.sender, address(this), 0)`, which succeeds,
so the claimer keeps the skimmed yield for free.

**Concrete trigger (USDC reward token, 6 dp, 2% discount):**
- One strategy skims `underlyingReceived = 1` (1e-6 USDC) to the claimer (L484).
- `_normalizeAmount(1, USDC) = 1 * 10^12 = 1e12` → `totalNormalizedYield = 1e12` (L489).
- L494: `1e12 != 0` → passes.
- `claimerPayment = 1e12 * 9800 / 10000 = 9.8e11` (L497).
- `_denormalizeAmount(9.8e11, USDC) = 9.8e11 / 10^12 = 0` (floor, L634) → **`actualPayment = 0`**.
- L501 with `minRewardTokenSupplied = 0` passes; L509 transfers 0; claimer keeps 1e-6 USDC free.

**Bound on impact.** The floor at L498 loses at most `< 1` native reward-token unit of payment
per claim (`10^(18-decimals)-1` in 18dp terms). At the documented 2% discount only
`underlyingReceived == 1` floors to zero (max free skim = 1e-6 USDC/claim). The free window
grows with discount: 90% → up to 9e-6 USDC/claim, 99.99% → up to ~0.01 USDC/claim. Every claim
burns exactly one NFT (L458/536), so draining a meaningful sum requires burning a proportional
number of NFTs; whether that is profitable is an **econ-scanner** question (NFT mint cost vs.
dust). The attacker also cannot freely choose `underlyingReceived` — `skimSurplus` delivers
whatever surplus the strategy currently holds (L481-484) — so this is opportunistic, not a
freely-amplifiable steal. **Refined verdict: real correctness defect, but value leak is dust,
hence Low/QA, not High.** The seed's "direct value theft" framing does not hold up at the
default discount.

**Fix sketch.** After computing `actualPayment`, require it to be non-zero whenever yield was
delivered: `if (actualPayment == 0) revert ZeroAmount();` (place after L498). This guarantees
the claimer always pays at least 1 unit when any strategy was skimmed.

---

### CODE-002 — Phlimbo allowance depletion bricks `claim()` until owner re-approves (cross-contract liveness)
- **Severity:** Low (availability; owner-recoverable, no value loss)
- **Type:** cross-contract liveness / call-chain dependency
- **Location:** `approvePhlimbo` L369-374 (`forceApprove`) vs `claim` L519 (`IPhlimbo.collectReward(phlimboAmount)`)
- **Status:** CONFIRMED interaction concern.

**Root cause.** `approvePhlimbo` sets a **fixed** allowance via `forceApprove(phlimbo, amount)`.
`claim()` does not top this allowance up; it relies on `collectReward(phlimboAmount)` pulling
`phlimboAmount` of `rewardToken` from SYA via that allowance (interface §5b). Each successful
claim consumes part of the allowance (standard `transferFrom` decrement). Once the cumulative
`phlimboAmount` across claims exceeds the approved amount, `collectReward` reverts and **every
subsequent `claim()` reverts** (L519) until the owner calls `approvePhlimbo` again.

**Trigger.** Owner approves a finite amount (e.g. 1000 USDC). Claims proceed until ~1000 USDC
of `phlimboAmount` has been forwarded; the next claim reverts inside `collectReward`. Permissionless
claiming is DoS'd for all users until owner re-approval. No funds lost (claim is atomic; failed
claim rolls back the skim and the `transferFrom`-in), but availability is interrupted.

**Note / dependency caveat.** Behavior depends on `IPhlimbo.collectReward`'s actual semantics
(the `phlimbo-ea` submodule is not checked out, see static-analysis compilation note). If
`collectReward` instead pulls SYA's full balance or uses `type(uint256).max` allowance, this
does not arise. Flagged for confirmation against the real `phlimbo-ea` implementation; if it is
a fixed-amount `safeTransferFrom`, this is a live operational footgun.

**Fix sketch.** Either (a) approve `type(uint256).max` once in `approvePhlimbo` (Phlimbo is a
trusted protocol contract), or (b) have `claim()` re-approve `phlimboAmount` immediately before
`collectReward`, or (c) push instead of pull (`safeTransfer(phlimbo, phlimboAmount)` and drop
the allowance model). Document the operational requirement either way.

---

### CODE-003 — `claim()` NatSpec describes payment-before-skim, code does skim-before-payment (doc/impl mismatch)
- **Severity:** QA
- **Type:** specification deviation
- **Location:** docstring L426-434 (and interface L314-323) vs code: skim at L484 (in loop), payment pull at L509
- **Status:** CONFIRMED. Cosmetic — NOT exploitable.

**Root cause.** Both the implementation docstring ("5. Transfer rewardToken FROM claimer TO
phlimbo … 6. skimSurplus each … strategy") and the interface docstring list the payment leg
*before* the skim leg. The actual execution order is the reverse: strategies are skimmed to the
claimer (L484) inside the accumulation loop, and only afterward is the payment pulled (L509).

**Why it is safe (refuting the "yield delivered before payment" exploit angle, seed #2/#5).**
The entire body is atomic under one transaction with `nonReentrant` (L447). If the payment pull
at L509 reverts (insufficient claimer balance/allowance), the whole transaction reverts and the
L484 skims are rolled back — no yield escapes unpaid. `skimSurplus` transfers a standard ERC20
to the claimer (no ERC777-style callback in the trusted token set), and re-entry into `claim`
is blocked. The NFT burn (L458/536) precedes both legs and is also rolled back on any later
revert, so a failed payment never wastes the NFT. **Seeds #2 and #5 do not yield a finding** —
ordering is benign; only the documentation is wrong.

**Fix sketch.** Correct the NatSpec on `claim()` (and `IStableYieldAccumulator.claim`) to reflect
the real order (skim-then-pay), or note that the order is immaterial because the call is atomic.

---

## Seeds explicitly refuted (with reasons)

- **Seed #3 — divide-before-multiply in `_denormalizeAmount` (Slither L629/L634): REFUTED as a
  finding.** In the reachable `decimals <= 18` path the operations are
  `scaled = scaled * 1e18 / exchangeRate` (L629, **multiply-before-divide**, correct) followed by
  `scaled = scaled / 10^(18-decimals)` (L634, a single trailing divide — no later multiply).
  Random fuzz (200k cases, 6/8/18 dp, rates 0.5–2.0×) shows max absolute error of **1 wei**, in
  the claimer's favor (rounds down). A genuine divide-before-multiply exists only in the
  `decimals > 18` branch (L636 multiplies after the L629 divide), but `setTokenConfig` enforces
  `decimals <= 18` (L282), so that branch is **dead** for any configured token. No
  cross-strategy compounding: each strategy's yield is normalized independently and summed in
  18dp (L489); the single floor happens once at the aggregate denormalize (L498). Sub-wei,
  claimer-favorable, mostly the same root as CODE-001's floor.

- **Seed #6 — `exemptStrategies` lets a claimer reduce payment while still skimming: REFUTED.**
  The exemption `continue` (L479) fires **before** the `skimSurplus` call (L484) and before the
  yield accumulation (L489). An exempted strategy is therefore neither skimmed nor charged —
  perfectly symmetric. There is no asymmetry to extract value from. `calculateClaimAmount`
  mirrors the same skip (L673), and both validate exempt entries are registered (L454/L654)
  before use. The exemption is a benign DoS-escape hatch, as designed.

- **Seed #4 — `rewardToken` with no TokenConfig mis-scales `_denormalizeAmount` by ~1e12:
  REAL behavior, but an owner-config/deploy-ordering footgun, not an attacker-reachable bug.**
  `setRewardToken` (L360) does not require a TokenConfig, and `_denormalizeAmount` early-returns
  the unscaled 18dp amount when `decimals==0 && exchangeRate==0` (L622-624). For a 6dp reward
  token with no config, `actualPayment` would be ~1e12× too large, so `safeTransferFrom` (L509)
  reverts on the claimer's balance — claims simply fail (safe-fail), they do not leak value. This
  is a misconfiguration the deploy script must avoid (set the reward token's config before
  enabling claims); per the project's "reckless admin mistakes are known-invalid" rule and the
  per-repo scope rule, this is at most a QA hardening note, not an H/M. Recommend `setRewardToken`
  require an existing TokenConfig (or `claim` assert `tokenConfigs[rewardToken].decimals != 0`)
  to convert a silent footgun into a loud revert at config time.

---

## General pass results

- **Access control on state mutators:** all setters are `onlyOwner` (L190, 227, 243, 280, 293,
  302, 324, 348, 360, 369, 385, 396, 414). `pause()` is `onlyPauser` (L204); `unpause()` is
  owner-or-pauser (L212-213). `claim()` is the sole permissionless mutator and is
  `whenNotPaused nonReentrant`. No missing or mis-scoped modifiers across call chains. The
  ADERYN-001 "nonReentrant not first modifier" note is benign: the only preceding modifier is
  `whenNotPaused`, which makes no external call before the guard engages.
- **Accounting conservation (I4):** `nudgeAmount + phlimboAmount == actualPayment` exactly
  (L512-513, subtraction-derived) — verified. SYA holds no residual reward token after a normal
  claim **provided** `collectReward` pulls exactly `phlimboAmount` (the allowance dependency in
  CODE-002).
- **Decimal normalization:** correct in the configured `decimals <= 18` path; only sub-wei
  flooring (CODE-001/seed #3). The unconfigured early-return is the seed-#4 footgun.
- **Partial-failure state consistency:** `claim()` is atomic and `nonReentrant`; any revert
  (NFT burn, skim, payment, nudge transfer, collectReward) rolls back the entire transaction,
  including the NFT burn. No partial state observed. `removeYieldStrategy` keeps the
  array/`isRegisteredStrategy`/`strategyTokens` trio in sync (I1, L250-257) — verified.
- **`getTotalYield` (L738) / `canClaim` (L700):** view-only bot helpers; `canClaim` loops over an
  externally-controlled `nftMinter.nextIndex()` — gas DoS on `eth_call` only, not on-chain.
  Not a Tier-2 finding.

---

## Summary table

| id | title | severity | location | status |
|----|-------|----------|----------|--------|
| CODE-001 | `claim()` floors payment to 0 while delivering skimmed yield | Low/QA | L494,498,509; 617-639 | confirmed, dust-bounded |
| CODE-002 | Phlimbo allowance depletion DoSes `claim()` until re-approval | Low | L369-374 vs L519 | confirmed (pending phlimbo-ea confirmation) |
| CODE-003 | NatSpec says pay-then-skim; code skims-then-pays | QA | L426-434 vs L484/509 | confirmed, cosmetic |
| (refuted) | divide-before-multiply (seed #3) | — | L629/L634 | ≤1 wei, dead >18dp branch |
| (refuted) | exemptStrategies payment asymmetry (seed #6) | — | L479/484 | symmetric |
| (refuted) | rewardToken w/o TokenConfig (seed #4) | QA note | L360,622-624 | safe-fail admin footgun |
| (refuted) | yield-before-payment ordering exploit (seeds #2/#5) | — | L484/509 | atomic + nonReentrant |
