# Spec-Conformance Report (Law-2 Faithfulness) — stable-staker-08

> **Scope.** This is the Law-2 *faithfulness* report: deviations between what a
> `[story-NNN]` commit / the submodule `CLAUDE.md` spec **says** a feature does and
> what the code at HEAD **actually** does. It is **separate from the QA bundle**.
> Findings here whose deviation *also* carries asset/value/availability impact are
> ALSO reported under an H/M label with their own PoC; those are cross-referenced by
> label, not duplicated.

- **Project:** stable-staker
- **Run:** stable-staker-08 (regression scan)
- **Audited commit (HEAD):** `f85450b6d73a728f530a97854ecc882151695cd8`
- **Source:** `lib/stable-staker/src/StableStaker.sol`, `lib/stable-staker/src/StableStakerMigrator.sol`
- **Stories newly checked this run:** story-006 (`e7bb675`), story-007 (`f85450b`)
- **Faithfulness verdict this run:** **F-00 — NO NEW deviations** (both new stories faithful, neither unsafe under Law 1)
- **Carryover faithfulness findings (still open):** F-01 (Low), F-02 (QA/Low)

---

## This run: NO NEW faithfulness deviations (F-00)

This is a regression run. The story-faithfulness scan checked the two stories that
landed since the last audited commit, and **both are FAITHFUL** to their `[story-NNN]`
intent — and, critically (Law 1), neither story's *intended* behaviour is itself unsafe.
No new `F-XX` finding is produced. The full conformance trace is recorded at
[`reports/stable-staker/08/findings/faithfulness.md`](../findings/faithfulness.md).

- **story-007 (`f85450b`) — "Relinquish strategy principal on buffer withdrawal" — FAITHFUL.**
  The buffer branch of `_routeExit` now calls `strategy.relinquishPrincipal(token, amount)`
  immediately after emitting `BufferWithdrawn` (`StableStaker.sol:703`), reducing the
  strategy's client principal by the same `amount` that the buffer-path withdraw decrements
  from `poolInfo.totalStaked` (L289). The story's stated invariant —
  `strategy.principalOf(token, this) == poolInfo[token].totalStaked` is preserved through a
  buffer-path withdraw — holds, restoring satisfiability of `initiateMigration`'s full-drain
  post-check. Two candidate gaps were checked and shown to be non-deviations: (a)
  `emergencyWithdraw` (guard OFF) keeps the principal ledger in sync via the
  `strategy.withdraw` primitive, so the story correctly omits it; (b) the protocol-favouring
  relinquish cap cannot bite while `amount <= totalStaked == principalOf` in the maintained
  flow. This story closes the previously-open Medium `dc361b7d` (M-04).

- **story-006 (`e7bb675`) — "Guard setYieldStrategy during migration + drain old strategy on swap" — FAITHFUL.**
  `setYieldStrategy` now reverts with `require(!migrationInfo[token].active, "StableStaker: migrating")`
  at its first statement (`StableStaker.sol:203`), implementing the M-02 guard verbatim, and
  drains the old strategy's position (`_routeExit(token, staked, false)`, L214-217) before
  reassignment. The commit explicitly scopes the drain as **"best-effort,"** so the absence of
  a hard `principalOf == 0` post-check (which `initiateMigration` carries) is faithful to the
  story's own wording, not a deviation — and it is safe because the old strategy is decoupled
  after reassignment and the pool stays live and re-drainable, so any under-recovery surfaces as
  the already-deferred protocol-absorbed haircut rather than a one-way bricking. This story
  closes the previously-open Medium `678e6fa2` (M-02).

> **Note on this run's new Medium M-06 (`dbdc3ac9`).** M-06 is a *residual* of the
> story-006 fix (an underwater strategy swap silently lifts the underwater-withdraw block),
> but it is **not a faithfulness deviation**: it is a value-leak/footgun security finding,
> `faithfulness: false`. It is reported individually with a PoC at
> [`M-06-setYieldStrategy-underwater-swap-rearms-withdraw.md`](./M-06-setYieldStrategy-underwater-swap-rearms-withdraw.md)
> and is referenced from F-02 below only for thematic adjacency (same view signal), not as
> a Law-2 item.

The remainder of this report carries the **still-open** faithfulness findings from prior
runs, reproduced here so the Law-2 lens is not lost between runs. These remain valid at HEAD
`f85450b`; they are Low/QA-grade and are also bundled in this run's QA report.

---

## F-01 — `batchMigrate` re-books migrants below principal through a haircutting destination strategy, breaking the userMigrate/batchMigrate equivalence guarantee

