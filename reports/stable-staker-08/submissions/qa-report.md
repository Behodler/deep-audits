# QA Report — stable-staker (run 08)

**Project:** stable-staker
**Scope:** `lib/stable-staker/src/StableStaker.sol`, `lib/stable-staker/src/StableStakerMigrator.sol`
**Audited commit:** `f85450b6d73a728f530a97854ecc882151695cd8`
**Run:** stable-staker-08 (regression)

This report bundles all QA-tier findings open against the current HEAD: Low Risk, Informational,
and the project's Centralization surface. The run's single new Medium (**M-06**,
`setYieldStrategy` underwater-swap re-arms the withdraw block) is submitted individually with a PoC
and is **not** duplicated here. The two faithfulness/spec deviations carried into this run (**F-01**,
**F-02**) are cross-listed below at honest QA severity but are authored in full in the dedicated
spec-conformance report; they are referenced, not re-derived. An automated QA/gas baseline produced
by **4naly3er** is attached as Appendix A.

All items below are carryover re-confirmations: each was first reported in an earlier run, remains
**open** in the ledger (not fixed, not triaged), and was re-confirmed present at HEAD `f85450b`.
Line numbers are updated to the current commit (story-006 / story-007 shifted them).

## Summary

| Severity | Count | Labels |
|----------|:-----:|--------|
| Low Risk | 5 | L-01 … L-05 |
| Informational | 2 | I-01, I-02 |
| Centralization | 1 | C-01 |
| **Total (Low + Info)** | **7** | |

| ID | Title | Fingerprint |
|----|-------|-------------|
| L-01 | `phUSDPerDay` sub-86,400-wei/day budget silently floors the emission rate to zero | `d47619d2` |
| L-02 | Unbounded per-user loop in `batchMigrate` / `StableStakerMigrator.migrate` (gas-bound DoS) | `59eebbf8` |
| L-03 | `rescueERC20` can sweep the buffer backing underwater withdrawals | `0790a76a` |
| L-04 | Migration credit asymmetry: `batchMigrate` haircuts where `userMigrate` keeps full value (F-01) | `4f143a95` |
| L-05 | `withdrawDisabled` view over-reports raw `_isUnderwater` after the buffer path (F-02) | `a56f8778` |
| I-01 | `initiateMigration` writes state after the external `strategy.withdraw` call (CEI ordering) | `796f775f` |
| I-02 | Unused return value of `EnumerableSet.add` / `remove` | `7b071779` |

---

## Low Risk Findings

### [L-01] `phUSDPerDay` budgets below the 86,400-wei/day floor silently set the emission rate to zero <!-- id: ss8l1 -->

