# Economic / Design-Level Findings — stable-staker

- **Project:** stable-staker
- **Scan timestamp:** 2026-06-01
- **Scan type:** economic (Tier 2, protocol-wide)
- **In scope:** `src/StableStaker.sol` (529L), `src/StableStakerMigrator.sol` (69L)
- **Context read:** `reports/stable-staker/01/profile.md`, `pattern-matches.md`,
  `IYieldStrategy.sol`, `ERC4626YieldStrategy.sol`, `AYieldStrategy.sol`, submodule `CLAUDE.md`.

> Scope discipline: the 9 documented by-design items (emission-cap invariant, dust rounds down,
> protocol-owned yield, underwater-withdraw *not blocked* on emergency/migrate, owner/migrator/pauser
> centralization, permissionless emergencyWithdraw while paused) are NOT reported. Findings below are
> economic deviations *beyond* those designs. The pure emission-cap and reward-debt leads (#1, #2) were
> examined and confirmed sound — no findings there.

---

## ECON-001 — Underwater `withdraw` buffer path is first-come-first-served: early withdrawers exit at par, socializing the entire strategy loss onto late / emergency / migrating users

- **Severity:** Medium
- **Contract:** `StableStaker.sol`
- **Function / line:** `_routeExit` `:494-502` (underwater buffer branch), reached from `withdraw` `:258`
- **Affected parties:** stakers who withdraw last (and emergency/migrating users); the protocol buffer.

### Economic mechanism
The submodule design says: while a token's strategy is below par, a *non-migrating* `withdraw` is
either (a) satisfied **in full, at par** from the on-contract protocol-owned buffer, or (b) reverted
if the buffer cannot cover it (`_routeExit:498` `if (t.balanceOf(this) >= amount) return amount;`
else `revert("strategy underwater")`). The buffer is a finite, shared, protocol-owned reserve.

The flaw is *ordering*: the buffer is consumed strictly first-come-first-served at **par**, with no
proportional haircut. The strategy principal is NOT redeemed in this branch — the user is paid
`amount` out of buffer and the strategy keeps the (below-par) shares. Consequences while underwater:

1. The first stakers to call `withdraw` are paid their **full principal** from the buffer (zero
   loss), draining it.
2. Once `bufferBalance < amount`, every remaining `withdraw` **reverts**. Those users can only exit
   via `emergencyWithdraw` / `migrateOut`, which redeem from the now-still-underwater strategy and
   receive the **full haircut** (measured balance-delta `< amount`).

So a loss that economically belongs to the whole pool pro-rata is instead borne entirely by whoever
is slow, while fast actors escape loss-free. `withdrawDisabled(token)` returns `true` during this
window, so the race is observable and front-runnable on-chain.

### Exploit / loss path
- Strategy goes below par by shortfall `S` (negative yield / lossy vault redeem). Buffer holds `B`.
- Sophisticated stakers (or an MEV bot watching `withdrawDisabled` flip / strategy NAV) front-run
  and `withdraw` until the buffer (`B`) is exhausted — they each receive par.
- Remaining `withdraw` calls revert; those stakers are forced to `emergencyWithdraw` and eat the
  entire shortfall `S` between them, even though, pre-race, the per-user expected haircut was only
  `S / totalStaked` of their stake.
- Profitability: the race itself costs only gas; the "profit" is loss-avoidance (avoiding a
  `S/totalStaked` haircut). Strictly positive expected value for any staker who acts first, paid for
  by the stakers who act last — a classic bank-run / unfair-loss-socialization dynamic.

### Impact
Below-par episodes do not distribute loss pro-rata as a pooled vault should; they convert it into a
winner-take-nothing race where the buffer subsidizes early exiters and the residual loss is fully
dumped on the last cohort (or on whoever the migrator batches last). This is *not* one of the
documented designs — the docs only state that emergency/migrate are "not blocked" and "accept the
haircut"; they do not document that solvent `withdraw` can be raced to make some users whole at
others' expense.

### Suggested remediation
While underwater, either (a) block the solvent `withdraw` path entirely (force everyone through the
haircut-bearing emergency/migrate path so loss is pro-rata), or (b) apply the strategy's current
par-ratio (`totalBalanceOf/principalOf`) to the buffer payout so every withdrawer takes the same
proportional haircut regardless of ordering, rather than paying par until the buffer is dry.

---

## ECON-002 — Migration of an underwater pool reverts (escape hatch unavailable when most needed) and, absent the revert, would mint phantom principal on the destination staker

- **Severity:** Medium
- **Contracts:** `StableStaker.sol` + `StableStakerMigrator.sol` (cross-contract)
- **Function / line:** `StableStaker.migrateOut` `:334` (`_routeExit(token, totalPrincipal, false)`
  returns haircut `payout < totalPrincipal`, but `amounts[i] = amt` = requested `:324`);
  `StableStakerMigrator.migrate` `:46-65` (`total = sum(requested)`, `forceApprove(total)` `:57`,
  loop `depositFor(..., amounts[i]=requested)` `:62`).
- **Affected parties:** all migrating users (migration DoS); destination-staker solvency (phantom
  principal in the non-reverting interpretation).

### Economic mechanism
`migrateOut` passes `guardUnderwater=false`, so under a below-par strategy it redeems the aggregate
`totalPrincipal` and forwards the **measured-received** `payout` (a haircut: `payout < totalPrincipal`)
to the migrator (`:334-335`). However the returned `amounts[]` array carries each user's **requested**
principal (`amounts[i] = amt`, `:324`), not their share of the redeemed `payout`.

The migrator then sums `total = Σ requested` (`:48-51`), `forceApprove(newStaker, total)` (`:57`), and
loops `newStaker.depositFor(token, users[i], requested)` (`:62`). Each `depositFor` does
`_pullToken(migrator, requested)` → `safeTransferFrom(migrator, newStaker, requested)`. The migrator
only holds `payout < total`, so once the running sum of pulled `requested` exceeds `payout`, a
`depositFor` reverts on insufficient balance and the **entire migration tx reverts atomically**
(rolling back `migrateOut` too — confirmed: single tx).

### Exploit / failure path
- A pool's strategy is below par (the exact incident scenario migration is meant to handle).
- Owner/migrator calls `Migrator.migrate(token, users)`.
- `migrateOut` succeeds internally and mints each user's pending phUSD, but the migrator receives
  only the haircut `payout`.
- The redeposit loop reverts as soon as cumulative requested principal exceeds `payout`.
- Result: **the migration of any underwater pool cannot complete**. The permissioned migration escape
  hatch — explicitly designed to remain callable while paused / during an incident — is unavailable
  precisely in the below-par incident it exists for. Users with pending rewards also can't use normal
  `withdraw` (reverts underwater) and are pushed to `emergencyWithdraw` (forfeiting rewards).
- Counterfactual (if the conservation were "fixed" by re-crediting `requested`): the destination
  staker's `totalStaked`/`user.amount` would exceed the tokens it actually received by the haircut,
  i.e. **phantom principal** — a conservation violation that the later destination withdrawers would
  realize as their own loss. Either way the requested-vs-received mismatch is unsound.

### Impact
Loss of the migration mechanism for any pool whose strategy is even marginally underwater (DoS of a
core operational/incident path). The mismatch also makes the migrator's approval (`forceApprove(total)`)
over-grant relative to its real balance. Note this is the protocol-level confirmation of profiler
LOCAL-M01, promoted because it disables an incident escape hatch in the exact condition it targets.

### Suggested remediation
Have `migrateOut` return the **actually-received per-user amount** (e.g. distribute `payout`
pro-rata across the migrated users, or return measured deltas), and have the migrator approve/redeposit
those received amounts so totals reconcile and the destination credits real principal. Alternatively,
redeem each user individually so per-user received is exact.

---

## ECON-003 — `rescueERC20` can sweep the entire underwater buffer (reserved = 0 when strategy set), bricking pending par-withdrawals

- **Severity:** Low / QA (centralization-adjacent)
- **Contract:** `StableStaker.sol`
- **Function / line:** `rescueERC20` `:521-528` (`reserved = ... ? totalStaked : 0`, `:523`)
- **Affected parties:** stakers relying on the underwater buffer; owner-trust boundary.

### Economic mechanism
When a strategy is set, `rescueERC20` treats `reserved = 0` and lets the owner transfer the **entire**
contract balance of `token`. But that balance is exactly the buffer that ECON-001's underwater
`withdraw` path (`_routeExit:498`) draws on, and that `skimSurplus`'s `setAsideBuffer` returns to this
client. Sweeping it (or front-running a pending underwater `withdraw` with a rescue) makes that
`withdraw` flip from "satisfied at par" to `revert("strategy underwater")`.

### Impact
The owner can remove the protocol-owned reserve that backs at-par underwater withdrawals. This is
owner-only (a documented high-trust role) and the funds are protocol-owned, so it does not steal
*accounted user principal* (principal sits in the strategy). It is reported as Low/QA because it is a
spec tension — the buffer is simultaneously "fully rescuable" and "the backing for par underwater
withdrawals" — rather than a permissionless exploit. Confirms profiler LOCAL-002.

### Suggested remediation
If the buffer is intended to back underwater withdrawals, reserve it from rescue (e.g. reserve
`max(0, principalOf(staker) - totalBalanceOf(staker))` worth of buffer when a strategy is set), or
explicitly document that buffer is discretionary and not a guarantee.

---

## Leads examined and NOT promoted (confirmed sound / by-design)

| Lead | Conclusion |
|---|---|
| **Emission-cap integrity (#1)** | Holds. Single accumulator writer `_updatePool`; empty-pool windows fast-forward `lastRewardTime` accruing nothing (`:434-436`); `phUSDPerDay` settles old rate via `_updatePool` *before* writing new rate (`:151-153`); each pool has independent `phusdPerSecond`/accumulator so shared rate is not shared budget. No share-timing / churn / dust path mints above `phusdPerSecond * elapsed`. By-design, no finding. |
| **Share / reward-debt exploits (#2)** | No share token; principal is 1:1; mul-before-div with `ACC_PRECISION=1e18`; dust rounds DOWN (protocol-favoring). `_settle` mints against pre-update `amount` then resets `rewardDebt`; flash stake earns 0 (elapsed 0). No first-depositor inflation (no rate-based share exchange). By-design, no finding. |
| **Solvent-path strategy accounting (#3)** | Sound for the single-client farm: `_isUnderwater` compares `totalBalanceOf(staker)` vs `principalOf(staker)` which are this client's own proportional values; solvent `_routeExit` measures balance-delta and never double-counts a pre-existing buffer. Stranded-principal arithmetic in the underwater buffer branch nets out to exactly the haircut the buffer absorbs (self-consistent with the documented "buffer absorbs the dip" model) — the *redistribution* problem is captured separately as ECON-001. |
| **Buffer drain to force revert (#4)** | Captured as ECON-001 (race) and ECON-003 (owner rescue). No additional permissionless value-extraction path: buffer payout is capped at par, never above the user's `amount`. |
| **Migration conservation happy-path (#5)** | At/above par (or idle tokens) received == requested and principal + reward entitlement are preserved exactly per user. Only the underwater case breaks, captured as ECON-002. |

---

## Ranked summary

1. **ECON-001 (Medium)** — Underwater `withdraw` buffer is FCFS at par; early exiters escape loss-free, full strategy loss socialized onto last/emergency/migrating users. `_routeExit:494-502`.
2. **ECON-002 (Medium)** — Underwater-pool migration reverts (escape hatch unavailable when needed) due to requested-vs-received mismatch; absent the revert would mint phantom principal on the destination. `migrateOut:324,334` ⇄ `Migrator.migrate:48-62`.
3. **ECON-003 (Low/QA)** — `rescueERC20` (reserved=0 with strategy set) can sweep the buffer that backs at-par underwater withdrawals. `rescueERC20:523`.
