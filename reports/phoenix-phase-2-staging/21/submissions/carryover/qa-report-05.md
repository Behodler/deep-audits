# Carryover QA report — audit 05 (entry point `dev`)

> **Carryover QA report — audit 05** (cut down from `reports/phoenix-phase-2-staging/05/findings/qa/`).
> Retained below (still open / untriaged as of audit 21): **Q-01**.
> Removed as no longer live: *(none — the only other `dev` entry from that audit, L-01 `StableStaker pauser == address(0)` / `c294d93f77…`, was closed `fixed` at `bd2290c` and is a Low, not a QA entry).*
> Labels are the originals — this run's own new QA labels (`Q-01`…`Q-04` under `findings/qa/`) are a **separate sequence** and must not be confused with the `Q-01` below, which is the **audit-05** Q-01.
> Line numbers were accurate at the originating commit (`912f57c`, still-live re-confirmed at `bd2290c`); **re-verify against current HEAD `3fb4e34` before acting.**

*Placement note (§8.5): this is a **full copy**, not a stub, relocated into `submissions/carryover/` so a reader working through `submissions/` finds it without following a link. The identical copy under [`findings/carryover/qa-report-05.md`](../../findings/carryover/qa-report-05.md) is left in place; neither is authoritative over the other. Relative links below resolve from this depth (`submissions/carryover/` is the same depth as `findings/carryover/`, so `../../../` reaches `reports/`).*

- **Carryover file:** `qa-report-05.md` · **Original label:** Q-01 (run `phoenix-phase-2-staging-05`)
- **Severity:** QA (unchanged since first report)
- **Status:** `open` (untriaged)
- **Fingerprint:** `0b497be32114147aa44ea7328329eaab2f024fd22b3208804fe604b84cca86b3` (unchanged — same fingerprint carried forward, not re-minted)
- **Entry point:** `dev`
- **First seen:** `phoenix-phase-2-staging-05` · **Last re-observed:** `phoenix-phase-2-staging-06`
- **Original report:** [reports/phoenix-phase-2-staging/05/findings/qa/Q-01-stablestaker-migrator-zero.json](../../../05/findings/qa/Q-01-stablestaker-migrator-zero.json)
- **Prior carryover:** [reports/phoenix-phase-2-staging/06/findings/qa/Q-01-CARRYOVER.md](../../../06/findings/qa/Q-01-CARRYOVER.md) *(that one was a pointer stub; this one is the full copy)*

## ⚠ Why this is carried forward rather than closed

**This finding was NOT re-observed by audit 21, and that is NOT evidence of a fix.**
Audit 21 was **story-073-scoped** (`dev` entry point, NudgeStreamer / multi-token batch minter / staker-V2 local mirror) and did **not** re-walk StableStaker Phase 3.7. Absence from a story-scoped run carries no closure authority.

- Status **remains `open`**. It was **not** auto-flipped to `fixed` and **no** ledger status was changed for it by this run.
- `lastSeenRun` was **deliberately left at `phoenix-phase-2-staging-06`** — bumping it would falsely assert re-observation.
- To close it, re-verify explicitly: `/recheck phoenix-phase-2-staging 0b497be32114…`, or a full `dev` re-scan.

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

- `c294d93f772bf5cb1aec185ff89fb8e1908bb114702bcf884561e778147c29d3` — **L-01, low, `fixed`** at `bd2290c` (StableStaker `pauser == address(0)`). Not re-flagged this run: **no regression observed**. Status untouched.