- **Severity:** Low (faithfulness) — also bundled in the QA report
- **Fingerprint:** `4f143a95`
- **Status:** open (carryover) · **First seen:** stable-staker-07 · **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Faithfulness:** yes · **Footgun:** yes (non-obvious, owner-config-dependent) · **PoC:** not required at Low
- **Story violated:** `story-004` ("Replace migrateOut with terminal migration state machine"), commit `f5f6039`
- **Location (actual path):** `batchMigrate` (`src/StableStaker.sol` L429-450) → `StableStakerMigrator.migrate` (L76-80) → destination `depositFor` (L531) → `_routeDeposit` (L656-662)
- **Original report:** [`reports/stable-staker/07/submissions/spec-conformance.md`](../../07/submissions/spec-conformance.md)

### What the spec says

`story-004` (commit `f5f6039`) states the terminal-migration design's equivalence guarantee:

> "batchMigrate + userMigrate then pay a fixed credit p_i\*min(R,P)/P from the
> idle pile, making payouts order- and method-independent (closes ss2m1/M-01)."

The submodule `CLAUDE.md` ("Terminal migration mode") restates it as a hard invariant:

> "every exit — operator `batchMigrate` or permissionless `userMigrate` — pays a
> fixed credit `p_i·min(R,P)/P` from the idle pile, so payouts are independent of
> batch composition, ordering, and **batch-vs-self**. Equal principal ⇒ equal payout."

And the migrator's own contract doc (`CLAUDE.md`) promises principal preservation:

> "moves a batch of users from one `StableStaker` to another with zero user action,
> **preserving principal** and minting earned rewards."

The stated intent: a user must end up in the same economic position whether the operator
sweeps them out with `batchMigrate` or they exit themselves with `userMigrate`.

### What the code actually does

The equal-credit guarantee holds only for the **exit** leg on the *old* staker: both
`batchMigrate` and `userMigrate` funnel through `_exitPosition` and pay `p_i·min(R,P)/P`. But
the two paths diverge **after** that equal credit is computed:

- **`userMigrate`** transfers the credit to the user's **own wallet** — they exit the system
  entirely with full value in hand; they are *not* re-deposited anywhere.
- **`batchMigrate`** hands the aggregate to the migrator, which redeposits each per-user credit
  into the **destination (new) staker** via `StableStakerMigrator.migrate` (L76-80) →
  `depositFor` → `_routeDeposit` (L656-662). If the destination has a haircutting (market)
  `IYieldStrategy` wired for the token at migration time, `_routeDeposit` books
  `credited = strategy.deposit(...) = amount·(1 - slip)`, and the user is recorded **below**
  their migrated principal.

So two equal-principal users diverge purely by exit method: the self-exiter keeps full value,
the batch-migrated user is silently haircut by the destination's `slippageToleranceBps`. This
contradicts the explicit "batch-vs-self … equal principal ⇒ equal payout" invariant and the
migrator's "preserving principal" promise — the equivalence the story closed `ss2m1`/M-01 on
is only preserved on the credit side, not end-to-end.

### Honest severity and disposition

Low, not Medium: the value delta equals the *normal entry slippage* any new depositor into a
haircutting strategy would take, is bounded by the destination's `slippageToleranceBps`, and is
**zero** when the destination is idle or full-credit (the typical state of a freshly deployed
migration target). It is a **non-obvious owner footgun** (migrating into a destination that
already has a haircutting strategy wired), surfaced here per Law 2 rather than buried.

**Safe-config guidance:** migrate into an idle / full-credit destination (wire the destination's
yield strategy *after* the migration batch completes), or normalize credit across both exit paths
so `batchMigrate` redeposits at the same effective value `userMigrate` delivers.

---

## F-02 — `withdrawDisabled` view over-reports after story-002 added the buffer path: returns raw `_isUnderwater`, not "withdraw is blocked"

- **Severity:** QA/Low (faithfulness) — also bundled in the QA report
- **Fingerprint:** `a56f8778`
- **Status:** open (carryover) · **First seen:** stable-staker-07 · **Still present as of:** stable-staker-08 (HEAD `f85450b`)
- **Faithfulness:** yes · **Footgun:** no · **PoC:** not required
- **Story context:** `story-002` ("Add buffer path to `_routeExit`", commit `48be4e2`)
- **Location:** `withdrawDisabled` (`src/StableStaker.sol` L594-600); spec text in `CLAUDE.md` ("Underwater withdraw block")
- **Original report:** [`reports/stable-staker/07/submissions/spec-conformance.md`](../../07/submissions/spec-conformance.md)

