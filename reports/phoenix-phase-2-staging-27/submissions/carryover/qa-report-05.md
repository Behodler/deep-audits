# Carryover QA report — audit 05 (entry point `dev`)

> **Carryover QA report — audit 05** (cut down from `reports/phoenix-phase-2-staging-05/findings/qa/`).
> Retained below (still open / untriaged as of audit 27): **Q-01**.
> Removed as no longer live: *(none from the QA bucket).* For completeness: the only other audit-05 `dev` entry, **L-01** `StableStaker pauser == address(0)` / `c294d93f772b…`, was closed **`fixed`** at `bd2290c` and is a Low, not a QA entry — it is not carried, and audit 27's regression check re-confirmed it has **not** reappeared.
> Labels are the originals. This file's `Q-01` is the **audit-05** Q-01. It is a different finding from audit 26's `Q-01` (`1c98937375ad…`, Story 079 provenance, still open) and from audit 27's own `Q-01` (`9067d8a232b5…` / `pps27q1`, `tokenIdToDispatcher` assertion gap). Three distinct findings share the string `Q-01` on this entry point — key on the **fingerprint**, never the label.
> Line numbers were accurate at the originating commit `912f57c` (still-live re-confirmed at `bd2290c`); **re-verify against current HEAD `1d8a3a7` before acting.**

*This is a **full copy**, not a stub. It is content-identical to the audit-26 copy at [`reports/phoenix-phase-2-staging-26/submissions/carryover/qa-report-05.md`](../../../phoenix-phase-2-staging-26/submissions/carryover/qa-report-05.md); only this header carries new information.*

- **Carryover file:** `qa-report-05.md` · **Original label:** Q-01 (run `phoenix-phase-2-staging-05`)
- **Severity:** QA (unchanged since first report)
- **Status:** `open` (untriaged)
- **Fingerprint:** `0b497be32114147aa44ea7328329eaab2f024fd22b3208804fe604b84cca86b3` (unchanged — carried forward, not re-minted)
- **`issueId`:** none. This entry predates the issueId scheme and **no ID was minted by this run** — minting one as a side effect of a carryover copy is a ledger-shape change and belongs to a human. Select it by fingerprint prefix `0b497be32114`.
- **Entry point:** `dev`
- **First seen:** `phoenix-phase-2-staging-05` · **Last re-observed:** `phoenix-phase-2-staging-06` (**not** bumped by audit 21, 26 or 27)
- **Original report:** [reports/phoenix-phase-2-staging-05/findings/qa/Q-01-stablestaker-migrator-zero.json](../../../phoenix-phase-2-staging-05/findings/qa/Q-01-stablestaker-migrator-zero.json)
- **Prior carryovers:** audit 06 ([pointer stub](../../../phoenix-phase-2-staging-06/findings/qa/Q-01-CARRYOVER.md)) → audit 21 ([full copy](../../../phoenix-phase-2-staging-21/submissions/carryover/qa-report-05.md)) → audit 26 ([full copy](../../../phoenix-phase-2-staging-26/submissions/carryover/qa-report-05.md)) → **audit 27 (this file)**

## ⚠ Why this is carried forward rather than closed — fourth audit running

**This finding was NOT re-observed by audit 27, and that is NOT evidence of a fix.**
Audit 27 was scoped to the `dev` entry point's `e1db0f1 → 1d8a3a7` delta — the story-079 rehearsal
follow-through — and did not re-walk StableStaker Phase 3.7. Absence from an entry-point-scoped run carries
no closure authority whatsoever.

- Status **remains `open`**. It was **not** auto-flipped to `fixed` and **no** ledger status was changed
  for it by this run.
- `lastSeenRun` was **deliberately left at `phoenix-phase-2-staging-06`** — bumping it would falsely
  assert re-observation.
- To close it, re-verify explicitly: `/recheck phoenix-phase-2-staging 0b497be32114…`, or a full `dev`
  re-scan.

## ⚠ This entry's fingerprint cannot be reproduced — watch-note `SAN-26-DEV-02`, still open

`0b497be32114147aa44ea7328329eaab2f024fd22b3208804fe604b84cca86b3` **does not reproduce** from its own
recorded inputs. The documented recipe is `sha256(contract:function:rootCauseClass[:entryPoint])`, and this
entry — a run-05/06-era record that predates the field — carries **no `rootCauseClass` at all**, so the
recipe cannot be evaluated and the stored value is unauditable.

