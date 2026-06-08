# Spec-Conformance Report (Law 2 — Faithfulness to Stories)

> **Channel:** This is the **Law-2 spec-conformance channel**, kept **separate from the QA bundle** (`qa-report.md`). It records story/spec deviations (`F-XX`) only. A deviation that *also* carried asset/value/availability impact would additionally receive an H/M label and its own report; none here does.

- **Project:** stable-yield-accumulator
- **Run:** stable-yield-accumulator-12
- **Submodule HEAD:** `71abe3e088559cb5d9c10e8475dc67e7cc57fac9`
- **Scan type:** cold scan (`--full`)
- **Stories in scope:** story-022, story-023, story-024, story-025

## Verdict summary

| Story | Behavior verdict | Unsafe-story flag |
|-------|------------------|-------------------|
| story-022 (simplify NFT validation — index-as-tokenId, 1 NFT burned/claim) | **FAITHFUL** | none |
| story-023 (nudge split on `actualPayment`) | **FAITHFUL** (behavior) — NatSpec doc-drift only (F-01) | none |
| story-024 (`exemptStrategies[]`, validate-before-burn) | **FAITHFUL** | none |
| story-025 (batch `skimSurplus`/`getAuthorizedClients`, return-value pricing) | **FAITHFUL** (behavior) — two-source preview/actual divergence documented | none |

**All four in-scope stories (022 / 023 / 024 / 025) are FAITHFUL in code behavior. There are NO unsafe-story flags.** No Law-1 override was triggered: none of the four stories mandates exploitable behavior. The only deviation found is **documentation-level** (F-01 below) — the `claim()` NatSpec flow block was not updated when story-023 (nudge split) and story-025 (return-value pricing) reshaped the payment path.

The related operational items surfaced during scanning — PARK-03 (nudge-misconfig availability footgun, see ledger L-04), PARK-06 (intended, slippage-guarded preview-vs-actual divergence, ledger L-06), PARK-07 (exempt self-grief) — are **intended/documented or recoverable behaviors**, owned by the severity-classifier / interaction scanners. They are **not** faithfulness deviations and are not re-raised here.

---

## F-01 — `claim()` NatSpec documents pay-then-skim with a direct claimer→phlimbo transfer; implementation skims-then-pays and routes claimer→contract then nudge-split + phlimbo pull

- **Type:** Faithfulness / spec-conformance (Law 2) — documentation-only
- **Severity carried:** Low (no security/value escalation; `securityEscalation: false`, `alsoSecurityImpact: false`)
- **Story tags:** story-023 / story-025 (`claim()` flow NatSpec)
- **Contract:** `src/StableYieldAccumulator.sol` — `claim` (flow block L424-442; body L463-520)
- **Interface:** `src/interfaces/IStableYieldAccumulator.sol` — `claim` NatSpec (L314-336)
- **Fingerprint:** `7e6197ae677a081851a47889a700be3929ac5e98f88487631caa99c8fc58bf5b` (shared with ledger L-03)

### Spec text violated (verbatim)

**Contract NatSpec — `src/StableYieldAccumulator.sol` L426-434** (`claim()` `@dev` "Full claim flow"):

> "... 5. Transfer rewardToken FROM claimer TO phlimbo  6. skimSurplus each non-exempt strategy, sending the batched surplus of ALL its authorized clients TO the claimer"

**Interface NatSpec — `src/interfaces/IStableYieldAccumulator.sol` L315-323** (`claim()` `@dev` "Full flow"):

> "... 6. TransferFrom claimer to phlimbo  7. skimSurplus each non-exempt strategy, sending the batched surplus of all its authorized clients to the claimer"

Both documents describe **pay-then-skim** ordering, and a **direct `claimer → phlimbo`** reward-token transfer.

### Actual behavior

`claim()` (`src/StableYieldAccumulator.sol` L463-520) does the opposite of the documented ordering, and a different payment destination/mechanism:

