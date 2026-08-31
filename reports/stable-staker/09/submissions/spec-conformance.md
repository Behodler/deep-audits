# Spec-Conformance Report — stable-staker (run stable-staker-09)

**Law 2 (faithfulness to stories).** This report tracks deviations between the documented/specified
behaviour and the implemented code. It is separate from the QA bundle. Entries here carry an `F-XX`
label; a deviation that *also* had asset/value/availability impact would additionally get an H/M
label and its own report — none here do.

- **Audited commit:** `93b7ce6ebe31f71c70a5841e074cdbfad9bced91`
- **Prior audited commit:** `f85450b6d73a728f530a97854ecc882151695cd8`
- **Scope:** regression run; F-01 and F-02 from prior runs remain open and are carried over (see
  `carryover/`). This run adds one new deviation, **F-03**.

---

## F-03 — Documentation lags story-009: CLAUDE.md still describes the irreversible `active`-bool terminal-migration model

- **Label:** F-03
- **Severity:** QA / Low
- **Type:** Spec-conformance / faithfulness (Law 2 doc-lag)
- **Story:** story-009
- **Security impact:** None. The **code** at HEAD is the new intended behaviour; the **documentation**
  is stale. No value, principal, or availability is at risk from the doc-lag itself.
- **Location (doc):** `lib/stable-staker/CLAUDE.md` — *Terminal migration mode* section, L84–96
- **Location (code):** `src/StableStaker.sol` — `finalizeAndReset` ~L585–596 (plus the `PoolState`
  enum that replaced the `active` bool)
- **Fingerprint:** `ss9f3-claudemd-terminal-migration-doc-lag-story-009`

### The deviation

The project spec (`lib/stable-staker/CLAUDE.md`, L84–96) documents terminal migration as a one-way,
**irreversible** state with **no resume path**:

> `initiateMigration(token)` (`onlyMigrator`) engages a **terminal, per-token** migration: it settles
> & freezes emissions, snapshots `P = totalStaked`, realizes the whole strategy position once into
> idle balance as `R` (via the client-callable `strategy.withdraw`, NOT `totalWithdrawal` — see the
> source comment for why), decouples the strategy, and sets `active = true`. Thereafter every exit —
> operator `batchMigrate` or permissionless `userMigrate` — pays a fixed credit `p_i·min(R,P)/P` from
> the idle pile, so payouts are independent of batch composition, ordering, and batch-vs-self.
> Equal principal ⇒ equal payout (closes ss2m1 / M-01). **Migration is terminal: once engaged a
> token's pool can never resume healthy operation (no resume path)**, and `stake` / `withdraw` /
> `emergencyWithdraw` / the old staker's `depositFor` are blocked while `active` to preserve the
> snapshot. […]

Two statements in that text no longer hold at HEAD `93b7ce6`:

1. **The `active` bool is gone.** story-009 replaced the boolean `active` flag with a `PoolState`
   enum (`Active` / `Migrating` / …). The "sets `active = true`" / "blocked while `active`" framing
   describes a field that no longer exists.
2. **Migration is no longer irreversible.** story-009 added `finalizeAndReset`, which **does** resume
   a fully-drained pool to healthy operation — directly contradicting *"once engaged a token's pool
   can never resume healthy operation (no resume path)."*

The actual implemented revival path (`src/StableStaker.sol` ~L585–596):

```solidity
function finalizeAndReset(address token) external onlyOwner poolExists(token) {
    require(poolState[token] == PoolState.Migrating, "StableStaker: pool not migrating");
    require(_stakers[token].length() == 0, "StableStaker: stakers remain");
    require(poolInfo[token].totalStaked == 0, "StableStaker: principal remains");

    // Clear the snapshot and fast-forward accrual so the frozen migration window is never
    // retroactively emitted into the revived pool.
    migrationInfo[token] = MigrationInfo({realized: 0, principalSnapshot: 0});
    poolInfo[token].lastRewardTime = block.timestamp;
    poolState[token] = PoolState.Active;
    emit PoolReset(token);
}
```

After every staker has exited and the principal is fully drained, the owner can call
`finalizeAndReset` to flip `poolState` from `Migrating` back to `Active`, clearing the migration
snapshot and fast-forwarding accrual. The pool resumes healthy operation — the precise behaviour the
documentation says is impossible.

### Why this is in scope (and only QA/Low)

Per Law 1, a plausibly-relevant deviation must not be silently dropped; per Law 2, features must match
their stories, and where doc and code disagree the disagreement is surfaced. Here the **code is the
authoritative new story** (story-009 deliberately introduced revival) and the **doc is the stale
artefact**, so there is no security exposure — only a faithfulness/documentation gap that will mislead
a future reader or auditor relying on CLAUDE.md as the spec. That keeps it at QA/Low.

> Note: a related **operational** hazard of the revival path — `finalizeAndReset` reviving a pool
> without resetting `phusdPerSecond` or re-wiring `yieldStrategy` — is tracked **separately** as the
> Low/QA footgun **L-01** in the QA bundle (`qa-report.md`), not here. F-03 is purely the doc-lag.

### Recommendation

Update `lib/stable-staker/CLAUDE.md` (Terminal migration mode, L84–96) to:

- Replace the `active = true` / "blocked while `active`" language with the `PoolState` enum
  (`Migrating` / `Active`) terminology.
- Remove the "migration is terminal … no resume path" claim and document `finalizeAndReset`: a
  drained, staker-empty migrating pool can be reset back to `Active` (owner-only), clearing the
  migration snapshot and fast-forwarding accrual.

**Not fixed here.** `lib/` is read-only (source repos are strictly read-only); this deviation is
**reported, not patched**. The doc update must be made upstream by the project owner.
