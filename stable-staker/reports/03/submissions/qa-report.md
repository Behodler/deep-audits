# QA Report — stable-staker (run stable-staker-03)

**Project:** stable-staker
**Submodule commit:** `f5f6039a682b0fb627355a5173502259d68967ba` (`f5f6039`)
**In scope:** `src/StableStaker.sol`, `src/StableStakerMigrator.sol`
**Run mode:** Regression scan (prior audited commit `0812167`, prior run `stable-staker-02`)
**Date:** 2026-06-02

> **Regression note.** This is a regression run against the prior baseline (`0812167`). Two
> previously-reported Mediums — both rooted in the deleted `migrateOut` batch-exit path —
> were **structurally closed** this run:
> - The non-uniform AMM-backed batch-exit haircut (prior `M-01`, fp `b5218ab2`, submitted) is
>   gone: `migrateOut` was removed and the new single-realization terminal-migration design
>   (`initiateMigration` realizes the whole position once, then every exit pays the fixed credit
>   `p_i·min(R,P)/P`) does not reintroduce it. Equal principal now yields equal payout.
> - The requested-vs-received accounting brick (prior `M-01` of run-01, fp `3d61c955`,
>   acknowledged) is structurally avoided by the same single-realization design.
>
> Neither Medium fingerprint reappeared (no regression). The findings below are the open QA-tier
> items reconciled against `reports/stable-staker/ledger.json`, plus one new Low this run (L-03)
> and a by-design centralization summary for completeness.

---

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| Informational | 1 |
| Centralization | 1 (by-design summary) |
| **Total** | **5** |

