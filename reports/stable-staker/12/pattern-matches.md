# Pattern Matches — stable-staker run-12

- **Project:** stable-staker
- **Submodule:** `lib/stable-staker` @ `ffa494783f585bcd2ce1ff60dd756345717287f1`
- **Scan type:** pattern-matching (regression, new contract)
- **Primary contract under test:** `src/InPlaceMigrator.sol` (new)
- **Surfaces read:** `src/StableStaker.sol`, `src/StableStakerMigrator.sol`
- **Pattern DB:** `patterns/vulnerability-patterns.json` (v1.0, 30 patterns)
- **Scan timestamp:** 2026-06-15

## Method

`InPlaceMigrator` is a new orchestration wrapper. It holds no economic math of its own — it calls
into `StableStaker`'s already-audited terminal-migration surface (`initiateMigration`,
`batchMigrate`, `depositFor`) and an OZ `EnumerableSet`. So every pattern was checked against
**both** the wrapper's own code and the boundary it crosses into the staker. The focus classes
named in the task map onto the DB's `staking-yield` family plus reentrancy / access-control /
first-depositor / slippage.

Findings below are routed per the Three-Law hierarchy: low-confidence *applicability* matches are
parked in Manual Review (not dropped), not because impact is low.

---

## Findings (medium/high-confidence matches)

### PM-12-01 — YIELD-PRINCIPAL-ACCOUNTING-SKEW (re-injection haircut on a market strategy)
- **Pattern:** `YIELD-PRINCIPAL-ACCOUNTING-SKEW` (HIGH) → potential-high
- **Confidence:** medium
- **Location:** `InPlaceMigrator.migrateIn` (`src/InPlaceMigrator.sol:223`) → `StableStaker.depositFor`
  (`src/StableStaker.sol:616-638`) → `_routeDeposit` (`src/StableStaker.sol:757-763`).
- **Matched signatures:** `depositFor`, `yieldStrategy`, `principalOf`, requested-vs-received delta
  (`_pullToken` balance-delta at `StableStaker.sol:740-745`, `_routeDeposit` returns strategy-booked
  `credited`).
- **Why it matches:** the whole purpose of the in-place migration is to wire a **new**
  `IYieldStrategy` (via `finalizeAndReset` + `setYieldStrategy`) and then re-inject parked principal.
  `migrateIn` approves the exact slice total and calls `depositFor(token, user, amt)`. Inside
  `depositFor`, `_routeDeposit` deposits into the **freshly-wired strategy**, and for a market/AMM
  strategy the booked principal `credited` is **less than** `amt` (entry haircut). The user is
  credited `credited`, not the `amt` that was parked for them. So a user who was drained at par
  `p_i·min(R,P)/P` can be re-credited a haircut amount on the way back in. The migrator's own state
  (`parked`, `totalParked`) is already zeroed by the *requested* `amt`, while the staker books the
  *received* principal — the canonical requested-vs-received skew this pattern describes, now
  appearing on the **deposit** leg rather than the exit leg.
- **Mitigation present (reduces, not eliminates):** the project's documented rounding rule says
  sub-amount differences "remain protocol-owned yield/loss." On the deposit leg the difference is a
  *loss to the user*, not protocol surplus, so the documented rule does not obviously cover this
  direction. `setYieldStrategy` swept idle balance is a no-op here (principal is parked in the
  migrator during the window, staker idle balance is 0), so the haircut lands entirely at
  `depositFor` time.
- **Verification needed:** is the intended new strategy a direct/`ERC4626` strategy (returns
  `amount`, no haircut) or a market strategy? If only direct strategies are ever wired in place, this
  collapses to informational. If a market strategy can be the re-injection target, this is a live
  per-user principal shortfall on re-entry and should be escalated. Cross-ref memory:
  stable-staker M-07 (AMM-execution slippage) and the `setYieldStrategy` empty-pool gate notes.
- **References:** patterns DB `YIELD-PRINCIPAL-ACCOUNTING-SKEW`; `StableStaker.sol:221-228` (swap
  desync root-cause comment), `:757-763`, `:774-794`.

### PM-12-02 — CENTRALIZATION-ADMIN / state-ordering footgun (migrateIn requires Active, but flow leaves pool Migrating)
- **Pattern:** `CENTRALIZATION-ADMIN` (LOW) + `EMISSION-WINDOW-BOUNDARY`/ordering adjacency → potential-low (operational footgun, Law 3)
- **Confidence:** medium
- **Location:** orchestration ordering across `InPlaceMigrator.migrateOut` (`:145`) →
  `migrateIn` (`:183`, calls `staker.depositFor` at `:223`) vs.
  `StableStaker.depositFor` guard `require(poolState[token] == PoolState.Active)` (`StableStaker.sol:624`).
