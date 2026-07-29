# Carryover — what is in this directory

A **carryover** is a finding from an **earlier audit run** of this project that is still live as of the
current run. This directory holds the QA-severity carryovers for
`reports/phoenix-phase-2-staging-21/` (entry point `dev`, commit `3fb4e34`).

## These are full copies, not stubs

Every file here is a **verbatim copy of the original report text**, with a metadata header prepended. It is
deliberately **not** a pointer stub. A reader reviewing this run's `submissions/` must be able to read the
whole finding without following a link into another run's directory. Links back to the originating run are
provided for provenance only — nothing here depends on following them.

The original copies remain in place under `../../findings/carryover/`. They are copies of each other; neither
is authoritative over the other.

## Why a finding appears here

A finding is carried over when the ledger entry is still `open` or `fix-pending`, or when a previously closed
entry has become valid again (a regression, or a closure whose rationale expired). Findings the human has
already triaged as `acknowledged`, `wont-fix`, or `false-positive` are **not** carried over — those were
disposed of deliberately.

**Absence from a scan is never evidence of a fix.** Run 21 was a story-073-scoped script audit of the `dev`
entry point; it did not re-walk every contract a prior run covered. A finding not re-observed by a scoped run
keeps its `open` status, keeps its original `lastSeenRun`, and is carried here rather than closed. Closing one
requires explicit re-verification — `/recheck phoenix-phase-2-staging <fingerprint>` or a full re-scan — and a
human decision via `/ledger phoenix-phase-2-staging`.

## File naming

- **QA / Low / Centralization** — one file per **originating audit**, named `qa-report-<NN>.md`, where `<NN>`
  is the run number the findings came from. It is that run's QA report **pruned to the entries that are still
  live**; every dropped entry is named in the header with its disposition, and survivors keep their original
  labels (gaps in the label sequence are the removals, not omissions).
- **High / Medium** — carried over as `../<label>-C<n>.md`, i.e. alongside this run's own submissions rather
  than in this directory. There are none in run 21.

## Label collisions

Carryover labels are the **originals**, from the run that first filed them. They are a **separate sequence**
from this run's own labels. `Q-01` in `qa-report-05.md` is audit 05's Q-01 and has nothing to do with run 21's
own `Q-01` in `findings/qa/`. When in doubt, match on the **fingerprint**, which is stable across runs and
collision-proof.

## Contents

| File | Originating run | Retained entries | Fingerprint(s) |
|---|---|---|---|
| [`qa-report-05.md`](./qa-report-05.md) | `phoenix-phase-2-staging-05` | Q-01 — StableStaker deployed with `migrator == address(0)` (qa, `open`, untriaged) | `0b497be32114147aa44ea7328329eaab2f024fd22b3208804fe604b84cca86b3` |
