# QA Report — stable-staker

**Run**: `stable-staker-14`  **Commit**: `8856781` (branch `master`)  **Date**: 2026-08-27

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 2 |
| Centralization | 0 |
| QA / Informational | 3 |
| **Total (this bundle)** | **5** |

### Findings routed elsewhere — not duplicated here

This run's `L-01` through `L-04` were classified as **faithfulness** findings (Law 2) and are
compiled in `submissions/spec-conformance.md`, not in this bundle. Listed by label only so a reader
can find them:

| Label | Title | Report |
|-------|-------|--------|
| L-01 | CrossVersionMigrator's batch-survival guard tests the SOURCE credit while the revert fires on the DESTINATION credit (dust poison) | `submissions/spec-conformance.md` |
| L-02 | NatSpec (E) and story-018 mis-attribute the uncompensated haircut to an underwater SOURCE | `submissions/spec-conformance.md` |
| L-03 | Golden-rule CI gate and PreToolUse hook both fail to prevent DELETION of `src/versions/IStableStakerV1.sol` | `submissions/spec-conformance.md` |
| L-04 | story-015's snapshot-extraction ritual targets `master` HEAD rather than the deploy commit | `submissions/spec-conformance.md` |

`Q-02` and `Q-03` below also carry a faithfulness dimension and are cross-referenced from
`submissions/spec-conformance.md`; their substance is filed here because their consequence is documentation and
robustness, not a spec deviation with runtime effect.

**This run raises 0 High and 1 Medium.** Final tally across all reports: **1 Medium, 6 Low, 3 QA.**

| Label | Title | Report |
|-------|-------|--------|
| M-01 | setYieldStrategy sweeps unmatched idle balance into the strategy, making terminal migration unavailable until an undocumented cross-repo owner call | `submissions/M-01.md` (submitted individually) |

Of the run's 6 Lows, this bundle carries **L-05 and L-06**; `L-01`–`L-04` are faithfulness findings
and remain pointers to `submissions/spec-conformance.md`.

**Label history — read this before reconciling artifacts.** Two findings changed label during this
run, and one of them changed twice. Both histories are recorded in the findings themselves; the
short version:

- The former `M-02` is now **`L-06`** (in this bundle). A Medium premised on there being no owner
  remedy; a passing PoC refuted that premise.
- The former `M-01` became `L-07` and is now **`M-01` again** (submitted individually). It was Medium
  on a false "no owner escape" premise, correctly dropped to Low when a passing PoC refuted that
  premise, and is Medium again on **entirely different grounds**: the condition is *already realized*
  on live mainnet pools. This is **not** a reversal of the downgrade — the owner escape still exists.
  Severity rose on **likelihood and realization, not on impact**. Chain state was verified at blocks
  25,851,201 and 25,851,231: `initiateMigration(DOLA)` and `initiateMigration(USDC)` from the
  configured migrator both revert `StableStaker: incomplete exit`, while `initiateMigration(USDe)`
  succeeds.
- **`L-07` is retired and must not be reused.** The surviving labels are not renumbered.

### Exit backstops — stated per finding, not as a blanket claim

The zero-High conclusion rests on a different backstop depending on the finding, so it is set out per
finding rather than asserted once. For the two Lows in this bundle:

| Finding | Pool state reached | Backstop | Quality of that exit |
|---|---|---|---|
| L-05 | unchanged (`Active`) | n/a — no user position is involved | Only stray/donated tokens are affected; no staker exit is at issue. |
| L-06 | latches `Migrating` | `userMigrate` (`src/StableStaker.sol:564`) | **Full value.** Permissionless, no `whenNotPaused`, pays the full snapshot credit. |

Note that `userMigrate` is **not** a universal backstop, and this report does not claim it is: it
hard-requires `poolState == PoolState.Migrating` (`src/StableStaker.sol:565`), so it is unreachable
for any finding in which the pool never leaves `Active`. `M-01` is exactly such a finding, and its
backstop is the lossy, first-come-first-served `emergencyWithdraw` (`src/StableStaker.sol:363-378`,
carrying the comment `// No underwater guard` at `:374`). That reasoning is set out in
`submissions/M-01.md`; it is flagged here only so this table is not read as covering the whole run.


---

## Low Risk Findings

### [L-05] CrossVersionMigrator has no rescue path while sibling InPlaceMigrator does, and the omission is undocumented <!-- id: ss14l5 -->

