<!--
FILED — label L-08, issue id ss14l8, ledger entry created 2026-08-28.
Project: stable-staker
Run: stable-staker-14
Commit: 8856781cc0d96d1e17f7c60e807e146c04cbad98 (branch `master`)
Ledger fingerprint: f7991b64adc3503e1f57825d8f34eb213d233d3d85cc72724eb3c69dd6c99388
     Preimage: src/StableStaker.sol:initiateMigration:set-aside-buffer-excluded-from-migration-realized
     (legacy hash form — entryPoint is empty; this is a contract scan, not a script audit)
Severity: LOW (the Medium counter-argument is argued in full below and recorded in the ledger)
Type: Law-2 faithfulness gap (implementation contradicts the owner's stated intent).
     Routed to spec-conformance, NOT the QA bundle.
LABEL NOTE: this is L-08, not L-07. L-07 was retired earlier in this run when the old L-07 was
     re-escalated to M-01 (ss14m1); reusing it would silently repoint every existing L-07
     cross-reference. See classified-findings.json -> severityTally.retiredLabels.
Related (cross-reference, DO NOT MERGE):
  - ss14m1 / M-01 (d1aa4060) — same function, different defect
  - 0790a76a (open Low, rescueERC20 can sweep the buffer backing underwater withdrawals)
  - 69c7666eee (wont-fix Medium), 0dca43f315 (acknowledged Medium) — same underwater-loss theme
Root Cause Link: https://github.com/Behodler/stable-staker/blob/master/src/StableStaker.sol#L472-L475
-->

# [L-08] Terminal migration ignores the set-aside buffer, haircutting users while liquid cushion sits idle

*(`ss14l8` · fingerprint `f7991b64…` · Law-2 faithfulness · spec-conformance)*

**Severity:** Low (filed; see [Severity](#severity), which argues the Medium case honestly — that call is the owner's)

**Status:** open. Filed 2026-08-28 as **L-08** (`ss14l8`), fingerprint
`f7991b64adc3503e1f57825d8f34eb213d233d3d85cc72724eb3c69dd6c99388`.

---

## Finding description and impact

### Summary

The protocol owner's stated intent is that **"all yield and the set-aside buffer should be swept into
principal during a migration."** The implementation does not do this. `initiateMigration` computes the
realized amount `R` **exclusively** from what the strategy withdrawal delivers, and deliberately excludes
the staker's pre-existing idle balance — the set-aside buffer.

Because migration credits are `amt * min(R, P) / P`, a smaller `R` means a larger haircut. So in exactly
the situation the set-aside buffer exists to cushion — an underwater strategy — **the buffer sits unused
on the staker while every user takes a proportional haircut.**

This is not a missed optimisation. The exclusion is a **deliberate, documented design decision** that
contradicts the owner's stated intent, which makes it a **Law-2 faithfulness gap**.

### Authority for this finding

This finding does not exist without the owner's statement. The code is internally consistent and does
exactly what its own comment at `:472-475` says; what makes it a finding is that the comment's choice
contradicts the intent the protocol owner stated directly on **2026-08-28**:

> "I want all yield and setAside buffer swept into principal during a migration… I'm not as
> interested in precise migrations as I am in safe migrations erring on the side of the user if
> possible, but never wrecking the protocol in a way that breaks any functionality (exploit vector)."

The current behaviour errs **against** the user — the opposite of that priority. That is the whole of
the Law-2 case, and it is recorded here as the finding's authority rather than left implicit.

### `R` excludes the buffer by construction

`_routeExit` returns only the delta produced by the strategy withdrawal —
`src/StableStaker.sol:801-803`:

```solidity
801:        uint256 balanceBefore = t.balanceOf(address(this));
802:        strategy.withdraw(token, amount, address(this));
803:        return t.balanceOf(address(this)) - balanceBefore;
```

Any idle balance already held by the staker is inside `balanceBefore` and is subtracted straight back
out. `initiateMigration` assigns that value directly as the realized figure (`:451`, `:476`):

```solidity
451:        uint256 R = _routeExit(token, P, false);
...
476:        migrationInfo[token] = MigrationInfo({realized: R, principalSnapshot: P});
```

And the credit formula caps at par, so a smaller `R` translates directly into a smaller payout —
`src/StableStaker.sol:536-537`:

```solidity
536:        uint256 S = mig.realized < P ? mig.realized : P; // min(R, P): caps credits at par
537:        credit = (amt * S) / P;
```

### The exclusion is explicit and deliberate

`src/StableStaker.sol:472-475` states the choice outright:

```solidity
472:        // Surplus is NOT swept. withdraw caps payout at par, so R ≤ P structurally; any above-par yield
473:        // stays inside the now-decoupled strategy as protocol-owned value and never reaches users (the
474:        // "stakers get principal + phUSD only" invariant holds). min(R, P) below is therefore == R in
475:        // practice but defends against a stray above-par R (e.g. a donation) by capping credits at par.
```

The comment's reasoning is internally coherent — it is defending the "stakers get principal + phUSD only"
invariant against *above-par* yield reaching users. But it does not address the *below-par* case, which
is the one that matters here: when `R < P`, users are haircut while liquid protocol funds sit idle on the
same contract, earmarked as a cushion for exactly this scenario.

### The buffer is already spendable — only the accounting excludes it

This is worth stating precisely, because it makes the fix an accounting change rather than a liquidity
change. Credits are paid by plain transfer from the staker's whole balance —
`src/StableStaker.sol:571` (`userMigrate`) and the batch equivalent:

```solidity
571:        IERC20(token).safeTransfer(msg.sender, credit);
```

So the set-aside buffer is **already available to pay migration credits**. It is simply never *counted*
in `R`, so the credits computed are smaller than the contract's own liquidity could support. Nothing
about the money's location needs to change.

### Impact

When a strategy is underwater, `R < P` and every user takes a proportional haircut while liquid buffer
sits unused. Verified on mainnet at block **25,851,231**:

| Pool | Set-aside buffer available but uncounted |
|------|------------------------------------------|
| USDe | 48.506672 |
| USDC | 9.941647 |
| DOLA | 6.663469 |

**This errs *against* the user — the opposite of the owner's stated priority.** No value is lost or
stolen; users are under-paid relative to intent, not relative to the current code.

---

## Severity

**Proposed: Low.** Arguing it honestly, including the Medium case:

**Why Low:**
- No exploit vector and no attacker. Nothing is stolen.
- No protocol functionality is broken — migration works; it simply pays less than intent allows.
- Users are under-paid **relative to stated intent**, not harmed relative to the code as written. The
  code does exactly what its own comment says it does.
- It bites only when a strategy is underwater (`R < P`); at or above par the cap makes it moot.

**The honest case for Medium**, since the brief asked whether the haircut it fails to soften is material:
the amounts are **not trivial relative to a haircut**. Against a pool of roughly 2,067 USDe, a 48.5 USDe
buffer is about **2.3%** of principal — enough to absorb a small impairment entirely, or to
meaningfully soften a larger one. For USDC (~9.94 against ~2,036, **~0.49%**) and DOLA (~6.66 against
~1,223, **~0.54%**) the proportions are smaller but real. If a strategy took a 2% loss, the USDe buffer
alone would cover essentially all of it, and users would be haircut anyway.

**On balance I keep Low**, because C4 Medium requires assets at risk or protocol
function/availability impacted, and neither holds: the value is not lost, it remains protocol-owned and
recoverable, and the migration path itself functions. The gap is between implementation and *intent*,
which is the Low/QA band. **But the Medium argument is not frivolous**, and if the owner regards
"users are haircut while the designated cushion sits idle" as a functional failure rather than an
imprecision, Medium would be defensible. Flagging rather than deciding unilaterally.

---

## Recommended mitigation

Include the staker's pre-existing idle balance for the token in `R`.

```solidity
// In initiateMigration, after the strategy realization at :451:
uint256 R = _routeExit(token, P, false);
// NEW: count the set-aside buffer already held. Credits remain capped at min(R, P), so this can
// only reduce a haircut, never create an over-credit.
R += idleHeldBeforeRealization;   // = t.balanceOf(address(this)) sampled before _routeExit
```

(Sample the idle balance **before** `_routeExit` runs, since `_routeExit` transfers the withdrawal
proceeds into the same balance.)

### Safe by construction

Credits are already capped at `min(R, P)` (`:536`), so a larger `R` **can never pay above par**. The
existing comment at `:474-475` already relies on that cap to defend against a stray above-par `R` from a
donation — this change leans on exactly the same guarantee. It can only *reduce* a haircut, never create
an over-credit, which satisfies "err toward the user" without opening any over-credit vector.

Payout backing also holds: total credits ≤ `min(R,P)` ≤ `R`, and after the change `R` equals the
contract's actual liquid balance for the token, so every credit remains fully backed.

### Two consequences to state up front

**(a) A revived pool starts with no cushion.** The buffer is consumed by the migration, so after
`finalizeAndReset` the pool has no set-aside buffer until it is refilled. This should be an explicit step
in the revival runbook, not a discovery. Note it also interacts with M-01: a re-wired pool that receives
a fresh buffer *before* `setYieldStrategy` will have that buffer swept into strategy principal.

**(b) `rescueERC20`'s reservation — verified, and it already behaves correctly.**
`src/StableStaker.sol:818-825`:

```solidity
820:        uint256 reserved = address(yieldStrategy[token]) == address(0) ? poolInfo[token].totalStaked : 0;
821:        uint256 bal = IERC20(token).balanceOf(address(this));
822:        require(bal >= reserved + amount, "StableStaker: would touch user principal");
```

During `Migrating`, `yieldStrategy[token]` has been zeroed (`:465`), so `reserved == totalStaked`. And
`totalStaked` decrements as each user exits (`:545`), while each outstanding credit is
`amt * min(R,P) / P ≤ amt`. Therefore `reserved` is always **greater than or equal to** the total
outstanding migration obligation, and the rescue guard already protects a buffer earmarked for migration
credits. **No change is required here** — but it is worth recording, because the protection is
incidental rather than intentional, and a future edit to either the `reserved` expression or the
`yieldStrategy`-zeroing at `:465` could silently remove it.

---

## Relationship to other ledger entries

### M-01

**Separate finding; cross-reference, do not merge.** M-01 concerns the *principal desync*
(`principalOf − totalStaked`, quantity 2) making `initiateMigration` revert. This finding concerns the
*set-aside buffer* (idle staker balance, quantity 1) being excluded from migration credits. Different
quantity, different code path (`:472-475` / `:801-803` versus `:272-274` / `:456-459`), different fix,
and neither fix resolves the other.

They share only the owner's intent statement as their origin, and the terminology collision documented
in M-01's disambiguation table — which is precisely why they must not be conflated.

### Other cross-references (do not merge)

- **`0790a76a`** (open, Low) — *"`rescueERC20` can sweep the buffer backing underwater withdrawals."*
  Adjacent: both concern the set-aside buffer's status under stress. That entry is about the buffer
  being **removable**; this one is about it never being **counted**. Different fixes.
- **`69c7666eee`** (wont-fix, Medium) — *"Underwater withdraw buffer is FCFS at par."*
- **`0dca43f315`** (acknowledged, Medium) — *"`emergencyWithdraw` realizes underwater loss FCFS."*

Both of the latter share this finding's theme of **who absorbs an underwater loss**, and are listed
for context only. Their triage statuses are untouched.
