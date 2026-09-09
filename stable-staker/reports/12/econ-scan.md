# Economic / Design-Intent Scan — stable-staker run-12

- **Project:** stable-staker
- **Submodule HEAD:** `ffa4947` — `[story-012] Add InPlaceMigrator`
- **Scan type:** Tier-2 economic / design-intent (regression)
- **Primary contract:** `src/InPlaceMigrator.sol` (new)
- **Boundary contracts read:** `src/StableStaker.sol` (deposit/withdraw/migration/NAV/share accounting), `src/StableStakerMigrator.sol`
- **Scan timestamp:** 2026-06-15
- **Prior Medium lineage:** M-01 `dab5a656` (idle-pool adoption haircut), M-05 `0dca43f3` (emergencyWithdraw FCFS), M-06 `dbdc3ac9` (underwater-swap rearm), M-07 `969722dc` (rate-vs-execution slippage residual). All four were collapsed by the story-010 empty-pool gate. story-012 re-enables operating *with* staked users.

## Framing — the central question

The story-010 empty-pool gate (`setYieldStrategy` requires `totalStaked == 0`) forced full terminal migration and thereby *collapsed* M-01/M-06/M-07. story-012's `InPlaceMigrator` does NOT remove that gate — it *satisfies* it by draining every staker into custody, letting the operator reset+rewire on an empty pool, then re-injecting. So the economic question is precise: **does drain-park-reinject neutralize the M-0x harms, or relocate them to the re-injection (deposit) leg?**

The terminal-migration leg (`initiateMigration` → `batchMigrate`) is upstream-audited and treated as axiomatic here: it realizes once, snapshots `(R,P)`, and pays every user a fixed `p_i·min(R,P)/P` independent of batch/order (closes M-01/M-05 FCFS economics on the *exit* leg). The migrator faithfully parks exactly the `amounts[i]` `batchMigrate` returns and transfers (`InPlaceMigrator.sol:146-157`), so `totalParked == ` received `== balanceOf` — INV-1/INV-3 hold even below par. The new economic surface is entirely on `migrateIn → depositFor → _routeDeposit`.

---

## ECON-12-01 — Re-injection through a haircutting (market/AMM) strategy underpays the user; loss is silently socialized away from the individual

- **Verdict:** CONFIRMED (conditional on the re-injection target being a market/AMM strategy). NEEDS-POC for severity escalation to Medium.
- **Type:** cross-contract value leakage / requested-vs-received accounting skew (M-07 residual, relocated to the deposit leg)
- **Severity:** potential-medium (Low if only direct/idle strategies are ever wired in place)
- **Contract / function:** `InPlaceMigrator.migrateIn` (`src/InPlaceMigrator.sol:207-224`) → `StableStaker.depositFor` (`src/StableStaker.sol:616-638`) → `_routeDeposit` (`src/StableStaker.sol:757-763`)
- **Confidence:** high on mechanism; medium on real-world trigger (depends on the deployed target strategy class)
- **Cross-ref:** M-07 `969722dc` (AMM-execution slippage residual), PM-12-01, SURFACE-1.

### Mechanism

`migrateIn` zeroes `parked[token][user]` to the full parked `amt` (`:215`) and passes that full `amt` to `depositFor` (`:223`). Inside `depositFor`:

```
uint256 received = _pullToken(token, msg.sender, amount);   // pulls full amt from migrator
uint256 credited = _routeDeposit(token, received);          // market strategy: credited < received
require(credited > 0, "StableStaker: nothing credited");
info.amount += credited;                                    // user credited the HAIRCUT, not amt
```

`_routeDeposit` (`:757-763`) returns `strategy.deposit(...)` for a non-zero strategy, and the contract's own doc comment confirms "**the market strategy haircuts this below `amount`; direct strategies return `amount`**". So:

- The migrator surrenders the full `amt` tokens (pulled by `_pullToken`).
- The user's credited principal is `credited = amt - haircut`.
- The migrator zeroes `parked[user]` to the full `amt` regardless (`:215`), so the `amt - credited` delta is gone from the migrator's books and is **not** re-attributable to the user.

This is the exact M-07 "requested-vs-received" skew the empty-pool gate was built to eliminate — **relocated from the in-place swap to the re-injection deposit**. The gate prevents the operator from moving live principal through a haircut; the migrator re-introduces a haircut on the way back in.

### Who loses / who gains

