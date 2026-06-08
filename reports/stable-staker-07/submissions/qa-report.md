# QA Report — stable-staker (run 07)

**Project:** stable-staker
**Scope:** `lib/stable-staker/src/StableStaker.sol`, `lib/stable-staker/src/StableStakerMigrator.sol`
**Audited commit:** `7e9ef80a916081148e28df60ef6daf83c9157a3b`
**Run:** stable-staker-07

This report bundles all QA-tier findings: Low Risk, Informational, and the project's
Centralization surface. High/Medium findings (M-01..M-05) are submitted individually with PoCs,
and the two faithfulness/spec deviations (F-01, F-02) are routed to the dedicated
spec-conformance report — neither is duplicated here. An automated QA/gas baseline produced by
**4naly3er** is attached as Appendix A.

## Summary

| Severity | Count | Labels |
|----------|:-----:|--------|
| Low Risk | 2 | L-01, L-02 |
| Informational | 1 | L-03 |
| Centralization | 1 | C-01 |
| **Total** | **4** | |

---

## Low Risk Findings

### [L-01] `phUSDPerDay` budgets below the 86,400-wei/day floor silently set the emission rate to zero <!-- id: ss7l1 -->

**Location:** [StableStaker.sol#L167-L172](../../../lib/stable-staker/src/StableStaker.sol#L167-L172) (`SECONDS_PER_DAY` at [#L49](../../../lib/stable-staker/src/StableStaker.sol#L49))

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
to `0`. The pool then emits **zero** phUSD with no revert, and the `RewardRateSet` event reports a
`(amountPerDay, 0)` pair — stakers accrue nothing while the operator believes a live budget is
configured. This is the residual silent-zero edge of the rounding behaviour; the ordinary
round-*down* dust (where `perSecond > 0`) is a documented, accepted known issue (#2 / wont-fix
`35e9be8d`) and is not re-reported here.

This is a non-obvious owner-config footgun (Law 3): a competent operator would be surprised that a
positive daily budget produces a silent zero-emission pool. For realistic 18-decimal phUSD budgets
the value at risk is negligible, hence Low.

**Recommendation:** Reject a budget that floors to zero, so the failure is loud rather than silent:

```solidity
uint256 perSecond = amountPerDay / SECONDS_PER_DAY;
require(amountPerDay == 0 || perSecond > 0, "StableStaker: budget below per-second floor");
```

(Allow `amountPerDay == 0` if explicitly pausing emissions is intended.) Alternatively store the
rate at higher precision (scale the numerator) so sub-floor budgets round to a non-zero rate.

---

### [L-02] Unbounded per-user loop in `batchMigrate` / `StableStakerMigrator.migrate` (gas-bound DoS) <!-- id: ss7l2 -->

**Location:** [StableStaker.sol#L440-L445](../../../lib/stable-staker/src/StableStaker.sol#L440-L445) (per-user mint in `_exitPosition` at [#L479-L481](../../../lib/stable-staker/src/StableStaker.sol#L479-L481)); [StableStakerMigrator.sol#L65-L81](../../../lib/stable-staker/src/StableStakerMigrator.sol#L65-L81)

**Status:** Re-confirmation of open ledger Low `59eebbf8`, **relocated** from the removed
`migrateOut` to its successors (`batchMigrate` + `Migrator.migrate`). The ledger entry should be
relocated, not duplicated.

**Description:** Both terminal-migration loops iterate over a caller-supplied `users[]` array and do
non-trivial per-element work — `batchMigrate` zeroes each position and mints frozen pending phUSD
per user, and `StableStakerMigrator.migrate` re-deposits each credit via an external
`newStaker.depositFor` call:

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
transfer-to-arbitrary-recipient that a single failing user could exploit to brick the whole batch,
and the contract already ships the pagination helpers `getStakers` / `getStakersRange` so the
operator can size batches off-chain. Under the trusted-operator model this is Low.

**Recommendation:** No code change is strictly required given operator control and pagination.
Document a recommended maximum batch size, and have the off-chain migration tooling page the staker
set via `getStakersRange(token, start, end)` rather than passing the full set in a single call.

---

## Informational Findings

### [L-03] `initiateMigration` writes state after the external `strategy.withdraw` call (CEI ordering) <!-- id: ss7l3 -->

**Location:** [StableStaker.sol#L369-L409](../../../lib/stable-staker/src/StableStaker.sol#L369-L409) (external call via `_routeExit` at [#L387](../../../lib/stable-staker/src/StableStaker.sol#L387); state write at [#L408](../../../lib/stable-staker/src/StableStaker.sol#L408))

**Description:** `initiateMigration` realizes the strategy position through the external
`strategy.withdraw` (via `_routeExit` at L387) and only afterwards writes `migrationInfo[token]` at
L408 — a write-after-call ordering that Aderyn flags HIGH and Slither flags Medium. No exploit path
exists: the function is `nonReentrant` and `onlyMigrator`, and the only external callees are the
owner-configured `IYieldStrategy` and the phUSD minter, both protocol-trusted (not
attacker-controlled). It is disposed here as Informational for completeness and CEI hygiene rather
than suppressed, so the static-tool flag has a visible disposition.

**Recommendation:** Tighten to checks-effects-interactions by computing and writing the
`migrationInfo` snapshot before the external realization where feasible, or document the deliberate
ordering and the `nonReentrant` + trusted-callee mitigation in-line so future readers (and tools) do
not re-flag it.

---

## Centralization Risks

### [C-01] Owner / migrator privilege surface (centralization-by-design) <!-- id: ss7c1 -->

**Location:**
- `onlyOwner` setters: [addToken (#L155)](../../../lib/stable-staker/src/StableStaker.sol#L155), [phUSDPerDay (#L167)](../../../lib/stable-staker/src/StableStaker.sol#L167), [setMigrator (#L175)](../../../lib/stable-staker/src/StableStaker.sol#L175), [setPauser (#L181)](../../../lib/stable-staker/src/StableStaker.sol#L181), [setYieldStrategy (#L198)](../../../lib/stable-staker/src/StableStaker.sol#L198), [rescueERC20 (#L706)](../../../lib/stable-staker/src/StableStaker.sol#L706)
- `onlyMigrator` role: [initiateMigration (#L369)](../../../lib/stable-staker/src/StableStaker.sol#L369), [batchMigrate (#L429)](../../../lib/stable-staker/src/StableStaker.sol#L429)

**Description:** `StableStaker` is an owner-administered farm. The owner alone registers tokens,
sets each token's emission budget, wires/clears per-token yield strategies, assigns the pauser and
migrator roles, and can `rescueERC20` any non-reserved balance; the permissioned `migrator` role
drives the terminal-migration hooks. This concentration is **accepted as design** and documented as
known issue #8. Consistent with the audit's owner-trust law, this report does **not** raise
"a malicious owner could…" vectors — the owner is assumed non-malicious.

What this report does surface, per the footgun carve-out, are the specific **non-obvious owner
operational hazards** discovered this run, where a competent, non-malicious operator could be
surprised by the consequence of a routine privileged action. These are reported in full elsewhere
and cross-referenced here as safe-config guidance; they are not duplicated:

- **`setYieldStrategy` during an active terminal migration** — wiring a strategy onto a token that
  is mid-migration sweeps the realized payout pile back into the strategy, bricking the
  `userMigrate` escape hatch and stranding migrants' principal. See **M-02** (missing `!active`
  guard on `setYieldStrategy`).
- **Revoking the old staker's phUSD minter mid-migration** — the terminal exit mints frozen pending
  phUSD before transferring principal, so a decommissioning step that revokes minter rights traps
  in-flight migrants' principal until rights are restored. See **M-03**.
- **Sub-floor emission budget** — a positive `phUSDPerDay` below 86,400 base units silently yields a
  zero-emission pool. See **L-01** above.

**Impact:** No additional impact beyond the cross-referenced findings; the privilege model itself is
intended. The risk is operational — an unaware operator triggering one of the footguns above during
normal administration or a migration runbook.

**Recommendation:**
1. Manage the owner key behind a multisig and, for migrations, codify the privileged sequence in a
   runbook (engage migration → migrate batches → only then decommission the old staker / re-wire
   strategies).
2. Adopt the targeted in-code guards from the individual findings — chiefly
   `require(!migrationInfo[token].active)` on `setYieldStrategy` (M-02) — which convert the most
   damaging footgun into a clean revert.
3. Consider a timelock and/or two-step transfer (`Ownable2Step`) for the owner role and the
   migrator/pauser assignment, giving downstream integrators time to observe privileged changes.

---

## Appendix A — Automated QA / Gas Report (4naly3er)

The canonical C4-style automated analyzer **4naly3er** was run against the in-scope contracts
(`src/StableStaker.sol`, `src/StableStakerMigrator.sol`) at the audited commit. Its full markdown
output is attached alongside this report:

**[`4naly3er-report.md`](./4naly3er-report.md)**

Headline counts from that run: 13 Gas-optimization classes, 18 Non-Critical classes, 10 Low-issue
classes, and 2 Medium-band classes. The two Medium-band bot findings are reconciled as follows:

- **M-1 (fee-on-transfer accounting):** a standard automated flag. Fee-on-transfer / non-standard
  tokens are a documented known-invalid category for this project (no FoT token is in scope), so it
  is not promoted to a manual finding.
- **M-2 (centralization risk for trusted owners):** the same privilege surface manually adjudicated
  above as **C-01**; the bot flag corroborates it.

The remaining bot output is automated baseline (style, gas, NatSpec, `address(0)` checks, two-step
ownership, etc.) and is retained verbatim in the appendix for completeness rather than re-listed
here. Where a bot Low overlaps a manual finding it has been folded in (e.g. L-4 "Division by zero
not prevented" relates to the `phUSDPerDay` floor behaviour analysed in **L-01**).
