# Code Scan (Tier-2, interaction-level) — stable-staker run-12

- **Project:** stable-staker
- **Submodule:** `lib/stable-staker` @ `ffa494783f585bcd2ce1ff60dd756345717287f1`
- **New contract under test:** `src/InPlaceMigrator.sol` (story-012)
- **Cross-contract surfaces read:** `src/StableStaker.sol` (`depositFor`, `_routeDeposit`,
  `_routeExit`, `initiateMigration`, `batchMigrate`, `_exitPosition`, `finalizeAndReset`,
  `setYieldStrategy`, `stake`/`withdraw`, pool-state machine), `src/StableStakerMigrator.sol`
- **Scan type:** interaction-level (Tier-2), profile-first, source-confirmed
- **Timestamp:** 2026-06-15

Trust posture: the profile's `verified` invariants (INV-1..INV-6) were treated as axioms only
where tagged `verified`; the `SURFACE-1`/`SURFACE-3` ("untested against a haircutting strategy",
"open question") items were re-examined against source per SCOPE-RESTRICTION #3. The single
load-bearing cross-contract fact — that `depositFor` credits the `_routeDeposit` **return**, which
a market strategy haircuts below the requested `amount` — is confirmed at source (`StableStaker.sol:631-634`,
`:757-762`, and the strategy's own doc comment at `:753-756`).

---

## CODE-12-01 — Re-injection haircut: `migrateIn` zeroes parked principal by the *requested* amount, not the *credited* amount (per-user principal loss on a market strategy)

- **Verdict:** CONFIRMED (Law-1 value loss; NEEDS-POC for the dollar magnitude on a real strategy → econ-scanner)
- **Type:** cross-contract requested-vs-received accounting skew / principal loss
- **Severity:** potential-high (conditional on the re-injection target being a haircutting market/AMM strategy)
- **Root-cause class:** YIELD-PRINCIPAL-ACCOUNTING-SKEW relocated to the deposit leg
- **Contract / function:** `InPlaceMigrator.migrateIn` → `StableStaker.depositFor` → `_routeDeposit`
- **Location:**
  - `src/InPlaceMigrator.sol:209` (`amt = parked[token][user]`)
  - `src/InPlaceMigrator.sol:215-217` (state zeroed by **requested** `amt`)
  - `src/InPlaceMigrator.sol:223` (`staker.depositFor(token, user, amt)`)
  - `src/StableStaker.sol:630-634` (`received = _pullToken(...)`; `credited = _routeDeposit(token, received)`; `info.amount += credited`)
  - `src/StableStaker.sol:757-762` (`_routeDeposit` returns `strategy.deposit(...)`)
  - `src/StableStaker.sol:753-756` (doc: "the market strategy haircuts this below `amount`; direct strategies return `amount`")

### Mechanism (exact)

1. At `migrateOut`, each user's parked balance is the staker's snapshot credit
   `amt_i = p_i · min(R,P) / P` (`StableStaker._exitPosition`, `:528`), transferred in aggregate to
   the migrator (`batchMigrate`, `:506-508`). So `totalParked == Σ amt_i == balanceOf(migrator)`
   (INV-1 holds — confirmed).
2. At `migrateIn`, the migrator approves the exact slice total (`:203`) and, per user, **zeroes
   `parked[user]` and decrements `totalParked` by the full `amt`** (`:215-217`) BEFORE calling
   `staker.depositFor(token, user, amt)` (`:223`).
3. Inside `depositFor`, the staker pulls the full `amt` out of the migrator
   (`_pullToken`, `:630` → `:740-745`) and routes it into the **freshly-wired new strategy**
   (`_routeDeposit`, `:631` → `:757-762`). For a market/AMM strategy `credited = strategy.deposit(...) < amt`.
4. The user is credited only `credited` (`info.amount += credited`, `:633`); `pool.totalStaked +=
   credited` (`:634`). The shortfall `amt - credited` was pulled from the migrator and deposited
   into the strategy but is **credited to no user** — it becomes protocol-owned surplus inside the
   strategy (consistent with the "sub-amount differences remain protocol-owned" rule, `:769`, except
   here the direction is a **loss to the user**, not protocol surplus skimmed off yield).

### Conservation violation (the exact statement)

Pre-injection: migrator holds `Σ amt_i` and books `totalParked = Σ amt_i`.
Post-injection: migrator holds `0`, `totalParked = 0`, but the sum of user-credited principal in the
staker is `Σ credited_i ≤ Σ amt_i`. The delta `Σ (amt_i − credited_i)` left the user-owned
accounting domain and now sits as protocol-owned surplus in the strategy. The "users get their
principal back" invariant the story claims (header (A), (C), (F)) is **violated by exactly the
deposit haircut** — the same M-07-class rate-vs-execution slippage the empty-pool gate
(`setYieldStrategy` `totalStaked==0`, `StableStaker.sol:228`) was created to keep off live pools, now
reintroduced on the re-injection deposit.

### Who is harmed / preconditions

- **Harmed:** each re-injected user, proportional to their parked principal. The protocol (strategy
  surplus) absorbs the gain. Remaining/other stakers are unaffected (per-user, not socialized across the pool).
- **Preconditions:** the new strategy wired by `setYieldStrategy` between `migrateOut` and `migrateIn`
  is a haircutting market/AMM strategy (e.g. the AMM-execution path of memory M-07), not a
  par-returning direct/ERC4626-1:1 strategy. If only direct strategies are ever wired in place, this
  collapses to informational.
- **No on-chain signal:** the migrator emits `MigratedIn(token, count, total)` with `total` = the
  requested sum (`:226`), not the credited sum — the shortfall is silent.

### Distinguishing Law-1 vs Law-3

This is a **Law-1 value loss**, NOT merely an owner footgun: the loss falls on end users, the
operator may be entirely non-malicious and following the runbook, and there is no on-chain warning.
The *owner-footgun* layer is secondary: an operator who runs in-place migration expecting "no loss"
onto a haircutting target is surprised by the consequence (footgun), but the harm lands on users
regardless of operator intent. Report at honest severity driven by the user loss.

### Test gap

`test/` uses a par-preserving `MockYieldStrategy` (`_routeDeposit` returns `amount`), so this path is
**never exercised against a haircutting strategy**. The story-012 test suite cannot catch it.

### Handoff to econ-scanner

Quantify the per-deposit haircut for the actual intended re-injection strategy (Tokemak autoUSD /
ERC4626 / AMM). If the target is strictly par/above-par at re-injection, severity drops to
Low/informational; if a market strategy can be the target, this is a live per-user principal
shortfall and a High. This is the **highest-priority** item in this scan.

---

## CODE-12-02 — Poison-user reverts the whole `migrateIn` slice (story-011 `require(credited>0)` interaction); ordering safe-fails

- **Verdict:** CONFIRMED (availability / migration-DoS + footgun; principal recoverable via timeout hatch)
- **Type:** batch-revert griefing / un-creditable parked user bricks a slice
- **Severity:** potential-medium (availability of migration; no permanent principal loss)
- **Root-cause class:** non-atomic per-user external call in an all-or-nothing loop
- **Contract / function:** `InPlaceMigrator.migrateIn` → `StableStaker.depositFor`
- **Location:**
  - `src/InPlaceMigrator.sol:207-224` (per-user loop, no try/catch)
  - `src/InPlaceMigrator.sol:223` (`staker.depositFor` call, reverts bubble up)
  - `src/StableStaker.sol:632` (`require(credited > 0, "StableStaker: nothing credited")`)

### Mechanism

`migrateIn` calls `depositFor` once per user in a straight loop (`:207-224`) with no per-call
isolation. `depositFor` carries the story-011 guard `require(credited > 0)` (`:632`). If a single
parked user's `amt` haircuts to **zero credit** on the new strategy (dust position, or a strategy
whose `deposit` rounds a tiny amount to 0), that user's `depositFor` reverts and **the entire slice
reverts** — no user in the slice is re-injected, and `totalParked`/`parked` are rolled back (state
changes within the reverted tx are undone).

