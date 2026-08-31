# Story-Faithfulness Report — stable-staker story-013

- **Project:** stable-staker
- **Scan type:** story-faithfulness (Law 2 + Law 1 override)
- **Submodule HEAD:** `d95f4a6`
- **Diff baseline:** `ffa4947` (story-012 — InPlaceMigrator introduced)
- **In-scope (changed) code:** `src/InPlaceMigrator.sol`, `src/interfaces/IStableStaker.sol`
- **Mode:** regression (story-013 only — the sole changed feature in range)
- **storiesChecked:** `["story-013"]`
- **Scan timestamp:** 2026-06-15

---

## 1. Story-013 — intent and source

**Source of truth (priority 1):** git commit `d95f4a6` message:

> `[story-013] Add surplus-funded re-injection top-up (M-01 haircut fix)`
>
> "migrateIn now restores re-injected stakers to par by drawing a per-user top-up from the migrator's
> surplus balance (balanceOf - totalParked), grossed up to survive its own haircut. Whole batch
> reverts if surplus is insufficient. No StableStaker.sol changes; implicit surplus model only."

**The defect it targets (ledger `970d7307…`, Medium, status `open`):** *"In-place migration
re-injection silently underpays stakers when the new yield strategy haircuts deposits"* — i.e. the
run-12 `ss12m1` re-injection haircut. At story-012, `migrateIn` credited a re-injected user only
`credited = strategy.deposit(amt) < amt` when the freshly-wired strategy haircuts deposits, so the
user landed below their parked principal (the M-07 haircut vector reborn on the migrateIn leg).

### Extracted acceptance criteria (checkable claims)

