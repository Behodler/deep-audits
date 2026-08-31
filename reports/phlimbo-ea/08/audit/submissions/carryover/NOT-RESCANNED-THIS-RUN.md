# Carryover scope — what was stubbed, and what was NOT re-scanned

**Run:** phlimbo-ea-08 · **HEAD:** `bf42c12` · **Baseline:** `7045a96`
**Scan scope:** V3-focused regression — `src/PhlimboV3.sol` + `src/MigratorV2V3.sol` (stories 024/025)

> **Read this before treating any absence below as evidence of a fix.**
> **Absence from this run's findings is NOT evidence of `fixed`.** A V3-focused regression scan
> does not re-detect entries on contracts it never scanned.

The ledger holds **27 non-closed entries** (25 `open` + 2 `fix-pending`). Only **5** strictly
reconcile against this run's scan. The rest are enumerated here rather than stubbed, because a
stub asserting "**Still present as of** phlimbo-ea-08" would be a claim this run did not earn.

---

## 1. Stubbed — re-detected and still-open (5)

These were re-detected by this run's scan against `bf42c12`. Each has a stub in this directory.

| Ledger label | Fingerprint | Contract | Note |
| --- | --- | --- | --- |
| **V3-M-02** | `d3a5b3ec` | `PhlimboV3.sol` | ⚠ **WIDENED — recovery advice INVERTED.** Severity unchanged (Medium). |
| **V3-L-02** | `c0e37955` | `PhlimboV3.sol` | Live, untouched. Replicated into the migrator by story-025 (`08-04` / `F-08-01`). |
| **V3-L-03** | `59e14f41` | `PhlimboV3.sol` | Live, untouched. |
| **V3-F-02** | `6027f256` | `PhlimboV3.sol` | Re-verified STILL ACCURATE. `lineStart` 816 → **812**. |
| **V3-F-01** | `3f241c3a` | `MigratorV2V3.sol` | ⚠ **CONFLICT — two agents, opposite dispositions. Human decides.** |

## 2. NOT stubbed — proposed `fixed`, awaiting human confirmation (3)

**No status was applied.** These are proposals only. They are not stubbed because the scan found
them resolved — but **a fix that merely stops tripping the scanner is not a verified fix.**

| Ledger label | Fingerprint | Current status | Proposal |
| --- | --- | --- | --- |
| **V3-H-01** | `88ae7589` | `fix-pending` | → propose `fixed` @ `bf42c12` (story-024 / `d61a7a3`). PoC-replayed; 4 agents / 3 independent angles. |
| **V3-M-01** | `0b7fa9be` | `fix-pending` | → propose `fixed` @ `bf42c12` — **⚠ CONDITIONAL on `08-03` landing in the ledger FIRST.** |
| **V3-Q-01** | `e1392170` | `open` | → propose `fixed` @ `ef98cd9` (promo sweep landed) — but see `08-10`: the sweep covers only the **LIVE** promo slot. |

> **⚠ V3-M-01's condition is load-bearing.** M-01's reverting-**recipient** root cause is
> genuinely closed (5/5 probes), but `08-03` is a **different `rootCauseClass`** carrying the
> **surviving brick**. **If `08-03` were dropped, closing M-01 would ERASE a live, PoC'd,
> unilaterally-triggerable migration brick.** `08-03` has landed in the ledger this run, so the
> condition is satisfied — but both `code-scanner` and `story-faithfulness` recommend
> `/recheck phlimbo-ea V3-M-01` @ `bf42c12` before a human applies it.

## 3. NOT stubbed — in scan scope but not re-detected (1)

| Ledger label | Fingerprint | Contract | Why no stub |
| --- | --- | --- | --- |
| **V3-L-01** | `5d5e3767` | `PhlimboV3.sol` | On a scanned contract but **not independently re-surfaced** this run, and **not** proposed fixed. Status stays `open`; `lastSeenRun` **NOT** bumped. **Absence is not a fix** — this run simply did not re-derive it. |

## 4. NOT stubbed — outside this run's scan scope (18 `open`)

All on **V2 contracts, which this V3-focused run never scanned**. Status unchanged, `lastSeenRun`
**NOT** bumped, **no stub** — this run has nothing to say about them either way.

`V2-M-01` (`e11518b6`, `MigratorV1V2.sol`) · `V2-C-01` (`a8848632`) · `V2-C-02` (`31764644`) ·
`V2-C-03` (`e85c9503`) · `V2-C-04` (`539b66c0`) · `V2-L-01` (`9ef309e7`) · `V2-L-02` (`cfcef23c`) ·
`V2-L-03` (`d6484512`) · `V2-L-04` (`9f9fad36`) · `V2-L-05` (`8dbde10f`) · `V2-L-06` (`6245e78a`) ·
`V2-L-07` (`4248dc02`) · `V2-L-08` (`81e52abf`) · `V2-L-09` (`08da5bba`) · `V2-L-10` (`49ae8eb2`) ·
`V2-Q-01` (`dfc30ff0`) · `V2-Q-02` (`c78c4024`) · `V2-F-01` (`2147577c`)
*(all `src/PhlimboV2.sol` except V2-M-01)*

## 5. NOT stubbed — disposed (26 `acknowledged`, 3 `wont-fix`)

**`acknowledged` and `wont-fix` are disposals** — suppressed from future scans, no carryover stub
by rule. The 26 acknowledged are the **V1 set** (`src/Phlimbo.sol`, V1 deprecated, owner-triaged
2026-06-08). The 3 wont-fix are `V2-M-02`, `V2-M-03`, `V3-L-04`.

> **Contrast with `fix-pending`**, which is **never** a disposal — it is rescanned, stubbed, and
> surfaced exactly like `open`. The two `fix-pending` entries above are unstubbed **only**
> because the scan found them resolved, and both remain `fix-pending` until a human applies the
> proposal.

---

## Reconciliation

| Bucket | Count |
| --- | --- |
| Stubbed (re-detected still-open) | 5 |
| Proposed fixed, awaiting human (2 `fix-pending` + 1 `open`) | 3 |
| In scope, not re-detected | 1 |
| Out of scan scope (V2) | 18 |
| **Total non-closed** | **27** |
| Disposed (`acknowledged` 26 + `wont-fix` 3) | 29 |
| **Ledger total** | **56 → 66** *(10 new this run)* |

**Recommendation for the human:** the 18 V2 entries and V3-L-01 have not been verified against
`bf42c12` by any run. If V2 assurance is wanted at this HEAD, that needs a `--full` cold scan or
a scoped V2 re-run — **this run cannot supply it**.