### What the spec says

The submodule `CLAUDE.md` ("Underwater withdraw block") documents the view's contract:

> "`withdrawDisabled(token)` is a cheap public view returning **`true` while withdraw
> is blocked** (and `false` when no strategy is set)."

The on-chain NatSpec frames the same promise around *withdrawals being disabled*:

> "True when non-migrating withdrawals are currently disabled for `token` because its
> yield strategy is below par (`totalBalanceOf < principalOf`)."

The documented contract is: `true` ⇔ a withdraw would currently be refused.

### What the code actually does

```solidity
function withdrawDisabled(address token) external view returns (bool) {
    IYieldStrategy strategy = yieldStrategy[token];
    if (address(strategy) == address(0)) {
        return false;
    }
    return _isUnderwater(token, strategy);   // raw underwater, NOT "blocked"
}
```

The view returns the raw underwater predicate (`totalBalanceOf < principalOf`). That equation
was the exact disabled-condition **before** `story-002`. But `story-002` (commit `48be4e2`)
added the buffer path to `_routeExit`:

> "When a token's yield strategy is underwater and the contract holds sufficient idle
> ERC20 balance, withdraw is now served from that buffer instead of touching the
> strategy."

After that change, "withdraw is blocked" became a **strict subset** of "underwater": while the
strategy is below par, a withdraw whose amount the on-contract buffer can cover **still
succeeds** (it is served from the buffer, not the strategy). So `withdrawDisabled` now returns
`true` in cases where a withdraw would in fact go through — the view **over-reports** disabled.
Its documented contract ("true while withdraw is blocked") no longer matches the code.

### Honest severity and disposition

QA/Low, **no value at risk**. The error is in the **conservative** direction only — the view can
report `true` (don't withdraw) when a withdraw would actually succeed, but it never reports
`false` (safe to withdraw) when one would be refused. Worst case is a UX false-negative: an
off-chain UI discourages a withdraw that would have worked via the buffer. This is *not* the
invalid "unused view" category — it is a documented public view whose stated behaviour drifted
from the code after `story-002`.

> **Cross-reference — M-06 is the OPPOSITE direction.** This run's new Medium **M-06**
> (`dbdc3ac9`, [`M-06-setYieldStrategy-underwater-swap-rearms-withdraw.md`](./M-06-setYieldStrategy-underwater-swap-rearms-withdraw.md))
> concerns the *same* `withdrawDisabled` / `_isUnderwater` signal, but is the hazardous
> **under-report**: an owner strategy swap performed while the old strategy is underwater
> recovers only `R_old < totalStaked`, redeposits into a new strategy that reads at par, and
> never rewrites `pool.totalStaked` — so `_isUnderwater` flips to `false` and `withdrawDisabled`
> flips **`true → false`** against a real, unrealized shortfall, silently lifting the protective
> block and realizing an FCFS loss. F-02 and M-06 are **distinct findings** with distinct
> fingerprints and distinct root causes: F-02 is a conservative over-report with no value at
> risk (UX-only), M-06 is a value-leaking under-report. They are kept separate by design.

**Recommendation:** either (a) make the view buffer-aware (return `true` only when underwater
*and* the on-contract buffer cannot cover a reference amount), or (b) update the docs/NatSpec to
state the view reports "strategy below par" rather than "withdraw blocked," since blocking is now
buffer-dependent.

---

## Summary

| Finding | Severity | Fingerprint | Status | Faithfulness lens |
|---|---|---|---|---|
| — (story-006 `e7bb675`) | — | — | **FAITHFUL** (F-00) | `!active` guard + best-effort drain implement the story; not unsafe under Law 1 |
| — (story-007 `f85450b`) | — | — | **FAITHFUL** (F-00) | buffer-path `relinquishPrincipal` preserves `principalOf == totalStaked`; not unsafe under Law 1 |
| F-01 | Low | `4f143a95` | open (carryover) | `batchMigrate`/`userMigrate` credit asymmetry vs story-004 equivalence + "preserving principal" |
| F-02 | QA/Low | `a56f8778` | open (carryover) | `withdrawDisabled` over-reports raw `_isUnderwater` vs story-002 buffer path (opposite of M-06) |

**New deviations this run: none (F-00).** Carryover faithfulness findings: **F-01, F-02**
(both still live at HEAD `f85450b`, both also bundled in the QA report). Security cross-reference:
the new Medium **M-06** (`dbdc3ac9`, reported individually) is thematically adjacent to F-02 but is
a non-faithfulness value-leak footgun, kept distinct.
