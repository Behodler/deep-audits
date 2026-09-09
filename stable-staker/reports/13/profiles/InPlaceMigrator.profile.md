# Contract Profile: InPlaceMigrator.sol

- **Contract:** `src/InPlaceMigrator.sol`
- **Project:** stable-staker
- **Submodule HEAD:** `d95f4a6` (story-013 "Add surplus-funded re-injection top-up (M-01 haircut fix)")
- **Diff baseline:** `ffa4947` (story-012, InPlaceMigrator introduced) → `d95f4a6`
- **Profile timestamp:** 2026-06-15T04:59:03Z
- **Solidity version:** `^0.8.20` (project compiles at `solc 0.8.28`)
- **Scope note:** Local analysis of InPlaceMigrator only. StableStaker / StableStakerMigrator / IStableStaker treated as trust boundaries (interfaces noted, not analyzed). Cross-contract exploitability deferred to interaction analysis.

---

## 0. Story-013 change surface (what moved between ffa4947 and d95f4a6)

The diff is confined to `InPlaceMigrator.sol` and `interfaces/IStableStaker.sol`. **StableStaker.sol is unchanged** (confirmed: the new `userInfo` interface entry is an interface-only auto-getter declaration matching the pre-existing public mapping at `StableStaker.sol:78`).

Concrete changes:
1. New import: `@openzeppelin/contracts/utils/math/Math.sol` (for `Math.mulDiv`).
2. New event `ReinjectedWithTopup(token, user, parked, credited, topup, finalCredited)`.
3. `migrateIn`'s approval step (E) changed: previously `forceApprove(staker, total)` (exact slice principal); **now `forceApprove(staker, balanceOf(this))`** — the migrator's full token balance, so the same scoped approval covers both the principal `depositFor`s and the additional surplus-funded top-up `depositFor`s.
4. `migrateIn`'s loop body now calls a new private helper `_reinjectWithTopup(token, user, amt)` instead of inlining `staker.depositFor(token, user, amt)`.
5. New private helper `_reinjectWithTopup` (the entire M-01 fix logic).
6. `IStableStaker.userInfo(token,user) -> (uint256 amount, uint256 rewardDebt)` added so the migrator can snapshot credited principal around each `depositFor`.

---

## 1. The migrateIn flow and the run-12 `ss12m1` re-injection haircut

### Where the haircut originates (unchanged mechanism)
`migrateIn` re-injects parked principal via `staker.depositFor(token, user, amt)`. Inside StableStaker (`StableStaker.sol:616-638`):
```
received = _pullToken(token, msg.sender, amt)   // pulls amt from migrator
credited = _routeDeposit(token, received)        // strategy.deposit(...) for market strategy
require(credited > 0, "StableStaker: nothing credited")
info.amount   += credited                         // user credited `credited`, NOT `amt`
pool.totalStaked += credited
```
`_routeDeposit` (`StableStaker.sol:757-763`): if a yield strategy is set, returns `strategy.deposit(...)`, which **for a market/AMM-backed strategy returns `credited < amt`** (deposit-side AMM slippage / NAV haircut). For an idle (no-strategy) or direct strategy it returns exactly `amt`.

### ss12m1 (run-12 Medium) restated
At story-012, `migrateIn` credited the user only `credited`. If the *newly-wired* strategy (the whole point of the in-place migration is to swap the strategy) is a market strategy with a deposit haircut, the re-injected user landed below their parked principal — the **M-07 haircut vector reborn on the migrateIn leg**. A user who parked `amt` got credited `amt - slippage`. This is the gap story-013 closes.

---

## 2. Story-013 mechanism: surplus-funded re-injection top-up

The new private helper `_reinjectWithTopup(token, user, amt)` (`InPlaceMigrator.sol:262-294`):

