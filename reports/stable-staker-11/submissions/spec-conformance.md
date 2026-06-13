# Spec-Conformance Report (Law 2 — Faithfulness)

- **Project:** stable-staker
- **Run:** stable-staker-11 (regression mode)
- **Range audited:** `125f585..c3ec65b`
- **Submodule HEAD:** `c3ec65bf0115e9bcc0a75f705a1c8cb57b32ce94`
- **Date:** 2026-06-09

This report covers Law-2 faithfulness findings (story / spec deviations) for this run.
Findings here carry no asset/value/availability impact of their own; where a deviation
*also* has security impact it additionally carries an H/M label and a standalone report.

**No new `F-XX` faithfulness deviation was found this run.** The sole `125f585..c3ec65b` change —
`[story-011]`'s one-line `depositFor` zero-credit guard — was verified **FAITHFUL** (see below).
The three carryover deviations (`F-01`, `F-02`, `F-03`) below are unchanged from prior runs and are
reproduced here for continued visibility.

---

## Positive faithfulness result — story-011 `depositFor` zero-credit guard is FAITHFULLY implemented and SAFE

`[story-011]` (commit `c3ec65b`) adds the missing zero-credit guard on `depositFor`, the symmetric
counterpart to the pre-existing guard on `stake`. Acceptance criterion (commit body):

> **`depositFor` must reject a deposit that books zero credited principal** — i.e. it must carry the
> same `require(credited > 0)` guard as `stake`, so a zero-position phantom staker can never be
> inserted into `_stakers`.

This is delivered **exactly** by the require at `src/StableStaker.sol:632`:

```solidity
require(credited > 0, /* zero-credit guard */);
```

- **Faithfulness: PASS.** Both `_stakers.add` sites are now guarded (the pre-existing `stake` guard
  at L301 and the new `depositFor` guard at L632). A zero-credit (`credited == 0`) insertion — the
  mechanism behind the phantom-staker family (`eae10d60` Low, escalated to `8d5ceff2` Medium) — can
  no longer occur.
- **Law-1 safety of the intended design: SAFE.** The guard only *removes* a degenerate reachable
  state (a zero-position staker stranded in `_stakers`); it introduces no new reachable behaviour.
  Three independent agents (story-faithfulness, code-scanner, poc-validator) confirm the fix is
  faithful, complete, and safe with no new bug and no surviving phantom-creation path. The original
  PoC (`test/PoC_DEDUP001_PhantomStakerBrick.t.sol`) now reverts at setup; the new proof-of-fix
  (`test/PoC_story011_DepositForZeroCreditReverts.t.sol`) passes.

---

## F-01 (carryover, Low, Law-2 deposit-side deviation) — Migration credit asymmetry: `batchMigrate` books below principal vs `userMigrate`

- **Severity:** Low  ·  **Status:** open  ·  **Fingerprint:** `4f143a95`
- **Contract / function:** `src/StableStaker.sol` — `batchMigrate` (L429-450); cross-contract
  `src/StableStakerMigrator.sol:migrate` (L76-80)
- **Original report:** [reports/stable-staker-07/submissions/spec-conformance.md](../../stable-staker-07/submissions/spec-conformance.md)
- **Carryover stub:** [reports/stable-staker-08/submissions/carryover/F-01-migration-credit-asymmetry-carryover.md](../../stable-staker-08/submissions/carryover/F-01-migration-credit-asymmetry-carryover.md)

### Story / spec text violated

The migrator's principal-preservation / equivalence story requires that a migrated staker is booked
at their **old-staker principal**, and that the exit method (operator-batched vs self-migrate) does
not change the credit a user receives.

### Actual behaviour

`StableStakerMigrator.migrate` (L76-80) re-deposits each user's credit via
`newStaker.depositFor → _routeDeposit`, which a **haircutting destination strategy** reduces to
`credited = amount * (1 - slip)`. A user who instead self-exits via `userMigrate` receives tokens at
**full credit**. Equal-principal users therefore diverge purely by exit method, breaking the
migrator's principal-preservation/equivalence story. Magnitude = destination `slippageToleranceBps`;
zero when the destination is idle / full-credit at migration time.

