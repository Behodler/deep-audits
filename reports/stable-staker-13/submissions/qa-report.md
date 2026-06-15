# QA Report — stable-staker (run-13)

**Project:** stable-staker
**Scope of this run:** `src/InPlaceMigrator.sol` (story-013, "surplus-funded re-injection top-up / M-01 haircut fix")
**Submodule HEAD:** `d95f4a6fa6391386c547e45e9bf99b3c39f2fe35`
**Diff baseline:** `ffa4947` (story-012)
**Mode:** regression
**Date:** 2026-06-15

## Preamble

This was a regression run over the single-file story-013 diff on `InPlaceMigrator.sol`. The **headline result is positive and is not in this bundle**: `ss12m1` (M-01, the `migrateIn` re-injection haircut that silently underpaid re-injected users by the migration slippage) is **PoC-verified FIXED** by story-013's surplus-funded gross-up top-up. Par is restored to within 1 wei, and the zero-surplus case reverts atomically rather than under-crediting. That fix is correct on the value-loss axis and is proposed `open → fixed` on the ledger separately by finding-manager.

The run produced **0 High, 0 Medium, and 0 faithfulness (F-XX) deviations.** The four items below are **operational-hardening residue of that very fix** — they live on the new top-up path itself. Every one of them is an atomic revert (no silent under-credit, no principal loss) or a pure documentation/hygiene defect, so none of them reopens the value-loss that `ss12m1` closes. They are surfaced at honest, conservative severity per the repo's severity discipline (non-critical findings discouraged; overstatement rejected).

Two of the four (L-01, L-02) are **owner footguns** under Law 3 of the audit hierarchy — non-obvious consequences of knowing, non-malicious operator actions — kept because a competent operator would be surprised by them. They are not malicious-owner vectors. The remaining two (L-03, L-04) are an arithmetic availability edge-case and a code-vs-comment contradiction respectively.

## Summary

| Severity | Count |
|----------|-------|
| Low Risk | 3 |
| Centralization | 0 |
| **Total** | **3 + 1 QA/info** |

