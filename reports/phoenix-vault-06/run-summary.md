# phoenix-vault-06 — Run Summary

- **Project:** phoenix-vault (submodule `lib/reflax-yield-vault`)
- **Mode:** REGRESSION
- **Baseline:** phoenix-vault-05 @ `7d11f66` → this run @ `043ff2c` (`043ff2cb5ee9808961b50311fb5ecb742b63a6e9`)
- **Story:** story-041 (skim path rewrite: `skimSurplusBatch(token, clients[], recipient)` → `skimSurplus(token, recipient)` over an owner-managed `EnumerableSet _authorizedClients`, single aggregate swap)
- **NEW findings:** 0
- **Run date:** 2026-05-26

This run is ledger reconciliation against the prior audit. No new findings were produced. Verdicts below reflect convergent code-scanner + econ-scanner + deduplicator output reconciled against `reports/ledgers/phoenix-vault.json`.

---

## Headline: M-01 FIXED (developer fix verified this run)

**M-01** — `_skimSurplus` over-skim via duplicate `clients[]` under-backs principal
(fingerprint `9addc259f322848c95fc1fa7cf6c9badf3c4826121667dddb758caafae70cdd3`)

- **Status flip:** `open` → **`fixed`**, `fixedAtCommit = 043ff2cb5ee9808961b50311fb5ecb742b63a6e9`.
- **Why fixed (story-041):**
  1. The caller-supplied `clients[]` list is gone. The only skim entry point is now `skimSurplus(token, recipient)`; the iterated set is the strategy-owned `EnumerableSet _authorizedClients`, so the caller cannot inject duplicates.
  2. `setClient(client, true)` uses `EnumerableSet.add` (idempotent) — the same client can never appear twice in the iterated set.
  3. Loud aggregate-surplus ceiling (defense-in-depth) at `ERC4626MarketYieldStrategy.sol#L434`:
     `require(totalShares <= vault.convertToShares(totalValue - totalDeposited), "ERC4626MarketYieldStrategy: skim exceeds aggregate surplus")`.
- **Arithmetic bound (both scanners):** Σfloor(convertToShares(surplus_i)) ≤ floor(convertToShares(Σsurplus_i)) ≤ floor(k·aggregateSurplus) — the ceiling is tight (no spurious revert, no principal breach). The duplicate-driven over-skim is structurally unconstructible.
- **PoC evidence:** `workspace/phoenix-vault/test/poc-M01-fix-verification.t.sol` — **PASSING 4/4** against `043ff2c` (verified this run):
  - `test_M01_callerCannotSupplyClientList_apiIsTwoArgsOnly`
  - `test_M01_setClientIsIdempotent_noDuplicatesInSkimSet`
  - `test_M01_skimTakesOnlyTrueSurplus_principalPreserved`
  - `test_M01_aggregateSurplusCeilingBoundsSkim`
- **Location updated:** old ledger entry pointed at `_skimSurplusBatch` L462-488; the code is now `_skimSurplus` at L413-441 (ceiling require at L434).

> NOTE FOR REVIEWER: This is an intentional status flip to `fixed`, backed by a passing fix-verification PoC against the current HEAD. Please confirm.

---

## Reconciliation results

| Label | Title (current) | Severity | Verdict this run | lastSeenRun |
|-------|-----------------|----------|------------------|-------------|
| M-01 | `_skimSurplus` over-skim via duplicate `clients[]` | Medium | **FIXED** @ 043ff2c (PoC 4/4) | 06 |
| M-02 | NAV-anchored minOut sandwich value leak | Medium | reconfirmed OPEN | 06 |
| M-03 | Requested-not-received decrement (last-withdrawer shortfall) | Medium | stays **merged → M-02** (no standalone recurrence) | 06 |
| L-01 | slippageToleranceBps default-0 + setter missing cap | Low | reconfirmed OPEN | 06 |
| L-02 | skimSurplus unbounded iteration over owner-grown client set | Low | **RESTATED** (partial fix) | 06 |
| C-01 | Centralization / owner-power bundle | Centralization | reconfirmed OPEN | 06 |