**Impact:** Law-2 faithfulness gap (deposit-side principal-preservation break). Honest severity
**Low** (bounded by destination slip, config-dependent). Non-obvious owner footgun. No new analysis
this run — unchanged at `c3ec65b`.

---

## F-02 (carryover, Low, Law-2 view deviation) — `withdrawDisabled` over-reports after the story-002 buffer path

- **Severity:** Low  ·  **Status:** open  ·  **Fingerprint:** `a56f8778`
- **Contract / function:** `src/StableStaker.sol` — `withdrawDisabled` (L594-600)
- **Original report:** [reports/stable-staker-07/submissions/spec-conformance.md](../../stable-staker-07/submissions/spec-conformance.md)
- **Carryover stub:** [reports/stable-staker-08/submissions/carryover/F-02-withdrawDisabled-overreports-carryover.md](../../stable-staker-08/submissions/carryover/F-02-withdrawDisabled-overreports-carryover.md)

### Story / spec text violated

`withdrawDisabled` is a documented public view whose stated contract is **"true while withdraw is
blocked."**

### Actual behaviour

The view returns raw `_isUnderwater`. After story-002 made *blocking* a **strict subset** of
underwater (buffer-covered withdraws still succeed while underwater), the view's documented contract
no longer holds — it **over-reports** `disabled`, reading `true` where a buffer-covered withdraw
would in fact succeed. The direction is conservative (it never *under*-reports), so no value is at
risk; the deviation is UX/spec only.

**Impact:** UX/spec false-negative only — an off-chain UI may discourage a withdraw that would have
succeeded via the buffer. This is **not** the invalid "unused view" category: it is a documented
public view whose stated behaviour drifted from the code. Unchanged at `c3ec65b`.

> Cross-reference: thematically adjacent to the (propose-fixed) Medium `dbdc3ac9` (M-06), which is
> the **opposite-direction** hazardous *under*-report on the same `withdrawDisabled`/`_isUnderwater`
> signal. Kept as separate entries.

---

## F-03 (carryover, Low, Law-2 doc-lag) — CLAUDE.md Terminal-migration section documents the superseded `active`-bool model

- **Severity:** Low  ·  **Status:** open  ·  **Fingerprint / ID:** `ss9f3`
- **Carries `proposedStatus: fixed @ 125f585`** (run-10) — pending human `/ledger` confirmation.
- **Contract / file:** `lib/stable-staker/CLAUDE.md` — Terminal-migration section (L84-96)
- **Story:** story-009
- **Original report:** [reports/stable-staker-09/submissions/spec-conformance.md](../../stable-staker-09/submissions/spec-conformance.md)

### Spec text violated

`lib/stable-staker/CLAUDE.md` Terminal-migration section (L84-96) still documents the irreversible
`active`-bool model:

> "sets `active = true` … Migration is terminal: once engaged a token's pool can never resume healthy
> operation (no resume path)."

### Actual behaviour

story-009 superseded that model with a **`PoolState` enum** plus **`finalizeAndReset`**
(`StableStaker.sol` ~L585-596), which **does revive** a fully-drained pool
(`PoolState.Migrating → Active`). The documented spec and the implemented code now disagree.

**Impact:** Law-2 documentation lag; no value at risk (the code is the new intended behaviour, the
doc is stale). `lib/` is read-only — this is **reported, not fixed**.

### Resolution note (this run)

Run-10 recorded that commit `125f585`'s CLAUDE.md rework resolves the documented-CLAUDE.md surface
this entry covers (the irreversible `active`-bool model is now superseded by the documented
`PoolState` enum + `finalizeAndReset` revival + empty-pool gate), so the entry carries
`proposedStatus: fixed @ 125f585`. story-011 (`c3ec65b`) does **not** touch this surface; the proposal
is unchanged and still **awaits human `/ledger` confirmation**:

```
/ledger stable-staker fixed ss9f3 --commit 125f585
```

> Note: the **in-source Solidity NatSpec** surface is a **distinct** doc deviation that `125f585` did
> *not* fix — that remains open as run-10's `ss10q1` / spec-conformance F-01 (`b197e829`), tracked in
> the QA bundle and the run-10 spec-conformance report.