- **Loses:** the individual re-injected staker, by `amt - credited` of principal each.
- **Gains:** the protocol/strategy surplus. The documented rounding rule ("sub-amount differences remain protocol-owned yield/loss") points the *deposit*-leg shortfall at the strategy as protocol-owned value — but that rule was written for the loss being **protocol surplus**, here it is a **loss to the user**. The direction the doc covers (exit-leg) and the direction here (deposit-leg, user-out-of-pocket) are not the same, so the documented rule does not legitimize this.
- **Not socialized across stakers** — it is borne per-user by exactly the user being re-injected (each `depositFor` is independent). So it is NOT M-05-style FCFS; it is a flat per-head haircut.

### Quantified impact

Bounded by the new strategy's per-deposit haircut. For an ERC4626 vault this is rounding dust (≤ 1 wei-ish, immaterial). For a market/AMM strategy (the M-07 class — e.g. a curve/balancer-routed adapter) it is execution slippage on the re-deposit, realistically 1-100 bps depending on pool depth and re-injection size. On a multi-million-dollar pool re-injected in large slices this is a real, repeatable per-migration leak.

### Preconditions

1. The strategy wired by the operator at the in-place step is a **market/AMM** strategy (not idle, not a par-preserving ERC4626 direct vault).
2. There is at least one parked user being re-injected.

The tests cover only `MockYieldStrategy` (par-preserving), so this path is **untested against a haircutting strategy** — confirming the gap is real, not theoretical-only.

### Law classification