1. **Ordering — skim FIRST, pay AFTER.** The `skimSurplus` loop runs first (**L463-492**), delivering all strategy yield to the claimer, and payment is computed/collected afterward (**L497-520**). The NatSpec has pay (step 5/6) preceding skim (step 6/7).
2. **Destination/mechanism — NOT a direct claimer→phlimbo transfer.** The reward token is `safeTransferFrom(claimer → this contract)` at **L509**, then split: `nudgeAmount` is `safeTransfer`'d to `nudge` (**L515-517**) and `phlimboAmount` is **pulled** by phlimbo via `IPhlimbo.collectReward` (**L518-519**). The documented single direct `claimer → phlimbo` transfer does not exist.

So both facets of the NatSpec flow block contradict the implementation: the **ordering** (documented pay-then-skim vs implemented skim-then-pay) and the **payment destination/mechanism** (documented direct transfer-to-phlimbo vs implemented transfer-to-self then nudge-split + phlimbo-pull). The NatSpec was simply not updated when story-023 (nudge split) and story-025 (return-value pricing) reshaped the flow.

### File:line of both sides

| | Documented (spec) | Actual (code) |
|---|---|---|
| Ordering | `src/StableYieldAccumulator.sol` L426-434; `src/interfaces/IStableYieldAccumulator.sol` L315-323 | skim loop `src/StableYieldAccumulator.sol` L463-492 → payment L497-520 |
| Payment destination | "FROM claimer TO phlimbo" (contract L426-434 / interface L315-323) | `safeTransferFrom(claimer → this)` L509 → nudge `safeTransfer` L515-517 + phlimbo `collectReward` pull L518-519 |

### Consequence

**Documentation / spec-conformance only — no security or value impact.**

- `claim()` is `nonReentrant` + `whenNotPaused`, so the skims-then-pays sequence is **atomic**: any later revert (e.g. an over-large `safeTransferFrom`) rolls back the earlier skims. There is no CEI/reentrancy exposure created by the reversed ordering (the reentrancy facet was refuted — RESOLVED-002).
- Payment is derived from the **actual `underlyingReceived`** the claimer obtained in the same transaction, so **value conservation holds** (PARK-02 confirms atomicity). The pay/receive ratio cannot be skewed by the reordering.
- The only residual risk is **reader/integrator confusion**: a developer trusting the NatSpec would expect pay-before-deliver (CEI) and a direct phlimbo transfer, neither of which is what the contract does.

### Recommendation

Correct the `claim()` NatSpec (`src/StableYieldAccumulator.sol` L424-442) and the interface comment (`src/interfaces/IStableYieldAccumulator.sol` L314-336) to reflect (a) **skim-then-pay** ordering and (b) the **`claimer → this contract → { nudge transfer, phlimbo collectReward pull }`** payment routing. Sub-QA, same doc-drift family (not separately ledgered): `lib/stable-yield-accumulator/CLAUDE.md` Claim Example (L30-45) predates the nudge feature and implicitly assumes `nudgeSplit == 0`.

### Cross-reference — ledger L-03

F-01 is the **faithfulness facet of ledger entry L-03** (`sya11l3`, open, Low — "claim() NatSpec says pay-then-skim; code skims-then-pays"), and **shares L-03's fingerprint** (`7e6197ae…bf5b`). It is **not** a separate ledger entry. F-01:

- **CONFIRMS** L-03 is still live at HEAD `71abe3e`, and
- **EXTENDS** L-03 with a *second* drift introduced by **story-023**: the **payment-destination / mechanism** change (documented direct claimer→phlimbo transfer vs implemented claimer→contract then nudge-split + phlimbo `collectReward` pull). L-03 alone only captured the ordering (pay-then-skim vs skim-then-pays) drift.

The L-03 ledger entry has been bumped to `lastSeenRun = stable-yield-accumulator-12` and annotated with a `faithfulnessExtension` note pointing here; its carryover stub is in `submissions/carryover/`. Keep L-03 (and its sibling L-06, same `claim()`-flow doc-drift family for the story-025 two-source design) distinct.