**Location**: `src/CrossVersionMigrator.sol` (contract-level — no rescue function exists anywhere in
the file); compare `src/InPlaceMigrator.sol:338` (`rescueERC20`).

**Description**: `InPlaceMigrator` ships an owner sweep for stray balances, floored at
`totalParked` and documented in its section (G). `CrossVersionMigrator` ships nothing equivalent, and
its NatSpec never records the omission as a deliberate decision. Any token that reaches the
cross-version migrator by a route other than `migrate()` — a donation, a rebase, or a misdirected
transfer — is permanently unrecoverable.

The asymmetry is a Law-3 footgun rather than a mere gap because of how it interacts with the
contract's own documentation. Section (E) at `src/CrossVersionMigrator.sol:49` states that underwater
haircuts "are not compensated here"; an owner reading that and **pre-funding the migrator** to cover
the shortfall achieves nothing and loses the funds. The deposit loop at
`src/CrossVersionMigrator.sol:133-138` pulls exactly `amounts[i]` per user and never draws on a
surplus, so pre-funded capital is consumed by nothing and then stranded. An owner reasoning by
analogy from the sibling migrator would reasonably expect a way back out.

**Likelihood is genuinely low, and stated as such**: nothing can accumulate via the normal flow.
Tier-3 `invariant_01_migratorTokenConservation` held a per-call migrator balance delta of exactly
zero across 750k Foundry calls and 1.0M Medusa calls. Exposure is confined to funds that should never
have been there.

**Cross-reference**: this finding and `L-02` (faithfulness, `submissions/spec-conformance.md`) cite each other —
`L-02` is the documentation defect that *creates* the pre-funding scenario this missing path fails to
remedy. Fixing only one leaves the footgun intact.

**Recommendation**: either add a floored sweep mirroring the sibling, or state the omission
explicitly in the contract NatSpec so the asymmetry reads as a decision rather than an oversight.
`CrossVersionMigrator` holds no parked principal between calls, so the floor is simply zero:

```solidity
/// @notice Sweep a stray/donated balance. The migrator holds no principal between
///         calls (see (A)), so any resting balance is by definition surplus.
function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
    emit Rescued(token, to, amount);
}
```

---

### [L-06] Unvalidated one-way door in CrossVersionMigrator.initiateMigration, plus a constructible self-aliased migrator <!-- id: ss14l6 -->

**Location**: `src/CrossVersionMigrator.sol:107-109` (forwarder) and `src/CrossVersionMigrator.sol:89-96`
(constructor); `src/StableStaker.sol:433` (`initiateMigration`), `:634` (`depositFor`), `:564`
(`userMigrate`), `:200` (`setMigrator`).

**Provenance — downgraded from Medium**: this finding was originally rated Medium on the premise that
the self-aliased case has **no owner remedy** — that the only route back to `Active` was every user
individually calling `userMigrate`, so a single unresponsive staker would wedge a funded pool
forever. That premise was tested and **refuted, twice independently**. The distinction missed at
classification time: the *migrator's* two endpoints are immutable (section (B)), but the *staker's*
`migrator` pointer is not part of that immutability — it is a plain owner-settable field:

```solidity
/// @notice Set the address authorized to perform permissioned migration.
function setMigrator(address _migrator) external onlyOwner {   // src/StableStaker.sol:200
```

It carries no `poolState` gate, no `poolExists` gate and no pause gate, so it is settable while the
pool is latched in `Migrating`. Recovery is **3 owner transactions with zero user cooperation**. The
"permanent wedge" leg that carried the Medium does not exist, and the finding sits at Low. This note
is retained because the reversal is part of the finding's provenance.

**Description**: Two coupled defects.

*First*, `CrossVersionMigrator.initiateMigration` is a thin owner-only forwarder:

```solidity
function initiateMigration(address token) external onlyOwner {   // :107-109
    oldStaker.initiateMigration(token);
}
```

The forwarded call (`src/StableStaker.sol:433`) irreversibly realizes the strategy position, unwires
`yieldStrategy[token]`, takes the `(R, P)` snapshot, freezes emissions and latches `Migrating` — while
checking **none** of the destination preconditions the contract's own NatSpec section (C)
(`src/CrossVersionMigrator.sol:33-37`) declares mandatory:

> (C) TWO-SIDED WIRING IS REQUIRED BEFORE USE. This migrator must be set as `migrator` via
> `setMigrator` on BOTH stakers, the destination staker must already have the token registered
> (`addToken`), and the destination staker must be an authorized phUSD minter.