```
(amountBefore,)  = staker.userInfo(token, user)        // snapshot pre-deposit credited principal
staker.depositFor(token, user, amt)                    // principal leg, pulls `amt` from balance
(amountAfter,)   = staker.userInfo(token, user)
credited = amountAfter - amountBefore                  // what the haircut actually credited (>0)

if (credited < amt) {
    topup = Math.mulDiv(amt - credited, amt, credited) // gross-up (see below)
    require(topup <= balanceOf(this) - totalParked[token],
            "InPlaceMigrator: top-up surplus exhausted")
    staker.depositFor(token, user, topup)              // top-up leg, pulls `topup` from surplus
}

(finalAmount,) = staker.userInfo(token, user)
finalCredited  = finalAmount - amountBefore
require(finalCredited >= amt - amt / 1000, "InPlaceMigrator: par not restored")
emit ReinjectedWithTopup(token, user, amt, credited, topup, finalCredited)
```

### Where the surplus comes from
The "surplus" is **migrator token balance held above `totalParked[token]`** — i.e. tokens donated/pre-funded into the migrator that are NOT earmarked as any user's parked principal. This is the same `balance - totalParked` quantity that `rescueERC20` (G) treats as sweepable surplus (`InPlaceMigrator.sol:338`). Story-013 repurposes that surplus as the funding source for top-ups. **The operator must pre-fund the migrator with enough surplus token to cover the aggregate batch haircut before calling `migrateIn`.** Nothing in the contract creates or guarantees this surplus; it is an operational precondition.

### What tops up
The second `staker.depositFor(token, user, topup)` call inside the helper. It pulls `topup` additional tokens from the migrator's balance (the surplus), credits the user a second time, stacking on top of the principal leg's credit.

### The gross-up
The top-up itself goes through `depositFor` → the same `_routeDeposit` haircut. To deliver an *effective* `amt - credited` of additional credit, the helper grosses up the nominal top-up so that after its own haircut it nets the shortfall:
```
topup = (amt - credited) * amt / credited     // Math.mulDiv, rounds DOWN
```
The model assumes the **deposit haircut ratio is locally linear** — i.e. depositing `topup` credits `topup * credited/amt`. Under that assumption the second credit ≈ `(amt-credited)`, restoring the user to `amt`. `Math.mulDiv` is used to avoid intermediate overflow on `(amt-credited) * amt`.

### Pre/post conditions and assumed invariants
- **Pre (ordering, enforced by caller):** `_reinjectWithTopup` MUST be called only after `migrateIn`'s CEI effects block has zeroed `parked`/`migrationBegin`, decremented `totalParked[token]` by `amt`, and removed the user from the set. The surplus check `balanceOf - totalParked[token]` relies on `totalParked` already excluding this user. The `migrateIn` loop (`InPlaceMigrator.sol:237-247`) does exactly this before the helper call — verified.
- **Budget invariant assumed:** cumulative top-ups across the whole batch ≤ surplus = `balance - totalParked`. Each principal `depositFor` pulls `amt` and is matched by an equal `totalParked` decrement; each top-up pulls extra with NO matching decrement, so top-ups are the only consumer of surplus. The per-user `require` re-reads live balance each iteration, so it is a running check, not a one-shot batch check.
- **Post:** `finalCredited >= amt - amt/1000` (par restored within 0.1%), else the whole batch reverts.
- **Sufficiency invariant assumed (NOT enforced):** the surplus is large enough to cover every user's grossed-up top-up. If not, the per-user `require` reverts and the entire `migrateIn` batch reverts (atomic — no partial re-injection).

---

## 3. Verified local properties

### verifiedProperties
| Property | Status | Notes |
|---|---|---|
| `noUnboundedLoops` | likely | `migrateIn` loops over a caller-bounded `[start,end)` slice; operator controls batch size. No new loop in story-013 (helper is per-user, called once per iteration). |
| `checkedArithmetic` | verified | `^0.8.20` checked math; `Math.mulDiv` for the one overflow-prone product. `amt - credited` guarded by `credited < amt`; `amountAfter - amountBefore` cannot underflow (`depositFor` only increments `info.amount`). |
| `reentrancyGuarded` | verified | `migrateIn` is `nonReentrant`; helper is `private`, inherits the guard. `claimTimedOut`, `migrateOut` also `nonReentrant`. |
| `accessControlled` | verified | `migrateIn` is `onlyOwner`. The new top-up path is reachable ONLY through `migrateIn` (helper is `private`) → no new externally-reachable entry point, no new access surface. |
| `initializerProtected` | n/a | Not upgradeable; `immutable staker`, constructor-set. |