**Location:** [StableStaker.sol#L167-L172](../../../lib/stable-staker/src/StableStaker.sol#L167-L172) (floor at [#L169](../../../lib/stable-staker/src/StableStaker.sol#L169); `SECONDS_PER_DAY` at [#L49](../../../lib/stable-staker/src/StableStaker.sol#L49))

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

### [L-02] Unbounded per-user loop in `batchMigrate` / `StableStakerMigrator.migrate` (gas-bound DoS) <!-- id: ss8l2 -->

**Location:** [StableStaker.sol#L447-L470](../../../lib/stable-staker/src/StableStaker.sol#L447-L470) (`batchMigrate`); [StableStakerMigrator.sol#L61-L81](../../../lib/stable-staker/src/StableStakerMigrator.sol#L61-L81) (`migrate`; external `depositFor` per user at [#L78](../../../lib/stable-staker/src/StableStakerMigrator.sol#L78))

**Status:** Re-confirmation of open ledger Low `59eebbf8`, **relocated** at run-07 from the removed
`migrateOut` to its successors (`batchMigrate` + `Migrator.migrate`); entry identity and history are
preserved, not duplicated.

**Description:** Both terminal-migration loops iterate over a caller-supplied `users[]` array and do
non-trivial per-element work — `batchMigrate` zeroes each position and mints frozen pending phUSD per
user, and `StableStakerMigrator.migrate` re-deposits each credit via an external `newStaker.depositFor`
call:

```solidity
// StableStaker.batchMigrate
for (uint256 i = 0; i < users.length; i++) {
    uint256 credit = _exitPosition(token, users[i]); // mints phUSD per user
    amounts[i] = credit;
    total += credit;
}

// StableStakerMigrator.migrate
for (uint256 i = 0; i < users.length; i++) {
    if (amounts[i] > 0) {
        newStaker.depositFor(token, users[i], amounts[i]); // external call per user
        migratedCount++;
    }
}
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

### [L-03] `rescueERC20` can sweep the buffer backing underwater withdrawals <!-- id: ss8l3 -->

**Location:** [StableStaker.sol#L725-L734](../../../lib/stable-staker/src/StableStaker.sol#L725-L734) (`rescueERC20`); at-par buffer branch reached via `_routeExit` / `withdraw`

**Description:** `rescueERC20` is guarded so the owner cannot sweep accounted user principal: it
computes a `reserved` amount and requires `bal >= reserved + amount`. However, the reserve is only
non-zero when **no** strategy is set:

```solidity
function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
    require(to != address(0), "StableStaker: zero recipient");
    uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;
    uint256 bal = IERC20(token).balanceOf(address(this));
    require(bal >= reserved + amount, "StableStaker: would touch user principal");
    IERC20(token).safeTransfer(to, amount);
    emit ERC20Rescued(token, to, amount);
}
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

### [L-04] Migration credit asymmetry — `batchMigrate` books users below principal where `userMigrate` keeps full value (F-01) <!-- id: ss8l4 -->

**Location:** [StableStaker.sol#L447-L470](../../../lib/stable-staker/src/StableStaker.sol#L447-L470) (`batchMigrate`); [StableStakerMigrator.sol#L76-L80](../../../lib/stable-staker/src/StableStakerMigrator.sol#L76-L80) (`migrate`)

**Cross-listing:** This is a Law-2 faithfulness gap authored in full as **F-01** in the dedicated
spec-conformance report ([`spec-conformance.md`](../../stable-staker-07/submissions/spec-conformance.md), run-07).
It is reproduced here at its honest QA severity (Low) so the QA bundle is complete; the
spec-conformance report remains authoritative for the faithfulness framing.

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

### [L-05] `withdrawDisabled` view over-reports raw `_isUnderwater` after the story-002 buffer path (F-02) <!-- id: ss8l5 -->

**Location:** [StableStaker.sol#L612-L617](../../../lib/stable-staker/src/StableStaker.sol#L612-L617) (`withdrawDisabled`); `_isUnderwater` at [#L666-L668](../../../lib/stable-staker/src/StableStaker.sol#L666-L668)

**Cross-listing:** This is a Law-2 faithfulness/spec gap authored in full as **F-02** in the
spec-conformance report ([`spec-conformance.md`](../../stable-staker-07/submissions/spec-conformance.md),
run-07). It is reproduced here at honest QA severity (Low) for bundle completeness; the
spec-conformance report is authoritative for the faithfulness framing.

**Description:** `withdrawDisabled` returns raw `_isUnderwater`. After story-002 made blocking a
*strict subset* of underwater (buffer-covered withdraws still succeed while underwater), the public
view's documented contract — "`true` while withdraw is blocked" — no longer holds: it **over-reports**
disabled, reading `true` in states where a buffer-covered withdraw would in fact succeed. No value is
at risk and the drift is conservative in one direction only (it never under-reports), so this is a
UX/spec false-negative.

> **Cross-reference (note):** this finding is *thematically adjacent to but opposite-direction from*
> this run's new Medium **M-06** (`dbdc3ac9`, `setYieldStrategy` underwater-swap re-arms the withdraw
> block). Both concern the `withdrawDisabled` / `_isUnderwater` signal, but they are distinct:
> **L-05/F-02** is a conservative *over*-report (the view reads `true` where a buffer-covered withdraw
> would succeed — UX false-negative, no value at risk), whereas **M-06** is the hazardous *under*-report
> (the signal is silently lifted to `false` against a real shortfall, realizing an FCFS loss). They
> are kept as separate ledger entries and separate reports.

**Impact:** UX/spec false-negative only. An off-chain UI keyed on `withdrawDisabled` may discourage a
withdraw that would have actually succeeded via the buffer. No funds at risk.

**Recommendation:** Have `withdrawDisabled` reflect the *actual* blocking predicate after the buffer
path — return `true` only when underwater **and** the buffer cannot cover the requested/expected
withdraw — or rename/redocument the view so its stated contract matches the conservative
"underwater" signal it now reports.

---

## Informational Findings

### [I-01] `initiateMigration` writes state after the external `strategy.withdraw` call (CEI ordering) <!-- id: ss8i1 -->

**Location:** [StableStaker.sol#L387-L408](../../../lib/stable-staker/src/StableStaker.sol#L387-L408) (external call via `_routeExit` at [#L387](../../../lib/stable-staker/src/StableStaker.sol#L387); `migrationInfo` write at [#L408](../../../lib/stable-staker/src/StableStaker.sol#L408))

**Description:** `initiateMigration` realizes the strategy position through the external
`strategy.withdraw` (via `_routeExit` at L387) and only afterwards writes `migrationInfo[token]` at
L408 — a write-after-call ordering that Aderyn flags HIGH and Slither flags Medium. No exploit path
exists: the function is `nonReentrant` and `onlyMigrator`, and the only external callees are the
owner-configured `IYieldStrategy` and the phUSD minter, both protocol-trusted (not
attacker-controlled). It is disposed here as Informational — deliberately preserved in a visible
channel rather than suppressed (Law 1) — so the static-tool flag has a recorded disposition.
Distinct from the now-fixed M-04 (`dc361b7d`, same function, different root cause).

**Recommendation:** Tighten to checks-effects-interactions by computing and writing the
`migrationInfo` snapshot before the external realization where feasible, or document the deliberate
ordering and the `nonReentrant` + trusted-callee mitigation in-line so future readers (and tools) do
not re-flag it.

---

### [I-02] Unused return value of `EnumerableSet.add` / `remove` <!-- id: ss8i2 -->

**Location:** [StableStaker.sol#L233-L361](../../../lib/stable-staker/src/StableStaker.sol#L233-L361) (`add` / `remove` on the staker `EnumerableSet`)

**Description:** `StableStaker` ignores the boolean success value returned by
`EnumerableSet.AddressSet.add` / `.remove`. The return signals whether membership actually changed.

**Impact:** Benign in context. `EnumerableSet` membership operations are idempotent — adding an
existing member or removing an absent member is a no-op that leaves the set in the intended state —
and the surrounding logic does not depend on the membership-delta. This is a code-quality observation
only; no security impact.

**Recommendation:** Optionally check the return value where a membership-delta is semantically
meaningful, or document that the idempotent behaviour is intentional. No change is required given the
idempotency.

---

## Centralization Risks

### [C-01] Owner / migrator privilege surface (centralization-by-design) <!-- id: ss8c1 -->

**Location:**
- `onlyOwner` setters: [addToken (#L155)](../../../lib/stable-staker/src/StableStaker.sol#L155), [phUSDPerDay (#L167)](../../../lib/stable-staker/src/StableStaker.sol#L167), [setMigrator (#L175)](../../../lib/stable-staker/src/StableStaker.sol#L175), [setPauser (#L181)](../../../lib/stable-staker/src/StableStaker.sol#L181), [setYieldStrategy (#L202)](../../../lib/stable-staker/src/StableStaker.sol#L202), [rescueERC20 (#L725)](../../../lib/stable-staker/src/StableStaker.sol#L725)
- `onlyMigrator` role: [initiateMigration (#L387)](../../../lib/stable-staker/src/StableStaker.sol#L387), [batchMigrate (#L447)](../../../lib/stable-staker/src/StableStaker.sol#L447)

**Description:** `StableStaker` is an owner-administered farm. The owner alone registers tokens,
sets each token's emission budget, wires/clears per-token yield strategies, assigns the pauser and
migrator roles, and can `rescueERC20` any non-reserved balance; the permissioned `migrator` role
drives the terminal-migration hooks. This concentration is **accepted as design** and documented as
known issue #8 (owner controls `addToken` / `phUSDPerDay` / `setPauser` / `setMigrator` /
`setYieldStrategy`). It is recorded here as the documented owner-trust surface, **not** as a defect.
Consistent with the audit's owner-trust law, this report does **not** raise
"a malicious owner could…" vectors — the owner is assumed non-malicious. 4naly3er's automated
centralization sweep (Appendix A, **M-2**, 12 instances) corroborates this same surface.

What this report *does* surface, per the footgun carve-out (Law 3), are the specific **non-obvious
owner operational hazards** open against this code, where a competent, non-malicious operator could
be surprised by the consequence of a routine privileged action. These are reported in full as their
own findings and cross-referenced here as safe-config guidance; they are not duplicated:

- **`setYieldStrategy` swapped while the old strategy is underwater** — silently lifts the
  underwater-withdraw block and converts a deferred underwater loss into a concrete FCFS principal
  loss on the last withdrawer. See **M-06** (submitted individually this run).
- **`rescueERC20` while a strategy is set** — drains the protocol-owned buffer backing at-par
  underwater withdrawals. See **L-03** above.
- **Batch migration into a haircutting destination** — books batch-migrated users below the
  principal that self-migrators keep. See **L-04 / F-01** above.
- **Sub-floor emission budget** — a positive `phUSDPerDay` below 86,400 base units silently yields a
  zero-emission pool. See **L-01** above.

(Two further migration-time footguns — `setYieldStrategy` during an active migration, and revoking
the old staker's phUSD minter mid-migration — were raised in prior runs; the former is now fixed by
story-006's `require(!migrationInfo[token].active)` guard, and the latter was triaged wont-fix as an
obvious admin step. They are noted here only for runbook continuity.)

**Impact:** No additional impact beyond the cross-referenced findings; the privilege model itself is
intended (KI#8). The residual risk is operational — an unaware operator triggering one of the
footguns above during normal administration or a migration runbook.

**Recommendation:**
1. Manage the owner key behind a multisig and, for migrations, codify the privileged sequence in a
   runbook (engage migration → migrate batches → only then decommission the old staker / re-wire
   strategies).
2. Adopt the targeted in-code guards from the individual findings — notably reserving the underwater
   buffer against `rescueERC20` (L-03) and blocking / reconciling `setYieldStrategy` swaps performed
   while a strategy is underwater (M-06).
3. Consider a timelock and/or two-step transfer (`Ownable2Step`) for the owner role and the
   migrator/pauser assignment, giving downstream integrators time to observe privileged changes
   (corroborated by 4naly3er L-1 / L-9, Appendix A).

---

## Appendix A — Automated QA / Gas Report (4naly3er)

The canonical C4-style automated analyzer **4naly3er** was re-run against the in-scope contracts at
the run-08 audited commit `f85450b`. Its full markdown output is attached alongside this report:

**[`4naly3er-report.md`](./4naly3er-report.md)**

> **Tool:** 4naly3er
> **Invocation:** `yarn analyze lib/stable-staker/src`
> **Detected scope:** `StableStaker.sol`, `StableStakerMigrator.sol`, `interfaces/IStableStaker.sol`
> **Compiler:** `solc-0.8.26` (retained in the 4naly3er toolchain under `tools/` from run-07 so the
> OpenZeppelin v5.6.1 `^0.8.24` imports compile; the read-only source repo is untouched).

Headline counts from this run: **13** Gas-optimization classes, **18** Non-Critical classes, **10**
Low-issue classes, and **2** Medium-band classes. The two Medium-band bot findings are reconciled as
follows:

- **M-1 (fee-on-transfer accounting):** a standard automated flag. Fee-on-transfer / non-standard
  tokens are a documented known-invalid category for this project (no FoT token is in scope), so it
  is not promoted to a manual finding.
- **M-2 (centralization risk for trusted owners, 12 instances):** the same privilege surface
  manually adjudicated above as **C-01**; the bot flag corroborates it and is not separately listed.

Where a bot Low overlaps a manual finding it has been folded in and is **not** double-counted:

- **L-4 (division by zero, 3 instances)** relates to the `phUSDPerDay` floor behaviour analysed in
  **L-01**.
- **L-10 (sweeping may break accounting)** relates to the `rescueERC20` concern analysed in **L-03**.
- The bot's unbounded-loop / external-call-in-loop flag relates to **L-02**.
- **L-1 / L-9 (two-step ownership)** inform the C-01 governance recommendation.

The remaining 4naly3er output (style, gas, NatSpec, `address(0)` checks, precision-loss, `PUSH0`,
etc.) is automated baseline retained verbatim in the appendix for completeness rather than re-listed
here. Treat the manual findings above as authoritative; the automated output is informational and is
**not** hand-verified.
