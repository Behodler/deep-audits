# Interaction-Level Code Findings — stable-staker

- **Project:** stable-staker
- **Tier:** 2 (interaction / cross-contract code scan)
- **Submodule commit:** f524cc3
- **Scope:** `src/StableStaker.sol`, `src/StableStakerMigrator.sol` (context: `src/interfaces/IStableStaker.sol`, `lib/reflax-yield-vault/src/...`)
- **Scan timestamp:** 2026-06-01
- **Inputs consumed:** `profile.md`, `static-analysis.md`. Strategy semantics verified against `reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` and `AYieldStrategy.sol`.

This report covers only **cross-contract interaction** bugs. Single-contract reentrancy guards, local arithmetic, access control on individual functions, and the 9 documented known issues (dust→protocol, protocol-owned yield, underwater-withdraw-not-blocked on emergency/migrate, owner/migrator centralization, permissionless emergencyWithdraw while paused) are explicitly NOT re-reported.

---

## CODE-001 — Underwater migration is bricked: `migrateOut` returns *requested* principal but transfers *received*, so the migrator cannot fund `depositFor`

- **Severity (suggested): Medium** (protocol function — the zero-user-action migration — is unavailable under a stated external condition: a below-par yield strategy. No funds lost; migration through this migrator simply cannot complete until the strategy recovers to par.)
- **Type:** cross-contract accounting mismatch / denial-of-service
- **Contracts/functions/lines:**
  - `src/StableStaker.sol : migrateOut` — `amounts[i] = amt` @324, `totalPrincipal += amt` @325, `payout = _routeExit(token, totalPrincipal, false)` @334, `safeTransfer(msg.sender, payout)` @335
  - `src/StableStaker.sol : _routeExit` @488–507 (balance-delta return @504–506)
  - `src/StableStakerMigrator.sol : migrate` — `amounts = oldStaker.migrateOut(...)` @46, `total = Σ amounts` @48–51, `forceApprove(newStaker, total)` @57, `newStaker.depositFor(token, users[i], amounts[i])` @60–65
  - `src/StableStaker.sol : depositFor` → `_pullToken` (`safeTransferFrom(migrator, ...)`) @356/457–461

### Root cause
`migrateOut` reports **two different quantities** for the same migration:

1. The per-user array it **returns** is the *requested* principal: `amounts[i] = amt` (line 324), where `amt = info.amount`.
2. The aggregate principal it **transfers** to the migrator is the *actual received*: `payout = _routeExit(token, totalPrincipal, false)` (line 334). When a yield strategy is set, `_routeExit` calls `strategy.withdraw(token, totalPrincipal, address(this))` and returns the **measured balance delta** (lines 504–506). The `ERC4626YieldStrategy` redeems shares and decrements principal by the *requested* amount while delivering only the shares' *current value* (`ERC4626YieldStrategy._withdrawInternal`, lines 290–295 + the contract docstring: "Principal is decremented by requested amount, not received amount, so any shortfall accumulates as protocol-owned yield"). When the strategy is **below par** (`totalBalanceOf < principalOf`, i.e. negative yield), the redeemed value is strictly **less** than `totalPrincipal`.

So after `migrateOut`, the migrator holds `payout < Σ amounts`.

The migrator then computes `total = Σ amounts[i]` (the requested figures), `forceApprove(newStaker, total)`, and in the redeposit loop calls `depositFor(token, users[i], amounts[i])` — each of which pulls `amounts[i]` (requested) from the migrator via `transferFrom`. The cumulative pulled amount equals `total > payout`, exceeding the migrator's balance.

### Concrete trigger path
1. Owner sets a yield strategy on `token` (`setYieldStrategy`), principal is custodied in an ERC4626 vault.
2. The vault's share price dips below par (negative yield / loss event). `withdrawDisabled(token)` now returns `true`; `migrateOut` is deliberately **not** blocked (documented: "the escape hatch and migrations always work").
3. Owner (acting as migrator) calls `StableStakerMigrator.migrate(token, users)` to move users to a new staker.
4. `oldStaker.migrateOut` redeems the aggregate principal at a haircut and transfers `payout` (< Σ requested) to the migrator, but returns the full requested `amounts`.
5. `migrate` approves and loops `depositFor`. Early iterations succeed (crediting users their FULL requested principal on the new staker), draining the migrator's haircut balance. A later `depositFor` calls `_pullToken → safeTransferFrom`, which reverts with an ERC20 insufficient-balance error once the running total exceeds `payout`.
6. The entire `migrate` transaction reverts, rolling back `migrateOut` as well (atomic within the single call — see LOCAL-M03). **The migration cannot complete through this migrator while the strategy is below par.**