| ID | Title | Class |
|----|-------|-------|
| [L-01](#l-01-underfunded-migratein-batch-reverts-and-greedy-cross-slice-surplus-strands-later-slices) | Underfunded `migrateIn` batch reverts; greedy cross-slice surplus strands later slices | Low (footgun) |
| [L-02](#l-02-rescueerc20-and-the-top-up-budget-share-one-balance--a-mid-migration-sweep-bricks-par-restoration) | `rescueERC20` and the top-up budget share one balance — a mid-migration sweep bricks par-restoration | Low (footgun) |
| [L-03](#l-03-small-principal-top-up-truncation-reverts-migratein-for-sub-1000-unit-principals) | Small-principal top-up truncation reverts `migrateIn` for sub-1000-unit principals | Low / QA |
| [L-04](#l-04-widened-forceapprove-leaves-a-dangling-allowance-contradicting-the-exact-slice-total-comment) | Widened `forceApprove` leaves a dangling allowance, contradicting the "exact slice total" comment | QA / info |

> An automated SAST / gas baseline (4naly3er) is attached as **Appendix A**: [`4naly3er-report.md`](./4naly3er-report.md).

---

## Low Risk Findings

### [L-01] Underfunded `migrateIn` batch reverts; greedy cross-slice surplus strands later slices <!-- id: ss13l1 -->

**Location:** [`lib/stable-staker/src/InPlaceMigrator.sol#L262-L294`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L262) (`_reinjectWithTopup`, called from `migrateIn`, `#L202-L251`)

**Description:**
The story-013 gross-up math silently introduces a **surplus pre-funding requirement that is invisible at the call site.** For each re-injected user, the first `depositFor(token, user, amt)` (`#L268`) is credited only the strategy's haircut-reduced return, and the shortfall is closed with a grossed-up top-up:

```solidity
topup = Math.mulDiv(amt - credited, amt, credited);            // :276
require(
    topup <= IERC20(token).balanceOf(address(this)) - totalParked[token],  // :280-281
    "InPlaceMigrator: top-up surplus exhausted"
);
```

The top-up is funded from surplus held *above* `totalParked` — i.e. balance the operator must pre-fund **over and above** the parked principal. An operator running the documented `migrateOut → finalizeAndReset → setYieldStrategy → migrateIn` runbook would reasonably assume the parked principal funds the re-injection; it does not. If the grossed-up surplus is not separately pre-funded, every `migrateIn` slice that routes through a haircutting strategy reverts atomically.

Two compounding facets on the same path:
- **No cross-slice reservation.** The surplus budget is checked per-user against the *live* `balanceOf - totalParked` with no reservation across a paginated migration. Earlier slices greedily consume the shared surplus, so a top-up that would have succeeded in isolation can strand later paginated slices once the surplus is drawn down.
- **Error-quality (folded sub-point):** the surplus check subtracts `balanceOf - totalParked` (`#L281`). When the surplus is exhausted this subtraction underflows to a panic (`0x11`) *before* the `require` string is reached, masking the real under-funding root cause from the operator with an opaque arithmetic panic.

**Impact:** None to assets. The failure mode is an **atomic revert** of the `migrateIn` batch — no silent under-credit, no principal loss. Parked principal stays escrowed under `totalParked` and is fully recoverable: the operator pre-funds and re-runs, or each parked user independently invokes the permissionless, self-scoped `claimTimedOut` (`#L306`) after the timeout. The migration is **deferred**, not bricked — hence Low, not Medium. (The conditional-Medium escalation was assessed and declined: the leg is retryable and recovery is permissionless.)

**Recommendation:**
- Document the gross-up surplus pre-funding precondition in the story-013 runbook: the operator must transfer grossed-up surplus to the migrator *before* `migrateIn`, sized for the worst-case haircut across the whole user set, not just the parked principal.
- Reserve per-slice top-up budget when paginating (e.g. track committed top-ups across slices) so earlier slices cannot strand later ones.
- Replace the underflow-prone surplus check with an explicit comparison that yields the readable revert string instead of a panic:

```solidity
uint256 bal = IERC20(token).balanceOf(address(this));
require(bal >= totalParked[token] + topup, "InPlaceMigrator: top-up surplus exhausted");
```

---

### [L-02] `rescueERC20` and the top-up budget share one balance — a mid-migration sweep bricks par-restoration <!-- id: ss13l2 -->

**Location:** [`lib/stable-staker/src/InPlaceMigrator.sol#L337-L341`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L337) (`rescueERC20`) vs `#L280-L281` (`_reinjectWithTopup` surplus budget)

**Description:**
`rescueERC20` and the `_reinjectWithTopup` top-up budget draw from the **same unescrowed quantity**, `balanceOf(address(this)) - totalParked[token]`:

```solidity
// rescueERC20 (:337-339)
uint256 surplus = IERC20(token).balanceOf(address(this)) - totalParked[token];
require(amount <= surplus, "InPlaceMigrator: cannot touch parked principal");
```

The contract's NatSpec (`#L327-L336`, point (G)) advertises `rescueERC20` as fenced below the `totalParked` floor and therefore "incapable of touching parked principal" — which is true. But the same fence does **not** protect the *in-flight top-up surplus*, which lives in exactly that above-the-floor band. An owner who has pre-funded surplus for an in-progress migration and then sweeps "stray" balance via `rescueERC20` as routine housekeeping — a reasonable, non-malicious action the NatSpec implies is safe — unknowingly removes the top-up budget and triggers the L-01 revert on the next `migrateIn` slice.

**Impact:** None to assets. The principal floor (`totalParked`) is intact and the NatSpec invariant (C)/(G) holds — no user loses principal. The consequence is a **stalled migration** (par-restoration cannot complete until surplus is re-funded), backstopped by the permissionless `claimTimedOut` escape hatch. Low-severity operational hazard: a non-obvious inter-function coupling a competent operator would be surprised by.

**Recommendation:** Make the in-flight top-up surplus explicit so `rescueERC20` cannot consume it. Either gate `rescueERC20` while a migration is open for the token, or track a `reservedSurplus[token]` and fence the rescue below `totalParked + reservedSurplus`:

```solidity
uint256 floor = totalParked[token] + reservedSurplus[token];
uint256 surplus = IERC20(token).balanceOf(address(this)) - floor;
```

At minimum, amend the (G) NatSpec to warn that `rescueERC20` can sweep the top-up surplus and must not be called mid-migration.

---

### [L-03] Small-principal top-up truncation reverts `migrateIn` for sub-1000-unit principals <!-- id: ss13l3 -->

**Location:** [`lib/stable-staker/src/InPlaceMigrator.sol#L262-L294`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L262) (`_reinjectWithTopup`)

**Description:**
Two integer-truncation edge-cases on small parked principals each abort the whole atomic batch:

1. **Top-up rounds to zero.** When the shortfall grosses up to `topup == 0` because `Math.mulDiv` floors (`#L276`), the second `depositFor(token, user, 0)` hits `depositFor`'s `require(amount > 0)` and reverts. The guarding predicate `if (credited < amt)` (`#L273`) is misaligned with `depositFor`'s `> 0` precondition: control enters the top-up branch with a zero amount and never reaches the non-reverting `finalCredited` backstop at `#L288-L292`.

2. **Slack floor evaporates below 1000 units.** The backstop tolerance is `amt - amt / 1000` (`#L292`). For `amt < 1000` raw units, `amt / 1000 == 0`, so the tolerance collapses to **zero-tolerance exact par**. Since the gross-up rounds DOWN, `finalCredited` is generically a few wei short, so `require(finalCredited >= amt - amt/1000)` reverts. The advertised "0.1% slack" silently disappears for any principal below 1000 units.

This is an implementation-quality / availability defect, not an owner action. It is distinct from known-issue KI#2 (which blesses *silent* reward-emission dust rounding DOWN in the protocol's favour): here the truncation causes a **revert on the migration path**, not a silent dust loss.

**Impact:** None to assets — an atomic revert, no value moves. A `migrateIn` slice that contains a sub-1000-unit ("dust") parked principal cannot complete until the dust user is excluded from the slice. Low/QA availability edge-case.

**Recommendation:**
- Align the predicates: skip the top-up `depositFor` when `topup == 0` (the `finalCredited` backstop already tolerates the residual), e.g. `if (topup > 0) staker.depositFor(token, user, topup);`.
- Use an absolute floor for the slack so it does not collapse below `amt = 1000`, e.g. `amt - Math.max(amt / 1000, 1)` or an explicit small-absolute tolerance, so par-restoration tolerates the few-wei integer residual at every principal size.

---

## QA / Informational

### [L-04] Widened `forceApprove` leaves a dangling allowance, contradicting the "exact slice total" comment <!-- id: ss13l4 -->

**Location:** [`lib/stable-staker/src/InPlaceMigrator.sol#L220-L227`](../../../lib/stable-staker/src/InPlaceMigrator.sol#L220) (vs the (E) NatSpec at `#L189-L192`)

**Description:**
The NatSpec point (E) at `#L189-L192` states the scoped approval "is set to the EXACT slice total immediately before the `depositFor` loop and never left dangling … `depositFor` pulls exactly the slice total, so nothing lingers." The implementation instead approves the migrator's **entire token balance**:

```solidity
if (IERC20(token).balanceOf(address(this)) > 0) {
    IERC20(token).forceApprove(address(staker), IERC20(token).balanceOf(address(this)));  // :225-226
}
```

`balanceOf(address(this))` exceeds `total + Σtopup` (the parked principal plus surplus), so after the batch a **residual allowance** of `balanceOf - (total + Σtopup)` remains granted to `staker`. The widening is intentional (it must cover both the principal deposits *and* the per-user surplus top-ups in one approval), but the in-code comment claiming "exact slice total … nothing lingers" is **false as written** — the invariant the comment advertises does not hold.

**Impact:** None. `staker` is `immutable` and trusted (the contract pins it at construction precisely to make it non-redirectable, NatSpec (D)), so the residual allowance puts no value at risk; the next `migrateIn` overwrites it (no monotonic accumulation). This is a documentation/hygiene defect, not a security issue — surfaced for accuracy (recall-beats-tidiness), not escalated.

**Recommendation:** Reconcile code and comment. Either tighten the approval to the actual need:

```solidity
forceApprove(address(staker), total + projectedTopups);
```

or keep the wide approval but clear it at the end of the batch and amend the (E) comment to describe the real behaviour:

```solidity
// after the loop:
IERC20(token).forceApprove(address(staker), 0);
```

---

## Appendix A — Automated QA / Gas Report (4naly3er)

The canonical C4-style automated analyzer **4naly3er** was run against the in-scope source tree (`workspace/stable-staker/src`, synced to `d95f4a6`) on 2026-06-15. Its full Gas-Optimization / Non-Critical markdown output is attached alongside this bundle:

- [`4naly3er-report.md`](./4naly3er-report.md)

The automated output is a low-severity SAST/gas baseline (revert-string→custom-error, `++i`, `address(0)` assembly checks, `renounceOwnership` disablement, two-step ownership, etc.). None of its findings rises above the QA/gas tier or overlaps a High/Medium path; the manual L-01..L-04 items above are the substantive QA content of this run. Scope reported by the tool: `InPlaceMigrator.sol`, `StableStaker.sol`, `StableStakerMigrator.sol`, `interfaces/IStableStaker.sol`.