Every one of those is discovered only at the first `migrate`, after the source is already frozen. The
documentation gap is precise and worth stating exactly: **documenting a precondition is not the same
as documenting that violating it is undetectable until after the irreversible step.** Section (C)
does the former and not the latter.

*Second*, the constructor (`:89-96`) checks both targets are non-zero but never that they **differ**:

```solidity
require(address(_oldStaker) != address(0), "Migrator: zero old staker");
require(address(_newStaker) != address(0), "Migrator: zero new staker");
```

So `CrossVersionMigrator(staker, staker, owner)` is constructible. `initiateMigration` then succeeds
and every non-empty `migrate` reverts permanently with the exact string
`"StableStaker: pool not active"`, because `depositFor` (`src/StableStaker.sol:634`) requires
`PoolState.Active` and the destination *is* the pool just frozen.

**Impact — why this is Low, stated without inflation**: no user funds are at risk for a single block.
`userMigrate` (`src/StableStaker.sol:564`) is permissionless, carries no `whenNotPaused`, and pays the
full snapshot credit. What freezes is `stake`, `withdraw`, `emergencyWithdraw` and emissions — **not
user capital**. What is actually lost is emissions across an owner-length remediation window, on a
pool the owner was deliberately retiring, with a unilateral owner fix available.

One property cuts the opposite way from how it usually reads and is worth making explicit: the
"undetectable until after the irreversible step" characteristic is severity-**reducing** here, not
severity-increasing, because the failure surfaces on the very next operator action rather than lying
dormant to be discovered later.

This is an owner footgun under Law 3 — a non-obvious consequence of a non-malicious owner's action —
and must not be read or written up as a malicious-owner vector.

**Recommendation** (unchanged by the downgrade, and still worth shipping):

```solidity
// constructor
require(_oldStaker != _newStaker, "Migrator: aliased stakers");
```

and add destination pre-flight checks to `initiateMigration` — at minimum that the destination has the
token registered and has this migrator wired — so the irreversible source-side step cannot run against
a destination that will reject the deposit.

**Cross-reference**: `L-05` (no rescue path) and the `L-02` entry in
`submissions/spec-conformance.md` both concern this same contract's NatSpec over-promising; all three
are instances of `CrossVersionMigrator` documentation asserting more than the code enforces.
---

## Centralization Risks