### Impact
- The protocol's marquee "zero-user-action migration during an incident" is **unavailable for exactly the scenario it was designed for** (a strategy in trouble / paused incident). It only works while the strategy is at or above par.
- No loss of funds and no state corruption: the revert is atomic, so users are neither double-credited nor stranded mid-batch. This caps severity at Medium (availability of a protocol function under a stated external condition), not High.
- Note: the design intent is explicit — `migrateOut` passes `guardUnderwater = false` precisely so a below-par migration "delivers the redeemed (haircut) amount" (line 333 comment). The migrator silently defeats that intent by re-deposit­ing the un-haircut requested amount.

### Fix direction
Have `migrateOut` return the **actually-delivered** per-user amounts (allocate the aggregate `payout` across users pro-rata to their `amt`, e.g. `amounts[i] = amt * payout / totalPrincipal`, with the dust remainder following the protocol's existing round-down rule), OR have the migrator read the migrator's realized `token` balance after `migrateOut` and redeposit pro-rata against that, rather than against `Σ amounts`. Either makes redeposit totals reconcile with the haircut principal. Crediting users their full pre-haircut principal on the new staker is in any case impossible without minting tokens the migrator never received.

---

## Items investigated and NOT promoted

### Lead 2 — Reentrancy across the strategy / token boundary: NO additional finding
Every externally-reachable mutating entrypoint on `StableStaker` carries `nonReentrant` except the owner-only config setters and `rescueERC20` (trailing transfer, no post-call state — acceptable). The yield strategy (`ERC4626YieldStrategy`/`AYieldStrategy`) is itself `nonReentrant` on `deposit`/`withdraw` and **never calls back into `StableStaker`** — it only touches the external ERC4626 vault and the underlying token. The only callee that could re-enter is a malicious `phUSD` or a malicious staked `token`, both of which are trusted by the documented model (phUSD is the protocol's own FlaxToken; tokens are assumed standard ERC20). No externally-reachable mutating path is missing a guard. The Slither/Aderyn `reentrancy-no-eth`/`reentrancy-state-change` hits on `stake`/`depositFor`/`migrateOut` are mitigated by the load-bearing `nonReentrant` guard plus the trusted-callee set. Confirms profile §"Reentrancy / CEI observations". Not a finding.

### Lead 3 — `rescueERC20` buffer scope when a strategy is set: centralization, already captured (LOCAL-002)
When `yieldStrategy[token] != 0`, `rescueERC20` sets `reserved = 0` (line 523) and lets the owner sweep the entire on-contract balance. With a strategy set, principal lives in the strategy, so the on-contract balance is the protocol-owned buffer/dust. A pending underwater `withdraw` draws from exactly this buffer (`_routeExit` buffer branch, lines 494–501): an owner rescue could remove buffer that a below-par non-migrating withdraw would have used, forcing those users onto `emergencyWithdraw` (haircut) instead. This is an **owner-trust / centralization** concern (the owner is explicitly trusted and `rescueERC20` is documented as owner-only), not an unprivileged exploit or a theft of *accounted* principal (principal sits in the strategy and remains reserved there). It matches LOCAL-002 and the documented owner-centralization known issue; deferred to the severity-classifier as centralization, not promoted as a code bug.

### Lead 4 — Reward-debt / accumulator accounting: NO finding
Verified `_updatePool` / `_settle` / `rewardDebt` across all paths:
- `stake`/`depositFor`: `_updatePool` → `_settle` (mints pending on the pre-update `amount`) → increment `amount`/`totalStaked` → recompute `rewardDebt` on the new `amount`. Correct.
- `withdraw`: `_updatePool` → `pending` computed on old `amount` with fresh `acc` → decrement → recompute `rewardDebt` → mint. Correct CEI and correct baseline.
- `claim`: `_updatePool` → pending → set `rewardDebt` → mint. Correct.
- `migrateOut`: single `_updatePool` before the loop; per-user pending uses the up-to-date `acc`; `amount`/`rewardDebt` zeroed together. Correct.
- Empty-pool fast-forward (`totalStaked == 0` ⇒ advance `lastRewardTime`, accrue nothing) and the `block.timestamp <= lastRewardTime` early-return are correct; rate changes settle the old rate first (`phUSDPerDay` calls `_updatePool` before mutating `phusdPerSecond`). Emission-cap invariant (I3) holds and is covered by `test/EmissionCap.t.sol`.
- Accumulator overflow (`elapsed * phusdPerSecond * 1e18`) requires an extreme owner-set `phUSDPerDay`; it is owner-controlled config that reverts (no loss) — documented centralization, not a finding.

No deposit/withdraw ordering bug, no `rewardDebt` desync, no pending-reward drain.

---

## Summary

| ID | Title | Contract:Function | Severity |
|----|-------|-------------------|----------|
| CODE-001 | Underwater migration bricked: migrateOut returns requested but transfers received, migrator under-funds depositFor | StableStaker.migrateOut ⇄ StableStakerMigrator.migrate | Medium |

One confirmed cross-contract code finding. Leads 2 and 4 cleared; Lead 3 is centralization (LOCAL-002), deferred.