**This is the live half of that defect, because this entry is `open`.** A future re-audit that
*recomputes* fingerprints rather than *matching* stored ones would produce a different hash for the same
defect, **re-file it as a brand-new finding, and orphan this entry permanently**. Audits 26 and 27 both
matched rather than recomputed, so nothing was orphaned.

**Fix (human only):** backfill `rootCauseClass` on this entry from the original audit-05 record —
`MissingPostStepConfiguration`, stated in the retained report below — **without changing the stored
fingerprint**, and record the backfill. Rewriting the fingerprint to match a recomputation would orphan
the entry and must not be done. The sibling `fixed` entry `c294d93f772b…` has the same gap and should be
backfilled at the same time.

## Retained entry — Q-01 (audit 05)

*The text below is a verbatim copy of the original report record. Do not re-severity or re-summarise it.*

---

### Q-01 — StableStaker deployed with `migrator == address(0)`: terminal-migration path is permanently unreachable

- **Severity:** qa
- **Contract:** `script/DeployMocks.s.sol` (registry-relative: `lib/phoenix-phase-2-staging/script/DeployMocks.s.sol`)
- **Function:** `run (Phase 3.7)`
- **Lines:** L654–L685
- **Entry point:** `dev`
- **Root cause class:** `MissingPostStepConfiguration`
- **Category:** intent-mismatch
- **Origin:** new (audit 05)

**Description**

> Phase 3.7 never calls setMigrator, so StableStaker.migrator() == address(0) (confirmed via cast). initiateMigration/batchMigrate/depositFor are onlyMigrator (require msg.sender == migrator); with migrator == address(0) none are reachable, so the terminal-migration escape hatch and the StableStakerMigrator orchestrator are inert in this deployment. Healthy-path withdraw/emergencyWithdraw do NOT depend on migrator — _routeExit/withdraw routing is migrator-independent (read of StableStaker.sol withdraw/_routeExit confirms migrator is referenced only by the migration entrypoints), so normal exits are unaffected (verify run withdrew principal cleanly).

**Impact**

> No incident-response migration is possible for the dev StableStaker (e.g. moving stakers to a new staker if a strategy winds down). Lower severity than the pauser gap because (a) it does not affect any healthy user path and (b) it can be set post-deploy by the owner at any time. Recorded as a half-configured deployment consistent with the deployment's stated optional-wiring step.

**Severity rationale**

> Half-configured local-dev deployment with no impact on any healthy user path: withdraw/emergencyWithdraw/_routeExit are migrator-independent (verified — the staker exited principal cleanly), so user funds are never trapped and no asset is at risk. The only consequence is that the optional terminal-migration escape hatch is inert, and the owner can enable it with a single setMigrator call post-deploy. This is pure missing-optional-state-configuration on a mock deployment — squarely QA/Low per the project's spec-deviation/state-handling category, and lower than finding 1 because it touches no incident-response surface that a healthy deployment relies on. Classified QA (the lower of the Low/QA band) given the explicit confirmation that nothing user-facing is affected and the deployment's own optional-wiring step covers it.

**Evidence**

> dev/side-effects.json: migrator()=0x0; StableStaker.sol onlyMigrator modifier gates initiateMigration/batchMigrate/depositFor; withdraw()/emergencyWithdraw()/_routeExit() contain no migrator reference.

**Recommendation**

> If the dev flow is meant to exercise migration, deploy StableStakerMigrator and call stableStaker.setMigrator(migrator) in Phase 3.7. Otherwise document explicitly that migration is intentionally out of scope for local dev.

**PoC:** none (QA, no exploit path).

---

## Other `dev` entry-point ledger state (for completeness, not carried)

- `c294d93f772bf5cb1aec185ff89fb8e1908bb114702bcf884561e778147c29d3` — **L-01, low, `fixed`** at
  `bd2290c` (StableStaker `pauser == address(0)`). **Regression check performed by audit 26 and
  NEGATIVE:** no candidate re-raised it, and the fix was source-verified still present at HEAD —
  `script/DeployMocks.s.sol:1269-1273` still calls `stableStaker.setPauser(address(pauser))` followed by
  `pauser.register(address(stableStaker))`, in the documented `setPauser`-BEFORE-`register` order. Status
  untouched; recorded here to evidence that the check was actually run rather than skipped.
  (Its fingerprint has the same `rootCauseClass` gap described above — see `SAN-26-DEV-02`.)