None filed this run. Aderyn's 16 `centralization-risk` flags and 4naly3er's `M-2` (19 instances) are
the ordinary `onlyOwner` surface and are suppressed under Law 3 (non-malicious owner assumed). The
owner-privilege item in this bundle that met the Law-3 footgun test is filed as a Low rather than
here: `L-06`, `initiateMigration` as an unvalidated one-way door. (`M-01`, submitted individually, is
the run's other Law-3 footgun.) Both are non-obvious consequences of a **non-malicious** owner's
action, which is what puts them in scope; neither is a malicious-owner vector and neither should be
read as one.

---

## QA / Informational

### [Q-01] IStableStakerV1.sol NatSpec is falsely exhaustive in two places <!-- id: ss14q1 -->

**Location**: `src/versions/IStableStakerV1.sol:63` and `src/versions/IStableStakerV1.sol:50-56`

**Description**: The frozen V1 snapshot exists to be the accurate description of the live deployment,
and two of its doc blocks claim completeness they do not have:

1. `:63` — "Mirrors of the **16 events** emitted by the deployed V1 contract." The count omits
   `OwnershipTransferred`, `Paused` and `Unpaused`, and the block does not mirror the OpenZeppelin
   custom-error set at all.
2. `:50` — the "Known external coupling" block names `IYieldStrategy` (reflax-yield-vault) and
   `IFlax` (flax-token) but omits `IStableStakerMigratable`, which the frozen file itself inherits.

**Impact**: none at runtime. It is filed rather than dropped because a doc block that asserts an
exact count is read as authoritative, and because it compounds `L-03`
(`submissions/spec-conformance.md`): the snapshot's self-description is wrong *and* its deletion is missed by
both purpose-built enforcement layers (a compile break in two importing tests catches it incidentally).

**Recommendation**: replace the fixed count with the enumerated list, or drop the number; add
`IStableStakerMigratable` to the coupling block.

---

### [Q-02] `migrate`'s two loops iterate different bounds, contradicting the contract's stated future-proofing goal <!-- id: ss14q2 -->

**Location**: `src/CrossVersionMigrator.sol:122-124` (sum) and `src/CrossVersionMigrator.sol:133-138`
(deposit)

**Description**: The summing loop bounds on `amounts.length`; the deposit loop bounds on
`users.length` while indexing `amounts[i]`.

```solidity
for (uint256 i = 0; i < amounts.length; i++) {   // :122
    total += amounts[i];
}
...
for (uint256 i = 0; i < users.length; i++) {     // :133
    if (amounts[i] > 0) {
        newStaker.depositFor(token, users[i], amounts[i]);
```

Against `StableStaker` V2 the lengths always match — `batchMigrate` returns one entry per user — so
there is **no exploitable path today**, and both staker addresses are `immutable` and owner-chosen.
The item is filed because the contract's section (A) claims the design survives arbitrary *future*
staker redesigns; a future staker returning a shorter array would produce an out-of-bounds panic
rather than a clean revert, which is exactly the class of failure that claim promises to withstand.
Severity is held at QA precisely because it rests on code that does not exist — speculation on future
code is not a basis for higher severity.

**Recommendation**: bound both loops identically and assert the relationship once:

```solidity
require(amounts.length == users.length, "CVM: length mismatch");
```

---

### [Q-03] CLAUDE.md overstates what golden-rule enforcement "layer 1" delivers <!-- id: ss14q3 -->

**Location**: `CLAUDE.md:181-182` (submodule root), § "Four layers of enforcement"

**Description**: The prose reads:

> **The compiler.** `StableStaker is IStableStaker`, so deleting one of the three from the contract
> fails the build (story 014).

That is true only for deleting a *function*. The inheritance link itself is removable at will: strike
`, IStableStaker` from the `StableStaker` contract declaration and the build succeeds with all three
functions gone. This was verified empirically — the CI gate (layer 3) still **exits 0** for the
inheritance-strip mutation.

To be precise about what is and is not broken: layer 3 does catch the mutation that actually matters,
because `check-migration-surface.sh` greps `StableStaker.sol` for the declarations directly rather
than relying on the inheritance link. The compile-time bypass named in story-014's review is
genuinely closed, and that half is faithful. The residual is that the CLAUDE.md description credits
layer 1 with coverage it does not have, so a reader budgeting defence-in-depth counts four layers
where three carry the weight.

**Impact**: none at runtime. Documentation accuracy only. It is recorded because it compounds `L-03`
(`submissions/spec-conformance.md`), which demonstrates that the *deletion* axis is missed by every
purpose-built enforcement layer, and is caught today only incidentally by a compile break.

**Recommendation**: reword layer 1 to state what it actually guarantees — that a declared
`is IStableStaker` cannot coexist with a missing implementation — and note that the inheritance
declaration itself is guarded by layer 3, not by the compiler.

---

## Automated tier residue — informational only

The items below are **deterministic tool output, not reasoned findings**. They are reproduced for
completeness and traceability, not because any of them was judged a defect. Each was checked and
found mitigated or intentional. Per project convention, automated-tool output without a demonstrated
exploit path is not a finding.

### Slither `reentrancy-no-eth` — 5 instances, all guarded, NOT exploitable

| Contract | Function | Line | Guard |
|----------|----------|-----:|-------|
| `src/StableStaker.sol` | `stake` | 311 | `nonReentrant` + `whenNotPaused`; callees are trusted protocol contracts |
| `src/StableStaker.sol` | `depositFor` | 644 | `nonReentrant` + `onlyMigrator` |
| `src/StableStaker.sol` | `initiateMigration` | 465 | `nonReentrant` + `onlyMigrator` |
| `src/StableStaker.sol` | `setYieldStrategy` | 264 | `onlyOwner`, gated on `totalStaked == 0` |
| `src/InPlaceMigrator.sol` | `migrateIn` | 239 | `nonReentrant` + `onlyOwner`; callee is the staker itself |

All five are state-after-external-call orderings sitting behind a reentrancy guard and/or a
privileged-caller modifier, with trusted callees. **As guarded, none is exploitable.** The mitigation
was verified rather than assumed. They are recorded here, not filed, and are recommended for closure
as noise at triage.

### Slither `timestamp` — 2 instances, retained deliberately

- `src/InPlaceMigrator.sol:310` (`claimTimedOut`) — `block.timestamp >= migrationBegin + migrationTimeout`
- `src/StableStaker.sol:724` (`_updatePool`), also `:658` (`pendingReward`) — reward accrual keyed on
  `block.timestamp`

Both are intentional time-based mechanics over multi-hour to multi-day horizons; validator timestamp
influence is bounded at seconds and cannot move either meaningfully. Retained rather than filtered
because this suite does not drop timestamp findings by default in a time-driven protocol.

### Aderyn `non-reentrant-not-first` — ordering nit, benign

`src/InPlaceMigrator.sol:165` and `src/InPlaceMigrator.sol:203` declare `nonReentrant` after
`onlyOwner`, so the guard is not the first modifier evaluated. Modifier order matters only when a
preceding modifier makes an external call before the guard engages; `onlyOwner` makes none. Benign
here — normalize the order if the codebase wants a uniform convention.

### Cross-reference, not a separate item

Slither's `unused-return` at `src/StableStaker.sol:274` (the discarded return of
`strategy.deposit(...)` on the `setYieldStrategy` idle-sweep leg) is **already merged into ledger
entry `dab5a656`** and is deliberately **not filed as a QA item here**. It is named only so a reader
scanning the SAST output can see where it went.