### State variables touched by story-013
- **Read:** `totalParked[token]` (in the surplus `require`), `staker` (immutable). No NEW state variables added.
- **Written:** none new in the helper. `migrateIn`'s effects block (unchanged ownership) writes `parked`, `migrationBegin`, `totalParked`, `_parkedUsers`. The helper itself writes no migrator storage — it only reads and makes external calls.

### Access control on the new top-up path
The top-up is gated behind `migrateIn` (`onlyOwner` + `nonReentrant`). `_reinjectWithTopup` is `private`. **No permissionless path can trigger a top-up.** The funding source (surplus) is whatever the operator pre-funds; the immutable `staker` target (D) is unchanged, so the top-up `depositFor` can only ever credit the original user in the one pinned staker.

### Arithmetic / rounding direction
- `topup = Math.mulDiv(amt - credited, amt, credited)` — `mulDiv` rounds **DOWN**. Rounding down means the top-up is, if anything, a few wei *short* of exact par (favours the protocol/surplus, never over-credits the user). This is consistent with the `amt - amt/1000` tolerance backstop.
- `finalCredited >= amt - amt/1000`: the 0.1% slack absorbs the integer-division residual. The dev comment claims this binds only under a pathological ~100% haircut.
- **No path over-credits the user** beyond `amt` except by the linear-haircut modelling error (see edge cases).

### New external calls / reentrancy surface
New external calls introduced by story-013 (all to the immutable trusted `staker`):
- `staker.userInfo(token, user)` ×2 (view, before/after principal deposit) + ×1 (view, final).
- `staker.depositFor(token, user, topup)` — second deposit, NEW call. Pulls `topup` from migrator balance via the staker's `_pullToken`, routes through the (untrusted, newly-wired) strategy's `deposit`.
- `IERC20(token).balanceOf(this)` — now read in the approval step and in the per-user surplus `require` (token is semi-trusted ERC20).
- The approval changed to `forceApprove(staker, balanceOf(this))` — wider allowance than before, but bounded by CEI + the immutable target. `forceApprove` overwrites, no dangling allowance after the batch (the staker only pulls principal+top-ups, both ≤ balance).

Reentrancy: the second `depositFor` is an external call that reaches the strategy. It occurs AFTER the migrator's own CEI effects for this user are already committed (`parked=0`, set-removed, `totalParked` decremented). `migrateIn` holds `nonReentrant`. The migrator exposes no re-enterable state that the top-up call could corrupt. **Reentrancy *exploitability* via the strategy callback is deferred to interaction analysis** (depends on strategy implementation), but the local CEI ordering is sound.

---

## 4. Edge cases the top-up may NOT cover (flagged for deeper scanning)

### LOCAL-001 — Insufficient / zero surplus reverts the ENTIRE batch (DoS / operational footgun)
If the pre-funded surplus is less than the aggregate grossed-up top-up, the per-user `require(topup <= balanceOf - totalParked)` reverts, and because `migrateIn` is atomic the **whole slice fails** — no user in the slice is re-injected. With zero surplus and any market-strategy haircut, `migrateIn` reverts on the FIRST haircut user. Parked users are then stuck until the operator pre-funds surplus and retries (or until `claimTimedOut` opens). This is a **non-obvious owner footgun** (Law 3): a competent operator could call `migrateIn` expecting it to work and be surprised it reverts because they didn't pre-stage surplus. Severity-classifier / story-faithfulness should weigh whether story-013 documents this funding precondition. **Local severity: medium.** Flag for econ/interaction scan: does the runbook guarantee surplus pre-funding?

