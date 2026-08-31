# QA Report — stable-staker (run 09)

**Project:** stable-staker
**Scope:** `lib/stable-staker/src/StableStaker.sol`, `lib/stable-staker/src/StableStakerMigrator.sol`
**Audited commit:** `93b7ce6ebe31f71c70a5841e074cdbfad9bced91` (story-009 — pool lifecycle state machine + `finalizeAndReset`)
**Run:** stable-staker-09 (regression)

This report bundles all QA-tier findings open against the current HEAD: Low Risk, Informational, and
the project's Centralization surface. It is a regression bundle on top of run-08: the only **new**
QA-tier finding this run is **L-01** (`finalizeAndReset` revival footgun introduced by story-009).
The remaining Low / Info items are carryover re-confirmations — each was first reported in an earlier
run, remains **open** in the ledger (not fixed, not triaged), and was re-confirmed present at HEAD
`93b7ce6`; their line numbers are updated for the story-009 shift.

Out of this report by design:

- This run's new Medium (**M-07**) is submitted individually with a PoC and is **not** duplicated here.
- The two carryover Mediums (**M-01** `dab5a656`, **M-05** `0dca43f3`) are tracked as carryover stubs,
  not QA items.
- The Law-2 faithfulness deviation **F-03** (and the carryover **F-01 / F-02**) are authored in the
  dedicated **spec-conformance** report; F-01 / F-02 are cross-listed below at honest QA severity for
  bundle completeness (as L-05 / L-06) but the spec-conformance report is authoritative for the
  faithfulness framing. F-03 is **not** absorbed here.
- **M-06 / M-02 / M-04** are fixed or acknowledged and are not re-reported.

An automated QA/gas baseline produced by **4naly3er** is attached as Appendix A.

## Summary

| Severity | Count | Labels |
|----------|:-----:|--------|
| Low Risk | 6 | L-01 … L-06 |
| Informational | 4 | INFO-01 … INFO-04 |
| Centralization | 1 | C-01 |
| **Total (Low + Info + C)** | **11** | |

| ID | Title | Fingerprint | Status |
|----|-------|-------------|--------|
| L-01 | `finalizeAndReset` carries over `phusdPerSecond` and leaves `yieldStrategy = 0` (revival footgun) | *new (story-009)* | new |
| L-02 | `phUSDPerDay` sub-86,400-wei/day budget silently floors the emission rate to zero | `d47619d2` | carryover-open |
| L-03 | Unbounded per-user loop in `batchMigrate` / `StableStakerMigrator.migrate` (gas-bound DoS) | `59eebbf8` | carryover-open |
| L-04 | `rescueERC20` can sweep the buffer backing underwater withdrawals | `0790a76a` | carryover-open |
| L-05 | Migration credit asymmetry: `batchMigrate` haircuts where `userMigrate` keeps full value (F-01) | `4f143a95` | carryover-open |
| L-06 | `withdrawDisabled` view over-reports raw `_isUnderwater` after the buffer path (F-02) | `a56f8778` | carryover-open |
| INFO-01 | Workspace PoCs (`PoC_M02/M03/M04`) bit-rotted against the story-009 `MigrationInfo` struct | *workspace-only* | new |
| INFO-02 | 4naly3er automated baseline surfaced no new actionable QA item beyond known-invalid noise | *tooling* | new |
| INFO-03 | `initiateMigration` writes state after the external `strategy.withdraw` call (CEI ordering) | `796f775f` | carryover-open |
| INFO-04 | Unused return value of `EnumerableSet.add` / `remove` | `7b071779` | carryover-open |

---

## Low Risk Findings

### [L-01] `finalizeAndReset` carries over `phusdPerSecond` and leaves `yieldStrategy = 0` (revival footgun) <!-- id: ss9l1 -->

