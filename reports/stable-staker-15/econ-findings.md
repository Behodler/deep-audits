# Economic / design-intent scan — stable-staker run-15

- **Scan type:** economic (Tier 2), REGRESSION vs `8856781`
- **HEAD:** `2146428bdd9adb1fbaf1c1feaa4fbf36133e5506`
- **Delta analysed:** `69c6fef` (story-020: self-heal divergence + count buffer in R), `2b9cf5e`/`2146428` (story-021 pre-flight), `387ed63`/`847cd98` (V1 freeze + V2 rename)
- **Story read (Law 2):** `~/code/product-owner/stories/stable-staker/auto-complete/stable-staker-version-pivot/020-self-heal-migration-divergence-and-count-buffer.md` (state: `auto-complete`, sprint `stable-staker-version-pivot`)
- **Contracts:** `src/StableStakerV2.sol`, `src/versions/v1/StableStakerV1.sol` (frozen), `src/CrossVersionMigrator.sol`, `src/InPlaceMigrator.sol`. Cross-repo dependency read for value-flow only: `lib/reflax-yield-vault/src/AYieldStrategy.sol`, `.../concreteYieldStrategies/*`.
- **Findings:** 1 Medium (re-raise of an owner wont-fix), 3 Low, 1 QA. Two prior findings propose-fixed **on V2 only**.

---

## HEADLINE — the fix does not reach the live contract

`ss14m1` (`d1aa4060`, M-01, open) is a **verified-live mainnet condition**: DOLA and USDC on `0xbce8ABC09BaEDCabE93419bF875f6186e182079A` revert `initiateMigration` with `"incomplete exit"` today. Story-020 lands the self-heal in `src/StableStakerV2.sol` **only**. The deployed instance is V1, now frozen verbatim at `src/versions/v1/StableStakerV1.sol` and explicitly unpatchable.

The cross-version escape does **not** clear it either: `CrossVersionMigrator.initiateMigration` forwards to `oldStaker.initiateMigration`, i.e. into V1's hard `require(principalOf == 0)`. The two funded pools therefore still cannot begin terminal migration under any on-chain path in this repo.

**Remedy enumeration (no "permanent" claim is made).** Owner-settable escapes that exist today:
- `AYieldStrategy.relinquishPrincipalAsOwner(client, amount)` (`:654`) — strategy-owner, writes the surplus down so V1's post-check passes. This is the documented runbook and it works.
- `AYieldStrategy.withdrawAsOwner` / `depositAsOwner` (`:627`, `:644`) — can move the booked principal, redeeming to the strategy owner, not the staker.
- Staker-side `setYieldStrategy` is **not** available: it is gated on `totalStaked == 0` and the pools are funded.

So the condition is recoverable by one strategy-owner call, but **`ss14m1` must not be flipped to `fixed` this run.** Correct disposition: split — fixed on V2, still open on V1/mainnet.

---

## Answers to the five questions

### Q1 — Who absorbs a below-par exit, and in what order?

**Order of absorption (V2), most-junior first:**

1. **Above-par yield inside the strategy** — never available. `_routeExit` requests exactly `P`; `AYieldStrategy._withdrawInternal` (`:732-752`) caps the request at booked principal, so surplus value can never be pulled to cover a shortfall. Protocol-owned, and it stays that way.
2. **B2, the on-contract idle pile** — **new this run**, absorbs the shortfall first, up to its full size.
3. **Stakers, pro-rata** — the residual only.

**Ordering among stakers is pro-rata, not FCFS**, and provably so: `migrationInfo` is written once in `initiateMigration:526` and read back in `_exitPosition:584-586` as `S = min(R,P)`, `credit = amt*S/P`. `P` is the immutable snapshot, never a re-summed batch total, so `batchMigrate` and `userMigrate` pay the identical credit at any ordering or batch composition. `withdraw`/`emergencyWithdraw` are both gated `poolState == Active`, so no one can jump the queue **once `Migrating` is set**. (The exploitable window is strictly *before* that — see ECON-15-01.)

**Worked example.** `P = 300e6` USDC (three stakers × `100e6`); strategy 5 % impaired, full exit delivers `285e6`; `B2 = 10e6`.

| | V1 (frozen / deployed) | V2 (this run) |
|---|---|---|
| `R` | `285,000,000` (exit delta only) | `295,000,000` (`balanceOf(this)`) |
| `S = min(R,P)` | `285,000,000` | `295,000,000` |
| credit per staker | `100e6·285/300 = 95,000,000` | `100e6·295/300 = 98,333,333` |
| haircut per staker | `5,000,000` (5.00 %) | `1,666,667` (1.67 %) |
| left on contract after all three exit | `10,000,000` (B2, untouched) | `1` wei (floor dust) |