### LOCAL-002 — Surplus drain / ordering effects across a batch (first-come-first-served)
The surplus budget is shared across all users in the batch and re-checked against *live* balance each iteration. Top-ups consume surplus as the loop proceeds. If surplus is enough for the *first* k users but not the (k+1)th, the batch reverts at user k+1 — so ordering determines *which* user trips the revert, but because the batch is atomic the practical outcome is all-or-nothing (no user is left partially paid within a successful tx). However: **across SEPARATE `migrateIn` calls** (operator paginates), an earlier slice can legitimately consume surplus and succeed, leaving a later slice underfunded and reverting. There is no global reservation of surplus against the *remaining* parked haircut — only the running `balance - totalParked` check. Flag for interaction/econ scan: multi-slice migrations can strand later slices if surplus is sized for the aggregate but consumed greedily by earlier slices. Ordering across calls matters.

### LOCAL-003 — Top-up restores APPROXIMATE par, not EXACT (linear-haircut assumption)
The gross-up `topup = shortfall * amt / credited` assumes the deposit haircut is **locally linear** (the same proportional ratio applies to the top-up deposit as to the principal deposit). For an AMM/market strategy, slippage is **convex / depth-dependent**: depositing an additional `topup` may incur a *different* (and for a thin pool, *larger*) marginal haircut than the principal deposit did. Consequences to scan:
  - If the top-up's actual haircut is worse than modelled, `finalCredited` may fall short of `amt - amt/1000` and the `require(finalCredited >= ...)` reverts → batch DoS (ties into LOCAL-001).
  - The 0.1% (`amt/1000`) tolerance is the only forgiveness; a real AMM marginal-slippage gap can exceed 0.1% on a shallow pool, turning "restore par" into "revert". This is the M-07-style "guard is NAV/ratio-based, bypassed by AMM execution slippage" lineage (see memory: ss9m7 / M-07). Flag for econ-scanner with a real market-strategy slippage curve.
  - Conversely, a *single* re-deposit grossed up by the ratio could in principle **over-deposit** relative to a convex curve, but rounding-down on `mulDiv` and the strategy keeping sub-amount differences as protocol-owned yield bound user over-credit; the realistic failure mode is *under*-restore → revert, not over-pay.

### LOCAL-004 — Top-up surplus is unprotected donated value; griefing / accounting interplay with rescueERC20
The surplus the top-up spends is the same `balance - totalParked` that `rescueERC20` (G) can sweep. There is no lock/escrow earmarking surplus for in-flight migrations. Sequencing note for interaction scan: an owner who sweeps surplus via `rescueERC20` between `migrateOut` and `migrateIn` removes the top-up budget and bricks par-restoration (owner footgun, not a malicious-owner finding). Also: anyone can *donate* token to inflate surplus (benign), but donation does not enter `totalParked`, so the `finalCredited` invariant and the surplus check both behave correctly under donation. No local violation; flagged only as an operational-coupling note.

### LOCAL-005 — `userInfo.amount` snapshot semantics under settle
The helper computes `credited` and `finalCredited` as deltas of `userInfo[token][user].amount` across `depositFor`. `depositFor` calls `_settle` and `_updatePool` but those touch `rewardDebt`/`accPhusdPerShare`, not `info.amount`; `info.amount` is incremented only by `credited` (`StableStaker.sol:633`). So the delta is exactly the credited principal — **assumption holds locally**. Edge: if the same `user` appeared twice in one slice (deduped by EnumerableSet, so not possible) the snapshot would still be correct. No finding; recorded as a verified assumption for downstream agents to treat as axiom.

---

## interfaceAbstraction

