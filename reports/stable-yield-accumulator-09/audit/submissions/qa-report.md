# Quality Assurance Report — yield-accumulator

## Executive Summary

This QA report consolidates the Low-severity and Centralization findings from the audit of `StableYieldAccumulator.sol`. The audit scope was the newly introduced **nudge mechanism** layered onto the existing accumulator, alongside the surrounding claim/discount path that the nudge mechanism interacts with. The most significant theme of the report is that the nudge mechanism endows the owner with privileges (notably the unilateral ability to redirect up to 100% of claim revenue) that materially exceed the documented owner trust scope — which previously covered only registering strategies, setting exchange rates, and pausing. The Centralization findings (C-01, C-02, C-03) capture three distinct facets of this expanded privilege surface; the Low findings cover input-validation gaps, event hygiene, view/state inconsistency, allowance hygiene, and bounded rounding/MEV concerns surfaced during review of the same code path.

Mitigations are concrete and inexpensive: cap `nudgeSplit` below 100, add a timelock and pauser-callable emergency reset for nudge configuration, and add input validation (`rate < 10000`) on `setDiscountRate`. None of the items below are claimed to be exploitable absent owner malice or compromise; they are reported because the new nudge privileges are not part of the trust model the protocol has previously communicated to users.

## Summary

| Label | Severity | Title | Location |
|-------|----------|-------|----------|
| C-01 | Centralization | Owner can front-run `claim()` to redirect entire payment via `nudgeSplit` | `StableYieldAccumulator.sol:410-427, 498-517` |
| C-02 | Centralization | Nudge mechanism allows owner to redirect 100% of claim revenue with no cap | `StableYieldAccumulator.sol:106-112, 410-427, 498-515` |
| C-03 | Centralization | `setDiscountRate` allows 100% discount, enabling free strategy drain | `StableYieldAccumulator.sol:337-343, 492` |
| L-01 | Low | NFT burn before yield availability check (gas griefing only) | `StableYieldAccumulator.sol:464-489` |
| L-02 | Low | No validation that `nudge != phlimbo, address(this), minterAddress` | `StableYieldAccumulator.sol:410-414` |
| L-03 | Low | `approvePhlimbo` allows owner to revoke phlimbo allowance, DoSing claims | `StableYieldAccumulator.sol:394-399, 514` |
| L-04 | Low | `setRewardToken` emits no event; missing two-step pattern across config setters | `StableYieldAccumulator.sol:385-388` |
| L-05 | Low | One-sided slippage protection; `calculateClaimAmount` inconsistent with `claim()` under owner-state changes | `StableYieldAccumulator.sol:492-496, 605-628, 634-658` |
| L-06 | Low | NFT burn assumes `NFTMinter` honors burn semantics | `StableYieldAccumulator.sol:526-535` |
| L-07 | Low | No event for nudge/phlimbo split amounts | `StableYieldAccumulator.sol:481, 517` |
| L-08 | Low | Independent setters for nudge/`nudgeSplit` allow inconsistent state DoS; `nudgeSplit==100` bypasses `phlimbo.collectReward` hook | `StableYieldAccumulator.sol:410-427, 501, 507-515` |
| L-09 | Low | `setPhlimbo` does not zero old phlimbo's allowance on `rewardToken` | `StableYieldAccumulator.sol:385-399` |
| L-10 | Low | Admin setters not gated by `whenNotPaused` — config drift during pause | `StableYieldAccumulator.sol:217-228, 410-427` |
| L-11 | Low | Compound precision loss in normalize/denormalize round-trip | `StableYieldAccumulator.sol:484, 492-493` |
| L-12 | Low | Token-pause yield backlog captured by single MEV claimer on unpause | `StableYieldAccumulator.sol:475, 306-318` |
| L-13 | Low | Reentrancy via nudge + hookable rewardToken — ordering demonstration | `StableYieldAccumulator.sol:510-515` |
| L-14 | Low | CEI: yield withdrawn before payment collected — ordering demonstration | `StableYieldAccumulator.sol:470-504` |

---

## Centralization Risks (C-XX)

The three Centralization findings below reflect the audit's central observation: the nudge mechanism, and the discount-rate setter that interacts with it, introduce **new** privileged powers that are not enumerated in the documented owner trust scope. The pre-existing trust model covered only registering strategies, setting exchange rates, and pausing. C-01 and C-02 are two framings of the same underlying privilege expansion — C-01 emphasises the per-claim front-running shape, C-02 the standing systemic redirect — and they are reported separately because each motivates a distinct mitigation (per-claim slippage bound vs. configuration-time guardrails). C-03 is a separate, lower-blast-radius input-validation gap on `setDiscountRate` that nonetheless allows a single owner mistake to enable free strategy drain.

