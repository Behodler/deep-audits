# Spec-Conformance Report (Law 2 — Faithfulness) — phoenix-nft-staking run-18

> **Scope of this report.** This bundle records **Law-2 (story / spec faithfulness)**
> deviations only: places where an in-scope feature does **not** do what the
> `[story-NNN]` it derives from, its own docstrings, or `docs/design.md` say it
> should. It is deliberately **separate** from the QA/gas bundle — a broken
> advertised behaviour is a correctness deviation, not gas/style noise.
>
> A faithfulness deviation that *also* carries asset/value/availability impact is
> additionally reported individually under an H/M label; the `F-XX` entry here is
> the faithfulness cross-reference for it (per the Three-Law hierarchy: Law 1
> security findings are reported on their own merits, with the Law-2 deviation
> recorded here for traceability).

- **Project:** phoenix-nft-staking
- **Run:** phoenix-nft-staking-18
- **Submodule HEAD audited:** `24acff83434e9708cb13e208b8ea32464af5c1f8`
- **Stories in scope this cycle:** story-018 (depletion-window emission model),
  story-019 (cross-instance + in-place staker migrators)

---

## Summary

| ID       | Story    | Deviation                                                                 | Cross-ref |
|----------|----------|---------------------------------------------------------------------------|-----------|
| F-18-01  | story-018| Depletion budget does **not** drain linearly; per-interaction rate-drift reintroduces the phlimbo V1 bug at the schedule level | M-01 (Medium) |

