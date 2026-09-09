# Pattern Matches — stable-staker run-15

- **Submodule HEAD:** `2146428bdd9adb1fbaf1c1feaa4fbf36133e5506` (`[story-021]`)
- **Prior audited commit:** `8856781` (run-14)
- **Pattern DB:** `patterns/vulnerability-patterns.json` v1.1 — **35 patterns loaded, 35 evaluated**
- **Patterns skipped (skip rule):** 1 — `FRONTRUN-APPROVE`
- **Scope scanned (5/5 files, no coverage gaps, no read errors):**
  `src/StableStakerV2.sol`, `src/versions/v1/StableStakerV1.sol`, `src/CrossVersionMigrator.sol`,
  `src/InPlaceMigrator.sol`, `src/versions/v1/IStableStakerV1.sol`
- **Result: 0 new primary findings. 4 items routed to manual review. 8 patterns matched-but-refuted
  with reasons. 22 patterns no-signature. 1 skipped.**

This run's delta is small and defensive (self-heal, `R` widening, pre-flight probes, aliasing guard).
Every pattern that fired on it resolved either to an existing ledger entry or to a `notVulnerableWhen`
clause that the code genuinely satisfies. Nothing here is filed as new.

---

## 0. Method note — how V1 was treated

`src/versions/v1/StableStakerV1.sol` is a **frozen, byte-verified copy of live mainnet bytecode**
(`0xbce8ABC09BaEDCabE93419bF875f6186e182079A`, from `c3ec65b`). I ran the full pattern sweep against it
anyway (Law 1: scope is a denylist), and mechanically re-derived the V1↔V2 diff:

```
sed 's/StableStakerV2/SS/' src/StableStakerV2.sol | diff - <(sed 's/StableStakerV1/SS/' src/versions/v1/StableStakerV1.sol)
```

124 diff lines, of which **19 are code** and the rest are comments. The 19 code lines reproduce exactly
the six deltas D1–D6 in the profile — no seventh divergence exists. **Every pattern that fires on V1
also fires identically on V2 except at D3/D4**, so V1 contributes no independent match. Findings that
would land on V1 are *deliberately preserved* per the freeze doctrine and are not re-filed.

---

## 1. Findings (medium/high confidence)

**None.**

Both plausible candidates I developed against the new code were killed by reading the actual dependency
rather than the interface — see §3.1 and §3.2. Recording that explicitly so a later run does not
re-derive the same two hypotheses from scratch.

---

## 2. Manual review (low confidence — routed, not dropped)

### MR-15-01 — `initiateMigration` pre-flight does not check destination pool state (one-way-door class)
- **Pattern:** no DB id (migration one-way-door class, requested by the run brief). Nearest DB relative:
  `TWO-STEP-COMMIT-WINDOW`.
- **Code:** `src/CrossVersionMigrator.sol:145-150`
```solidity
require(_isRegisteredOn(address(newStaker), token), "Migrator: destination token not registered");
(address destMigrator, bool probed) = _migratorOf(address(newStaker));
require(!probed || destMigrator == address(this), "Migrator: destination not wired");
oldStaker.initiateMigration(token);   // <-- terminal, irreversible
```
- **Match assessment: real but narrow, and strictly an improvement on run-14.** The new pre-flight
  checks two of the five destination preconditions. It does **not** check that the destination pool is
  `Active` (a destination already `Migrating` makes every later `depositFor` revert), nor that the
  destination is an authorized phUSD minter (documented in-source as a runbook obligation). Either
  failure surfaces only in the *second* owner transaction, after the source is already frozen.