Rounding direction is correct throughout: `credit = (amt*S)/P` floors, so each user receives **≤** fair share, and `Σ floor(p_i·S/P) ≤ S ≤ R = balance`, i.e. the idle pile always covers every credit under any interleaving. Dust is protocol-owned. No round-trip leg exists on this path.

### Q2 — Is folding B2 into `R` a cross-cohort subsidy?

**No. It is a protocol-funded top-up, not a transfer between users.** Filing it as a value leak would be wrong on three independent grounds:

1. **B2 is protocol money by construction on this path.** The only writer that puts non-user tokens there is `setYieldStrategy`'s sweep, itself gated on `totalStaked == 0` (`:251`). Where `yieldStrategy == address(0)` B2 does contain user principal — but then it *is* the principal being migrated, and `R` is capped at `P`, so nothing extra is paid.
2. **There is no "remaining staker" cohort of that token to lose it.** Terminal migration exits *every* position; `finalizeAndReset` (`:652-658`) refuses to revive the pool until `stakerCount == 0 && totalStaked == 0`. B2 is per-token (`balanceOf(this)` for that ERC20), so there is no cross-token contamination either.
3. **The only cohort affected is temporal — future stakers of a revived pool** — and per the standing framing, B2 is **working capital, not a solvency reserve**. No future staker was ever entitled to it, nothing sizes it against outstanding principal, and `rescueERC20` may sweep it at the owner's discretion anyway.

Net: value moves from the protocol's balance sheet to users, once, deliberately, capped at par. That is the story's stated intent, and it is the correct severity treatment (**no finding**). What *is* reportable is the two mechanisms that now compete for that same pot — ECON-15-01 and ECON-15-02 below.

### Q3 — Donation / inflation on `balanceOf(this)`, both directions

**Inflation direction — cannot unlock anything.** `R` is capped at `P` two lines after it is read (`:521-524`) and capped again at the credit site. Consequences enumerated:
- **Payout:** a donor can only *reduce* a haircut, never create an over-credit. A staker donating `D` recovers only `p_i·D/P` of it — strictly loss-making, so there is no self-donation arbitrage.
- **Post-check:** the `"incomplete exit"` require (`:496-499`) reads `strategy.principalOf`, not a balance. A donation cannot satisfy it.
- **Rescue:** `rescueERC20` reserves `totalStaked` when no strategy is set — which is exactly the `Migrating` state, since `initiateMigration:505` clears the strategy. While users remain, `bal ≈ R ≤ P = ` remaining `totalStaked`, so a below-par migration hard-blocks any non-zero rescue. A donation raises `bal` and could in principle unlock a rescue of the donated amount — but the donor is the only one out of pocket and credits are unaffected. Not exploitable.
- **Post-snapshot donations** do **not** raise `R` (snapshot immutable), so `min(R,P)` at `_exitPosition:585` is genuinely redundant defence, as the in-source comment claims.

**Withheld/drained direction — cannot brick, but silently downgrades.** No `require` anywhere reads `R`. `R = 0` does **not** revert: `_exitPosition` returns credit `0`, positions are still zeroed, `safeTransfer(_, 0)` succeeds on a standard ERC20, and `CrossVersionMigrator.migrate` explicitly *skips* zero-credit users (they are exited from the source with nothing and never appear on the destination). So the failure mode is not a brick — it is a **silent total wipe**. See ECON-15-03. The drain vector itself is ECON-15-02.

### Q4 — The self-heal's economic floor

**There is no lower bound anywhere — not on `booked`, not on `R`.**

- `strategy.relinquishPrincipal(token, booked)` (`:489`) is called for **any** `booked > 0`, with no ceiling and no sanity comparison against `P`. It writes `clientBalances` down without moving a single share (`AYieldStrategy._relinquishInternal:667-683`), so the staker permanently forfeits its claim on whatever it relinquishes.
- `R` is whatever the balance happens to be, and the migration proceeds at any value including zero.

