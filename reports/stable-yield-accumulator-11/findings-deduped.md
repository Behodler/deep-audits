# Deduplicated Findings — StableYieldAccumulator (run yield-accumulator-11)

Submodule: `lib/stable-yield-accumulator` @ 71abe3e
**23 raw candidates → 4 canonical findings** (11 refuted/no-finding dropped). **No High or Medium survives.**

## Surviving canonical findings

### DEDUP-001 — `claim()` delivers skimmed yield while charging 0 payment (payment denormalizes/floors to zero) — Low / QA
- **Location:** `StableYieldAccumulator.sol:498` (`actualPayment = _denormalizeAmount(claimerPayment, rewardToken)` — unguarded floor) vs `totalNormalizedYield == 0` guard at L494; floor mechanics L617-640.
- **Absorbs:** CODE-001, ECON-01, PM-01, Invariant A (forge + Medusa), Halmos Property 1.
- **Description:** The only zero-payment guard (L494) checks the 18dp aggregate `totalNormalizedYield != 0`; it does not re-check the post-discount, post-denormalize `actualPayment` (L498), which floors. A strategy skims non-zero native yield to the claimer at L484, then `actualPayment` can floor to 0 and `safeTransferFrom(msg.sender, this, 0)` at L509 succeeds — free yield. Machine-proven three ways with matching counterexamples: Foundry stateful invariant runner and Medusa both shrank independently to `underlyingReceived = 1` (1e-6 USDC → 1e12 → discount 9.8e11 → floor 0); Halmos refuted `actualPayment > 0` in 0.64s with the identical counterexample. Impact is dust (≤ ~1 USDC-wei/claim at 2% discount, ≤ ~$0.01 at 99.99%), one NFT burned per claim, strictly unprofitable to farm. Round-trip corollary (Invariant B / Halmos Property 2) confirmed floor-only, never over-credits.
- **Fix:** `if (actualPayment == 0) revert ZeroAmount();` after L498.

### DEDUP-002 — Phlimbo allowance depletion bricks `claim()` until owner re-approves — Low (availability)
- **Location:** `StableYieldAccumulator.sol:369-374` (`approvePhlimbo` fixed `forceApprove`) vs `claim()` L519 (`IPhlimbo.collectReward` pull).
- **Absorbs:** CODE-002.
- **Description:** Fixed allowance is never topped up; each claim's `collectReward` pull consumes it, and once cumulative `phlimboAmount` exceeds the approved amount every subsequent permissionless `claim()` reverts until the owner re-approves. Atomic, no fund loss.
- **Dependency caveat — FLAG FOR HUMAN REVIEW:** contingent on `IPhlimbo.collectReward` doing a fixed-amount pull; `phlimbo-ea` is not checked out, so semantics are unconfirmed. Drop if it pulls full balance or uses max allowance.

### DEDUP-003 — Owner-centralization / configuration guardrails (QA bundle) — QA / Centralization (Low)
- **Location:** `setDiscountRate` L324-330 (allows 100% discount), `setTokenConfig` L280 (unbounded `normalizedExchangeRate`), `Ownable` decl L57, `nonReentrant`-order note L447.
- **Absorbs:** ECON-02, PM-04, SEMGREP-001 (Ownable2Step), ADERYN-001 (nonReentrant-not-first).
- **Description:** Designed owner authority, not an exploit — reject any "owner drains via 100% discount" High framing (documented depeg adjustment, oracle-free tradeoff previously accepted, "reckless admin" exclusion). Single-step `Ownable` can brick controls on a mistyped owner. The ADERYN modifier-order note is benign (`whenNotPaused` makes no external call before the guard). Optional QA guardrails: cap discount < 10000, bound exchange rate, adopt `Ownable2Step`.

### DEDUP-004 — `claim()` NatSpec says pay-then-skim; code skims-then-pays — QA (doc)
- **Location:** docstring L426-434 (and interface L314-323) vs skim L484 / payment L509.
- **Absorbs:** CODE-003.
- **Description:** Cosmetic doc/impl mismatch; `claim()` is atomic + `nonReentrant`, so a failed payment rolls back the skim and NFT burn — also refutes the "yield-before-payment" exploit angle.
- **Fix:** correct the NatSpec.

## Dropped (refuted / no-finding, recorded for traceability)
- **divide-before-multiply** (SLITHER-001 / Halmos Property 3): reachable path is mul-before-div (≤1 wei, claimer-favorable); the real div-before-mul `decimals>18` branch is dead (Halmos proved unreachable).
- **exemptStrategies asymmetry** (ECON-05): exempt `continue` precedes skim and accumulation; skim-set == pay-set, symmetric.
- **rewardToken without TokenConfig** (seed #4): safe-fail (claim reverts), admin deploy-ordering footgun under "reckless admin" exclusion.
- **yield-before-payment ordering** (seeds #2/#5): atomic + nonReentrant; only doc is wrong (DEDUP-004).
- **ECON-03** NFT/grief/MEV: intended mechanism / self-funded grief / designed race.
- **ECON-04** nudgeSplit: subtraction-derived, exact conservation.
- **PM-02** first-depositor/inflation: not a share vault.
- **PM-05** ERC20-no-return: cleared (SafeERC20 throughout).
- **Reentrancy-ERC777**: cleared (nonReentrant + onlyOwner/onlyPauser mutators).
- **PM-03 / SLITHER-002..010** unbounded-loop DoS: QA/gas tool-noise; strategy list owner-curated, view-only helpers are eth_call-only. No demonstrated on-chain DoS.

## Notes for downstream
- DEDUP-001 is the only finding with Tier-3 machine proof; agreed impact across all tiers is Low/QA despite proof strength — do not let proof inflate severity.
- DEDUP-002 has an unresolved external dependency (`phlimbo-ea` not checked out) — flag for human confirmation of `IPhlimbo.collectReward` semantics before submission.
- DEDUP-003 and DEDUP-004 are QA-bundle candidates, not individual H/M submissions.