**Law-3 footgun, escalating toward Law-1/Law-2 depending on target.** A competent, non-malicious operator running the in-place flow to swap *into* a market strategy would be **surprised** that re-injected users silently lose deposit-leg slippage that the gate was supposed to prevent — the contract's own doc (B/C) promises "re-injects the same users, crediting each user the exact principal that was parked for them" (`:168`, `:222`), which is **violated** whenever the target strategy haircuts. That is a story-faithfulness break (Law 2): story-012's stated intent is a *safe* in-place dependency swap, and "users get their parked principal back" is the invariant it claims; a haircutting target silently breaks it. The migrator cannot detect this on-chain (it can't compare `credited` to `amt` — `depositFor` returns nothing).

### Recommendation

- Document explicitly that the in-place flow is **only** safe for direct/par-preserving (idle / ERC4626-direct) re-injection targets, and forbid wiring a market strategy in the in-place runbook (mirror the underwater-swap guard's spirit).
- OR have `depositFor` return `credited` and have `migrateIn` re-park the shortfall (`amt - credited`) so the user can `claimTimedOut` the remainder, rather than zeroing to the full `amt`. (This makes the loss visible and recoverable instead of silent.)

---

## ECON-12-02 — Underwater migration: single haircut faithfully propagated (no double-haircut, no arbitrage) UNLESS the new strategy also haircuts

- **Verdict:** REFUTED for the "double-haircut / arbitrage at stakers' expense" hypothesis on a par re-injection target. CONFIRMED as a compounding second haircut only when ECON-12-01's market-strategy precondition also holds.
- **Type:** loss socialization (terminal-migration economics) + compounding with ECON-12-01
- **Severity:** informational on its own; folds into ECON-12-01 when both conditions hold
- **Confidence:** high
- **Cross-ref:** M-05 `0dca43f3` (emergencyWithdraw FCFS), M-06 `dbdc3ac9`.

### Analysis

If the OLD strategy is underwater at `initiateMigration` (realizable `R < P`):

1. `initiateMigration` (`:443`) realizes the whole position with the underwater guard OFF, producing `R`. Snapshot `{realized: R, principalSnapshot: P}`.
2. `batchMigrate` → `_exitPosition` (`:528`) credits each user `credit = amt · min(R,P)/P = amt·R/P` — the **proportional, order-independent** socialized haircut. This is exactly the M-05-killing economics: every equal-principal user gets equal payout, no FCFS, no last-claimer starvation (`Σ floor(p_i·R/P) ≤ R`, conservation proven in the source comment `:407`).
3. The migrator parks `amounts[i] = p_i·R/P` (`:153`) — the **already-haircut** amount, NOT the original principal `p_i`. So `totalParked == Σ amounts == R == ` what was transferred in. INV-1/INV-3 hold below par.
4. On `migrateIn`, the user is re-credited `p_i·R/P` into the new strategy.

**No double-haircut and no arbitrage on a par re-injection target.** The underwater delta `p_i·(1 − R/P)` is lost exactly once, at the terminal-migration snapshot, identically to the upstream-audited `userMigrate`/`batchMigrate` path. No party gains at stakers' expense (above-par yield, if any, is left in the decoupled old strategy as protocol-owned value — `:464`; dust stays protocol-owned). The migrator is a faithful courier of the snapshot economics. This is **intended design** (matches the staker's `min(R,P)/P` socialization and the CLAUDE.md "survivors are paid `min(R,P)/P` and must re-stake").

**The only new risk is compounding:** if the operator runs the in-place flow on an *underwater* old strategy AND wires a *market* new strategy, the user eats the underwater haircut (`R/P`) at migrateOut **and** the deposit slippage at migrateIn — two sequential haircuts. The second is the ECON-12-01 finding; ECON-12-02 just notes they stack.

### Footgun nuance (Law 3)

There is a *non-obvious operator footgun*: nothing stops `initiateMigration` from being run on an underwater pool. The in-place flow's purpose (per doc A) is a *dependency swap*, which an operator may reach for thinking it is loss-neutral. It is loss-neutral only for a healthy (R==P) old strategy. Running it underwater silently realizes and socializes the loss — faithful to the terminal-migration contract, but the operator who picked the in-place tool for a "routine strategy swap" may be **surprised** that it crystallized a loss on live users. Surface as operational guidance: **do not run the in-place flow on an impaired/underwater strategy** — that case is the cross-staker `StableStakerMigrator` / accept-the-haircut terminal path, not a "swap." Severity: Low operational hazard (the loss itself is intended and correctly socialized; only the tool-choice surprise is the footgun).

---

## ECON-12-03 — Revived-pool race: permissionless `stake` between `finalizeAndReset` and `migrateIn` — no value extraction from parked principal, no first-depositor skim

- **Verdict:** REFUTED (no theft / inflation / rate-manipulation that extracts the about-to-be-reinjected parked principal). Residual: a benign availability/footgun.
- **Type:** first-depositor / MEV / rate-manipulation (checked, not matched)
- **Severity:** informational → Low (operational)
- **Confidence:** high
- **Cross-ref:** PM-12-MR-02 (the most security-relevant low-confidence pattern item).

### Analysis

After `finalizeAndReset` (`:593-604`) the pool is `Active` and `stake` is permissionless again, while parked principal still sits in the migrator awaiting `migrateIn`. Examined three extraction vectors:

1. **First-depositor / ERC4626 inflation.** Does NOT apply. The staker's reward accounting is **MasterChef accumulator** (`accPhusdPerShare` / `rewardDebt`), not a share price derived from `totalAssets` (`_updatePool` `:706-727`, `pendingReward` `:645-655`). A first depositor cannot inflate a share price that later depositors round against — there is no share price. Each `depositFor`/`stake` credits `credited` 1:1 into `user.amount` and `pool.totalStaked` independently; no per-deposit cross-subsidy.

2. **Rate manipulation against the re-injected users.** A third party who `stake`s first only changes `pool.totalStaked`, which dilutes *future phUSD emission share* (standard MasterChef dilution), not principal. Re-injected users' **principal** is credited exactly `credited` regardless of who else is in the pool. Emission dilution is the normal, intended consequence of more TVL — not value extraction from parked principal. No principal path reads `totalStaked` to pay a user.

3. **Sandwiching the re-injection deposit.** The re-deposit haircut of ECON-12-01 is execution slippage *inside the strategy*, which a sandwicher could in principle worsen — but `migrateIn` is `onlyOwner` and the strategy deposit happens atomically inside the operator's tx; an attacker can pre-position liquidity in the underlying AMM but cannot insert between `_pullToken` and `strategy.deposit`. This is the generic M-07 strategy-slippage exposure, already captured by ECON-12-01; the revived-pool window adds nothing new to it.

**Conclusion:** the parked principal is never reachable by an outside staker — each parked user's `depositFor` credits *that user's own* `amt`, pinned to the original address (`:223`), and the migrator's funds only ever leave to `depositFor(originalUser)` or `claimTimedOut(self)`. The single-operator-session assumption is unenforced on-chain (an outside staker *can* enter the half-refilled pool), but this only dilutes emissions and does not interfere with `migrateIn` accounting. Law-3 footgun-flavored at most (operator should pause around the window — `finalizeAndReset` and `depositFor` both run while paused, so the recommended runbook can wrap the whole out→reset→rewire→in in pause/unpause to close the permissionless-stake window). Recommend documenting the pause-wrap.

---

## ECON-12-04 — Timeout hatch & emission cap: no double-count, no reset exploit, no profitable force-timeout incentive

- **Verdict:** REFUTED (emission cap preserved across out→reset→in; no profitable timeout-vs-wait or operator-grief incentive that extracts value).
- **Type:** emission-cap integrity / incentive alignment
- **Severity:** informational; one Low operator footgun (short-timeout multi-batch)
- **Confidence:** high
- **Cross-ref:** SURFACE-4, SURFACE-5, SA-004; core emission-cap invariant (CLAUDE.md).

### Emission-cap integrity (the out→reset→in cycle)

Confirmed **no double-count and no reset exploit**:

- phUSD is minted to users **once**, at `migrateOut` (inside `_exitPosition` `:539-541`, the frozen pending). The migrator handles **principal only** and never mints.
- During `Migrating`, `_updatePool` is a no-op (`:710-712`) — the empty/frozen window accrues nothing.
- `finalizeAndReset` sets `lastRewardTime = block.timestamp` (`:601`) AND `_updatePool`'s `totalStaked==0` branch fast-forwards `lastRewardTime` anyway (`:717-719`) — belt-and-suspenders. So the entire out→reset window emits **zero** phUSD; there is no retro-accrual gap to claim.
- After `migrateIn`, users re-stake fresh and begin accruing from `lastRewardTime = now`. No retro-accrual, no overlap with the frozen pending already minted. The MasterChef `phUSDPerDay` cap (CLAUDE.md core invariant) holds across the cycle: the cycle neither double-counts the frozen pending nor resets the budget to re-emit it.

### Incentive analysis (force-timeout vs wait; operator grief)

- **User force-timeout incentive:** none beneficial-to-attacker. `claimTimedOut` returns **principal only** (phUSD already minted at `migrateOut`). A user who waits gets the same principal re-staked (and resumes phUSD accrual); a user who claims out gets principal but stops accruing phUSD and exits the system. So waiting weakly dominates claiming for an honest user — there is no value-extraction incentive to force the timeout, only a self-harming "leave early and forfeit future emissions" choice. No griefing of others (self-scoped, removes only the caller).
- **Operator grief:** the operator cannot strand principal — the immutable-staker target (`:71`, design note D) and the permissionless self-scoped hatch (`:239`) guarantee every parked user recovers principal after `migrationTimeout` even if the operator vanishes or the key is compromised. `rescueERC20` is fenced below `totalParked` (`:270-272`, INV-3). No operator path sends parked principal anywhere but back to the user.

### The one real footgun (Law 3) — short timeout on a multi-batch job

If the operator deploys with `migrationTimeout` near `MIN_TIMEOUT` (1 day) and the rewire stalls past it, parked users can `claimTimedOut` mid-migration, leaving a **partially re-filled pool**: those users took principal back and are removed from the set, so the later `migrateIn` slice skips them (`:210` `amt==0 → continue`). No value is lost (they got principal; they self-exited), but the migration is left incomplete and those users are no longer in the pool. The doc explicitly scopes the contract to "a small staker set, a single batch, and a short window. Not built for long-running, multi-day, many-batch migrations" (`:54-55`). A competent operator following that scope is fine; one who runs a many-batch job with a near-MIN timeout would be **surprised** by mid-flight self-exits. Surface as operational guidance: **size `migrationTimeout` comfortably above the expected full out→reset→in duration** (the doc's recommended 7-day default is sound for the intended single-session use). Severity: Low operational hazard — no fund loss, only migration completeness.

---

## Summary table

| ID | Question | Verdict | Severity | Who loses | Prior-Medium ref |
|----|----------|---------|----------|-----------|------------------|
| ECON-12-01 | Re-injection value conservation | **CONFIRMED** (market-strategy target) | potential-medium | individual re-injected staker (deposit slippage) | M-07 `969722dc` (relocated to deposit leg) |
| ECON-12-02 | Underwater migration double-haircut/arbitrage | **REFUTED** (single haircut, faithful); compounds with -01 | informational / Low footgun | (intended socialized loss only) | M-05 `0dca43f3`, M-06 `dbdc3ac9` |
| ECON-12-03 | Revived-pool race extraction | **REFUTED** (no theft/inflation/rate-manip) | informational / Low footgun | none (emission dilution only) | — |
| ECON-12-04 | Timeout hatch & emission cap | **REFUTED** (cap preserved, no profitable force) | informational / Low footgun | none | core emission-cap invariant |

## Headline

The story-012 in-place migrator **does not re-open the M-01/M-05/M-06 economic harms** that the empty-pool gate collapsed: the exit leg keeps the order-independent `min(R,P)/P` socialization (no FCFS rebirth), parked principal is unreachable by outsiders, and the emission cap survives the out→reset→in cycle intact. The **one genuine relocation** is **M-07 (rate-vs-execution slippage), reborn on the re-injection deposit leg** (ECON-12-01): if the operator wires a market/AMM strategy as the in-place target, re-injected users silently lose deposit slippage, contradicting the story's "users get their parked principal back" claim — untested (mock is par-preserving) and undetectable on-chain by the migrator. That is the only finding worth a Medium, and only under the market-strategy precondition; everything else is intended design or a documented-scope operator footgun. **Recommend a PoC** wiring a haircutting strategy through `migrateIn` to fix severity, and re-evaluating ECON-12-01 against whatever strategy class the operator actually intends to wire in place.