The operator must then rebuild the slice to exclude the poison user. Meanwhile the poison user
remains parked. **`claimTimedOut` does rescue that user's principal** (`:239-256`): it is
self-scoped, permissionless, transfers `parked[msg.sender]` after `migrationTimeout`, and is
independent of the new strategy — confirmed it returns the full parked principal, not a re-deposit.
So no permanent loss, but the migration of that slice is blocked until the operator pages around the
user, and the stuck user waits out the timeout.

### Ordering sub-question (PM-12-02 / SURFACE-2 first half): SAFE-FAIL

`depositFor` requires `poolState[token] == Active` (`StableStaker.sol:624`). Between `migrateOut` and
`finalizeAndReset` the pool is `Migrating` (`initiateMigration` sets it, `:462`; `finalizeAndReset`
returns it to `Active`, `:602`). So calling `migrateIn` **too early** (before `finalizeAndReset`)
reverts cleanly with `"StableStaker: pool not active"` for every user — **safe-fail, no state
corruption, no fund movement.** Verdict on the early-call hazard: REFUTED as an exploit; it is a
benign mis-ordering revert. It remains a minor Law-3 footgun (the migrator gives no early
`poolState` pre-check or friendlier revert), but not a vulnerability.

### Who is harmed / preconditions

- **Harmed:** migration availability (operator must re-slice); the poison/dust user waits for the
  timeout hatch. No theft, no permanent loss.