- **Why it matches:** the documented runbook is `initiateMigration` (pool → `Migrating`) →
  `migrateOut`/`batchMigrate` (pool drained empty) → operator `finalizeAndReset` (pool → `Active`) +
  `setYieldStrategy` → `migrateIn`. `depositFor` **reverts unless the pool is `Active`**. If the
  operator calls `migrateIn` before `finalizeAndReset` (e.g. a partial drain, or simply wrong order),
  every `depositFor` reverts — the slice cannot be re-injected. This is not a fund-loss bug (the
  timeout hatch still returns principal), but it is a **non-obvious ordering coupling** between two
  contracts with no on-chain guard or helpful revert in the migrator itself. The migrator never
  checks `staker.poolState` before attempting re-injection.
- **Owner-trust framing:** a competent operator following the runbook is fine, but the *consequence
  of mis-ordering* (whole `migrateIn` slice reverts mid-migration, window keeps ticking toward the
  timeout hatch) is a Law-3 footgun, not obvious misuse. Surface as operational hazard with
  safe-sequence guidance, not as a malicious-owner vector.
- **References:** `StableStaker.sol:593-604` (finalizeAndReset Active transition), `:616-624`.

---

## Manual Review (low-confidence applicability — routed, not dropped)

### PM-12-MR-01 — REENTRANCY-ERC777 across migrator ↔ staker ↔ strategy boundary
- **Pattern:** `REENTRANCY-ERC777` (HIGH).  **Confidence:** low.
- **Location:** `migrateIn` (`:207-224`), `claimTimedOut` (`:239-256`), `migrateOut` (`:145-163`).
- **Why considered / why low:** all three external-call paths cross a token boundary
  (`depositFor`/`safeTransfer`/`batchMigrate`) and a malicious/hookful token could re-enter. BUT the
  migrator applies strict CEI: `parked` zeroed, `migrationBegin` deleted, `totalParked` decremented
  and user removed from the set **before** the external call, all under `nonReentrant`. A re-entrant
  call sees `parked == 0` and the `amt == 0` / `amount > 0` skips fire (no double-pay). The staker
  side is also `nonReentrant`. Reentrancy appears **mitigated**; flagged only so a reviewer confirms
  the cross-contract guard composition (two separate `nonReentrant` domains — migrator's guard does
  not protect the staker and vice versa) holds for the specific tokens in scope. Stable tokens in
  scope are not ERC777, lowering real exposure.
- **Note:** `rescueERC20` (`:270-274`) has **no `nonReentrant`**, but it is `onlyOwner` and reads
  `balanceOf - totalParked` live, so a re-entrant rescue cannot cross the parked floor. Worth a glance.

### PM-12-MR-02 — FIRST-DEPOSITOR / dust-share inflation on the revived pool
- **Pattern:** `FIRST-DEPOSITOR-ATTACK` / `ERC4626-INFLATION` (HIGH).  **Confidence:** low.
- **Why considered / why low:** the in-place flow deliberately drives the pool to empty
  (`finalizeAndReset` requires `totalStaked == 0`) and then re-wires a strategy and re-injects users.
  The window where the revived pool transiently has `totalStaked == 0` with a freshly-wired
  `IYieldStrategy` is structurally a "first depositor" moment. However: (a) `migrateIn` is
  `onlyOwner`, so an external attacker cannot interleave a dust deposit between `setYieldStrategy` and
  the first re-injection (the pool is `Active` and `stake` is permissionless during this gap — see
  below); (b) the staker accrues phUSD on a MasterChef accumulator, not on a share price derived from
  `totalAssets`, so the classic ERC4626 inflation does not directly apply to reward accounting.
  **Residual concern to verify:** after `finalizeAndReset` sets the pool `Active`, the pool is open to
  **permissionless `stake`** before the operator runs `migrateIn`. A third party could `stake` into
  the freshly-wired market strategy first, establishing a `principalOf`/`totalBalanceOf` baseline that
  interacts with the subsequent `depositFor` haircut (PM-12-01). Whether that lets an attacker grief
  or skim the re-injected users is the open question — needs Tier-2/3 reasoning, not a pure pattern
  call. This is the most security-relevant of the low-confidence items.