- **Why not a finding:** both gaps are owner-configuration, both are explicitly documented in the
  contract's own NatSpec as runbook obligations, and the freeze is recoverable — stranded users exit via
  the permissionless `userMigrate` escape hatch. Under Law 3 this is at most a non-obvious footgun, and
  it is already substantially covered by ledger `7cdb92fdc7` ("initiateMigration is an unvalidated
  one-way door") which this commit *partially fixes*. Routed so triage can decide whether `7cdb92fdc7`
  should be narrowed rather than closed.

### MR-15-02 — fail-open staticcall probes (`_isRegisteredOn`, `_migratorOf`)
- **Pattern:** no DB id (fail-open probe / version-detection-by-revert, requested by the brief).
- **Code:** `src/CrossVersionMigrator.sol:214-239`
```solidity
if (!ok || data.length < 32) return (address(0), false);   // _migratorOf  -> requirement waived
if (!ok || data.length < 64) return true;                  // _isRegisteredOn -> requirement waived
```
- **Match assessment: the fail-open is real and deliberate, and the in-source documentation of it is
  accurate** (verified line by line): a probe that *succeeds and answers no* hard-reverts; only a probe
  that *fails* passes through. The purpose is version-agnosticism, and it is correct that an empty
  registry ABI-encodes to exactly 64 bytes, so `length == 0` is decoded honestly and correctly rejected
  — the `< 64` guard does not accidentally swallow the empty-registry case.
- **Residual worth a human eye:** the failure mode that waives the check is indistinguishable from the
  failure mode that *should* block it (an OOG on a large `getStakedTokens()`, or a destination whose
  `migrator()` reverts). Both V1 and V2 implement both getters, so on the only two shapes that exist
  today the probes always succeed. Speculative beyond that.

### MR-15-03 — `versionOf` infers version 1 from a reverting staticcall
- **Pattern:** no DB id (version-detection by revert).
- **Code:** `src/CrossVersionMigrator.sol:198-202`, and the V1 constraint at
  `src/versions/v1/StableStakerV1.sol` (no `STAKER_VERSION` getter, by design).
- **Match assessment: matched, and correct as written — but it is a doctrine dependency, not a code
  guard.** Any `!ok` is read as "version 1". If V1 ever gained a `STAKER_VERSION` getter the inference
  silently inverts. **Impact is nil today:** `versionOf` is consumed only by the
  `MigratedAcrossVersions` event and gates no control flow. Filing at anything above informational would
  overstate it. Routed because the profile flags "V1 must never gain this getter" as a live invariant
  whose only enforcement is the frozen-file hash check.

### MR-15-04 — `phUSDPerDay` floor-divides the daily budget to zero
- **Pattern:** `DIVISION-PRECISION` (MEDIUM) — partial match.
- **Code:** `src/StableStakerV2.sol:209` — `uint256 perSecond = amountPerDay / SECONDS_PER_DAY;`
- **Match assessment: matched, already ledgered.** This is existing open Low `d47619d29f`
  ("phUSDPerDay sub-86400-wei/day budget floors phusdPerSecond to 0"). Unchanged this run. Re-listed
  only so the pattern tier's coverage is auditable; **do not re-file**.

---

## 3. Matched but does NOT apply (with reasons)

### 3.1 `YIELD-PRINCIPAL-ACCOUNTING-SKEW` (HIGH) — the D3 self-heal
Every signature fires (`principalOf`, `totalBalanceOf`, `yieldStrategy`, `balanceBefore/After`). This was
my strongest hypothesis and it is **refuted by the dependency, not by the comments**.

The hypothesis: V2 replaces V1's hard `require(principalOf == 0)` brick with
`if (booked > 0) strategy.relinquishPrincipal(token, booked)` (`StableStakerV2.sol:478-499`). If a
strategy could exit only *partially*, `booked` would be genuinely user-backed principal, and V2 would
now **write it off to the protocol and proceed** — converting V1's loud brick into a silent socialized
haircut. V1's own comment names exactly this case ("a tranche/queue vault that can only exit partially
would understate R and strand value").

Why it does not apply: `reflax-yield-vault/src/AYieldStrategy.sol:732-752` (`_withdrawInternal`)
decrements `clientBalances` by the **requested (capped) amount**, independent of what `_disposeShares`
actually redeemed:
```solidity
uint256 availablePrincipal = clientBalances[token][balanceHolder];
if (amount > availablePrincipal) { amount = availablePrincipal; }
uint256 sharesDisposed = _disposeShares(amount, recipient);
clientBalances[token][balanceHolder] -= amount;
```
So after `_routeExit(token, P, false)` with `P == totalStaked`, the client book is **structurally zero**
for the entire concrete strategy family. The only way `booked > 0` is `clientBalances > totalStaked`,
i.e. the `setYieldStrategy` idle-sweep excess — which is protocol money by construction (the sweep is
gated on an empty pool). **The write-down can never reach user principal on any strategy that exists.**

A partial-exit shortfall instead shows up as a low contract balance → low `R` → the pro-rata `min(R,P)/P`
haircut, which is the pre-existing documented socialization, not new behaviour. Filing the tranche-vault
variant would be *speculation on future code without a demonstrated root cause* — a C4 known-invalid.
The second `vulnerableWhen` clause (underwater withdraw forcing loss onto non-exiting users) is real but
is ledger `69c7666eee`, **wont-fix**, identical in V1 and V2, untouched this run.

### 3.2 `BATCH-PAYOUT-FIXED-POT` (MEDIUM) — the D4 `R = balanceOf(this)` measurement
Signatures fire on `balanceOf(address(this))` at `StableStakerV2.sol:521`, and the sharpest
`vulnerableWhen` clause is a direct hit in form: *"pot read/snapshotted AFTER an external mint/transfer
loop"*. `R` is indeed read after `_routeExit`'s `strategy.withdraw` and after `relinquishPrincipal`.

Refuted on the economics. A donation landing before the read raises `R` toward `P`. Since
`credit_i = p_i·min(R,P)/P` and `Σ credit_i ≤ R`:
- above par the `if (R > P) R = P` cap absorbs it entirely — no effect;
- below par a donor holding `p_i` recovers only `p_i/P · D < D` of a donation `D`, so the manoeuvre is
  strictly loss-making and **not attacker-repeatable for profit**;
- the recipient is not caller-chosen (`_exitPosition` pays the position holder), which satisfies the
  `notVulnerableWhen` clause outright.

The pot is also read inside a `nonReentrant` frame with no attacker-controlled call between the last
state write and the read. This is the *intended* softening of `ss14l8` (ledger `f7991b64ad`), and it
strictly benefits users. Not a finding in either direction.

### 3.3 `REWARD-ACCRUAL-ORDER` (HIGH) — every `notVulnerableWhen` clause holds
`accPhusdPerShare` / `rewardDebt` / `_updatePool` all fire. Verified by reading all six mutation sites:
- `stake`, `withdraw`, `claim`, `depositFor` call `_updatePool` **before** any share mutation;
- `phUSDPerDay:207-211` calls `_updatePool` at the **old** rate before writing `phusdPerSecond` — no
  retroactive rate change;
- `_updatePool:766-786` is the sole writer of `accPhusdPerShare`, fast-forwards `lastRewardTime` on an
  empty pool without accruing, and returns early on `poolState != Active` so emissions freeze at the
  migration snapshot;
- `claim:` re-baselines `user.rewardDebt` before minting, so a `claim` during `Migrating` followed by
  `_exitPosition` cannot double-mint (`pending` computes to 0 on the second pass) — I checked this
  specifically because it is the classic double-mint seam.

### 3.4 `MINT-ON-DEMAND-OVERMINT` (HIGH) — single writer, capped
`mint(` / `phUSD` fire on four sites. All four mint exactly settled `pending` derived from the single
`_updatePool` writer, so realized emission over any window is bounded by `phusdPerSecond * window`
regardless of stake size or user behaviour. Satisfies all three `notVulnerableWhen` clauses.

### 3.5 `EMISSION-WINDOW-BOUNDARY` (MEDIUM) — no window exists
`lastRewardTime` / `elapsed` / `block.timestamp` fire, but accrual is strictly bounded to
`[lastRewardTime, now]`, `totalStaked == 0` is guarded before the division, and `finalizeAndReset`
fast-forwards `lastRewardTime` so a revived pool cannot accrue retroactively. Documented residual —
`finalizeAndReset` not resetting `phusdPerSecond` — is existing open Low `ss9l1-fina`.

### 3.6 `REWARD-RUNWAY-DEPLETION` (HIGH) — the Linear-Depletion class, explicitly checked
The brief calls this out because the org has hit it repeatedly. **It does not exist in this codebase.**
Only one of the six signatures (`phusdPerSecond`) is present; there is no `windowEnd`, no `rewardBudget`,
no `committedDebt`, no `_recomputeSchedule`, no depletion curve, and no `_safePay`. `phUSD` is
**minted on demand** against an unbounded minter authorization rather than paid from a funded pot, so
the rate-drift mechanic (a recompute pushing `windowEnd` forward and applying it retroactively) has no
surface to land on. This is a flat-rate MasterChef, not a depletion schedule. Reported as *checked and
structurally absent*, not as *clean by luck*.

### 3.7 `ROUNDING-DIRECTION` (MEDIUM) — all divisions floor toward the protocol
`credit = (amt * S) / P` floors (dust protocol-owned); `accPhusdPerShare += reward*1e18/totalStaked`
floors (under-emission). The one direction that favours the user is the standard MasterChef
`rewardDebt = amount*acc/1e18` floor, worth ≤ 1 wei of phUSD per settle and costing a full transaction
to harvest — provably not attacker-repeatable for profit, which is the pattern's own exclusion. No
`Rounding.Ceil`/`ceilDiv` anywhere; `mulDiv` appears only in `InPlaceMigrator`'s grossed-up top-up
(unchanged this run, already covered by `bf5018deab`).

### 3.8 `FEE-ON-TRANSFER-ACCOUNTING` (MEDIUM) — measured delta + standing OOS
`_pullToken:800-805` credits `balanceAfter - balanceBefore`, satisfying the primary `notVulnerableWhen`.
Token set is owner-registered stables; FoT/weird-ERC20 is a standing known-invalid class for this project.

### 3.9 `DOS-UNBOUNDED-LOOP` (MEDIUM) — already ledgered
`batchMigrate` and `CrossVersionMigrator.migrate` loop over owner-supplied arrays; `getStakers()` is an
unbounded view. Existing open Low `59eebbf87b`. `_isRegisteredOn`'s loop over `getStakedTokens()` is
bounded by an owner-controlled, single-digit add-only registry; its OOG-fails-open edge is folded into
MR-15-02 rather than filed separately.

### 3.10 `REENTRANCY-CROSS-FUNCTION` / `REENTRANCY-READONLY` / `REENTRANCY-ERC777` (HIGH ×3)
`transfer(`/`safeTransfer(`/`balances[` signatures fire. OZ `ReentrancyGuard` is **contract-wide**, not
per-function, so the sibling-set clause is satisfied by construction; all eight value-moving functions
carry `nonReentrant`. `rescueERC20` and `finalizeAndReset` are unguarded but are `onlyOwner` with no
post-transfer state. No ERC777/ERC721/ERC1155 hook surface and no `receive`/`fallback` (grep-verified:
0 hits for `msg.value`, `address(this).balance`, `onERC721Received`, `_safeMint`). For read-only
reentrancy the contract exposes no price/exchange-rate/`convertToAssets` view for an integrator to
consume as an oracle — 0 hits on the entire signature list.

### 3.11 `INCORRECT-OPERATOR` (MEDIUM) — boundaries checked individually, all correct
Per the pattern's own note I only evaluated genuine window/cap boundaries, not every `require`:
`if (R > P) R = P` (correct cap), `block.timestamp <= pool.lastRewardTime` (correct — prevents a
zero/negative elapsed), `bal >= reserved + amount` (correct fence),
`block.timestamp >= migrationBegin + migrationTimeout` (correct hatch). None off by one.

### 3.12 `RETURN-VALUE-IGNORE` (MEDIUM) — deliberate, and D6 fixes the one that mattered
`_routeExit(token, P, false)` at `StableStakerV2.sol:469` discards its return — **intentional** under D4,
since `R` is now measured from the balance instead. The genuinely silent one was
`strategy.deposit(token, idleBalance, address(this))` in `setYieldStrategy`; D6 now captures `credited`
and emits `ProtocolPrincipalSwept`. Note this makes the sweep **observable**, it does not stop it — the
root cause remains open ledger Medium `d1aa40605d`. SafeERC20 is used throughout, so no unchecked
ERC20 boolean exists. Existing informational `7b0717792d` covers the `EnumerableSet.add/remove` returns.

---

## 4. Fork-drift analysis (V1 frozen vs V2 evergreen)

Requested as a live class. **Result: drift exists, is fully enumerated, and every instance is
deliberate — no accidental drift, and no bug fixed on one side that silently survives on the other
outside the two declared cases.**

| Drift | Direction | Status |
|---|---|---|
| `ss14m1` — idle-sweep divergence bricks migration | Fixed in V2 (D3), **live and unpatchable in V1** | Deliberately preserved; ledger `d1aa40605d` (open Medium) is the root cause, and it is a *source* defect the V1 freeze merely records |
| `ss14l8` — set-aside buffer excluded from `R` | Fixed in V2 (D4), **live in V1** | Deliberately preserved; ledger `f7991b64ad` (open Low) |
| D1/D2/D5/D6 (interface `override`s, `STAKER_VERSION`, two events) | V2 only | No behavioural or ABI consequence; selectors pinned by `test/GoldenRule.t.sol` |

**Reverse-direction check (a V1 fix absent from V2): none exists** — the normalized diff has no code line
present in V1 and absent from V2 other than the two lines D3/D4 replace. **Storage-layout drift: none**
— identical slots in identical order; `STAKER_VERSION` is a `constant` and occupies no slot, and neither
contract sits behind a proxy, so `STORAGE-COLLISION` is doubly inapplicable.

The operational hazard worth carrying forward is not a code defect: **`d1aa40605d` remains open, so the
divergence can still be *created* on V2** — D3 only stops it from bricking the migration. Live DOLA and
USDC on V1 are in this state today and still require the off-chain
`relinquishPrincipalAsOwner` runbook, which no code path enforces.

---

## 5. Coverage ledger

**Skipped (skip rule, `note` cites C4 QA/known-issue):**

| Pattern | Reason | HM twist? |
|---|---|---|
| `FRONTRUN-APPROVE` | `note`: "C4 typically considers this QA/known issue". | **No.** All approvals are `forceApprove` (zero-then-set) to *immutable, trusted* targets — the strategy in `setYieldStrategy`, the pinned `newStaker` in `CrossVersionMigrator`, the immutable `staker` in `InPlaceMigrator`. No user-facing approve surface. Nothing to route. The one dangling-allowance issue (`InPlaceMigrator.migrateIn` approving its whole balance) is already ledger `f84992e9ac` and is a hygiene/doc issue, not a race. |

**Checked, no code signature present (22):** `ERC4626-INFLATION`, `ORACLE-STALE`, `ORACLE-ROUNDID`,
`SIGNATURE-REPLAY`, `FLASH-LOAN-PRICE`, `UNSAFE-DOWNCAST`, `UNPROTECTED-INIT`, `STORAGE-COLLISION`,
`MISSING-SLIPPAGE`, `SELFDESTRUCT-FORCE-ETH`, `DOUBLE-VOTING`, `PERMIT-FRONTRUN`,
`FIRST-DEPOSITOR-ATTACK`, `CROSS-CHAIN-REPLAY`, `TIMELOCK-BYPASS`, `REENTRANCY-ERC721-RECEIVE`,
`WEAK-PRNG`, `TWO-STEP-COMMIT-WINDOW`, `CENTRALIZATION-ADMIN`, plus the three reentrancy entries and
`DIVISION-PRECISION` accounted for above.

Two of these deserve a word rather than a bare "no match":
- **`UNSAFE-DOWNCAST`** — grep-verified **zero** narrowing casts and zero `SafeCast` imports across all
  five files. Every accounting variable is `uint256`. There is no `unchecked` block and no `assembly`
  outside the three `staticcall`s.
- **`CENTRALIZATION-ADMIN`** — 12 owner/migrator/pauser-gated entry points fire the signature. Under
  Law 3 the owner is trusted for knowing actions, and none of these enable a rug: `rescueERC20`'s
  `reserved` fence provably cannot reach user principal in **any** pool state, including `Migrating`
  (with `R < P` the require blocks *every* non-zero rescue outright, since `bal = R < reserved`).
  Suppressed as noise, not silently dropped.

**Errors:** none. All five in-scope files read and parsed; the pattern DB parsed cleanly (35/35 entries).