- **Preconditions:** a parked user whose credited amount on the new strategy is 0 (dust + haircut),
  OR any other `depositFor` revert reachable for one user (e.g. a token-side condition). Bounded by
  operator pagination but a single bad entry blocks any slice containing it.

### Severity note

Availability-only; principal always recoverable via `claimTimedOut`. Frame as Medium (migration
function impaired under a realistic dust/haircut condition) or Low depending on econ-scanner's
verdict on whether the intended strategy can actually produce zero-credit. Tightly coupled to
CODE-12-01: if the target is par-preserving, both this and CODE-12-01 collapse.

---

## CODE-12-03 — Revived-pool permissionless `stake` window before re-injection: benign race (no first-depositor theft)

- **Verdict:** REFUTED as an exploit (benign race; minor Law-3 single-session footgun only)
- **Type:** interleaving / first-depositor exposure on the transiently-empty revived pool
- **Contract / function:** `StableStaker.stake` interleaved with `InPlaceMigrator.migrateIn`
- **Location:**
  - `src/StableStaker.sol:593-604` (`finalizeAndReset` → `poolState = Active`)
  - `src/StableStaker.sol:289-307` (`stake` is `whenNotPaused`, requires `Active`, permissionless)
  - `src/InPlaceMigrator.sol:183` (`migrateIn` is `onlyOwner`)

### Analysis

After `finalizeAndReset` the pool is `Active` and empty, and `stake` is permissionless again
(`:289`, `whenNotPaused poolExists`). There is a genuine window where a third party can `stake` into
the freshly-wired strategy before the operator runs `migrateIn`. Examined for two exploit shapes:

(a) **First-depositor / ERC4626-style share inflation:** does NOT apply. Reward accounting is a
MasterChef accumulator (`accPhusdPerShare`, `rewardDebt`, `_updatePool` at `:706-727`), credited from
`elapsed · phusdPerSecond` divided by `totalStaked`, NOT from a share price derived from
`totalAssets`/`balanceOf`. A first staker cannot inflate a share price to skim a later depositor's
principal — there are no "shares," only `info.amount` (principal) and a per-second emission split.
The classic inflation attack has no foothold.

(b) **Adversarial interference with re-injection:** each parked user's `depositFor` credits **their
own** `amt` to **their own** `userInfo[token][user]` (`:627`, `:633`); a third party's prior `stake`
only changes `pool.totalStaked` and `accPhusdPerShare`, which dilutes *emission share* (reward rate),
not principal. The interloper cannot redirect, skim, or reduce any parked user's re-credited
principal. The only effect is that re-injected users share emissions with the early staker for the
window — a reward-rate dilution, not a loss of principal, and the early staker is a legitimate staker
who took on the same haircut/risk. No theft path.

Residual: this confirms the profile's SURFACE-6 conclusion. The single-operator-session assumption
(header (B)) is not enforced on-chain, so an early interloper *can* exist; but it is value-benign.
The interaction with the CODE-12-01 haircut is just "the interloper also eats the deposit haircut on
their own stake" — symmetric, not exploitable against parked users. Best filed as a Low/QA
single-session-not-enforced note, subordinate to CODE-12-01.