| Label | Title | Status |
|-------|-------|--------|
| [L-01](#l-01-rescueerc20-can-sweep-the-buffer-backing-underwater-withdrawals) | `rescueERC20` can sweep the underwater-withdraw buffer | Open (carryover) |
| [L-02](#l-02-unbounded-per-user-migrate-loop) | Unbounded per-user migrate loop | Open (carryover) |
| [L-03](#l-03-terminal-migration-has-no-mint-free-escape-hatch) | Terminal migration has no mint-free escape hatch | Open (new) |
| [I-01](#i-01-unused-return-value-of-enumerableset-addremove) | Unused return value of `EnumerableSet.add/remove` | Open (info) |
| [C-01](#c-01-owner--migrator--pauser-trust-model-by-design) | Owner / migrator / pauser trust model (by-design summary) | Informational |

An automated SAST/gas baseline (4naly3er) is attached at
[`4naly3er-report.md`](./4naly3er-report.md) in this submission directory.

---

## Low Risk Findings

### [L-01] `rescueERC20` can sweep the buffer backing underwater withdrawals <!-- id: ss3l1 -->

**Severity:** Low (owner-trust bounded; centralization-adjacent)

**Location:** [`StableStaker.sol#L702-L709`](../../../lib/stable-staker/src/StableStaker.sol#L702-L709)

**Description:** The `rescueERC20` reserve guard only protects user principal when a token has
**no** yield strategy set. The reserved amount is computed as:

```solidity
uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;
uint256 bal = IERC20(token).balanceOf(address(this));
require(bal >= reserved + amount, "StableStaker: would touch user principal");
```

When a yield strategy **is** set, `reserved` is `0` because principal lives inside the strategy.
The premise is that the contract balance is then "purely buffer + dust" (per the NatSpec). But that
buffer is precisely the reserve that backs at-par / underwater withdrawals (the documented
"a non-migrating user cannot be forced to realise a loss" invariant). Because `reserved == 0` in the
strategy case, the **entire** contract balance — including that withdraw buffer — is owner-rescuable.

**Impact:** An owner (malicious, compromised, or mistaken) can drain the buffer that backs at-par
withdrawals during an underwater dip, undermining the no-forced-loss guarantee for in-flight
withdrawals. Bounded by owner trust; user principal held inside the strategy is not directly reached
by this path.

**Recommendation:** Track the buffer obligation explicitly (e.g. the amount currently reserved to
honor at-par/underwater withdrawals) and fold it into `reserved` even when a strategy is set, so a
rescue cannot dip into buffer that is owed to stakers. At minimum, document that `rescueERC20` is
not buffer-aware in the strategy case and gate it behind the same operational controls as other
fund-touching owner actions.

---

### [L-02] Unbounded per-user migrate loop <!-- id: ss3l2 -->

**Severity:** Low (availability / operational)

**Location:**
[`StableStaker.sol#L428-L482` (`batchMigrate`)](../../../lib/stable-staker/src/StableStaker.sol#L428-L482),
[`StableStakerMigrator.sol#L61-L83` (`migrate`)](../../../lib/stable-staker/src/StableStakerMigrator.sol#L61-L83),
[`StableStaker.sol#L556-L562` (`getStakers`)](../../../lib/stable-staker/src/StableStaker.sol#L556-L562)

**Description:** `StableStakerMigrator.migrate` and `StableStaker.batchMigrate` iterate over a
caller-supplied `users[]` array (and `migrate` calls `depositFor` per user). A sufficiently large
batch will exceed the block gas limit and revert. The contract already provides paging primitives —
`getStakersRange(token, start, end)` and `stakerCount(token)` — so operators are expected to page
the staker set off-chain into bounded batches.

Separately, `getStakers(token)` returns the **full** staker set with no bound. It is a `view`
function (off-chain gas only), so it cannot brick on-chain state, but it can fail to return for very
large sets and should not be relied on for on-chain batch construction.

**Impact:** No funds at risk. Migration of a token with a very large staker population must be paged;
a naive single-call migration of the full set would revert. Operationally important to document so
migrations are not attempted as one oversized batch.

**Recommendation:** Document the off-chain paging requirement (build batches via
`getStakersRange`/`stakerCount`, never from `getStakers` for large sets) in the migration runbook,
and consider an explicit max-batch-size note in the migrator NatSpec.

---

### [L-03] Terminal migration has no mint-free escape hatch <!-- id: ss3l3 -->

**Severity:** Low (owner-trust bounded; principal recoverable, not permanently lost)

**Location:** [`StableStaker.sol#L478-L503`](../../../lib/stable-staker/src/StableStaker.sol#L478-L503)

**Description:** While a token is under active terminal migration, `emergencyWithdraw` is blocked
(migration active), so the only exits are `userMigrate` and `batchMigrate`. Both route through
`_exitPosition`, which settles and **mints** the frozen pending phUSD via `phUSD.mint(account, pending)`
before transferring principal:

```solidity
if (pending > 0) {
    phUSD.mint(account, pending);   // L479
}
```

If the staker contract loses its phUSD minter rights while a token is active (e.g. the phUSD owner
revokes `setMinter` mid-migration), this `mint` reverts and the only available exits revert with it —
even though the user's principal is sitting idle and ready to transfer. In **healthy** mode the
system has a mint-free escape (`emergencyWithdraw` forfeits rewards and just returns principal);
in **terminal** mode there is no equivalent mint-free path.

**Impact:** Owner-trust-bounded availability. Principal is **not** permanently lost — it becomes
retrievable again as soon as minter rights are restored — but during a minter-revoked-mid-migration
window, terminal-migration exits revert and principal is temporarily unrecoverable. Requires the
owner-trusted precondition of minter rights being revoked while a migration is active.

**Recommendation:** Provide a mint-free terminal-state escape that mirrors `emergencyWithdraw`:
allow a staker to forfeit pending phUSD and withdraw only principal during an active migration, so
exits never depend on the mint succeeding. Alternatively, make the pending-phUSD mint best-effort
(skip on mint failure, optionally booking the unminted pending for later claim) so a revoked minter
cannot block principal return.

---

## Informational

### [I-01] Unused return value of `EnumerableSet.add/remove` <!-- id: ss3i1 -->

**Severity:** Informational

**Location:** `StableStaker.sol` lines
[~253](../../../lib/stable-staker/src/StableStaker.sol#L253),
[~273](../../../lib/stable-staker/src/StableStaker.sol#L273),
[~313](../../../lib/stable-staker/src/StableStaker.sol#L313),
[~476](../../../lib/stable-staker/src/StableStaker.sol#L476),
[~534](../../../lib/stable-staker/src/StableStaker.sol#L534)

**Description:** Several calls to `EnumerableSet.add` / `EnumerableSet.remove` on `_stakers[token]`
ignore the boolean return value indicating whether the set actually changed. Because the operations
are idempotent (adding a present member or removing an absent one is a no-op that returns `false`
without reverting), and the surrounding logic only requires the post-condition membership state, the
ignored return is harmless here. (Note: the `_registeredTokens.add` site at L157 deliberately checks
the return inside a `require` to reject duplicate tokens, so it is unaffected.)

**Impact:** None. Idempotent set semantics make the ignored return values safe.

**Recommendation:** Optional. If strict accounting is ever desired (e.g. to assert a staker was
genuinely newly added or genuinely removed), capture and assert the boolean. Otherwise no change
needed; flagged for completeness.

---

## Centralization Risks

### [C-01] Owner / migrator / pauser trust model (by-design summary) <!-- id: ss3c1 -->

**Severity:** Centralization (documented, by-design — surfaced for completeness, not a defect)

**Location:** `src/StableStaker.sol`

**Description:** The protocol concentrates several privileged capabilities in three trusted roles.
These are by-design per the project's known issues and documentation; they are listed here for
completeness so reviewers have the full trust surface in one place.

**`onlyOwner`:**
- `addToken` ([L155](../../../lib/stable-staker/src/StableStaker.sol#L155)) — register a staked token.
- `phUSDPerDay` ([L167](../../../lib/stable-staker/src/StableStaker.sol#L167)) — set the per-token
  emission budget (the core emission-cap parameter).
- `setMigrator` ([L175](../../../lib/stable-staker/src/StableStaker.sol#L175)) — designate the
  migration orchestrator.
- `setPauser` ([L181](../../../lib/stable-staker/src/StableStaker.sol#L181)) — designate the pauser.
- `setYieldStrategy` ([L198](../../../lib/stable-staker/src/StableStaker.sol#L198)) — route a token's
  principal through a yield strategy (sweeps idle balance into the strategy).
- `rescueERC20` ([L702](../../../lib/stable-staker/src/StableStaker.sol#L702)) — sweep tokens (see
  [L-01](#l-01-rescueerc20-can-sweep-the-buffer-backing-underwater-withdrawals) for the
  buffer-awareness gap).

**`onlyMigrator`:**
- `initiateMigration` ([L368](../../../lib/stable-staker/src/StableStaker.sol#L368)) — engage the
  terminal per-token migration (settles emissions, snapshots `P`, realizes the strategy, decouples).
- `batchMigrate` ([L428](../../../lib/stable-staker/src/StableStaker.sol#L428)) / `depositFor` — the
  permissioned terminal-migration hooks.

**`onlyPauser`:**
- `pause` ([L225](../../../lib/stable-staker/src/StableStaker.sol#L225)) — halt the system via the
  Behodler3 `IPausable` integration.

**Impact:** A compromised or malicious owner can redirect principal into an attacker-controlled
strategy, alter emissions, or sweep buffer balances ([L-01]); a compromised migrator can initiate an
irreversible terminal migration of a token; a compromised pauser can halt the system. The staker
contract is additionally a phUSD minter, so the broader trust assumption (an honest phUSD owner that
does not revoke minter rights mid-migration) underpins
[L-03](#l-03-terminal-migration-has-no-mint-free-escape-hatch).

**Recommendation:** These privileges are accepted by design. For defense-in-depth, consider holding
the owner and migrator roles behind a multisig and/or timelock, and document the operational
expectation that phUSD minter rights are not revoked while any token is under active migration.

---

## Appendix — Automated QA / Gas Report (4naly3er)

The canonical C4-style automated report was generated with **4naly3er** over the in-scope source
tree (`lib/stable-staker/src`, which resolves to `StableStaker.sol`, `StableStakerMigrator.sol`, and
`interfaces/IStableStaker.sol`) at commit `f5f6039`. The full markdown output is attached alongside
this report:

- [`4naly3er-report.md`](./4naly3er-report.md) — 13 Gas optimization classes (GAS-1 … GAS-13) and
  18 Non-Critical classes (NC-1 … NC-18).

These are automated-tool baseline observations (gas micro-optimizations and style/non-critical
notes) and are intentionally **not** re-listed as manual findings above, per C4 conventions that
discourage padding QA reports with non-critical tool output. Refer to the attached file for the
itemized GAS/NC entries and their line references.
