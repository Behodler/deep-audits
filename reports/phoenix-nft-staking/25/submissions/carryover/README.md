# Carryover — phoenix-nft-staking run-25

**This directory is a deliberate NARROWING of the project's open findings. Read this file before
inferring anything from an absence.**

## What is here

| File | Entry | Fingerprint | Severity | Ledger status | Original |
|---|---|---|---|---|---|
| `H-01-C1.md` | H-01 (run-20) | `1c222d548523…` | High | **fix-pending** | `reports/phoenix-nft-staking/20/submissions/H-01.md` |
| `M-02-C1.md` | M-02 (run-20) | `a62fe01a25e2…` | Medium | **fix-pending** | `reports/phoenix-nft-staking/20/submissions/M-02.md` |
| `M-05-C1.md` | M-05 (run-20) | `bdf84579b6ff…` | Medium | **fix-pending** | `reports/phoenix-nft-staking/20/submissions/M-05.md` |
| `M-07-C1.md` | M-07 (run-20) | `ad36260fc91f…` | Medium | **fix-pending** | `reports/phoenix-nft-staking/20/submissions/M-07.md` |
| `qa-report-21.md` | L-04 (run-21) | `75305ec0242b…` | Low | open | `reports/phoenix-nft-staking/21/submissions/qa-report.md` §L-04 |
| `F-20-07-C1.md` | F-20-07 (run-20) | `a7dffb34c990…` | Low | open | run-21 spec-conformance §carryover + run-20 finding record (**partly reconstructed — labelled in the file**) |

Every file is a **full copy** of the original report body with a metadata header prepended. **None
is a pointer stub.** Original labels are preserved so entries stay traceable across runs.

## The selection rule used

The project ledger currently holds **78 entries: 53 `open`, 4 `fix-pending`, 15 `wont-fix`, 3
`submitted`, 2 `false-positive`, 1 `fixed`.** A literal reading of "carry forward every still-open
entry" would reproduce **57** reports into this run. That was **not** done. The rule applied instead:

1. **Recurrence targets.** Ledger entries that a run-25 finding **recurs on** — i.e. where this run
   re-observed the issue and bumped `lastSeenRun` rather than minting a new fingerprint. Run-25
   `L-02` recurs on **two** entries (`75305ec0…` code site, `a7dffb34…` doc site), so both are here.
2. **The whole `fix-pending` set.** `fix-pending` is never a disposal: it means a fix is **owed** and
   someone is relying on it landing. These entries are never suppressed, never auto-closed, and are
   surfaced exactly like `open`. All **four** are here.

Nothing else was carried.

## ⚠ What the omissions do and do not mean

The **~51 open entries not reproduced here are omitted by selection only.** Their absence carries
**no information about their status** — they are **not** fixed, acknowledged, wont-fixed, or found
invalid. They remain fully live in the ledger.

For the complete set of undealt-with findings, run:

```
/open-issues phoenix-nft-staking
```

The same caveat is repeated inside `qa-report-21.md`, which names every run-21 QA entry it drops.

## ⚠ Two deviations from the standard carryover layout, recorded so they are not silent

1. **H/M carryovers are in this directory, not in `submissions/`.** The standard places High and
   Medium carryovers alongside the run's new submissions as `submissions/<label>-C<n>.md`, reserving
   `carryover/` for QA. Run-25 was explicitly directed to place all carryover here. The
   `<label>-C<n>` naming is retained so labels stay recognisable. **Consequence:** a reader scanning
   `submissions/` alone will see this run's `M-01`/`M-02`/`M-03` but **not** the carried-forward
   High. `submissions/H-01-C1.md` does not exist — it is `carryover/H-01-C1.md`.
2. **`M-05-C1.md` was added beyond the entries enumerated for this run.** The carryover instruction
   named three `fix-pending` entries; the ledger holds four. `bdf84579…` (M-05, the load-bearing
   `stake()`-wedge backstop) is the fourth and was carried under the instruction's own stated rule
   ("the never-suppressed `fix-pending` set"). **Flagged rather than assumed** — if the omission was
   deliberate, remove that file explicitly.

## Cross-cutting warnings that survive this carryover

- ⚠ **`75305ec0…` and `a7dffb34…` must NOT be collapsed.** Same claim, **two artefacts** — code site
  vs doc site, different fixes. Collapsing loses whichever site is not chosen as canonical.
- ⚠ **No value claim may be added to `75305ec0…`.** Its deferral of the value consequence is
  load-bearing anti-double-counting; in run-25 the value is priced in **`M-01` (`pns25m1`) only**.
- ⚠ **`1c222d54…` is not ledger `H-01` `858e9e80…`.** This project reuses labels across runs and
  contracts. **Always disambiguate by fingerprint.** `H-01-C1.md` also carries the 2026-07-21
  erratum: an unauthorised `wont-fix` flip on that entry was reverted and the `fix-pending` triage
  reinstated.
- ⚠ **The three `propose-fixed` records in this directory are proposals, not closures.** None was
  applied. `a62fe01a…` is the weakest of them and asks for `/recheck` first; `ad36260f…` is
  conditional on run-25 `L-03` and `L-04`; `bdf84579…` covers new deployments only while the frozen
  V1 instance stays ungated.

**This ledger was not modified by the run-25 carryover step.**
