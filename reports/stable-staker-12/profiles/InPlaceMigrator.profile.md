# Contract Profile: InPlaceMigrator.sol

- **Contract:** `src/InPlaceMigrator.sol` (stable-staker)
- **Submodule HEAD:** `ffa4947` — `[story-012] Add InPlaceMigrator: in-place single-staker yield-strategy swap`
- **Solidity:** `^0.8.20` (project pins `solc = 0.8.28`)
- **LOC:** ~316 (new contract, +316)
- **Inheritance:** `Ownable`, `ReentrancyGuard` (OZ v5.6.1)
- **Profile type:** local-only (single contract). Cross-contract risks surfaced as trust boundaries / ranked surfaces for interaction scanners.

---

## 1. Purpose & High-Level Flow

`InPlaceMigrator` swaps a single live `StableStaker`'s per-token `IYieldStrategy` **in place** —
source and target are the *same* staker — without standing up a throwaway temp staker (the role
`StableStakerMigrator` plays for the cross-staker case).

It exists *because* of the story-010 empty-pool gate: `StableStaker.setYieldStrategy` reverts unless
`poolInfo[token].totalStaked == 0`. There is no hot-swap path. To re-strategize a live pool the
operator must drain every staker, reset the pool, wire the new strategy, then put everyone back.
This migrator does the drain/park/re-inject around the operator's reset+rewire.

**Operator-orchestrated sequence (per token):**
1. `migrator.initiateMigration(token)` → `staker.initiateMigration(token)` (terminal snapshot `(R,P)`, freezes emissions, realizes + decouples old strategy, `poolState → Migrating`).
2. `migrator.migrateOut(token, users[])` → `staker.batchMigrate(...)`; staker mints each user's frozen phUSD and `safeTransfer`s the aggregate snapshot credit to the migrator, which **parks** it per-user.
3. **Operator (directly on staker, NOT via migrator):** `staker.finalizeAndReset(token)` (pool now empty → `Active`), then `staker.setYieldStrategy(token, newStrategy)` (passes empty-pool gate; sweeps idle = 0).
4. `migrator.migrateIn(token, start, end)` → `staker.depositFor(token, user, parkedAmt)` for each parked user, re-crediting them on the **same** staker now routed through the new strategy.

**Escape hatch:** `claimTimedOut(token)` — permissionless, self-scoped; a parked user reclaims their
own principal once `migrationTimeout` has elapsed since their `migrateOut`. Principal only (phUSD was
already minted at `migrateOut`).

**Custody concession (by design):** between `migrateOut` and `migrateIn` the migrator physically holds
raw principal for every parked user. Window intended to be short (minutes–hours), single operator session.

---

## 2. Public / External Function Inventory

| Function | Visibility | Access | State mutated | External calls |
|---|---|---|---|---|
| `constructor(_staker, _migrationTimeout, initialOwner)` | — | — | `staker` (immutable), `migrationTimeout` (immutable) | none. Guards: non-zero staker; `MIN_TIMEOUT(1d) ≤ timeout ≤ MAX_TIMEOUT(30d)` |
| `initiateMigration(token)` | external | `onlyOwner` | none (forwarder) | `staker.initiateMigration(token)` |
| `migrateOut(token, users[])` | external | `onlyOwner` `nonReentrant` | `parked`, `migrationBegin`, `_parkedUsers`, `totalParked` | `staker.batchMigrate(token, users)` (staker mints phUSD + safeTransfers aggregate IN) |
| `migrateIn(token, start, end)` | external | `onlyOwner` `nonReentrant` | zeroes `parked`, `migrationBegin`, `totalParked`, removes from `_parkedUsers` | `IERC20(token).forceApprove(staker, sliceTotal)`; `staker.depositFor(token, user, amt)` per user |
| `claimTimedOut(token)` | external | **permissionless**, self-scoped `nonReentrant` | zeroes caller's `parked`, `migrationBegin`, `totalParked`, set removal | `IERC20(token).safeTransfer(msg.sender, amount)` |
| `rescueERC20(token, to, amount)` | external | `onlyOwner` | none | `IERC20.balanceOf`; `safeTransfer(to, amount)`; fenced below `totalParked` floor |
| `parkedUserCount(token)` | external view | — | — | — |
| `parkedUsersRange(token, start, end)` | external view | — | — | — |
| `claimableAt(token, user)` | external view | — | — | — |

Note: `migrateIn` and `claimTimedOut` carry `nonReentrant`; `rescueERC20` does **not** (owner-only, single transfer, fenced by floor — acceptable).

