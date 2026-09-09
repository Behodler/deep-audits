# stable-staker-07 — Contract Profiles Index

**Submodule:** `lib/stable-staker/` @ `7e9ef80a916081148e28df60ef6daf83c9157a3b`
**Compiler:** pragma `^0.8.20`, foundry pins `solc 0.8.28` (OZ v5.6.1 requires >= 0.8.24)
**Scan mode:** cold
**Generated:** 2026-06-07

| Contract | Profile | LOC | State-changing ext fns | Ext-call targets | Local findings |
|---|---|---|---|---|---|
| `src/StableStaker.sol` | [StableStaker.profile.json](./StableStaker.profile.json) | 714 | 15 | phUSD (IFlax), IYieldStrategy, IERC20 token, pauser | 1 (local-low) |
| `src/StableStakerMigrator.sol` | [StableStakerMigrator.profile.json](./StableStakerMigrator.profile.json) | 85 | 2 | oldStaker, newStaker (IStableStaker), IERC20 token | 0 |

Out-of-scope context: `src/interfaces/IStableStaker.sol` (the minimal `initiateMigration` / `batchMigrate` / `depositFor` surface the migrator binds to).

---

## StableStaker.sol — summary

MasterChef-style multi-token farm. One pool per registered ERC20; rewards are **minted on demand** in phUSD (the farm is an authorized phUSD minter — rewards are not pre-funded). Principal optionally routes through a per-token `IYieldStrategy`; yield stays protocol-owned (never credited to stakers). A terminal, per-token migration mode freezes a pool and pays a fixed snapshot credit.

**Access-control surface**
- `onlyOwner`: `addToken`, `phUSDPerDay`, `setMigrator`, `setPauser`, `setYieldStrategy`, `rescueERC20`
- `onlyPauser`: `pause`; `owner() || pauser`: `unpause`
- `onlyMigrator`: `initiateMigration`, `batchMigrate`, `depositFor`
- permissionless: `stake`, `withdraw`, `claim`, `emergencyWithdraw` (escape hatch), `userMigrate` (terminal escape hatch)

**Reentrancy:** `nonReentrant` on all 8 principal/reward-moving paths (stake, withdraw, claim, emergencyWithdraw, initiateMigration, batchMigrate, userMigrate, depositFor). Unguarded by design: `setYieldStrategy` and `rescueERC20` (both `onlyOwner`; rescueERC20 is strict CEI).

**Pausing:** `whenNotPaused` gates stake/withdraw/claim. Escape hatches and all migration hooks remain callable while paused — a broken mint or an incident can never trap principal.

**Local invariants established (all `verified`):**
1. **INV-SS-1 emission-cap** — `_updatePool` is the *sole* writer of `accPhusdPerShare` (grep-confirmed: only storage write is L623; rate changes settle first). No action sequence mints more than `phUSDPerDay`.
2. **INV-SS-2 dust-down** — all reward/migration division floors in protocol favor; no `unchecked`/assembly anywhere.
3. **INV-SS-3 totalStaked conservation** — `totalStaked == Σ user.amount` (every write paired with equal user delta) → subtractions cannot underflow.
4. **INV-SS-4 migration freeze** — `active` is terminal; `_updatePool` no-ops while active; mutating paths blocked → snapshot `P` immutable.
5. **INV-SS-5 credit order-independence** — `credit = amt·min(R,P)/P` over fixed `P`; batch == self == any ordering (closes legacy ss2m1/M-01).
6. **INV-SS-6 migration solvency** — `Σ floor(p_i·S/P) ≤ S ≤ R`; idle pile always covers every credit.
7. **INV-SS-7 rescue guard** — idle-held principal reserved (`= totalStaked`) when no strategy set.
8. **INV-SS-8 CEI on exits** — effects before transfer on all exit paths, plus nonReentrant.

