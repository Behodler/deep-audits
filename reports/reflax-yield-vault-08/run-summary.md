# reflax-yield-vault-08 — Run Summary

- **Mode:** Regression scan (ledger exists; scoped to files changed since last audited commit)
- **Baseline commit:** `5f9abdde43a7b587dc0eaa840d20403c3a1f6ab6` (reflax-yield-vault-07)
- **HEAD audited:** `a65dbf0d1c4bbfd19bca33b63ed913438094a442`
- **Date:** 2026-06-04
- **Story under review:** story-043 — "conservative principal crediting"
- **Result:** **ZERO new High/Medium findings.** No new ledger entries created.

## In-scope changed file

- `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (story-043)

story-043 introduces a **deposit-side haircut**: credited principal is computed as
`creditedPrincipal = amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS`. After
review across the pipeline (code-scanner, econ-scanner, dedup, severity-classifier,
severity-auditor) the change was determined to be **documented intended design**
("conservative principal crediting"), supported by:

- NatSpec contract header L19-23 describing the conservative-crediting philosophy,
- `_creditedPrincipal` implementation at L204-214,
- `Deposited` event at L58-62,
- the `designDecision` philosophy already recorded for this strategy.

The only forward-looking residue (the haircut magnitude is bounded **only** by the
missing upper cap on `slippageToleranceBps`) was folded into the existing open Low
**L-01** as an added impact note. It is **not** reported as a new H/M.

## Candidate findings raised this run and their dispositions

| Candidate | Substance | Disposition |
|-----------|-----------|-------------|
| **DEDUP-001** | Deposit-side haircut creates skimmable surplus | **SUPPRESSED** — documented intended design (NatSpec L19-23, `_creditedPrincipal` L204-214, `Deposited` event L58-62; `designDecision` philosophy). severity-classifier ruled **Low**; severity-auditor ruled **REFUTED**. Folded into **L-01** as an added impact note. NOT reported as H/M. |
| **DEDUP-002** | No deposit-time bps snapshot; owner can drift credited principal vs floor | **DUPLICATE** of open **L-01** + **C-01**. |
| **DEDUP-003** | `slippageToleranceBps == MAX_BPS` strands deposits (credited principal → 0) | **SUPPRESSED** — reckless-admin known-invalid; residue is **L-01** (missing sane cap). |
| **DEDUP-004** | Buffer front-run amplification | **DUPLICATE** of open **L-03**; the cross-client-principal angle was already adjudicated **false-positive** under **M-04**. |
| **DEDUP-005** | `minOut ≤ 1-ulp` double-floor; `Deposited` event nominal-vs-haircut mismatch | **SUPPRESSED** — design/NatSpec-documented QA. |
| **SAST** (Slither) | `reentrancy-no-eth`, `incorrect-equality`, `uninitialized-local` | **DROPPED** — noise in UNCHANGED code. |

## Ledger reconciliation (this run)

- **Re-surfaced / still-open (lastSeenRun bumped to reflax-yield-vault-08):** L-01, L-03, C-01.
- **L-01 augmented** with a note that story-043 added a NEW deposit-side haircut
  (`creditedPrincipal = amount * (MAX_BPS - slippageToleranceBps) / MAX_BPS`) whose
  magnitude is bounded only by the missing `slippageToleranceBps` upper cap.
  Recommendation: enforce a hard sane cap (e.g. a few hundred bps) and add a
  deposit-side `designDecisions` entry to the registry. Severity (Low) and status
  (open) unchanged.
- **Human-authoritative statuses untouched:** M-02 (acknowledged), L-02 (wont-fix),
  M-04 (false-positive). M-01 (fixed) untouched.
- **No new ledger entries created.**
- `lastAuditedCommit` → `a65dbf0d1c4bbfd19bca33b63ed913438094a442`
- `lastRun` → `reflax-yield-vault-08`
- `updatedAt` → 2026-06-04

## Tooling artifacts

Static-analysis artifacts (originally mis-written to a phantom `reflax-yield-vault-09/`
directory) were consolidated into this run under `tooling/`:
`static-analysis-findings.json`, `slither-output.json`, `aderyn-report.json`,
`semgrep-output.json`. The phantom `-09` directory was removed.

## Carryover stubs

Thin carryover stubs for the still-open re-surfaced entries (L-01, L-03, C-01) were
written to `submissions/carryover/`.