---

## CODE-12-04 — Reentrancy / CEI across migrator ↔ staker ↔ strategy: SOUND

- **Verdict:** REFUTED as a vulnerability (CEI + dual `nonReentrant` confirmed sound; rescue floor sufficient)
- **Type:** cross-contract reentrancy across a mid-batch reverting/reentering `depositFor`
- **Location:**
  - `src/InPlaceMigrator.sol:215-223` (effects-before-interaction in `migrateIn`)
  - `src/InPlaceMigrator.sol:247-254` (`claimTimedOut`)
  - `src/InPlaceMigrator.sol:270-274` (`rescueERC20`, no guard)
  - `src/StableStaker.sol:616-638` (`depositFor` is `nonReentrant`)

### Analysis

`migrateIn` (`:183`) and `claimTimedOut` (`:239`) are `nonReentrant`, and the staker's `depositFor`
is independently `nonReentrant` (`:618`). For each user `migrateIn` zeroes `parked[user]`, deletes
`migrationBegin`, decrements `totalParked`, and removes the set entry (`:215-218`) **before** calling
`depositFor` (`:223`). A re-entrant call (e.g. via a hookful token in `_pullToken`) would:

- hit the migrator's own `nonReentrant` and revert immediately if it re-enters `migrateIn`/`claimTimedOut`; and
- even absent the guard, see `parked[user] == 0` and either `continue` (`migrateIn`, `:210`) or
  `require(amount > 0)` revert (`claimTimedOut`, `:241`) — no double-pay.

The two `nonReentrant` domains are separate (migrator's guard does not protect the staker and vice
versa), but the CEI ordering in the migrator means a cross-domain re-entry cannot observe stale
parked state. Confirmed: mid-batch a reverting `depositFor` rolls back that user's just-zeroed state
along with the whole tx (no partial corruption), and a reentering `depositFor` cannot
re-trigger a second payout for the same user. The in-scope stable tokens are not ERC777 (no transfer
hooks), further reducing real exposure.

**`rescueERC20` lacks `nonReentrant` (`:270`)** but is `onlyOwner`, reads `balanceOf − totalParked`
live each call (`:271`), and performs a single `safeTransfer`. A re-entrant rescue re-reads the live
balance and is still fenced by `totalParked`, so it cannot cross the parked-principal floor. The
floor is sufficient; the missing guard is acceptable. Matches profile INV-3 and INV-5 (verified) —
no re-examination overturned them.

---

## Verdict summary

| ID | Surface | Verdict | Severity (pre-econ) | Harm | Law |
|----|---------|---------|---------------------|------|-----|
| CODE-12-01 | Re-injection haircut (SURFACE-1 / PM-12-01) | CONFIRMED | potential-high (conditional) | re-injected users lose `amt−credited` | Law 1 |
| CODE-12-02 | Poison-user batch revert (SURFACE-2 / PM-12-02 / SA-002) | CONFIRMED | potential-medium | migration availability; user waits timeout | Law 1 (availability) + Law 3 |
| CODE-12-02b | Early `migrateIn` ordering | REFUTED (safe-fail) | — | benign revert | Law 3 (minor) |
| CODE-12-03 | Revived-pool permissionless stake (SURFACE-6 / PM-12-MR-02) | REFUTED | low/QA | reward-share dilution only | Law 3 |
| CODE-12-04 | Cross-contract reentrancy / CEI (SA-001/003 / PM-12-MR-01) | REFUTED (sound) | — | none | — |

### Cross-cutting note
CODE-12-01 and CODE-12-02 share a single precondition: **the new re-injection strategy haircuts the
deposit.** If econ-scanner determines the intended target is strictly par/above-par at re-injection,
BOTH collapse to informational and the story-012 design is sound. If a market/AMM strategy can be the
re-injection target, CODE-12-01 is a live per-user principal-loss High and CODE-12-02 a migration-DoS
Medium. This is the decisive open question and the right thing for Tier-3 PoC (a haircutting mock
strategy through `migrateIn`, asserting `info.amount < parked` and `totalParked` zeroed). The
existing par-preserving `MockYieldStrategy` cannot reproduce it.