### Semgrep

All 93 Semgrep hits were gas/style (`use-custom-error-not-require` ×44 and similar). **Zero security
rules matched, because `p/smart-contracts` ships no usable Solidity security ruleset** — its clean
security result is not evidence of absence and must not be read as one.

---

## Pre-existing, not filed — EIP-170 contract size

`forge build --sizes` exits non-zero at this commit:

| Contract | Runtime size | EIP-170 limit | Margin |
|----------|-------------:|--------------:|-------:|
| `StableStaker` | 25,389 B | 24,576 B | **-813 B** |
| `InPlaceMigrator` | 12,163 B | 24,576 B | +12,413 B |
| `CrossVersionMigrator` | 4,529 B | 24,576 B | +20,047 B |

No optimizer is configured in this repo (`solc 0.8.28`, `forge build` otherwise clean at exit 0).
This condition is **pre-existing at the baseline commit and was not caused by this run's changes**;
it is recorded for visibility only and is not filed as a finding. The two migrators are comfortably
inside the limit.

---

## Terminology — three different quantities are all called "buffer"

Raised by the protocol owner reviewing this audit. Using the word unqualified made our numbers look
wrong, so this bundle uses none of the three unqualified, and any reader reconciling our artifacts
against the deployment scripts should hold the distinction:

| # | Term | Definition | Where it lives | DOLA | USDC | USDe |
|---|------|------------|----------------|-----:|-----:|-----:|
| 1 | **Set-aside buffer** | Idle ERC20 held by the **staker** contract | Staker | 6.663469 | 9.941647 | 48.506672 |
| 2 | **Principal desync** | `strategy.principalOf` − `poolInfo.totalStaked` | Strategy | +26.898456 | +27.043385 | 0 |
| 3 | **Accrued yield** | `totalBalanceOf` − `principalOf` | Strategy | 0.362377 | 0.953480 | 0.519837 |

Sense (1) is the protocol's intended concept — a liquidity cushion sized for daily withdrawal flow,
**deliberately not a claim-satisfying reserve**. Sense (2) is `M-01`'s quantity, and it sits inside
the strategy, not the staker.

**Trap for script readers**: `PostMigrationCleanup.s.sol` logs sense **(2)** under the label
"buffer". That is *not* the protocol's set-aside buffer, and reading it as such will make the
staker's cushion look roughly four times larger than it is.

---

## Appendix — 4naly3er automated report

The canonical C4-style automated QA/gas report was generated over the full in-scope set (6 files) and
is attached as a separate file:

**`submissions/4naly3er-report.md`** (2,246 lines)

Invocation, for reproducibility:

```bash
cd /home/justin/code/audits/tools/4naly3er
yarn analyze /home/justin/code/audits/lib/stable-staker/ <scope-list>.txt
```

Note on invocation: the third argument is a **scope list**, not a remappings file. `remappings.txt`
resolves *relative to* `BASE_PATH`, so `BASE_PATH` must be the submodule root — not `src/`.

Headline counts from that report, none of which is filed as a finding above:

| Class | Issue types | Instances |
|-------|------------:|----------:|
| Gas optimizations | 14 | 250 |
| Non-critical | 20 | 171 |
| Low | 11 | 43 |
| Medium | 2 | 20 |

Both 4naly3er "Medium" classes are already accounted for: `M-1` fee-on-transfer accounting is
C4-known-invalid for this project (no FoT token is in scope — see `manual-review.json` `MR-22-J4`,
which carries an explicit reopen trigger should one ever be added), and `M-2` "Centralization Risk for
trusted owners" (19 instances) is the ordinary `onlyOwner` surface, suppressed under Law 3.