**One** faithfulness deviation was found this cycle (F-18-01). See the
[negative-result record](#negative-result--what-was-verified-faithful) below for
everything that was checked and confirmed faithful — including the whole of
story-019.

---

## F-18-01 — NFTStakerDepletion violates story-018's linear-depletion promise (per-interaction rate-drift)

- **Severity (faithfulness):** Spec deviation — primary advertised behaviour broken
- **Status:** open
- **Contract:** `src/NFTStakerDepletion.sol`
- **Cross-reference:** also carries Medium security/value impact, submitted
  individually as **M-01** —
  [`reports/phoenix-nft-staking/18/submissions/M-01-depletion-rate-drift.md`](./M-01-depletion-rate-drift.md).
  F-18-01 is the Law-2 faithfulness face of that finding; M-01 is its
  C4 Medium face. **Triage them together.**

### The promise (story / spec / docstring text it violates)

**1. story-018 — "Add NFTStakerDepletion with depletion-window emission model."**
The budget is intended to drain **linearly to dust over exactly the depletion
window**. The contract's own docstrings restate this as the headline behaviour:

> `src/NFTStakerDepletion.sol#L59-L63` (contract docstring):
> "Stakers deposit ERC1155 units of `stakedId` and earn per-second emissions of
> `rewardToken` (phUSD) that **drain `rewardBudget` over exactly
> `depletionWindowMonths`**."

> `src/NFTStakerDepletion.sol#L128-L130` (`depletionWindowMonths` docstring):
> "The reward budget **drains linearly to (floor) dust over
> `depletionWindowMonths * SECONDS_PER_MONTH`**. Replaces `NFTStaker.targetAPY`."

**2. The explicit "we are not phlimbo" claim.**
The contract advertises that its design specifically avoids the historical
phlimbo Linear-Depletion (rate-drift) bug:

> `src/NFTStakerDepletion.sol#L150-L151` (`rewardRate` docstring):
> "Recomputed ONLY in `setDepletionWindow` / `_syncBudget` / `_recomputeSchedule`,
> never inside per-interaction accrual (**avoids phlimbo's V1 rate-drift bug**)."

> `src/NFTStakerDepletion.sol#L445-L448` (`_updatePool` docstring):
> "CRITICAL: does NOT recompute `rewardRate` here … **Recomputing the rate inside
> per-interaction accrual was phlimbo's V1 bug.**"

**3. `docs/design.md` — zero-inflow pull must be a no-op.**
The design spec is explicit that, absent new inflow, the schedule must **not** be
re-derived:

> `docs/design.md#L141-L146` (`_syncBudget` / `pull` flow):
> "5. If `inflow > 0`: … `windowEnd = block.timestamp + windowDuration`;
> `rewardRate = rewardBudget / windowDuration` …
> **6. If `inflow == 0`: no-op — existing schedule continues untouched.**"

> `docs/design.md#L231-L232` (stated invariant):
> "**Zero-inflow `pull()` is a no-op** — `inflow == 0` branch **skips
> rate/window mutation entirely**."

### The actual behaviour (code that breaks it)

The rate/window recompute is **not** gated on inflow. `_syncBudget` calls
`_recomputeSchedule()` **unconditionally**, *before* the `inflow > 0` guard — and
that guard only governs whether the `Pulled` event is emitted, not whether the
schedule is re-derived:

> `src/NFTStakerDepletion.sol#L423-L436` (`_syncBudget`):
> ```solidity
> uint256 pre = rewardToken.balanceOf(address(this));
> dispatcherHook.pull();
> uint256 inflow = rewardToken.balanceOf(address(this)) - pre;
> _recomputeSchedule();              // <-- runs on EVERY interaction, even inflow == 0
> if (inflow > 0) {
>     emit Pulled(inflow, rewardBudget);   // guard only gates the event
> }
> ```

`_recomputeSchedule` then re-derives the rate from the *remaining* budget and
resets the window to a **fresh full window from now**:

> `src/NFTStakerDepletion.sol#L513-L534` (`_recomputeSchedule`):
> ```solidity
> uint256 windowSeconds = depletionWindowMonths * SECONDS_PER_MONTH;
> ...
> uint256 budget   = V > committedDebt ? V - committedDebt : 0;
> uint256 newRate  = (windowSeconds == 0) ? 0 : budget / windowSeconds;
> rewardRate   = newRate;
> rewardBudget = budget;
> windowEnd    = block.timestamp + windowSeconds;   // <-- fresh full window every call
> lastRewardTime = block.timestamp;
> ```

Because `rewardRate = remainingBudget / windowSeconds` and `windowEnd` is reset to
`now + windowSeconds` on **every** interaction, each interaction re-spreads the
*remaining* budget over a *fresh full window*. The consequences:

- **No linear drain.** Emission decays **geometrically**, not linearly — the more
  often the pool is touched, the slower the budget bleeds.
- **The window never terminates.** `windowEnd` is pushed forward by up to a full
  `windowSeconds` on every interaction, so the schedule has no fixed end. PoC
  shows `windowEnd` drifting a **full extra 365 days** beyond the intended end.
- **Active stakers are short-changed.** Over a nominal 12-month window, active
  stakers receive only **~63% (PoC-measured 6326 bps)** of the intended
  emissions; **~37% of the budget is stranded** (never paid, never reclaimed on
  schedule).

This is **exactly** the phlimbo V1 Linear-Depletion / rate-drift bug the
docstrings at L150-L151 and L445-L448 claim to avoid. The author correctly moved
the recompute *out* of `_updatePool` (the literal phlimbo V1 location) — but
reintroduced the identical drift one level up, by recomputing the
*budget-derived* rate unconditionally in `_syncBudget` on every interaction. The
defense at the accrual level is real; the equivalent defense at the schedule
level is missing.

### Faithfulness verdict

**Deviates.** The contract's single most-advertised behaviour — "drain the budget
linearly to dust over exactly `depletionWindowMonths`" — does not hold for any
pool that is interacted with during its window (i.e. every live pool). The
zero-inflow-no-op invariant stated in `docs/design.md#L231-L232` is violated
directly. The "avoids phlimbo's V1 rate-drift bug" claim is false as written.

### Security / value note (why this is also M-01)

The deviation is **solvency-safe**: `balance == rewardBudget + committedDebt`
holds throughout, the `reward > rewardBudget` clamp in `_updatePool` prevents
over-payment, and floor rounding stays in the protocol's favour — **no theft, no
insolvency**. The harm is a **value/availability** one: every active staker is
under-paid ~37% of promised emissions and the budget is stranded off-schedule.
That impact is what earns the individually-submitted **Medium (M-01)**; this
F-18-01 entry records the Law-2 face and the spec/docstring text it contradicts.
See [M-01](./M-01-depletion-rate-drift.md) for the runnable PoC and the
recommended fix (gate `_recomputeSchedule` so a zero-inflow / window-unchanged
interaction is a true no-op, preserving the existing `windowEnd` and `rewardRate`
rather than re-spreading the remaining budget over a fresh window).

---

## Negative result — what was verified faithful

This report records the negative result as well as the positive: **only one**
faithfulness deviation (F-18-01) was found across the two stories in scope this
cycle. Everything below was checked against its story/spec text and confirmed to
implement it faithfully:

- **story-018 — depletion-window emission model (the rest of `NFTStakerDepletion.sol`).**
  Aside from the F-18-01 rate-drift deviation, the contract is faithful to its
  spec: the `rate = budget / windowSeconds` inversion of `NFTStaker`'s APY math
  is implemented as designed; the `balance == rewardBudget + committedDebt`
  solvency invariant is preserved (`_updatePool` / `_safePay` / `_recomputeSchedule`
  move value between buckets without minting it); floor rounding is consistently in
  the protocol's favour; the `totalStaked == 0` config gates
  (`setStakedId` / `setDispatcherIndex` / `setNFTMinter`) hold; and the
  `emergencyWithdraw` escape hatch (principal-returning, reward-forfeiting,
  `_syncBudget`-skipping, callable while paused) matches the spec. The rate-drift
  is a single, localized schedule-recompute deviation, **not** a systemic
  re-architecture of the contract.

- **story-019 — staker migration orchestrators (`NFTStakerMigrator.sol`,
  `InPlaceNFTStakerMigrator.sol`, shared `INFTStakerMigratable.sol`).**
  Verified faithful to story-019: the cross-instance zero-user-action migration
  path and the in-place dispatcher/hook rewire (with custody handoff and the
  timeout hatch) implement their stated intent. **No** faithfulness deviation was
  found in either migrator or the shared interface.

No other in-scope contract (`NFTStaker.sol`, `BatchNFTMinter.sol`,
`NFTStakerPriceScaled.sol` — carried as parity/context baseline) introduced a new
faithfulness deviation this cycle.

---

*Generated for phoenix-nft-staking-18. Law-2 faithfulness bundle; kept separate
from the QA/gas report. Triage F-18-01 together with its Medium cross-reference
M-01 via `/ledger phoenix-nft-staking`.*
