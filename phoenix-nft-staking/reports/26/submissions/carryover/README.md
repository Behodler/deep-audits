# Carryover — phoenix-nft-staking run-26

**This directory is a deliberate NARROWING of the project's open findings. Read this file before
inferring anything from an absence.**

## What is here

| File | Entries retained | Fingerprints | Severity | Ledger status | Original |
|---|---|---|---|---|---|
| `qa-report-24.md` | L-01, **L-02**, L-03, Q-01 (run-24) | `4a1d8edc929b…`, **`aaebb4b9b056…`**, `6f46ec80f1fb…`, `cf332bf46c6c…` | Low, Low, Low, QA | all **open** (untriaged) | `reports/phoenix-nft-staking/24/submissions/qa-report.md` |

One originating audit ⇒ one file, per the carryover rule (a QA report is carried as **one** pruned
copy of that run's `qa-report.md`, never one file per Low finding). Per-finding text is **verbatim**;
only entries that are no longer live were deleted, and the deletion is named in the file's header.

- **Dropped from `qa-report-24.md`:** run-24 `L-04` (`2d34673536…`) — **`fixed`** at `5015f1b`,
  re-verified still-fixed this run. Its label gap is that removal, not an omission.
- **Labels are the originals.** Run-24's `L-02` stays `L-02` even though run-26 also has an `L-02`
  (a different finding, `5aa60247…`). **Disambiguate by fingerprint, never by label.**

## Why `L-02` is the reason this directory exists

`aaebb4b9b056…` was re-confirmed present at `9611312` and **materially re-framed** by run-26: the
griefing characterisation is **replaced**, its natural remediation is **reversed** (do **not**
permission `collectNudge` — it buys 0.11 pp and breaks both production donors), and an earlier
quantitative claim is **corrected for orientation** (~63% of a burst is *retained* at the nominal
window end, not released).

Before this file was written, `qa-report.md:46` pointed readers at a `carryover/` directory that
**did not exist**, so that entire re-frame reached **no deliverable** — it lived only in the ledger
and in `dedup-report.md`. Under Law 1 that is the "parked in a channel nobody reads" failure the
visible-channel clause exists to prevent, and it was the most serious defect the run's own
severity audit found. This file closes it.

## The selection rule used, stated so the gaps are readable

The project ledger holds **91 entries** (**59 `open`**, 3 `fix-pending`, 18 `wont-fix`, 3
`submitted`, 3 `fixed`, 4 `false-positive`, 1 `merged`). A literal reading of "carry forward every
still-open entry" would reproduce roughly **60** reports into this run. That was **not** done. The
rule applied:

1. **Recurrence and re-frame targets.** Ledger entries that run-26 re-observed and *annotated*
   rather than re-filed — i.e. `lastSeenRun` was bumped and no new fingerprint was minted. The four
   run-24 entries in `qa-report-24.md` are exactly the annotated set from that originating audit,
   and `aaebb4b9b0…` additionally carries a mandatory re-frame.
2. **Nothing else.** No `acknowledged`, `wont-fix` or `false-positive` entry is carried — the human
   already triaged those, and carrying them would be re-litigation.

**An absence here carries no information about status.** For the complete set of undealt-with
findings run **`/open-issues phoenix-nft-staking`**; the full original reports are under
`reports/phoenix-nft-staking-<NN>/submissions/`.

## ✅ GAP CLOSED — the `fix-pending` set IS now reproduced (in `submissions/`, not here)

**An earlier version of this file recorded the three `fix-pending` entries as a deliberate, flagged
gap. THAT DECISION HAS BEEN REVERSED AND THE GAP IS CLOSED.** The reasoning behind the omission was
that no run-26 header could be written for them without asserting something run-26 had not
established. That premise was sound; the conclusion was wrong. CLAUDE.md is explicit that
`fix-pending` is *"never suppressed — rescanned, stubbed, and shown by `/open-issues` exactly like
`open`, until a human marks it `fixed`"* — precisely so an incomplete or absent fix cannot go
unnoticed while someone depends on it landing. **A `fix-pending` High missing from the deliverable
set is the exact failure that rule exists to prevent.** The honest resolution is not omission; it is
a full copy that states plainly what was and was not done.

Per the carryover rule, **High/Medium carryover lives alongside the run's own submissions, not in
this subdirectory** (this directory holds QA-severity carryover only). The three files:

| Fingerprint | Severity | Reproduced this run at | Contract touched in `5015f1b..9611312`? |
|---|---|---|---|
| `1c222d548523…` | **High** | [`../H-01-C1.md`](../H-01-C1.md) | **No** — `src/NFTStakerDepletion.sol` is not in the diff |
| `a62fe01a25e2…` | Medium | [`../M-02-C1.md`](../M-02-C1.md) | **YES — rewritten in range.** ⚠ highest-priority `/recheck`; the ⚠ INCOMPLETE-FIX risk surface |
| `bdf84579b6ff…` | Medium | [`../M-05-C1.md`](../M-05-C1.md) | **No** — `src/NFTStakerPriceScaledMigrateReady.sol` is not in the diff |

**Every one of the three carries an explicit header stating that RUN-26 DID NOT RE-VERIFY IT** — no
PoC was replayed, no targeted re-scan, invariant, symbolic run or fork probe was aimed at it, and no
tier of run-26 took it as its object. Their `fix-pending` statuses are carried forward **unchanged
and unexamined**. Nothing in those files may be read as re-verification.

**Consequence for a reader:** the three `fix-pending` entries are **still owed fixes** as of
`9611312`. The run-25 copies remain the last *full treatment* of each and are linked from every
header. Re-verify with `/recheck phoenix-nft-staking <label-or-fingerprint>` — the cheapest next
action, and **mandatory** for `a62fe01a25e2` before any human applies the run-25 propose-`fixed`.
**No `fixed` is proposed against any of them by run-26, and no status was changed.**

---

*No status was changed by anything in this directory. Triage with `/ledger phoenix-nft-staking`.*