### PM-12-MR-03 — MISSING-SLIPPAGE / sandwich on the rewire swap
- **Pattern:** `MISSING-SLIPPAGE` (HIGH).  **Confidence:** low.
- **Why considered / why low:** the migrator performs **no swap**; it parks raw principal and
  re-injects it. The swap-like exposure lives entirely in `StableStaker.setYieldStrategy` /
  `_routeDeposit` / `_routeExit` when a market strategy is wired (deposit/exit haircut = the
  AMM execution path of memory M-07). The migrator inherits that exposure indirectly via
  `depositFor` (folded into PM-12-01). No `minAmountOut`/deadline is exposed at the migrator layer,
  but slippage control would have to live in the strategy. Flagged for completeness; routed into
  PM-12-01 for the economic angle.

### PM-12-MR-04 — UNSAFE-DOWNCAST / arithmetic
- **Pattern:** `UNSAFE-DOWNCAST` (MEDIUM), `DIVISION-PRECISION` (MEDIUM).  **Confidence:** low.
- **Why low:** `InPlaceMigrator` has no casts and no division. The only division in the path is
  `_exitPosition`'s `credit = (amt * S) / P` (`StableStaker.sol:528`) which is in the already-audited
  staker, multiply-before-divide, and `min(R,P)`-capped. Dust rounds down (cannot over-pay). No new
  surface introduced by the migrator. Recorded as no-match-but-checked.

---

## Patterns checked and NOT matched (with reason)

| Pattern | Result |
|---|---|
| UNPROTECTED-INIT | N/A — no initializer; immutable `staker`/`migrationTimeout` set in constructor with `MIN/MAX_TIMEOUT` bounds. |
| STORAGE-COLLISION | N/A — not a proxy; no `delegatecall`. |
| ORACLE-STALE / ORACLE-ROUNDID | N/A — no oracle reads in the migrator. |
| SIGNATURE-REPLAY / PERMIT-FRONTRUN / CROSS-CHAIN-REPLAY | N/A — no signatures, no permit, no bridge. |
| DOS-UNBOUNDED-LOOP | Bounded by design — `migrateIn` is paged `[start,end)`, `migrateOut` takes a caller-built `users[]` batch. Doc'd "small set, single batch." No match. |
| SELFDESTRUCT-FORCE-ETH | N/A — no ETH handling; no `address(this).balance` logic. |
| RETURN-VALUE-IGNORE | Mitigated — uses `SafeERC20` (`safeTransfer`/`forceApprove`); `batchMigrate`/`depositFor` returns consumed. |
| FLASH-LOAN-PRICE | N/A — no spot-price reads in the migrator (strategy NAV concerns tracked in staker scope). |
| REWARD-ACCRUAL-ORDER / MINT-ON-DEMAND-OVERMINT / REWARD-RUNWAY-DEPLETION | N/A to migrator — phUSD was already minted to users at `migrateOut` (inside `batchMigrate`/`_exitPosition`); migrator handles **principal only**, never mints. Accrual logic untouched. |
| BATCH-PAYOUT-FIXED-POT | No match — no count-gated pot; per-user credit pinned to original user, not caller-chosen. |
| TWO-STEP-COMMIT-WINDOW | Adjacent (out→in is two-step) but the parked amount is **snapshotted per-user**, not re-read live; re-injection credits the exact parked `amt`. Apart from the haircut in PM-12-01, no live-value re-read race. |
| FRONTRUN-APPROVE | `forceApprove` to exact slice total immediately before the `depositFor` loop, consumed in-tx; no dangling non-zero allowance. No match. |

## Access-control summary (task focus item)
- `initiateMigration`, `migrateOut`, `migrateIn` — all `onlyOwner`. ✓
- `claimTimedOut` — permissionless but **self-scoped** (`parked[token][msg.sender]`) and time-gated
  (`migrationBegin + migrationTimeout`, bounds 1–30 days). Not a missing-control gap. ✓
- `rescueERC20` — `onlyOwner`, fenced below `totalParked[token]` floor (cannot touch parked
  principal). ✓ (no `nonReentrant`, see PM-12-MR-01 note.)
- The migrator additionally depends on being set as `staker.migrator` via `setMigrator` for
  `initiateMigration`/`batchMigrate`/`depositFor` (`onlyMigrator` on the staker side). Mis-wiring is
  an obvious operational prerequisite, not a footgun.

## Summary counts
- Patterns checked: 30
- Findings (medium/high confidence): 2 (PM-12-01, PM-12-02)
- Manual review (low-confidence applicability): 4 (MR-01..MR-04)
- Highest-priority item for Tier-2/3: **PM-12-01** (re-injection haircut) and **PM-12-MR-02**
  (permissionless `stake` into the revived-Active pool before `migrateIn`).