**Local finding:** `LOCAL-SS-001` (local-low) — `phUSDPerDay` budgets below 86,400 wei/day floor `phusdPerSecond` to 0 (silent zero emission). Owner-config footgun; requires an implausibly tiny budget. Surfaced for recall; classifier to decide.

**Deferred to interaction/econ analysis (not local findings):** phUSD `mint` revert bricking reward legs; IYieldStrategy underwater/slippage/`principalOf` honesty; `setYieldStrategy` replace-without-drain stranding principal (documented owner footgun); `rescueERC20` sweeping the underwater-withdraw buffer when a strategy is set.

---

## StableStakerMigrator.sol — summary

Owner-only orchestrator of a zero-user-action migration between two `StableStaker` instances. Holds the staked token only transiently within a single `migrate()` call.

**Access control:** `onlyOwner` on both `initiateMigration` and `migrate`. No pause, no reentrancy guard (acceptable: owner-gated + immutable trusted callees).

**Local invariants established (all `verified`):**
1. **INV-MIG-1** — `forceApprove(newStaker, total)` exactly equals `Σ amounts[i]` redeposited → no dangling allowance.
2. **INV-MIG-2** — net token custody per call is zero (pull `total` in via batchMigrate, push `total` out via depositFor).
3. **INV-MIG-3** — atomic batch (any sub-call revert reverts the whole tx); already-migrated users surface as `amounts[i]==0` and are skipped (no double-credit).

No local findings.

---

## Cross-contract interaction surface (StableStakerMigrator → StableStaker)

The migrator depends only on the 3-function `IStableStaker` interface. The migrator address must be set as `migrator` on **both** stakers via `setMigrator` (so the staker's `onlyMigrator` gate accepts it).

```
Owner ── initiateMigration(token) ─────────► Migrator.initiateMigration
                                                  └─► oldStaker.initiateMigration(token)   [onlyMigrator]
                                                        • settle + freeze emissions
                                                        • snapshot P = totalStaked
                                                        • realize whole strategy position → R (idle)
                                                        • decouple strategy, set active=true   (TERMINAL)

Owner ── migrate(token, users[]) ──────────► Migrator.migrate
                                                  ├─► oldStaker.batchMigrate(token, users)  [onlyMigrator]
                                                  │     • per user: mint frozen phUSD, zero position
                                                  │     • credit_i = p_i·min(R,P)/P  (Σ ≤ R)
                                                  │     • transfer Σ credits to migrator
                                                  │     ◄── returns amounts[]
                                                  ├─► IERC20(token).forceApprove(newStaker, Σ amounts)
                                                  └─► for each non-zero: newStaker.depositFor(token, user, amounts[i]) [onlyMigrator]
                                                        • pulls amounts[i] from migrator (transferFrom)
                                                        • credits user, settles (mints) on the NEW pool
```

**Trust handshake / wiring prerequisites (deployment-time, verified safe-fail on misconfig):**
- Migrator set as `migrator` on **both** old and new stakers.
- `newStaker.addToken(token)` done, and `newStaker` is an authorized phUSD minter (so `depositFor`'s `_settle` mint and future emissions work).
- `oldStaker` token under terminal migration (`active`) before any `migrate` batch — else `batchMigrate` reverts.

**Boundary the profiler asserts as axioms for downstream agents:**
- `batchMigrate`'s returned `amounts` satisfy `Σ amounts ≤ R` and are order/composition-independent (StableStaker INV-SS-5/6). The migrator trusts this — it does not re-derive credits. An interaction/econ agent that wants to challenge the snapshot conservation should target StableStaker's `initiateMigration`/`_exitPosition`, not the migrator.
- The migrator never custodies value across calls (INV-MIG-2) and never grants residual allowance (INV-MIG-1) under standard ERC20.

**Shared trust assumptions across both contracts:** standard ERC20 staked tokens (no fee-on-transfer/rebasing); honest, correctly-wired `IYieldStrategy`; valid phUSD minter relationship; trusted non-malicious owner and migrator role.