### externalEntryPoints (story-013-relevant)
- `migrateIn(address token, uint256 start, uint256 end)` — `external onlyOwner nonReentrant`. State changed: `parked`, `migrationBegin`, `totalParked`, `_parkedUsers`. External calls: `token.balanceOf`, `token.forceApprove`, and per user `staker.userInfo`×3, `staker.depositFor`×(1 or 2). Reentrancy guard: yes. New in story-013: full-balance approval + top-up second deposit per haircut user.
- Unchanged entry points (context): `migrateOut` (onlyOwner, nonReentrant), `claimTimedOut` (permissionless, self-scoped, nonReentrant), `rescueERC20` (onlyOwner, surplus-fenced), `initiateMigration` (onlyOwner forwarder), views.

### externalCalls / trust boundaries
- `IStableStaker staker` (immutable) — **trusted** (pinned at construction, cannot be redirected). Methods now include `userInfo` (view) and a second `depositFor`. The `depositFor` reaches the per-token strategy internally.
- per-token `IYieldStrategy` (reached transitively through `staker.depositFor` → `_routeDeposit` → `strategy.deposit`) — **untrusted / semi-trusted**: this is the newly-wired strategy whose deposit haircut is the entire reason for the top-up. Its slippage curve is the central unknown for downstream analysis (LOCAL-003).
- `IERC20 token` — **semi-trusted** standard ERC20; fee-on-transfer/weird tokens out of scope per project KI. Note: a fee-on-transfer token would itself create a haircut indistinguishable from strategy slippage, but is project-OOS.

### new state read in helper
`totalParked[token]` (surplus denominator). No new storage variables.

### events
`ReinjectedWithTopup` (new), plus existing `MigratedIn`, `MigratedOut`, `TimedOutClaim`.

### modifiers
`onlyOwner`, `nonReentrant` (helper inherits via private call from `migrateIn`).

---

## trustAssumptions
1. Operator pre-funds the migrator with surplus token (`balance - totalParked`) sufficient to cover the aggregate grossed-up haircut of every batch BEFORE calling `migrateIn`. Not contract-enforced; insufficient surplus reverts the batch (LOCAL-001).
2. The newly-wired strategy's deposit haircut is locally linear so the ratio gross-up restores par within 0.1% (LOCAL-003). Convex/depth-dependent AMM slippage can break this → batch revert.
3. `staker` is the immutable, honest StableStaker; `userInfo` is its faithful auto-getter and `depositFor` only increments `info.amount` by the credited principal (verified against StableStaker.sol:633, unchanged).
4. Owner does not sweep migration surplus via `rescueERC20` mid-migration (LOCAL-004 operational coupling).
5. token is a standard ERC20 (no fee-on-transfer / no hooks) — project KI.

## inheritanceChain
`Ownable`, `ReentrancyGuard` (OZ v5.6.1).

## complexity (story-013 delta)
- New private function: 1 (`_reinjectWithTopup`, ~33 lines).
- New event: 1. New import: 1 (`Math`).
- New external calls per haircut user: up to 4 (3× `userInfo` view, 1× extra `depositFor`).
- New state variables: 0. New externally-reachable entry points: 0.

---

## Downstream routing recommendations
- **econ-scanner / interaction:** LOCAL-003 (convex AMM slippage breaks the linear gross-up → revert or under-restore) and LOCAL-002 (multi-slice surplus drain ordering) need a real market-strategy slippage model. This is the M-07 lineage (ratio guard vs execution slippage) — cross-reference ss9m7. Note: ss12m1 (the run-12 Medium this story fixes) should be re-checked as proposed-fixed, but the fix's *completeness* hinges on LOCAL-003.
- **story-faithfulness:** does story-013 state the surplus pre-funding precondition (LOCAL-001) and acknowledge approximate-par/revert semantics? A faithful-but-footgun implementation (silent revert on under-funding) is in scope as an operational hazard.
- **severity-classifier:** LOCAL-001/003 are availability/DoS-flavoured (Medium ceiling) and footgun-flavoured; not direct fund loss because the batch is atomic and `claimTimedOut` remains the backstop. The user is never *under-credited silently* anymore (that was ss12m1) — the new failure mode is *revert*, not *loss*.