**Location:** [StableStaker.sol#L585-L596](../../../lib/stable-staker/src/StableStaker.sol#L585-L596) (`finalizeAndReset`); sole `phusdPerSecond` writer at [phUSDPerDay #L186-L187](../../../lib/stable-staker/src/StableStaker.sol#L186-L187); strategy zeroed during [initiateMigration #L449](../../../lib/stable-staker/src/StableStaker.sol#L449)

**Status:** New this run — introduced by story-009 (`93b7ce6`), which added `finalizeAndReset` to
revive a fully-drained migrating pool back to `Active`.

**Description:** `finalizeAndReset` is the revival path for a pool whose terminal migration has fully
drained (`stakerCount == 0`, `totalStaked == 0`). It clears the migration snapshot, fast-forwards
`lastRewardTime` to `now`, and flips `poolState` back to `Active`:

```solidity
function finalizeAndReset(address token) external onlyOwner poolExists(token) {
    require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");
    require(_stakers[token].length() == 0, "StableStaker: stakers remain");
    require(poolInfo[token].totalStaked == 0, "StableStaker: principal remains");

    migrationInfo[token] = MigrationInfo({realized: 0, principalSnapshot: 0});
    poolInfo[token].lastRewardTime = block.timestamp;
    poolState[token] = PoolState.Active;
    emit PoolReset(token);
}
```

Two pieces of pre-migration state survive this "reset" and are easy to overlook:

1. **`phusdPerSecond` is not cleared.** Its sole writer is `phUSDPerDay` (L186-L187); `finalizeAndReset`
   never touches it, so the *pre-migration* emission rate carries straight over into the revived pool.
2. **`yieldStrategy[token]` is `address(0)`.** `initiateMigration` already zeroed it (L449) when it
   decoupled the strategy, so the revived pool has **no** strategy wired until the owner re-runs
   `setYieldStrategy`.

**Consequence (footgun).** The revival runbook treats re-setting `phUSDPerDay` as optional ("maybe"),
because the rate already looks configured. If the operator skips it, the **first re-staker** after
revival accrues the carried-over per-day emission against a near-zero `totalStaked` denominator and
over-collects emissions relative to what the operator believes is configured for the freshly-revived
pool. Separately, until `setYieldStrategy` is re-run the pool silently runs in idle-hold mode (no
yield routing), which a competent operator may not expect of a pool that previously had a strategy.

This is a genuine Law-3 footgun, not a malicious-owner vector: revival is a rare operation and a
competent, non-malicious operator could reasonably be surprised that a method named `…AndReset`
silently retains a live emission rate and a zeroed strategy.

**Impact (why Low, not Medium):** The core emission-cap invariant is **not** violated — emissions
remain bounded by the last `phUSDPerDay` rate (the only writer of `accPhusdPerShare`, `_updatePool`,
still folds in exactly `elapsed * phusdPerSecond`). No user principal is at risk. The harm is bounded
over-emission of phUSD during the post-reset / pre-rewire window, hence Low / operational hazard.

**Recommendation:**
1. **Safe-config (runbook, mandatory steps):** keep the pool **paused** across the entire revival
   sequence and treat re-wiring as mandatory, not optional:
   `pause → finalizeAndReset → setYieldStrategy(token, freshStrategy) → phUSDPerDay(token, budget) → unpause`.
   With the pool paused, no staker can enter the post-reset / pre-rewire window.
2. **Optional hardening (in-code):** have `finalizeAndReset` defensively zero the carried-over rate so
   a revived pool starts cold and cannot over-emit before the operator re-sets the budget:

```solidity
poolInfo[token].phusdPerSecond = 0; // require an explicit phUSDPerDay re-set on revival
```

---

### [L-02] `phUSDPerDay` budgets below the 86,400-wei/day floor silently set the emission rate to zero <!-- id: ss9l2 -->

**Location:** [StableStaker.sol#L184-L189](../../../lib/stable-staker/src/StableStaker.sol#L184-L189) (floor at [#L186](../../../lib/stable-staker/src/StableStaker.sol#L186); `SECONDS_PER_DAY` at [#L49](../../../lib/stable-staker/src/StableStaker.sol#L49))

**Status:** Carryover re-confirmation of open ledger Low `d47619d2`, present at HEAD `93b7ce6`.

**Description:** `phUSDPerDay` converts a daily budget to a per-second rate by integer division:

```solidity
function phUSDPerDay(address token, uint256 amountPerDay) external onlyOwner poolExists(token) {
    _updatePool(token);
    uint256 perSecond = amountPerDay / SECONDS_PER_DAY; // SECONDS_PER_DAY = 86400
    poolInfo[token].phusdPerSecond = perSecond;
    emit RewardRateSet(token, amountPerDay, perSecond);
}
```

Any positive `amountPerDay` strictly below `SECONDS_PER_DAY` (86,400 base units) floors `perSecond`
to `0`. The pool then emits **zero** phUSD with no revert, and `RewardRateSet` reports an
`(amountPerDay, 0)` pair — stakers accrue nothing while the operator believes a live budget is
configured. This is the residual silent-zero edge of the rounding behaviour; the ordinary
round-*down* dust (where `perSecond > 0`) is a documented, accepted known issue (#2 / wont-fix
`35e9be8d`) and is **not** re-reported here.

This is a non-obvious owner-config footgun (Law 3): a competent operator would be surprised that a
positive daily budget produces a silent zero-emission pool. For realistic 18-decimal phUSD budgets
the value at risk is negligible, hence Low.

**Recommendation:** Reject a budget that floors to zero so the failure is loud rather than silent:

```solidity
uint256 perSecond = amountPerDay / SECONDS_PER_DAY;
require(amountPerDay == 0 || perSecond > 0, "StableStaker: budget below per-second floor");
```

(Allow `amountPerDay == 0` if explicitly pausing emissions is intended.) Alternatively store the
rate at higher precision (scale the numerator) so sub-floor budgets round to a non-zero rate.

---

### [L-03] Unbounded per-user loop in `batchMigrate` / `StableStakerMigrator.migrate` (gas-bound DoS) <!-- id: ss9l3 -->

**Location:** [StableStaker.sol#L481-L508](../../../lib/stable-staker/src/StableStaker.sol#L481-L508) (`batchMigrate`; per-user exit at [#L494](../../../lib/stable-staker/src/StableStaker.sol#L494)); [StableStakerMigrator.sol#L61-L81](../../../lib/stable-staker/src/StableStakerMigrator.sol#L61-L81) (`migrate`; external `depositFor` per user at [#L78](../../../lib/stable-staker/src/StableStakerMigrator.sol#L78))

**Status:** Carryover re-confirmation of open ledger Low `59eebbf8`, present at HEAD `93b7ce6`.

**Description:** Both terminal-migration loops iterate over a caller-supplied `users[]` array and do
non-trivial per-element work — `batchMigrate` zeroes each position and mints frozen pending phUSD per
user (via `_exitPosition`), and `StableStakerMigrator.migrate` re-deposits each credit via an external
`newStaker.depositFor` call:

```solidity
// StableStaker.batchMigrate
uint256 credit = _exitPosition(token, users[i]); // mints phUSD per user

// StableStakerMigrator.migrate
newStaker.depositFor(token, users[i], amounts[i]); // external call per user
```

A sufficiently large batch can exceed the block gas limit and revert. Impact is limited to liveness:
the calls are `onlyMigrator` / `onlyOwner` (operator-controlled), there is no per-user
transfer-to-arbitrary-recipient a single failing user could exploit to brick the whole batch, and
the contract already ships the pagination helpers `getStakers` / `getStakersRange` so the operator
can size batches off-chain. Under the trusted-operator model this is Low.

**Recommendation:** No code change is strictly required given operator control and pagination.
Document a recommended maximum batch size and have the off-chain migration tooling page the staker
set via `getStakersRange(token, start, end)` rather than passing the full set in a single call.

---

### [L-04] `rescueERC20` can sweep the buffer backing underwater withdrawals <!-- id: ss9l4 -->

**Location:** [StableStaker.sol#L799-L808](../../../lib/stable-staker/src/StableStaker.sol#L799-L808) (`rescueERC20`; reserve computed at [#L801](../../../lib/stable-staker/src/StableStaker.sol#L801)); at-par buffer branch reached via `_routeExit` / `withdraw`

**Status:** Carryover re-confirmation of open ledger Low `0790a76a`, present at HEAD `93b7ce6`.

**Description:** `rescueERC20` is guarded so the owner cannot sweep accounted user principal: it
computes a `reserved` amount and requires `bal >= reserved + amount`. However, the reserve is only
non-zero when **no** strategy is set:

```solidity
uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;
uint256 bal = IERC20(token).balanceOf(address(this));
require(bal >= reserved + amount, "StableStaker: would touch user principal");
```

When a yield strategy is set, principal lives inside the strategy and `reserved` collapses to `0`,
so the owner may sweep the **entire on-contract balance**. That balance is exactly the
protocol-owned buffer that backs at-par underwater withdrawals via the `_routeExit` buffer branch.
Sweeping it does not steal accounted user principal (the swept funds are protocol-owned), but it
removes the backstop that lets pending underwater withdrawals settle at par.

**Impact:** A non-obvious owner footgun (Law 3): a routine rescue performed while a strategy is set
drains the at-par underwater backstop, flipping in-flight buffer withdrawals to revert
(`StableStaker: strategy underwater`) during the precise window users most need the at-par exit.
Owner-only; no theft of user principal — hence Low rather than a centralization defect (the
privilege itself is intended; see C-01).

**Recommendation:** When a strategy is set, reserve the buffer that backs at-par exits rather than
reserving `0`, e.g. compute a non-zero reserve from the strategy's reported shortfall
(`max(0, principalOf - totalBalanceOf)`) so the buffer cannot be swept while underwater.
Alternatively, explicitly document the on-contract balance as discretionary protocol funds not
guaranteed to back underwater withdrawals.

---

### [L-05] Migration credit asymmetry — `batchMigrate` books users below principal where `userMigrate` keeps full value (F-01) <!-- id: ss9l5 -->

**Location:** [StableStaker.sol#L481-L508](../../../lib/stable-staker/src/StableStaker.sol#L481-L508) (`batchMigrate`); [StableStakerMigrator.sol#L76-L80](../../../lib/stable-staker/src/StableStakerMigrator.sol#L76-L80) (`migrate`); destination crediting in [`_routeDeposit` #L748](../../../lib/stable-staker/src/StableStaker.sol#L748)

**Status:** Carryover re-confirmation of open ledger Low `4f143a95`, present at HEAD `93b7ce6`.

**Cross-listing:** This is a Law-2 faithfulness gap authored in full as **F-01** in the dedicated
spec-conformance report. It is reproduced here at its honest QA severity (Low) so the QA bundle is
complete; the spec-conformance report remains authoritative for the faithfulness framing.

**Description:** Batch-migrated users are booked below their old-staker principal:
`StableStakerMigrator.migrate` redeposits each credit via `newStaker.depositFor` → `_routeDeposit`,
which a haircutting destination strategy reduces to `credited = amount * (1 - slip)`. A user who
instead self-exits via `userMigrate` receives tokens at full credit. Equal-principal users therefore
diverge purely by exit method, breaking the migrator's principal-preservation / equivalence story.
The magnitude equals the destination's `slippageToleranceBps` and is zero when the destination
strategy is idle / full-credit at migration time.

**Impact:** Deposit-side principal-preservation break (Law-2 faithfulness gap). Bounded by the
destination slippage tolerance and config-dependent, so honest severity is Low. Non-obvious owner
footgun: an operator running a batch migration into a freshly-wired haircutting strategy would not
expect batch-migrated users to be credited less than self-migrators.

**Recommendation:** Make the two migration paths credit-equivalent — credit batch-migrated users at
full pre-migration principal (book the destination haircut against protocol surplus rather than the
user), or migrate batches only into a non-haircutting / idle destination so `slip = 0` at migration
time. At minimum, document that batch and self migration are not credit-equivalent through a
haircutting destination.

---

### [L-06] `withdrawDisabled` view over-reports raw `_isUnderwater` after the story-002 buffer path (F-02) <!-- id: ss9l6 -->

**Location:** [StableStaker.sol#L686-L691](../../../lib/stable-staker/src/StableStaker.sol#L686-L691) (`withdrawDisabled`); `_isUnderwater` at [#L740](../../../lib/stable-staker/src/StableStaker.sol#L740)

**Status:** Carryover re-confirmation of open ledger Low `a56f8778`, present at HEAD `93b7ce6`.

**Cross-listing:** This is a Law-2 faithfulness/spec gap authored in full as **F-02** in the
spec-conformance report. It is reproduced here at honest QA severity (Low) for bundle completeness;
the spec-conformance report is authoritative for the faithfulness framing.

**Description:** `withdrawDisabled` returns raw `_isUnderwater`. After story-002 made blocking a
*strict subset* of underwater (buffer-covered withdraws still succeed while underwater), the public
view's documented contract — "`true` while withdraw is blocked" — no longer holds: it **over-reports**
disabled, reading `true` in states where a buffer-covered withdraw would in fact succeed. No value is
at risk and the drift is conservative in one direction only (it never under-reports), so this is a
UX/spec false-negative.

**Impact:** UX/spec false-negative only. An off-chain UI keyed on `withdrawDisabled` may discourage a
withdraw that would have actually succeeded via the buffer. No funds at risk.

**Recommendation:** Have `withdrawDisabled` reflect the *actual* blocking predicate after the buffer
path — return `true` only when underwater **and** the buffer cannot cover the requested/expected
withdraw — or rename/redocument the view so its stated contract matches the conservative
"underwater" signal it now reports.

---

## Informational Findings

### [INFO-01] Workspace PoCs (`PoC_M02 / M03 / M04`) bit-rotted against the story-009 `MigrationInfo` struct <!-- id: ss9i1 -->

**Location (workspace only — `lib/` untouched):**
`workspace/stable-staker/test/PoC_M02_SetStrategyDuringMigration.t.sol:72`,
`PoC_M03_TerminalExitNotMintFree.t.sol:59`,
`PoC_M04_BufferDesyncBricksMigration.t.sol:99`

**Description:** story-009 replaced the old `MigrationInfo` struct (a 3-field shape exposing a leading
`bool active`) with a 2-field struct, and moved the active/Migrating signal onto the new `poolState`
enum:

```solidity
struct MigrationInfo {
    uint256 realized;          // R
    uint256 principalSnapshot; // P
}
```

The three named PoC files still destructure the public `migrationInfo(...)` getter as a 3-tuple
`(bool active, uint256 R, uint256 P)`, which no longer type-checks and breaks whole-suite
`forge test` compilation in the workspace:

```solidity
(bool active, uint256 R, uint256 Psnap) = staker.migrationInfo(address(dai)); // stale 3-tuple
```

**Impact:** Cosmetic / workspace-only. These three PoCs back findings that are now **fixed**
(M-04 `dc361b7d`) or **wont-fix** (M-03 `e4567dc3`), so the bit-rot does not affect any live finding —
it only blocks a clean whole-suite compile in the writable workspace. The read-only `lib/` submodule
is not involved.

**Recommendation:** Apply the one-line destructure fix to each (read `poolState[token] == Migrating`
for the active signal and take `(uint256 R, uint256 P)` from the 2-tuple getter), or `--skip` the
three retired PoCs so the suite compiles. No production code change.

---

### [INFO-02] 4naly3er automated baseline surfaced no new actionable QA item beyond known-invalid noise <!-- id: ss9i2 -->

**Description:** The 4naly3er automated QA/gas sweep (Appendix A) was run on the in-scope contracts at
HEAD `93b7ce6`. Its output is the standard bot baseline — Gas optimizations, Non-Critical style/NatSpec
notes, Low-band items, and two Medium-band classes. None of it promotes to a new manual finding:

- The Medium-band **M-1 (fee-on-transfer accounting)** maps to the project's documented known-invalid
  category (no FoT / non-standard token is in scope) and is not promoted.
- The Medium-band **M-2 (centralization risk for trusted owners, 13 instances)** is the same privilege
  surface adjudicated below as **C-01**; the bot flag corroborates it and is not separately listed.
- The contract checks the boolean return of `EnumerableSet.add` for token registration, so 4naly3er
  did **not** raise an unused-return flag there; the only unused-`EnumerableSet`-return observation
  remains the staker-set add/remove case already tracked as **INFO-04**.

The remaining bot Lows fold into existing manual findings without double-counting (division-by-zero ⇒
L-02; sweeping-breaks-accounting ⇒ L-04; unbounded-loop ⇒ L-03; two-step-ownership ⇒ C-01 guidance).
Recorded here so the automated baseline has an explicit, visible disposition rather than being
silently dropped.

---

### [INFO-03] `initiateMigration` writes state after the external `strategy.withdraw` call (CEI ordering) <!-- id: ss9i3 -->

**Location:** [StableStaker.sol#L417-L461](../../../lib/stable-staker/src/StableStaker.sol#L417-L461) (external realization via `_routeExit` at [#L435](../../../lib/stable-staker/src/StableStaker.sol#L435); `migrationInfo` write at [#L460](../../../lib/stable-staker/src/StableStaker.sol#L460))

**Status:** Carryover re-confirmation of open ledger Info `796f775f`, present at HEAD `93b7ce6`.

**Description:** `initiateMigration` realizes the strategy position through the external
`strategy.withdraw` (via `_routeExit`) and only afterwards writes `migrationInfo[token]` /
`poolState[token]` — a write-after-call ordering that Aderyn flags HIGH and Slither flags Medium. No
exploit path exists: the function is `nonReentrant` and `onlyMigrator`, and the only external callees
are the owner-configured `IYieldStrategy` and the phUSD minter, both protocol-trusted (not
attacker-controlled). It is disposed here as Informational — deliberately preserved in a visible
channel rather than suppressed (Law 1) — so the static-tool flag has a recorded disposition. Distinct
from the now-fixed M-04 (`dc361b7d`, same function, different root cause).

**Recommendation:** Tighten to checks-effects-interactions by computing and writing the snapshot before
the external realization where feasible, or document the deliberate ordering and the `nonReentrant` +
trusted-callee mitigation in-line so future readers (and tools) do not re-flag it.

---

### [INFO-04] Unused return value of `EnumerableSet.add` / `remove` <!-- id: ss9i4 -->

**Location:** [StableStaker.sol#L658](../../../lib/stable-staker/src/StableStaker.sol#L658) (`add` / `remove` on the staker `EnumerableSet`)

**Status:** Carryover re-confirmation of open ledger Info `7b071779`, present at HEAD `93b7ce6`.

**Description:** `StableStaker` ignores the boolean success value returned by
`EnumerableSet.AddressSet.add` / `.remove` on the per-token staker set. The return signals whether
membership actually changed.

**Impact:** Benign in context. `EnumerableSet` membership operations are idempotent — adding an
existing member or removing an absent member is a no-op that leaves the set in the intended state —
and the surrounding logic does not depend on the membership-delta. Code-quality observation only; no
security impact.

**Recommendation:** Optionally check the return value where a membership-delta is semantically
meaningful, or document that the idempotent behaviour is intentional. No change is required given the
idempotency.

---

## Centralization Risks

### [C-01] Owner / migrator privilege surface (centralization-by-design) <!-- id: ss9c1 -->

**Location:**
- `onlyOwner` setters: [addToken (#L172)](../../../lib/stable-staker/src/StableStaker.sol#L172), [phUSDPerDay (#L184)](../../../lib/stable-staker/src/StableStaker.sol#L184), [setMigrator (#L192)](../../../lib/stable-staker/src/StableStaker.sol#L192), [setPauser (#L198)](../../../lib/stable-staker/src/StableStaker.sol#L198), [setYieldStrategy (#L219)](../../../lib/stable-staker/src/StableStaker.sol#L219), [finalizeAndReset (#L585)](../../../lib/stable-staker/src/StableStaker.sol#L585), [rescueERC20 (#L799)](../../../lib/stable-staker/src/StableStaker.sol#L799)
- `onlyMigrator` role: [initiateMigration (#L417)](../../../lib/stable-staker/src/StableStaker.sol#L417), [batchMigrate (#L481)](../../../lib/stable-staker/src/StableStaker.sol#L481)

**Description:** `StableStaker` is an owner-administered farm. The owner alone registers tokens, sets
each token's emission budget, wires/clears per-token yield strategies, assigns the pauser and migrator
roles, can `rescueERC20` any non-reserved balance, and — new this run — can revive a drained migrating
pool via `finalizeAndReset`; the permissioned `migrator` role drives the terminal-migration hooks.
This concentration is **accepted as design** and documented as known issue #8 (owner controls
`addToken` / `phUSDPerDay` / `setPauser` / `setMigrator` / `setYieldStrategy`). It is recorded here as
the documented owner-trust surface, **not** as a defect. Consistent with the audit's owner-trust law,
this report does **not** raise "a malicious owner could…" vectors — the owner is assumed
non-malicious. 4naly3er's automated centralization sweep (Appendix A, **M-2**, 13 instances)
corroborates this same surface.

What this report *does* surface, per the footgun carve-out (Law 3), are the specific **non-obvious
owner operational hazards** open against this code, where a competent, non-malicious operator could be
surprised by the consequence of a routine privileged action. These are reported in full as their own
findings and cross-referenced here as safe-config guidance; they are not duplicated:

- **`finalizeAndReset` revival** — silently retains the pre-migration emission rate and leaves the
  pool with no strategy until re-wired, over-emitting to the first re-staker if the budget re-set is
  skipped. See **L-01** above (new this run).
- **`rescueERC20` while a strategy is set** — drains the protocol-owned buffer backing at-par
  underwater withdrawals. See **L-04** above.
- **Batch migration into a haircutting destination** — books batch-migrated users below the principal
  that self-migrators keep. See **L-05 / F-01** above.
- **Sub-floor emission budget** — a positive `phUSDPerDay` below 86,400 base units silently yields a
  zero-emission pool. See **L-02** above.

(Prior migration-time footguns — `setYieldStrategy` during an active migration, the underwater-swap
re-arm, and revoking the old staker's phUSD minter mid-migration — were raised in earlier runs; the
`setYieldStrategy`-during-migration case is fixed by the lifecycle/`!Migrating` guard, the
underwater-swap case is tracked as the acknowledged **M-06** `dbdc3ac9`, and the minter-revoke case
was triaged wont-fix as an obvious admin step. Noted here only for runbook continuity.)

**Impact:** No additional impact beyond the cross-referenced findings; the privilege model itself is
intended (KI#8). The residual risk is operational — an unaware operator triggering one of the footguns
above during normal administration, a migration runbook, or a pool revival.

**Recommendation:**
1. Manage the owner key behind a multisig and codify the privileged sequences in runbooks. For pool
   revival specifically, keep the pool paused across the whole
   `finalizeAndReset → setYieldStrategy → phUSDPerDay → unpause` sequence (L-01). For migrations,
   engage migration → migrate batches → only then decommission the old staker / re-wire strategies.
2. Adopt the targeted in-code guards from the individual findings — notably reserving the underwater
   buffer against `rescueERC20` (L-04) and defensively zeroing `phusdPerSecond` in `finalizeAndReset`
   (L-01).
3. Consider a timelock and/or two-step transfer (`Ownable2Step`) for the owner role and the
   migrator/pauser assignment, giving downstream integrators time to observe privileged changes
   (corroborated by 4naly3er L-1 / L-9, Appendix A).

---

## Appendix A — Automated QA / Gas Report (4naly3er)

The canonical C4-style automated analyzer **4naly3er** was run against the in-scope contracts at the
run-09 audited commit `93b7ce6`. Its full markdown output is attached alongside this report:

**[`4naly3er-report.md`](./4naly3er-report.md)**

> **Tool:** 4naly3er (`tools/4naly3er`, git `8a9d1eb`, 2024-02-16; package `1.0.0`)
> **Invocation:** `yarn analyze workspace/stable-staker/ <scope.txt> https://github.com/Behodler/stable-staker/blob/93b7ce6`
> (built from the writable `workspace/` clone synced to `93b7ce6`; the read-only `lib/` source repo is
> untouched. The scope file lists `src/StableStaker.sol` + `src/StableStakerMigrator.sol`.)
> **Detected scope:** `src/StableStaker.sol`, `src/StableStakerMigrator.sol`

Headline counts from this run: **13** Gas-optimization classes, **18** Non-Critical classes, **10**
Low-issue classes, and **2** Medium-band classes. Reconciliation of the Medium-band and the
overlapping Low-band bot flags is recorded in **INFO-02** above (FoT ⇒ known-invalid; centralization
⇒ C-01; division-by-zero ⇒ L-02; sweep-accounting ⇒ L-04; unbounded-loop ⇒ L-03; two-step-ownership
⇒ C-01 guidance).

The remaining 4naly3er output (style, gas, NatSpec, `address(0)` checks, precision-loss, `PUSH0`,
etc.) is automated baseline retained verbatim in the attached appendix for completeness rather than
re-listed here. Treat the manual findings above as authoritative; the automated output is
informational and is **not** hand-verified.

> Note: the generated github links in the appendix carry a tool-formatting artifact (the trailing
> slash after the commit hash is omitted, yielding `…/blob/93b7ce6src/…`); the intended path is
> `…/blob/93b7ce6/src/…`. This is cosmetic and does not affect the analysis content.