| # | Criterion (quoted intent) | Source |
|---|---|---|
| AC1 | After `migrateIn`, a re-injected staker is "restored to par" — credited principal == parked `amt` (within the stated tolerance). | commit body |
| AC2 | The top-up is "a per-user top-up from the migrator's surplus balance (`balanceOf - totalParked`)" — surplus-funded, not principal-cannibalising. | commit body |
| AC3 | The top-up is "grossed up to survive its own haircut" (so the second deposit's own haircut still nets the shortfall). | commit body |
| AC4 | "Whole batch reverts if surplus is insufficient." | commit body |
| AC5 | "No StableStaker.sol changes; implicit surplus model only." | commit body |

---

## 2. Conformance check (Law 2)

Traced against `_reinjectWithTopup` (`InPlaceMigrator.sol:262-294`) and `migrateIn`
(`:202-251`), confirmed against StableStaker `depositFor` (`:616-639`) / `_routeDeposit`
(`:757-763`).

| AC | Verdict | Evidence |
|---|---|---|
| AC1 | **CONFORMS** | Snapshots `amountBefore`/`amountAfter` from `staker.userInfo`, computes `credited = amountAfter - amountBefore`, and when `credited < amt` deposits a top-up. Post-condition `require(finalCredited >= amt - amt/1000)` (`:292`) enforces par within 0.1%. `info.amount` is the user's own credited principal (`StableStaker.sol:633`), so the credit truly lands on the migrated-in user. |
| AC2 | **CONFORMS** | Budget gate `require(topup <= balanceOf(this) - totalParked[token])` (`:280-283`). `totalParked` was already decremented by `amt` in `migrateIn`'s CEI block (`:240`) *before* the helper runs (ordering verified `:237-247`), so the denominator correctly reflects this user's exit. Surplus = `balance − totalParked` is the exact `rescueERC20` sweepable quantity (`:338`) — unearmarked donated/pre-funded value, not any user's parked principal. |
| AC3 | **CONFORMS** | `topup = Math.mulDiv(amt - credited, amt, credited)` (`:276`) — gross-up by the `amt/credited` ratio, `mulDiv` rounds DOWN (never over-credits). Avoids `(amt-credited)*amt` intermediate overflow. |
| AC4 | **CONFORMS** | The surplus `require` (`:280`) and the par-not-restored `require` (`:292`) both revert; `migrateIn` is atomic (no partial state commit across the slice for the reverting tx), so an under-funded batch reverts whole. |
| AC5 | **CONFORMS** | Diff touches only `InPlaceMigrator.sol` + `IStableStaker.sol`. The new `userInfo` interface entry is an interface-only auto-getter declaration matching the pre-existing public `userInfo` mapping (`StableStaker.sol:78`) — no StableStaker bytecode change. "Implicit surplus model" (no new escrow/earmark state) holds: 0 new storage variables. |

**Faithfulness result: no Law-2 deviation. The implementation does what story-013 says.** ss12m1
(`970d7307…`) is **proposed FIXED** — re-injected users are no longer silently under-credited; they
are restored to par from surplus or the batch reverts (loss → revert).

One narrow correctness note, not a deviation (the linear-gross-up only restores *approximate* par
on a convex AMM curve) is an **econ/interaction** concern (LOCAL-003 in the profile, M-07 lineage),
not a faithfulness gap — the story explicitly scopes its guarantee to "par … grossed up to survive
its own haircut" and bounds the residual with the `amt/1000` revert backstop. It is faithful to the
stated intent; whether the linear model holds against real slippage belongs to econ-scanner.

---

## 3. Law-1 override — is the story's OWN intent safe?

Independently asked: *if the code did exactly what story-013 says, would that be exploitable or break
an invariant?* Examined each hazard the brief raised.

### 3a. Does sourcing the top-up from "surplus" cannibalise value that belongs to someone else?

**No.** The surplus is `balanceOf(this) − totalParked[token]`. Every parked user's principal is
fenced beneath `totalParked` (invariant (G), `:338`); `rescueERC20` already treats only the
above-floor remainder as sweepable. The top-up spends the *same* above-floor remainder. It therefore
**cannot** dip into any other parked user's principal — the per-user `require` re-reads live balance
each iteration, and because each principal `depositFor` pulls `amt` matched by an equal `totalParked`
decrement, only top-ups (which have no matching decrement) consume the surplus. The surplus is
unearmarked, operator-pre-funded / donated value with **no other on-chain owner** inside this
migrator. Spending it to make migrated users whole is exactly its intended use. **Safe.**

### 3b. Could the top-up OVER-credit a user beyond true principal (mint value other users paid in)?

**No.** Target is `finalCredited == amt` (the user's own parked principal). `mulDiv` rounds DOWN, so
the top-up is if anything a few wei short of exact par — the post-check `finalCredited >= amt -
amt/1000` only ever *forgives a shortfall*, it never permits an overage. There is no path that
credits more than `amt`. Even on a convex curve, the realistic failure mode is *under*-restore →
revert, not over-pay (profile LOCAL-003). The credit lands on the same user via the immutable,
pinned `staker` (invariant (D)) — it cannot be redirected. **Safe / no value minting.**

### 3c. Does "par within 0.1%" conflict with KI#5 (exits forward ACTUAL, principal decremented by REQUESTED)?

**No conflict — they operate on opposite legs and are mutually consistent.** KI#5 governs *exits*
(`_routeExit`): the user is paid the actual balance-delta while internal principal is debited by the
requested amount, sub-amount difference staying protocol-owned. Story-013 governs *re-deposit*
crediting: `info.amount` is incremented by `credited` (the actual strategy return,
`StableStaker.sol:633`), and the top-up tops that credit up toward `amt`. The 0.1% tolerance lives
purely on the deposit/credit side and never widens an exit payout. The "yield stays protocol-owned /
sub-amount differences remain protocol-owned" rule (KI#4/#5) is preserved: the top-up is funded from
the migrator's *own* surplus, not from another staker's principal or from minted phUSD, and any
mulDiv rounding residual is left in the migrator (protocol-owned), consistent with KI#5's rounding
philosophy. **No conflict.**

### 3d. Footgun triage (Law 3)

The story's intent introduces an **operational precondition that is not contract-enforced**: the
operator must pre-fund surplus ≥ aggregate grossed-up batch haircut, *and* must not `rescueERC20` the
surplus mid-migration, *and* (for multi-slice paginated `migrateIn`) must size surplus against the
*remaining* haircut, since earlier slices greedily consume it with no global reservation. Under-funding
silently turns `migrateIn` into a revert (parked users stranded until refunded or `claimTimedOut`
opens). A competent, non-malicious operator could be **surprised** by this → these are **non-obvious
owner footguns**, in scope as operational hazards (profile LOCAL-001/002/004). They are **availability**
hazards (atomic revert + `claimTimedOut` backstop ⇒ no fund loss), not security escalations, and they
already have ledger homes routed to econ/severity. **They do not make the story's intent *unsafe* in
the Law-1 sense** — no exploit, no invariant break, no value leak; just a DoS-flavoured config trap.

### Law-1 verdict

**The story's intended behaviour is SAFE.** Surplus-funding does not cannibalise any owner's value;
the gross-up cannot over-credit; the 0.1% tolerance does not conflict with KI#5; the immutable target
and `totalParked` floor are untouched. **No `story-unsafe` / `securityEscalation` finding.** The only
residue is non-obvious owner footguns (availability) already covered downstream.

---

## 4. Cross-check with prior stories (010 / 011 / 012)

- **story-010** (empty-pool-only `setYieldStrategy` gate): unaffected. story-013 adds no strategy
  (un)wiring and does not touch the gate. **No contradiction.**
- **story-011** (`depositFor` zero-credit guard, `require(credited > 0)`): **relied upon, not
  undermined.** The helper's comment (`:270`) banks on `depositFor` reverting on zero credit so
  `credited > 0` and the `amt - credited` / `mulDiv` divisor `credited` are safe. story-013 is
  *consistent with and dependent on* story-011. **No contradiction.**
- **story-012** (InPlaceMigrator introduced): story-013 is the **completion** of the migrateIn leg,
  not a regression. The run-12 conclusion was that the empty-pool gate "does not close the migrateIn
  door" — story-013 is indeed the real fix for the *under-credit* of that door: it closes the silent
  under-payment (ss12m1) by restoring par or reverting. It does **not** introduce a new
  redirect/over-credit door (target still immutable, `totalParked` floor intact, no new external
  entry point — helper is `private`, only reachable via `onlyOwner migrateIn`).
  - **Caveat (does it FULLY close, or NARROW?):** story-013 closes the *silent-loss* failure mode
    completely (user is made whole or the batch reverts). It does **not** make the migration
    unconditionally succeed: it converts "silent haircut loss" into "revert unless surplus is
    pre-funded and the linear-haircut model holds." So from the *user-loss* lens it fully closes
    ss12m1; from the *availability* lens it shifts the residual to the surplus-funding /
    convex-slippage footguns (LOCAL-001/002/003 — econ-scanner territory, M-07 lineage). That shift
    is faithful to the story ("whole batch reverts if surplus is insufficient" is stated intent).

---

## 5. Findings summary

**No Law-2 faithfulness findings (F-XX): none.** story-013 conforms to all five acceptance criteria.

**No Law-1 story-unsafe escalation: the story's intent is safe.**

Recommended ledger action (out of this agent's lane, noted for routing):
- ss12m1 (`970d7307…`, Medium, `open`) → **propose FIXED** by story-013 (faithfulness verified;
  completeness of the *fix* under convex slippage is the econ-scanner's LOCAL-003 call, not a
  faithfulness gap).
