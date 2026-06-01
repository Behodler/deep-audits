# QA Report for stable-staker

**Run**: stable-staker-02
**Commit**: 0812167
**Scope**: `src/StableStaker.sol`, `src/StableStakerMigrator.sol`
**Mode**: REGRESSION (baseline: run-01 @ `f524cc3`)

## Summary

This regression run surfaced **no new QA-tier findings**. The only QA-tier
candidate this run — `L-01` (haircut-branch predicate accuracy) — was **dropped as
wont-fix**: it is subsumed by an accepted known issue ("integer-division dust rounds
DOWN, in protocol favor"). No replacement Low/Centralization/Informational finding
was raised.

The sole substantive finding this run is **M-01** (non-uniform AMM haircut in
`migrateOut`), which is Medium severity and is **submitted separately** — it is not
part of this QA bundle.

Accordingly, the purpose of this QA report is to **carry over the still-open
Low / Centralization / Informational findings from prior runs** so they are not lost
between runs, and to point at the unchanged automated SAST/gas baseline.

| Severity | New this run | Carried over (still-open) |
|----------|--------------|---------------------------|
| Centralization | 0 | 1 |
| Low Risk | 0 | 1 |
| Informational | 0 | 1 |
| **Total** | **0** | **3** |

| ID (run-01) | Title | Severity | Status |
|-------------|-------|----------|--------|
| C-01 | `rescueERC20` can sweep the buffer backing underwater withdrawals | Centralization | open (carryover) |
| L-01 | Unbounded per-user external-call loop in `migrateOut` / `migrate` | Low | open (carryover) |
| L-02 → Info | Unused return value of `EnumerableSet.add` / `remove` | Informational | open (carryover) |

An automated SAST/gas baseline produced by **4naly3er** in run-01 remains valid for
this run (see appendix) and is referenced rather than re-generated.

---

## Carryover (still-open from prior runs)

The following findings were raised in **stable-staker-01** and remain **open** in the
ledger (`reports/ledgers/stable-staker.json`, status `open`) — not fixed, not triaged.
They are reproduced as stubs so they are not lost between runs. Triage them with
`/ledger stable-staker`. Each links to its carryover stub and to the full original
write-up in the run-01 QA report.

### [C-01] `rescueERC20` can sweep the buffer backing underwater withdrawals <!-- id: ss2c1 -->

- **Severity**: Centralization (Low)
- **Location**: [`src/StableStaker.sol#L521-L528`](../../../lib/stable-staker/src/StableStaker.sol#L521-L528) (`rescueERC20`)
- **Fingerprint**: `0790a76a…`
- **First seen**: stable-staker-01 · **Still present as of**: stable-staker-02
- **Carryover stub**: [`carryover/C-01-CARRYOVER.md`](./carryover/C-01-CARRYOVER.md)
- **Original report**: [stable-staker-01 QA report — C-01](../../stable-staker-01/submissions/qa-report.md)

**Summary**: When a yield strategy is set, `rescueERC20`'s reserve collapses to `0`,
allowing the owner to sweep the entire on-contract balance — the protocol-owned buffer
that backs at-par underwater withdrawals (`_routeExit` buffer branch). No theft of
accounted user principal, but it removes the backstop that lets in-flight underwater
withdrawals settle at par. See the original report for full description, impact and
recommendation.

---

### [L-01] Unbounded per-user external-call loop in `migrateOut` / `migrate` <!-- id: ss2l1 -->

- **Severity**: Low
- **Location**: [`src/StableStaker.sol#L301-L337`](../../../lib/stable-staker/src/StableStaker.sol#L301-L337) (`migrateOut`); [`src/StableStakerMigrator.sol#L45-L65`](../../../lib/stable-staker/src/StableStakerMigrator.sol#L45-L65) (`migrate`)
- **Fingerprint**: `59eebbf8…`
- **First seen**: stable-staker-01 · **Still present as of**: stable-staker-02
- **Carryover stub**: [`carryover/L-01-CARRYOVER.md`](./carryover/L-01-CARRYOVER.md)
- **Original report**: [stable-staker-01 QA report — L-01](../../stable-staker-01/submissions/qa-report.md)

**Summary**: Both migration paths iterate over an operator-supplied `users[]` batch
with an external call per user and no bound on batch size; an oversized array can push
the transaction past the block gas limit. The caller is permissioned and the condition
is fully recoverable by re-batching with the existing pagination helpers. See the
original report for full description, impact and recommendation.

---

### [Info] Unused return value of `EnumerableSet.add` / `remove` <!-- id: ss2i1 -->

- **Severity**: Informational (was L-02 in run-01)
- **Location**: [`src/StableStaker.sol`](../../../lib/stable-staker/src/StableStaker.sol) — `add` at `L233`, `L361`; `remove` at `L250`, `L287`, `L323`
- **Fingerprint**: `7b071779…`
- **First seen**: stable-staker-01 · **Still present as of**: stable-staker-02
- **Carryover stub**: [`carryover/Info-CARRYOVER.md`](./carryover/Info-CARRYOVER.md)
- **Original report**: [stable-staker-01 QA report — L-02](../../stable-staker-01/submissions/qa-report.md)

**Summary**: The boolean success value of `EnumerableSet.AddressSet.add` / `.remove`
is ignored. Benign in context — the operations are idempotent and the surrounding logic
does not depend on the membership-delta. Code-quality observation only; no security
impact. See the original report for full description and recommendation.

---

## Previously triaged / by-design

The following items were considered in run-01 and **resolved** as triaged / intended
design. They are listed here so the reader knows they were evaluated and are **not**
re-bundled as open findings:

- **M-02 (run-01)** — Underwater buffer pays at par first-come-first-served.
  **Wont-fix / intended design**: the buffer branch is a deliberate code path
  implementing the documented invariant that a non-migrating user cannot be forced to
  realise a loss during a transient, mean-reverting underwater dip. Recorded in run-01
  as informational note **I-01**.
- **I-01 (run-01)** — Underwater buffer FCFS-at-par semantics (by design). Informational
  note; no code change required. See C-01, which keeps the backstop the design relies on
  from being swept.
- **I-02 (run-01)** — Break-even deposit→withdraw round-trip can grief the underwater
  buffer. **Rejected as a standalone finding** — break-even for the actor, no profit
  mechanism; recorded for completeness as an informational note only.

---

## Appendix: Automated Tool Output (4naly3er)

**This run does not re-generate the 4naly3er baseline.** The only code change between
run-01 (`f524cc3`) and run-02 (`0812167`) is the 12-line M-01 pro-rata fix in
`migrateOut` plus a 7-line interface change — the M-01 fix added only the per-user
scaling loop. The SAST/gas baseline is therefore **materially unchanged**, and run-01's
4naly3er report remains the authoritative automated baseline for this run.

> **Tool**: 4naly3er
> **Invocation (run-01)**: `yarn analyze lib/stable-staker/src`
> **Compiler**: `solc-0.8.26` (added to the 4naly3er toolchain so the OpenZeppelin
> v5.6.1 `^0.8.24` imports compile).
> **Full report (run-01)**: [`../../stable-staker-01/submissions/4naly3er-report.md`](../../stable-staker-01/submissions/4naly3er-report.md)

The complete report lives at
`reports/stable-staker-01/submissions/4naly3er-report.md`. Its summary tables are
reproduced below for convenience.

### 4naly3er summary (run-01 baseline — unchanged)

**Gas Optimizations** (13 categories): `a += b` vs `a = a + b` (8), assembly
`address(0)` checks (11), cache array length (3), `unchecked` for non-overflowing ops
(55), custom errors vs revert strings (19), avoid contract-existence checks (7),
single-use stack cache (1), `immutable` constructor-only state (3), `payable` admin
functions (8), `++i` vs `i++` (5), `private` constants (2), unchecked loop increments
(4), `!= 0` vs `> 0` (14).

**Non-Critical** (19 categories): missing `address(0)` checks, style-guide ordering,
two-step procedures, `renounceOwnership`, duplicated `require` checks, events missing
old/new values, function ordering / length, setter checks, incomplete NatSpec,
modifier-vs-require for actors, named mappings, renounce-while-paused, redundant
`return`, layout ordering, number-literal underscores, unindexed event fields,
zero-initialised variables.

**Low** (11 categories): two-step ownership transfer (3), zero-value transfer reverts
(5), missing `address(0)` check (1), division by zero (2), **external calls in
unbounded for-loop / DoS (1)** — overlaps manual L-01, renounce-while-paused (1),
rounding (2), precision loss (12), `PUSH0` on 0.8.20+ (2), `Ownable2Step` (2),
**sweep accounting with multi-address tokens (1)** — relates to manual C-01.

**Medium** (2 categories): fee-on-transfer accounting (1) — note fee-on-transfer tokens
are a known-invalid class per the audit ruleset; **centralization risk for trusted
owners (11)** — the broad automated centralization sweep, of which the specific
buffer-sweep concern is captured as manual C-01.

> **Delta note (run-02)**: no 4naly3er categories or counts change as a result of the
> M-01 fix. The fix adds a bounded scaling loop already covered by the existing
> "external calls in unbounded for-loop" and gas-optimization categories above; no new
> SAST/gas class is introduced.