**How far the V1-vs-V2 comparison actually goes (important — the obvious framing is overstated):** V1's `require(principalOf == 0)` was never a loss-refusal. Because `_withdrawInternal` debits the **requested** amount regardless of what `_disposeShares` delivered (`:748`, and the in-source "protocol-favouring write-down" note at `:730`), a catastrophic under-delivery leaves `booked == 0` and **V1 proceeded too**, haircutting users on a smaller `R`. V1 reverted only on *unreconciled* principal. So story-020 did not remove a loss guard; it removed a reconciliation brick — and on the loss path V2 is strictly *better* for users than V1.

**What is genuinely new is the unbounded write-down.** With the current `AYieldStrategy`, `booked` after `_routeExit(P)` is exactly `max(0, availablePrincipal − P)` — the swept surplus, protocol money by construction, small. That is the intended case and it is economically correct. A large `booked` requires a strategy whose `withdraw` debits less than it caps to; **no such strategy exists in `reflax-yield-vault` today**, so this is a latent guard-degradation, not a live vector — stated plainly rather than inflated.

**The reachable floor problem is `R`, and it is real.** `ERC4626YieldStrategy._disposeShares` (`:126-138`) caps at `availableShares` and calls `vault.redeem` with **no minimum out**. An impaired Tokemak vault delivers arbitrarily little; principal is debited in full; `booked == 0`; the post-check passes; `PrincipalDivergence(token, P, 0, 0)` is emitted — **the clean-case payload** — and the pool transitions to the one-way `Migrating` state at whatever the market gave in that block.

**Who is surprised:** (a) **every staker in the pool** — `withdraw` and `emergencyWithdraw` are both `Active`-gated, so once `Migrating` is set the only exit is `userMigrate` at the same haircut; there is no opt-out and no reversal; (b) **the operator**, who gets a `PrincipalDivergence` log identical in shape to a clean migration and must diff `MigrationInitiated(R, P)` by hand to notice. This is the one economic precondition the story's own governing principle — *"every precondition a runbook is currently trusted to satisfy must be either self-healed or asserted on chain before the irreversible step"* — did not close. Filed as ECON-15-03.

### Q5 — B1 vs B2: is there a story/code mismatch?

**No mismatch. The story means B2, and the code counts B2.** The story defines its own term at line 27:

> "that idle balance is protocol money by construction — **set-aside buffer, dust, donations** — never staked principal"

and prescribes the exact implementation at lines 144-145 (`R = IERC20(token).balanceOf(address(this)); if (R > P) R = P;`), which is what `StableStakerV2.sol:521-524` does. The title's "set-aside buffer" is the on-contract idle pile, not the strategy-side `setAsideBufferSize` percentage dial. The prescription also matches `ss14l8`'s own recommended fix verbatim.

Two residual notes rather than a mismatch finding:
- **Name collision (QA).** "Set-aside buffer" names B1 everywhere in `reflax-yield-vault` (`AYieldStrategy:57,63`) and B2 in this story and in `StableStakerV2`'s NatSpec. Both meanings now appear in one sentence of the source comment at `:513-516`. Worth one disambiguating word.
- **The fix's *efficacy* does depend on B1** — filed as ECON-15-04.

---

## Findings

### ECON-15-01 — MEDIUM — Story-020 turns the FCFS par-exit buffer into a front-run on the migration cushion

- **Type:** incentive misalignment / cross-path value transfer (**RE-RAISE**, see disclosure below)
- **Contract / function:** `src/StableStakerV2.sol` — `_routeExit` (`:834-856`) interacting with `initiateMigration` (`:512-527`)
- **Confidence:** medium-high (mechanism verified in source; severity contested by prior owner triage)

**DISCLOSURE — this re-raises an owner wont-fix.** Prior entry `69c7666eee33698e7f4f2cce7ab94406e40929494e19a2517a2a324e5c9ea73d`, *"Underwater withdraw buffer is FCFS at par, socializing strategy loss onto slow stakers"*, Medium, **wont-fix**, triaged 2026-06-01. Its `triageReason` reads in part:

> "Intended design (confirmed by protocol owner) … bank-run / mass-exit is handled separately by migrateOut with pro-rata distribution. **The report itself concedes there is no incremental victim (the slow staker is baseline-unchanged vs a no-buffer world).**"

**Basis for re-filing:** the emphasised clause was the load-bearing half of the closure, and story-020 falsified it. Under V1 the buffer was *only* an FCFS par-exit pot — it never entered the migration payout, so a slow staker's migration credit was indeed identical with or without a buffer. Under V2, `R = balanceOf(this)` makes B2 part of the pro-rata pool, so **every par exit taken while `Active` now removes cushion that would otherwise have been distributed pro-rata to the whole cohort.** The incremental victim now exists and is quantifiable. The first clause of the closure (par exits during transient dips avoid forcing loss realisation) is untouched and I am not disputing it — the recommendation below is deliberately narrower than the two fixes the owner rejected.