### M-02 — reconfirmed OPEN (unchanged severity)
NAV-anchored `minOut` is execution-price-blind. story-041's single-aggregate-swap rewrite did **not** change the root cause — `minOut` is still derived from `convertToAssets` (NAV) rather than execution price, leaving the swap sandwich-exploitable. Reconfirmed via duplicates PATTERN-001 / PATTERN-002. `_skimSurplusBatch` reference in the function list updated to `_skimSurplus`.

### L-02 — RESTATED / NARROWED (partial fix)
- **Sub-vector (1) — zero-address whole-batch revert: RESOLVED at 043ff2c.** The caller no longer supplies the list; `setClient` rejects the zero address so it can never enter the set, and the in-loop zero check (`ERC4626MarketYieldStrategy.sol#L421`) is now unreachable defense-in-depth.
- **Sub-vector (2) — unbounded loop: PERSISTS, transformed.** `skimSurplus` now iterates the full owner-managed `_authorizedClients` set with no pagination (all-or-nothing). This is owner-controlled growth — an admin would have to authorize an extreme number of clients to brick the skim — so it remains **OPEN at Low** as an owner-bounded availability/gas note.
- Title rewritten to "skimSurplus unbounded iteration over owner-grown authorized-client set (no pagination)". **PATTERN-006 and SLITHER-005 (calls-loop) consolidate INTO this entry** — no separate entries created.

### L-01 — reconfirmed OPEN (unchanged severity)
`setSlippageTolerance` still accepts an unbounded bps value and defaults to 0. Reconfirmed via PATTERN-001 (bps-half). Root cause unchanged by the skim rewrite.

### C-01 — reconfirmed OPEN (unchanged severity)
Reconfirmed via PATTERN-005. story-041 **adds** owner power: an owner-managed authorized-client `EnumerableSet` (`setClient`), and the rewritten skim sends 100% of aggregate surplus to a single withdrawer-chosen recipient (trusted-actor discretion). The single-aggregate-swap rewrite did not change the centralization root cause.

### M-03 — stays merged into M-02
No standalone loss primitive and no standalone recurrence this run. Fingerprint retained so a future standalone recurrence can still be matched. `lastSeenRun` bumped to 06.

---

## Dropped non-findings / QA-bucket summary

Static analysis (Slither / Aderyn / Semgrep) and pattern-matching on the story-041 diff surfaced 6 pattern hits; after dedup these mapped onto existing ledger entries — **no new standalone findings**:

- **PATTERN-001 / PATTERN-002** → consolidated into existing **M-02** (NAV-anchored minOut) and the bps-half into **L-01**.
- **PATTERN-005** → consolidated into existing **C-01** (centralization bundle, now including the authorized-client set + single-recipient skim).
- **PATTERN-006** and **SLITHER-005 (calls-loop)** → consolidated into the restated **L-02** (unbounded iteration). No separate entries created.
- Slither/Aderyn/Semgrep residue on the rewrite (standard informational/optimization noise, calls-in-loop) carries no demonstrated HM exploit path → QA bucket, not separately reported per C4 conventions.

---

## Run artifacts (co-located in this run dir)

These intermediate artifacts were generated this run (against `043ff2c`, story-041 focus) but had been misfiled into `reports/phoenix-vault-05/`; relocated here so the run's artifacts are co-located (05's May-25 report submissions were left untouched):

- `reports/phoenix-vault-06/static-analysis-findings.json` (`targetCommit: 043ff2c`)
- `reports/phoenix-vault-06/pattern-matches.json` (`submoduleCommit: 043ff2c…`, 6 hits)
- `reports/phoenix-vault-06/aderyn-report.json`
- `reports/phoenix-vault-06/semgrep-output.json`
- `reports/phoenix-vault-06/slither-ERC4626MarketYieldStrategy.json`
- `reports/phoenix-vault-06/slither-CurveAMMAdapter.json`
- `reports/phoenix-vault-06/slither-IAMMAdapter.json`
- `reports/phoenix-vault-06/slither-ICurveRouterNG.json`

PoC evidence for M-01: `workspace/phoenix-vault/test/poc-M01-fix-verification.t.sol` (passing 4/4 @ 043ff2c).

## Ledger

`reports/ledgers/phoenix-vault.json` upserted: `lastAuditedCommit → 043ff2c`, `lastRun → phoenix-vault-06`, `updatedAt → 2026-05-26T10:12:03Z`. No human-set triage statuses (acknowledged / wont-fix / false-positive) were present or touched.