---

## 3. State Variables & Locally-Verifiable Invariants

State:
- `IStableStaker public immutable staker` — pinned at construction (deliberate anti-drain measure; no owner-supplied re-injection target).
- `uint256 public immutable migrationTimeout` — bounded `[1d, 30d]`.
- `mapping(token => user => uint256) public parked` — per-user custody balance.
- `mapping(token => user => uint256) public migrationBegin` — timeout anchor (set to `block.timestamp` at out).
- `mapping(token => EnumerableSet.AddressSet) private _parkedUsers` — worklist.
- `mapping(token => uint256) public totalParked` — Σ parked per token; the rescue floor.
- Constants `MIN_TIMEOUT = 1 days`, `MAX_TIMEOUT = 30 days`.

**Locally verified invariants (confidence: verified unless noted):**
- **INV-1 (accounting sum):** `totalParked[token] == Σ_u parked[token][u]`. Every mutation moves both in lockstep (`migrateOut` +=, `migrateIn`/`claimTimedOut` -=). *verified.*
- **INV-2 (set membership ↔ parked>0):** a user is in `_parkedUsers[token]` iff `parked[token][u] > 0`. `migrateOut` adds only when `amt>0`; both exits remove on zeroing. *verified* (one nuance: `migrateOut` re-run for an already-parked user re-`add`s — set is idempotent, so no corruption; `parked` accumulates via `+=` which is correct since `batchMigrate` returns 0 for an already-exited position, so re-run adds 0).
- **INV-3 (rescue cannot touch principal):** `rescueERC20` computes `surplus = balanceOf(this) - totalParked[token]` and requires `amount ≤ surplus`. While `balanceOf ≥ totalParked` holds, principal is fenced. *verified locally*; see SURFACE-3 for the cross-contract assumption that backs `balanceOf ≥ totalParked`.
- **INV-4 (timeout bounds):** constructor enforces `1d ≤ timeout ≤ 30d`. *verified.*
- **INV-5 (CEI on both exits):** `migrateIn` and `claimTimedOut` zero state before the external token/`depositFor` call, under `nonReentrant`. Reentrancy double-claim test (`test_claimTimedOut_reentrancyGuarded`) confirms single payout. *verified.*
- **INV-6 (no double-pay across paths):** a user who `claimTimedOut`s is removed from the set and `parked==0`; a later `migrateIn` over the whole set skips them (`amt==0 → continue`). *verified* (`test_noDoubleSpend_...`).

**Computational properties:**
- `migrateOut` / `migrateIn` loop over a caller-supplied `users[]` / `[start,end)` slice → **bounded by the operator's own batch size** (owner-only). Not an attacker-controlled DoS vector. `noUnboundedLoops`: effectively true (operator-paginated).
- Checked arithmetic throughout (0.8.x); no `unchecked`, no assembly.

---

## 4. Interaction Map (ordering matters)

Calls into `StableStaker` (all on the single immutable `staker`):

```
initiateMigration(token)         -> staker.initiateMigration(token)      [onlyMigrator on staker]
migrateOut(token, users)         -> staker.batchMigrate(token, users)    [onlyMigrator]  (RECEIVES principal)
   ... operator OUT-OF-BAND:        staker.finalizeAndReset(token)        [onlyOwner on staker]
   ... operator OUT-OF-BAND:        staker.setYieldStrategy(token, NEW)   [onlyOwner, empty-pool gate]
migrateIn(token, start, end)     -> token.forceApprove(staker, sliceTot)
                                 -> staker.depositFor(token, user, amt)   [onlyMigrator]  (PAYS principal)
claimTimedOut(token)             -> token.safeTransfer(user, amount)
```

**Required pre-wiring:** the migrator MUST be set as `staker.setMigrator(migrator)` (else
`initiateMigration`/`batchMigrate`/`depositFor` revert `onlyMigrator`). The new strategy MUST have
authorized the staker as a client (`newStrategy.setClient(staker, true)`) before `setYieldStrategy`,
else later deposits revert.

**Ordering hazards for scanners:**
- `migrateIn` MUST come after `finalizeAndReset` + `setYieldStrategy` — `depositFor` requires
  `poolState == Active`, so calling `migrateIn` before `finalizeAndReset` reverts (safe-fail).