**Mechanism.** `_routeExit`'s underwater branch (`:840-849`) pays the withdrawer `amount` **at par** out of B2 and calls `strategy.relinquishPrincipal(token, amount)`, which writes the claim down without moving shares. `withdraw` is `Active`-gated; `initiateMigration` is a single transaction that flips the pool to `Migrating`. There is therefore a mempool window in which any staker can convert their pro-rata haircut into a par exit, rationed FCFS by `B2 ≥ amount` (`:845`).

**Worked example.** `P = 1,000e6` USDC — Alice `100e6`, others `900e6`. Vault 20 % impaired: a full exit delivers `800e6`. `B2 = 150e6`.

| | No front-run | Alice front-runs `withdraw(100e6)` |
|---|---|---|
| Alice | `100e6·950/1000 = 95,000,000` | `100,000,000` (par, from B2) |
| B2 remaining at snapshot | `150,000,000` | `50,000,000` |
| `P` at snapshot | `1,000,000,000` | `900,000,000` |
| strategy delivers | `800,000,000` | `800,000,000` |
| `R = min(delivery+B2, P)` | `950,000,000` | `850,000,000` |
| others receive | `855,000,000` (5.00 % haircut) | `850,000,000` (5.56 % haircut) |
| **total distributed** | `950,000,000` | `950,000,000` |

**Economic impact:** an exact zero-sum transfer of **5,000,000 USDC** from the remaining cohort to Alice. Totals are conserved — no protocol value is created or destroyed; this is purely an allocation-rule arbitrage between two claim orders on one pot (par/FCFS while `Active`, pro-rata while `Migrating`).

**Attack scenario:** 1. Strategy goes underwater (depeg, impairment). 2. Operator broadcasts `CrossVersionMigrator.initiateMigration(token)`. 3. Any staker with `position ≤ B2` front-runs with `withdraw(full position)`. 4. Par exit; principal relinquished; remaining cohort's `R` falls by exactly the amount paid.

**Profitability:** profit = `position × (P − R)/P`, here 5 % of position; gas is a few dollars. Profitable for any position above roughly `$1k` at a 5 % haircut. Requires no capital, no flash loan, and no privileged access. Naturally rationed by `B2` size, which is what makes it a race rather than a general drain.

**Affected parties:** the slow stakers of the migrating cohort. The protocol's balance sheet is unaffected either way (B2 is spent in both branches).

**Recommendation (narrower than the rejected fixes — preserves the par-exit design intent):** gate the *par* branch, not the buffer. Either (a) have the migrator take the pool through a short `Pausable` window before `initiateMigration` — `withdraw` is `whenNotPaused`, `initiateMigration` is not, so `pause() → initiateMigration() → unpause()` closes the window today with **zero code change** and belongs in the runbook regardless; or (b) reserve a fraction of B2 from the par branch. Option (a) is free and should be adopted immediately.

---

### ECON-15-02 — LOW — `rescueERC20` reserves nothing while a strategy is set, so a routine dust sweep silently converts a par migration into a haircut migration

- **Type:** owner footgun (non-obvious consequence — Law 3 in-scope) / **impact re-weigh, not a new defect**
- **Contract / function:** `src/StableStakerV2.sol` — `rescueERC20` (`:868-875`)
- **Confidence:** high

**This is not a new finding.** It is the existing open Low `0790a76a00ed176437d53a474145b1b5eac1a0359034e1dde31b98470b9837bb` — *"rescueERC20 can sweep the buffer backing underwater withdrawals"* — whose **impact narrative is now materially larger** and should be updated rather than duplicated. No re-file; same `contract:function`, same root cause.

**Mechanism.** `uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;` — when a strategy *is* wired (the normal operating state) `reserved == 0`, so the owner may sweep the **entire** on-contract balance. The NatSpec justifies this as "the contract balance is purely buffer + dust, so the full balance is rescuable" — accurate before story-020, and now incomplete: that balance is the migration cushion.

**Worked example** (same pool as ECON-15-01, `B2 = 150e6`, delivery `800e6`, `P = 1,000e6`):

| | B2 intact | Owner rescued `150e6` as "dust" the day before |
|---|---|---|
| `R` | `950,000,000` | `800,000,000` |
| haircut | 5.00 % | **20.00 %** |
| a `100e6` staker receives | `95,000,000` | `80,000,000` |