### [C-01] Owner can front-run `claim()` to redirect entire payment via `nudgeSplit`

**Severity:** Centralization

**Location:** [`StableYieldAccumulator.sol:410-427, 498-517`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

`setNudgeAddress` and `setNudgeSplit` are independent owner-only setters with no timelock and no per-claim slippage bound on the split distribution. A claimer who has computed an expected payment via `calculateClaimAmount` and submits `claim()` can be front-run by the owner: the owner sets `nudgeAddress` to an owner-controlled EOA and `nudgeSplit` to 100 in the block immediately preceding the claim. The claimer's transaction then settles with the NFT burned, strategies drained, and 100% of the payment routed to the owner-controlled nudge address. The slippage parameter on `claim()` only protects against a reduced *total* payment, not against the split distribution between phlimbo and nudge.

This is a privilege not covered by the documented owner trust scope (registering strategies, exchange rates, pausing). It is being classified as Centralization rather than Medium because reachability fundamentally requires owner malice or key compromise, and the harm is privilege expansion rather than a state/spec defect.

**Impact**

Per-claim revenue grab: claimer pays the full amount, the NFT is burned, strategies are drained, but 100% of the payment is routed to the owner-controlled nudge address. Phlimbo (and therefore the broader protocol accounting that depends on `collectReward`) receives nothing for that claim.

**Recommendation**

- Cap `nudgeSplit` at a constant well below 100 (e.g. `MAX_NUDGE_SPLIT = 50`) enforced in `setNudgeSplit`.
- Add a per-claim `minPhlimboAmount` parameter to `claim()` so the claimer can specify a floor on the phlimbo-bound portion, not only the gross payment.
- Place nudge configuration changes behind a timelock so that any redirect is observable on-chain before it can be applied.

---

### [C-02] Nudge mechanism allows owner to redirect 100% of claim revenue with no cap

**Severity:** Centralization

**Location:** [`StableYieldAccumulator.sol:106-112, 410-427, 498-515`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

This is the standing-state framing of the same privilege surface as C-01. Independently of any specific pending claim, the owner can synchronously set `nudgeAddress` to any EOA and `nudgeSplit` to 100 with no cap, no timelock, and no beneficiary lock. From that moment forward, every `claim()` routes its entire payment to that EOA until the configuration is reverted. There is no on-chain delay during which token holders or governance can react.

The documented owner trust scope does not contemplate revenue-redirection power. A compromised owner key — a scenario the rest of the trust model otherwise treats as catastrophic — is sufficient to permanently divert all future claim revenue, with no architectural circuit-breaker beyond pausing the entire contract (which itself depends on the same key).

**Impact**

All future claim revenue is diverted to an attacker-controlled address until governance intervenes. Because there is no separate pauser role with the authority to reset nudge configuration, recovery requires the same key that was compromised.

**Recommendation**

- Cap `nudgeSplit` at a constant strictly below 100 so that no single setting can divert all revenue.
- Require `nudgeAddress` to be a contract (`code.length > 0`) or a pre-registered allowlist entry, to make accidental EOA misconfiguration harder.
- Add a timelock on `setNudgeAddress` and `setNudgeSplit`.
- Grant a pauser role the authority to reset nudge configuration to safe defaults (e.g. `nudgeSplit = 0`) so that compromise of the owner key does not block recovery.

---

### [C-03] `setDiscountRate` allows 100% discount, enabling free strategy drain

**Severity:** Centralization

**Location:** [`StableYieldAccumulator.sol:337-343, 492`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

`setDiscountRate` accepts any `uint` up to and including `10000` (100% in basis points). When `discountRate == 10000`, the discount applied at claim time produces `actualPayment == 0`. Combined with the absence of a zero-payment guard on the claim path, any NFT holder can then call `claim()` and receive the full strategy payout for zero payment. There is no economic motive for the owner to make this setting; the concern is a single-setter misconfiguration with no input-validation backstop.

Per C4's known-invalid guidance on "reckless admin mistakes," a single-setter misconfiguration with no offsetting attacker-controlled precondition is a centralization concern rather than High. The fix is straightforward input validation.

**Impact**

If the owner sets `discountRate = 10000` (whether by error or through a compromised key), any NFT holder can drain strategies for free by calling `claim()` until the owner re-sets the rate. The loss is bounded by available strategy balance per claim but unbounded across consecutive claims while the misconfiguration persists.

**Recommendation**

- Add `require(rate < 10000, "discount must be < 100%")` (or an even tighter cap) in `setDiscountRate`.
- Independently, add a zero-payment guard on `claim()` so that a degenerate `actualPayment == 0` cannot drain strategies — this hardens the path against future misconfigurations and reduces dependence on every setter being individually well-validated.

---

## Low / QA Findings (L-XX)

### [L-01] NFT burn before yield availability check (gas griefing only)

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:464-489`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

`claim()` burns the caller's NFT before checking whether the strategies hold sufficient yield to honour the payout. If the availability check then reverts, the burn is also rolled back along with the rest of the transaction. There is no fund loss; the issue is purely cosmetic and gas-wasting on bad-state claims.

**Impact**

Wasted gas for callers who attempt to claim against insufficient strategy balances. No funds at risk.

**Recommendation**

Reorder the claim flow so that strategy-balance availability is checked before the NFT burn. A short-circuit revert before any state mutation gives the caller a cleaner failure mode and avoids unnecessary execution.

---

### [L-02] No validation that `nudge != phlimbo, address(this), minterAddress`

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:410-414`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

`setNudgeAddress` performs no aliasing checks. Setting `nudgeAddress = address(this)` silently accumulates the nudge share inside the accumulator with no rescue function; setting `nudgeAddress = phlimbo` double-credits phlimbo while breaking accounting; setting `nudgeAddress = minterAddress` mixes payout flow with NFT-minting state. None of these are exploitable by a non-owner, but each is a single-tx owner mistake with no recovery path.

**Impact**

Misallocation of nudge share with no rescue function. Owner-reachable in a single transaction.

**Recommendation**

Add input validation to `setNudgeAddress`:

```solidity
require(nudge != address(0), "zero address");
require(nudge != address(this), "self");
require(nudge != phlimbo, "alias phlimbo");
require(nudge != minterAddress, "alias minter");
```

---

### [L-03] `approvePhlimbo` allows owner to revoke phlimbo allowance, DoSing claims

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:394-399, 514`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

`approvePhlimbo` is owner-callable and can be invoked with a zero allowance, after which `phlimbo.collectReward` fails the inner allowance check and `claim()` reverts. The DoS is owner-only and reverts cleanly, so no funds are lost; the concern is liveness during owner-driven config changes.

**Impact**

Owner can pause the claim path without using the formal pause function, bypassing any external monitoring keyed on `Paused` events.

**Recommendation**

Either remove the ability to set the allowance to zero through `approvePhlimbo` (use the formal pause path instead), or emit a distinct event when the allowance is set to zero so off-chain monitoring can react.

---

### [L-04] `setRewardToken` emits no event; missing two-step pattern across config setters

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:385-388`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

`setRewardToken` mutates a critical configuration variable without emitting an event, making off-chain indexing of reward-token migrations dependent on transaction-level inspection. Several other config setters in the same area share the pattern. None of these setters use a two-step (propose/accept) flow, which would be the standard hardening for irreversible configuration migrations.

**Impact**

Off-chain monitoring gap; no direct asset risk.

**Recommendation**

Emit `RewardTokenUpdated(oldToken, newToken)` (and analogous events on the other config setters in the same block) and consider a two-step propose/accept flow for the most critical setters.

---

### [L-05] One-sided slippage protection; `calculateClaimAmount` inconsistent with `claim()` under owner-state changes

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:492-496, 605-628, 634-658`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

`calculateClaimAmount` is a view used by integrators to quote the expected payment. Its result can diverge from the value actually computed inside `claim()` when the owner mutates `discountRate` or nudge configuration between the quote and the claim. The slippage parameter on `claim()` protects against gross payment falling below a floor, but does not protect against the *split* distribution between phlimbo and nudge changing.

This is a quote-quality / view-vs-state-mutation consistency gap. It compounds the higher-severity slippage discussion treated separately in the main report; on its own it is a Low/QA item under C4's view-function guidance.

**Impact**

Integrators relying on the view to display a quote may show stale split information. No direct asset loss path absent owner action separately classified.

**Recommendation**

Either expose the split breakdown through `calculateClaimAmount` so callers can pass a per-component floor into `claim()`, or lock the split for the duration of a pending claim via the timelock recommended in C-02.

---

### [L-06] NFT burn assumes `NFTMinter` honors burn semantics

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:526-535`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

The claim flow trusts `NFTMinter` to enforce the burn invariant: after `burn(tokenId)`, the token must not be transferable or re-claimable. `NFTMinter` is an in-scope trusted dependency, so any failure of that invariant would itself surface as a separate finding against `NFTMinter`. The defensive hardening — checking `balanceOf` before and after the burn — is cheap and provides a depth-in-defence backstop without changing the trust model.

**Impact**

None under the documented trust model.

**Recommendation**

Add a balance-of check around the burn so that a future regression in `NFTMinter` (or substitution with a non-conformant minter) cannot allow a burned NFT to remain claimable.

---

### [L-07] No event for nudge/phlimbo split amounts

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:481, 517`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

When a claim splits the payment between phlimbo and nudge, no event records the per-recipient amounts. Token-level `Transfer` events are emitted by the underlying ERC-20, but they do not carry the protocol-level context (which claim, which split ratio) needed to attribute revenue off-chain.

**Impact**

Off-chain attribution gap; no direct asset risk.

**Recommendation**

Emit `ClaimSplit(tokenId, phlimboAmount, nudgeAmount, nudgeAddress)` from `claim()`.

---

### [L-08] Independent setters for nudge/`nudgeSplit` allow inconsistent state DoS; `nudgeSplit==100` bypasses `phlimbo.collectReward` hook

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:410-427, 501, 507-515`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

`nudgeAddress` and `nudgeSplit` are set by independent transactions, so a state where `nudgeSplit > 0` and `nudgeAddress == address(0)` (or vice versa) is reachable. In that intermediate state `claim()` reverts. Separately, `nudgeSplit == 100` causes the claim path to skip the call to `phlimbo.collectReward` (because the phlimbo amount is zero), which is a downstream accounting hook some integrators rely on.

The DoS shape is owner-only and reverts cleanly. The bypass of `collectReward(0)` compounds C-01/C-02 rather than introducing a new vector.

**Impact**

Liveness DoS during owner config changes; missed `collectReward` hook at `nudgeSplit==100`.

**Recommendation**

Replace the two setters with a single atomic `setNudgeConfig(address nudge, uint nudgeSplit)` that validates the pair together. Independently, ensure `phlimbo.collectReward(0)` is invoked even on full-nudge claims, or document the hook contract explicitly.

---

### [L-09] `setPhlimbo` does not zero old phlimbo's allowance on `rewardToken`

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:385-399`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

When the owner rotates the phlimbo address, the previous phlimbo's ERC-20 allowance on `rewardToken` is not revoked. The standing allowance is bounded by the transient SYA balance and only consumable by a previously-trusted contract, so under the documented trust model there is no asset risk; it is allowance hygiene.

**Impact**

Stale allowance to a deprecated trusted contract. No direct asset risk.

**Recommendation**

In `setPhlimbo`, set the old phlimbo's allowance to zero before assigning the new address and approving the new address.

---

### [L-10] Admin setters not gated by `whenNotPaused` — config drift during pause

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:217-228, 410-427`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

Admin setters (including the nudge setters) can be called while the contract is paused. This means configuration can drift during the pause window, which compounds front-running vectors handled separately in the main report (C-01 in particular). On its own it is a state-handling gap: callers reading config during a pause cannot assume the config will be the same on unpause.

**Impact**

Configuration drift during the pause window; amplifies vectors handled elsewhere.

**Recommendation**

Either gate config setters with `whenNotPaused` so that configuration is frozen during pauses, or emit a distinct `ConfigDriftedDuringPause` event when a setter is invoked while paused.

---

### [L-11] Compound precision loss in normalize/denormalize round-trip

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:484, 492-493`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

The claim path performs a normalize-then-denormalize round-trip across token decimals and a discount multiplication. Each step rounds; the rounding direction is claimer-favoured (i.e. the protocol absorbs the dust), so the loss is bounded per call and cannot be exploited for unbounded extraction. C4 treats rounding-dust losses as QA/Low.

**Impact**

Per-call dust loss to the protocol, bounded by token decimals and discount precision.

**Recommendation**

Either compute the final payment in a single combined expression to minimise intermediate rounding, or document the per-call dust bound so integrators can reason about it.

---

### [L-12] Token-pause yield backlog captured by single MEV claimer on unpause

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:475, 306-318`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

When the owner pauses a token and later unpauses it, the yield accrued during the pause window becomes claimable in a single block. An MEV claimer monitoring `Unpaused` events can capture the entire backlog in the first claim of the unpause block. There is no protocol invariant breach — the backlog is paid for at the standard discount, so phlimbo accounting remains correct — but the distribution across NFT holders is not what an unsophisticated user would expect.

**Impact**

MEV-distributed backlog rather than user-distributed; honest claimers may consistently lose to bots on unpause events. No protocol-level loss.

**Recommendation**

Either rate-limit per-block claim throughput on unpause (bleed the backlog over N blocks), or document the MEV behaviour so honest claimers can defend with private mempools.

---

### [L-13] Reentrancy via nudge + hookable rewardToken — ordering demonstration

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:510-515`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

The claim path transfers the nudge share of the reward token to `nudgeAddress` *before* invoking `phlimbo.collectReward`. When the configured `rewardToken` exposes transfer hooks (e.g. ERC777 `tokensReceived`, ERC1363 `onTokenReceived`) and `nudgeAddress` is a contract that registers for those hooks, the hook callback fires synchronously inside `claim()` while the SYA is in an intermediate state: the phlimbo share has not yet been forwarded, and `phlimbo.collectReward` has not yet executed.

The demonstration PoC ([`poc-M-08.t.sol`](../../../workspace/stable-yield-accumulator/test/poc-M-08.t.sol)) deploys an ERC1363-style `HookableRewardToken` and a `NudgeReceiver` that records the moment its hook fires through a shared `OrderingOracle`. The asserted invariants are:

1. The nudge hook fires during `claim()`.
2. The nudge hook's ordering index is strictly less than `phlimbo.collectReward`'s ordering index.
3. At hook time, the SYA's reward-token balance equals the *phlimbo* amount (i.e. the phlimbo share has not been forwarded yet).
4. At hook time, `phlimbo.collectRewardCallCount == 0`.

Direct value extraction is **not** demonstrated: the SYA's `nonReentrant` guard blocks recursive `claim()` entry, and phlimbo is not itself a victim of the hook in the current architecture. The finding's value is the ordering itself — any external system the nudge contract interacts with during its callback observes the SYA in an inconsistent intermediate state.

The path is conditional on the owner setting a hookable reward token; USDC has no hooks. The `poc_status` is `ORDERING_ONLY`, and severity-auditor and validity-checker convergent feedback supported demoting this from Medium on that basis. The architectural gap is recorded here so that a future migration to a hookable reward token cannot silently inherit the inversion.

**Impact**

External contracts called from the nudge hook observe SYA mid-claim with un-forwarded phlimbo balance and `collectReward` not yet invoked. No direct value extraction on the current `rewardToken` (USDC, no hooks). Conditional on owner action to introduce a hookable token.

**Recommendation**

Reorder the claim flow so that `phlimbo.collectReward` (and the phlimbo-side accounting it represents) executes before any external transfer to `nudgeAddress`. Alternatively, restrict `rewardToken` to non-hookable ERC-20s by rejecting tokens whose `supportsInterface` advertises ERC777/ERC1363, and document that constraint at `setRewardToken`.

---

### [L-14] CEI: yield withdrawn before payment collected — ordering demonstration

**Severity:** Low

**Location:** [`StableYieldAccumulator.sol:470-504`](../../../lib/stable-yield-accumulator/src/StableYieldAccumulator.sol)

**Description**

The claim path calls `strategy.withdrawFrom` (which transfers yield to `msg.sender`) at line 480 *before* `safeTransferFrom` collects the claimer's payment at line 504. The claimer therefore receives the strategy yield before the protocol has collected payment for it, inverting the standard checks-effects-interactions ordering.

The demonstration PoC ([`poc-M-09.t.sol`](../../../workspace/stable-yield-accumulator/test/poc-M-09.t.sol)) records the relative ordering of the yield delivery and the payment collection during a single `claim()` call, confirming the inversion. The PoC is `ORDERING_ONLY`: it does not demonstrate value extraction on standard ERC-20 reward tokens, because the entire transaction is atomic and the payment `transferFrom` reverts the whole flow if the claimer is underfunded. Standard fee-on-transfer tokens are out of scope per project rules, so the FOT-bricked-claim shape is not classified here. The architectural defect remains: a future reward token with callbacks, or any future change that exposes a re-entrant surface between line 480 and line 504, would inherit the inversion.

Severity-auditor and validity-checker convergent feedback supported demoting this from Medium on the basis that the PoC demonstrates ordering only.

**Impact**

Claim flow is fragile against callback or fee-on-transfer reward tokens, and against any future change that introduces an external call between the yield withdrawal and the payment collection. No direct value extraction on the current standard-ERC-20 reward token.

**Recommendation**

Reorder the claim flow so that `safeTransferFrom` collects the claimer's payment *before* `strategy.withdrawFrom` delivers yield. This restores standard CEI ordering and removes the dependence on per-token assumptions about callbacks.

---