- `setYieldStrategy` on the **same** staker is reached while the pool is `Active` and empty (post-reset).
  The empty-pool gate is satisfied *because* the migrator drained everyone — this is the design the
  gate was built to force. **Central question for econ/story scanners:** does re-injection through the
  NEW strategy reintroduce the haircut/slippage the gate prevents? See SURFACE-1.

---

## 5. Trust / Authorization Boundaries

- **Owner = operator.** `initiateMigration`, `migrateOut`, `migrateIn`, `rescueERC20` are `onlyOwner`.
  `finalizeAndReset` + `setYieldStrategy` are `onlyOwner` on the staker (same operator expected).
- **Operates WITH staked users present** — this is the whole point. It does NOT assume an empty pool;
  it *creates* the empty pool (by parking everyone) so the staker's empty-pool gate can be satisfied,
  then refills. This is the inverse of the prior collapse posture (M-01/M-06/M-07 were collapsed by
  *forbidding* in-place swap; story-012 re-enables it via an orchestrated drain-park-refill).
- **Immutable staker target** (design note (D)): no owner-supplied `depositFor` target — a compromised
  key cannot point re-injection at a malicious sink and strand parked users. Strong, verified locally.
- **No owner exit for parked principal** (design note (C)): the only outflows of parked principal are
  `migrateIn → depositFor(original user)` and `claimTimedOut → user`. `rescueERC20` is fenced below
  `totalParked`. Verified locally (modulo INV-3's balance assumption).
- **Trusted, non-malicious owner (Law 3):** the contract is explicitly built to constrain even a
  *compromised* owner key (immutable target, rescue floor, permissionless timeout hatch). Footgun
  surface is therefore mostly about *unknowing* consequences, not malice — fits the in-scope footgun lens.

---

## 6. Story / Commit Provenance

> `ffa4947 [story-012] Add InPlaceMigrator: in-place single-staker yield-strategy swap`

This is the introducing commit and the only `[story-NNN]` tag for the contract. Directly relevant
lineage (all in the staker, not this contract):
- `[story-010]` (`bbfa140`/`125f585`) — empty-pool gate on `setYieldStrategy` (collapsed M-01/M-06/M-07).
- `[story-009]` (`93b7ce6`) — pool lifecycle enum + `finalizeAndReset` (the reset this migrator drives).
- `[story-008]` (`a7e2f78`) — underwater-swap guard (M-06).
- `[story-011]` (`c3ec65b`) — `depositFor` zero-credit phantom-staker guard (the `require(credited>0)` that re-injection relies on).

Story-faithfulness scanner: verify story-012's *intent* — "safely change a per-token dependency on a
live staker" — is actually safe, i.e. that the drain/park/refill genuinely avoids the desync the
empty-pool gate was created to prevent, rather than relocating it to the re-injection leg.

---

## 7. Ranked Security-Relevant Surfaces (for interaction scanners)

**SURFACE-1 (HIGHEST — share/principal accounting on re-injection): `migrateIn` re-credits less than parked.**
`staker.depositFor(token, user, amt)` internally does `_routeDeposit` → `newStrategy.deposit(token, amt, this)`
and credits the **returned `credited`**, which for a market/AMM strategy can be `< amt` (deposit
haircut / execution slippage). The migrator approved exactly `sliceTotal` and the staker pulls the full
`amt` per user, but the *user's credited principal* may be less than what was parked. This is precisely
the M-07-class "rate-vs-execution slippage" residual the empty-pool gate was meant to eliminate —
**relocated from the swap to the re-injection deposit.** The migrator zeroes `parked[user]` to the full
`amt` regardless of how much got credited, so any haircut is silently socialized away from the user.
For econ-scanner: quantify whether a real Tokemak/ERC4626/AMM strategy haircuts `deposit`, and whether
re-injection therefore underpays users vs. their parked principal. For story-faithfulness: does this
break the "users get principal back" invariant the whole story claims to preserve? (The tests use
`MockYieldStrategy`, which is par-preserving, so this path is **untested against a haircutting strategy**.)

**SURFACE-2 (HIGH — `depositFor` revert-on-zero-credit bricks a batch): story-011 guard interaction.**
`depositFor` has `require(credited > 0, "nothing credited")`. If the new strategy haircuts a small
`amt` to zero credit (dust user, high-slippage strategy), `migrateIn` **reverts for the whole slice**,
not just that user. Operator must then exclude that user from the range — but the user is stuck parked
until `claimTimedOut`. Assess as availability/DoS-of-migration + footgun. Bounded by operator pagination
but a single un-creditable parked user can block any slice that contains it.

**SURFACE-3 (MEDIUM — rescue floor depends on a cross-contract balance assumption).**
INV-3 (`rescueERC20` cannot touch principal) holds only while `balanceOf(this) ≥ totalParked[token]`.
The contract never *transfers principal out* except via the two sanctioned exits, so locally this holds.
But the principal arrives via `batchMigrate`'s `safeTransfer(this, total)` where `total = Σ p_i·min(R,P)/P`.
**If the migration was below par (R < P), the migrator receives only `min(R,P)/P` of each user's
principal, yet `migrateOut` parks `amounts[i]` = that haircut credit, not the original principal.**
Verify: `parked[user]` is set to `amounts[i]` (the realized credit), so `totalParked == ` received `total`
and `balanceOf == total` — INV-3 holds even below par. BUT then `migrateIn` re-credits only the haircut
amount, and the user permanently loses the underwater delta with no signal. Cross-check with story's
claim that in-place swap is for *healthy* strategy changes; if `initiateMigration` is run on an
underwater strategy, the migrator faithfully propagates the socialized loss. Confirm this is intended
(it matches the staker's `min(R,P)/P` socialization) and not a new footgun where an operator runs the
in-place flow on an impaired strategy expecting no loss.

**SURFACE-4 (MEDIUM — timeout hatch vs. operator window race).**
`claimTimedOut` opens at `migrationBegin + migrationTimeout`. If the operator's rewire stalls past the
timeout, parked users can pull principal mid-migration, leaving a partially-refilled pool and a
`migrateIn` that now skips them. Not a loss (user got principal), but a migration-integrity/availability
concern, and an operator footgun if `migrationTimeout` is set near `MIN_TIMEOUT` for a multi-batch job
the docs say it's NOT built for ("not for long-running, multi-day, many-batch migrations"). Interaction
scanner: confirm no value is lost, only migration completeness; flag the multi-batch-with-short-timeout
footgun.

**SURFACE-5 (LOW/MEDIUM — phUSD already minted at `migrateOut`; re-stake double-emission window).**
`batchMigrate` mints frozen pending phUSD to users at `migrateOut`. After `migrateIn` they are staked
fresh on the revived pool and begin accruing again from `lastRewardTime = now` (set by `finalizeAndReset`).
The frozen migration gap is fast-forwarded (no retro-accrual). Verify against the core emission-cap
invariant that no extra phUSD is mintable across the out→reset→in cycle (the empty Migrating window
accrues nothing; looks safe, but confirm the `finalizeAndReset` `lastRewardTime` reset + re-stake can't
be gamed by interleaving stake/withdraw on the revived pool before all users are re-injected).

**SURFACE-6 (LOW — partial re-injection leaves the revived pool open to outside stakers).**
After `finalizeAndReset`, the pool is `Active` and `stake` is permissionless again. Between `setYieldStrategy`
and the final `migrateIn` slice, third parties can `stake`/`withdraw` on the half-refilled pool. No
direct theft (each parked user's `depositFor` credits them their own `amt`), but the operator's
single-session assumption is not enforced on-chain. Footgun-flavored; confirm no accounting interference
with in-flight `migrateIn`.

---

## Verified Properties Summary

```json
{
  "noUnboundedLoops": "operator-paginated (owner-only); not attacker-controlled",
  "checkedArithmetic": true,
  "reentrancyGuarded": ["migrateOut", "migrateIn", "claimTimedOut"],
  "accessControlled": ["initiateMigration", "migrateOut", "migrateIn", "rescueERC20"],
  "permissionlessByDesign": ["claimTimedOut (self-scoped)"],
  "immutableTarget": "staker pinned at construction (anti-drain)",
  "rescueFloor": "totalParked (cannot touch principal, modulo balance assumption)",
  "initializerProtected": "n/a (no upgradeable/init pattern)"
}
```

## Trust Assumptions Passed Downstream
- `staker.batchMigrate` returns and transfers exactly `Σ amounts` and zeroes source positions (treat as axiom; StableStaker-local, verified upstream).
- `staker.depositFor` pulls exactly `amt`, credits `_routeDeposit` return (which **may be < amt** for haircutting strategies — see SURFACE-1).
- The new strategy is wired (`setClient`) and par/above-par at re-injection; tests only cover a par-preserving mock.
- Token is a standard ERC20 (USDT-style allowance and FoT explicitly out of project scope).
- Operator runs out→reset→rewire→in in a single uninterrupted session within `migrationTimeout`.