A **15,000,000 USDC** swing across the cohort from one `onlyOwner` call whose NatSpec says it cannot touch user value. The owner is not acting maliciously and is not warned: the sweep is a *permitted* action with a consequence three contracts away, and it is irreversible once `initiateMigration` snapshots `R`. That is the definition of a footgun under Law 3 — a competent non-malicious owner would be surprised.

**Affected parties:** the migrating cohort. Protocol keeps the swept capital, so there is no protocol loss — this is a downgrade of a discretionary gift, not a breach of entitlement, which is why it stays **Low**.

**Recommendation:** update the `rescueERC20` NatSpec to state that the rescuable balance is the migration cushion; and add an operational note that no rescue should be performed on a token whose strategy is below par or whose migration is being prepared. A code-level option, if wanted: refuse `rescueERC20` while `poolState == Migrating` for a below-par `R` (already implicit via the `reserved` check) and emit a warning event when `_isUnderwater(token, strategy)`.

---

### ECON-15-03 — LOW — The one-way door has no minimum-realization floor: `initiateMigration` completes at `R → 0` and reports it as clean

- **Type:** design-intent gap / operator footgun (extends open Low `ss14l6`, `7cdb92fd`)
- **Contract / function:** `src/StableStakerV2.sol` — `initiateMigration` (`:449-528`)
- **Confidence:** high on mechanism; the trigger requires a genuinely impaired yield source

**Mechanism.** Nothing in `initiateMigration` compares `R` against `P` other than to cap it. `ERC4626YieldStrategy._disposeShares` (`:126-138`) redeems with **no minimum out** and caps silently at `availableShares`; `_withdrawInternal` debits the full requested principal regardless (`:748`), so `booked == 0` and the `"incomplete exit"` post-check passes. `PrincipalDivergence(token, P, 0, 0)` is emitted — byte-identical in shape to a clean migration — and `poolState` flips to `Migrating`, which is irreversible except through `finalizeAndReset`, itself only reachable once every position has already been zeroed at the bad rate.

**Worked example.** `P = 1,000e6`, vault 90 % impaired, `B2 = 0`. Exit delivers `100e6`. `R = 100e6`, `S/P = 0.1`. Every position is zeroed for 10 cents on the dollar, `emergencyWithdraw` is blocked (`Active`-gated), `withdraw` is blocked, and `userMigrate` pays the same 90 % haircut. At `R = 0` the same sequence runs to completion paying literally nothing, and `CrossVersionMigrator.migrate` **skips** each zero-credit user, so they never appear on the destination staker either.

**Not a regression.** V1 behaves identically here (its `R` would be `100e6` with B2 excluded — i.e. worse). This is a gap story-020 declined to close, not one it opened. It is reported because the story's own governing principle — *"every precondition a runbook is currently trusted to satisfy must be either self-healed or asserted on chain before the irreversible step"* — names exactly this class, and the story closed the reconciliation precondition while leaving the economic one to operator judgement.

**Related latent leg (stated, not rated):** `strategy.relinquishPrincipal(token, booked)` at `:489` has no ceiling. With today's `AYieldStrategy`, `booked` is exactly the swept surplus, so the call is correct. A future strategy whose `withdraw` debits less than it caps to would have an arbitrarily large `booked` written off — irreversibly from the staker's side, since `_relinquishInternal` moves no shares and there is **no client-callable way to re-credit**. Owner-side remedies do exist on the strategy (`depositAsOwner`, `withdrawAsOwner`) so this is recoverable, not permanent.

**Recommendation:** add an operator-supplied floor to the irreversible step — `initiateMigration(address token, uint256 minRealized)` with `require(R >= minRealized)` after `:524` — so the operator states the loss they are willing to socialize rather than discovering it after the door has closed. Sizing `booked` against `P` (e.g. `require(booked <= P/10)`) would additionally keep the self-heal narrow to its intended surplus case.

---

### ECON-15-04 — LOW — The `ss14l8` fix is only as large as an off-chain config nobody asserts

- **Type:** cross-contract trust-assumption gap
- **Contract:** `src/StableStakerV2.sol:521` ↔ `lib/reflax-yield-vault/src/AYieldStrategy.sol:63`
- **Confidence:** high

`R`'s new cushion is B2, and B2 is fed principally by B1 deliveries — but only when the strategy's **global, owner-settable** `setAsideBufferRecipient` happens to be this staker. It is one address for the whole strategy, not per client, and `StableStakerV2` never reads it, never asserts it, and has no view exposing the expected cushion. If the recipient points at a treasury (a perfectly reasonable configuration), `R` gains only floor-division dust and stray donations, and `ss14l8` is closed on paper while the cushion it promised is ~0 in practice.

**Worked example.** Same `P = 1,000e6`, delivery `800e6`. Recipient == staker over a year of skims: `B2 ≈ 150e6` → haircut 5 %. Recipient == treasury: `B2 ≈ a few hundred wei` → haircut **20 %**. Same code, same story, 4× difference in user outcome, decided entirely off-chain and invisible from this repo.

**Recommendation:** expose a `migrationCushion(token)` view returning `IERC20(token).balanceOf(address(this))` and make the pre-migration runbook assert it against expectation; or, on the strategy side, document that `setAsideBufferRecipient` must equal the staker for any client relying on `ss14l8`'s cushion.

---

### ECON-15-05 — QA — `R` is not decomposable from the event stream

- **Contract / function:** `src/StableStakerV2.sol` — `initiateMigration:469`

`_routeExit`'s return value is deliberately discarded, so the **actual strategy delivery is never recorded on chain**. `MigrationInitiated(token, R, P)` shows *that* there was a shortfall but not its composition; `PrincipalDivergence` reports `booked`, which is `0` in exactly the impairment case that matters. An operator therefore cannot tell a clean par migration from one where a 20 % strategy loss was quietly absorbed by working capital — which is precisely the reconciliation story-020 built `ProtocolPrincipalSwept` to enable on the other side of the ledger.

**Recommendation:** capture `uint256 delivered = _routeExit(token, P, false);` and add it to `MigrationInitiated` (or a sibling event). One word of the same NatSpec comment (`:513-516`) should also disambiguate the two things it calls "set-aside buffer" (see Q5).

---

## Reconciliation against the ledger

| Prior entry | Disposition this run |
|---|---|
| `f7991b64…` `ss14l8` L-08 *"Terminal migration ignores the set-aside buffer"* | **PROPOSE FIXED.** Implemented exactly as its own `recommendation.fix` prescribed (`:521-524`), with the `min(R,P)` cap retained as it predicted. Human confirmation required per CLAUDE.md. |
| `d1aa4060…` `ss14m1` M-01 *"setYieldStrategy sweeps unmatched idle balance… REALIZED TODAY on two funded mainnet pools"* | **FIXED ON V2 ONLY — DO NOT CLOSE.** The deployed V1 is frozen and still bricked; `CrossVersionMigrator` routes into V1's revert. See HEADLINE. |
| `69c7666e…` *"Underwater withdraw buffer is FCFS at par"* — Medium, **wont-fix** | **RE-RAISED as ECON-15-01** with disclosure; half the closure rationale was invalidated by story-020. |
| `0790a76a…` *"rescueERC20 can sweep the buffer"* — Low, open | **IMPACT RE-WEIGH (ECON-15-02).** Same fingerprint, larger consequence. Do not re-file. |
| `7cdb92fd…` `ss14l6` *"initiateMigration is an unvalidated one-way door"* — Low, open | Partly addressed (constructor aliasing guard + destination pre-flight, story-021). The **economic** precondition remains unasserted — ECON-15-03. |
| L-02 *"uncompensated haircut on the cross-version path"* — Low, open | Unchanged. `CrossVersionMigrator.migrate` still redeposits exactly what `batchMigrate` returned, and the destination's own `_routeDeposit` may haircut again. Story-020 shrinks the first haircut; it does not compensate either. |

## Explicitly NOT filed

- **B2 consumption as a value leak.** Protocol-funded top-up, not an inter-user transfer (Q2). Also engages the standing rule that externally-derived yield is opportunity cost, never economic loss.
- **Donation-inflated `R`.** Capped at `P` twice; strictly loss-making for the donor (Q3).
- **Unbounded-slippage sandwich on the migration exit.** `ERC4626MarketYieldStrategy._disposeShares` computes `minOut` from `slippageToleranceBps` (`:168-174`) and reverts beyond it — a bounded, owner-settable dial, and a revert fails safe (the door stays open).
- **Rounding.** Every conversion on the changed path floors in the protocol's favour; `Σ credits ≤ S ≤ R` holds under any ordering. No asymmetry, no round-trip leg.
- **Local/single-function arithmetic**, per Tier-1 deferral.
- **Malicious-owner variants** of ECON-15-02 (Law 3). Only the *unknowing* consequence is filed.
