# phoenix-vault-04 Audit Summary

**Project:** phoenix-vault (lib/reflax-yield-vault)
**Submodule commit:** `f328d52` ([story-039] Correct pool2 coin indices from mainnet verification)
**Mode:** Regular audit
**Audit run:** phoenix-vault-04
**Workspace:** `workspace/phoenix-vault-04/`
**Date:** 2026-04-07

## Scope (focused per user request)

The user requested a focused audit on the recent additions:
- `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (NEW story-038, ~452 LOC)
- `src/AMMAdapters/CurveAMMAdapter.sol` (NEW story-039, ~142 LOC)
- `src/AMMAdapters/IAMMAdapter.sol` (~23 LOC)
- `src/AMMAdapters/ICurveRouterNG.sol` (~35 LOC)
- `AMMRoutes.json` (NEW story-039, configuration)

Context (in-scope for understanding, not flagged): `src/AYieldStrategy.sol` (base class).

**Note on registered scope:** The previously registered scope referenced `SurplusTracker.sol` and `SurplusWithdrawer.sol`, both removed upstream in story-037. `registered-projects.json` was updated to reflect the current scope.

## Final findings

| ID | Severity | Title | PoC | Submission |
|----|----------|-------|-----|------------|
| H-01 | High | First-mover bank run: principal debited by requested-not-received on AMM dislocation | ✓ | ✓ |
| H-02 | High | Deposit principal in underlying units lets later depositors dilute earlier discount buyers | ✓ | ✓ |
| H-03 | High | Surplus extraction sells from shared share pool, draining other clients' yield | ✓ | ✓ |
| M-01 | Medium | `emergencyWithdraw` bypasses 24h rugpull delay AND leaves client accounting permanently stale | ✓ | ✓ |
| M-02 | Medium | AMM withdraw slippage anchored to vault internal rate bricks exits during AMM discount | ✓ | ✓ |
| M-03 | Medium | Two-phase `totalWithdrawal` cache is decorative — child reads live balance | ✓ | ✓ |

**Severity downgrades applied** (per second-opinion review by severity-auditor):
- M-02 (was H-01): downgraded to Medium — DoS-on-withdraw maps to "protocol availability impacted"; sandwich-extraction angle is structurally weak because vault-anchored `minOut` is conservative, so manipulated swaps revert rather than executing at unfavorable rates.
- M-03 (was H-04): downgraded to Medium — the cache desync is real but the realised exploit primitive collapses into the H-01/H-02 family.

## Cross-finding cluster

H-01, H-02, and H-03 share a single root cause: **per-client accounting denominated in underlying units against a shared share pool that is purchased at variable AMM rates.** Each finding demonstrates a distinct, independently triggerable exploit primitive:

- **H-01** (withdraw side): first-mover takes full principal, last-mover eats the entire dislocation.
- **H-02** (deposit side): late fair-rate depositor dilutes earlier discount-rate depositor via the average-credit formula.
- **H-03** (surplus extraction side): authorized withdrawer extracts from shared share pool, silently draining other clients' yield.

C4 norm preserves these as three separate Highs because each surface is independently exploitable and would not be fixed by patching only one of the others. **The shared mitigation is per-client share tracking** (replace `clientBalances[token][account]` with `clientShares[token][account]`).

## Deferred findings (not submitted)

- **H-04 (sandwich economics, originally H-06):** corollary of M-02. Real but largely a manifestation of the slippage anchor problem. Demonstrating it cleanly requires fork testing on Curve mainnet, which was not in scope for this audit run. Stored as draft JSON only at `audit/findings/high/H-04.json`.
- **M-04 (first-depositor donation, originally M-02):** the donation pattern is not cleanly exploitable in a way that benefits the attacker — donating shares to the strategy is a free gift to the first depositor rather than a theft. Stored as draft JSON only at `audit/findings/medium/M-04.json`.

Both should be reviewed manually before being added to the submission set.

## Out of scope per user

- **QA / Low / Centralization findings:** The user said "not that interested in QA". Low and Centralization findings discovered during analysis are stored in `audit/findings/low/` and `audit/findings/centralization/` for record but no QA report was bundled.

## Files

### Submissions (Details field for each C4 form)
- `reports/phoenix-vault-04/audit/submissions/H-01-submission.md`
- `reports/phoenix-vault-04/audit/submissions/H-02-submission.md`
- `reports/phoenix-vault-04/audit/submissions/H-03-submission.md`
- `reports/phoenix-vault-04/audit/submissions/M-01-submission.md`
- `reports/phoenix-vault-04/audit/submissions/M-02-submission.md`
- `reports/phoenix-vault-04/audit/submissions/M-03-submission.md`

### PoCs (canonical, runnable in workspace)
- `workspace/phoenix-vault-04/test/poc-H-01.t.sol` (slippage anchor — now M-02 severity)
- `workspace/phoenix-vault-04/test/poc-H-02.t.sol` (bank run — now H-01 ID)
- `workspace/phoenix-vault-04/test/poc-H-03.t.sol` (deposit dilution — now H-02 ID)
- `workspace/phoenix-vault-04/test/poc-H-04.t.sol` (cache desync — now M-03 severity)
- `workspace/phoenix-vault-04/test/poc-H-05.t.sol` (cross-client surplus — now H-03 ID)
- `workspace/phoenix-vault-04/test/poc-M-01.t.sol` (emergency withdraw — unchanged)

The workspace files use the original filenames (since renaming would require renaming the test contracts and re-running). For C4 form submission, use the renamed copies under `reports/phoenix-vault-04/audit/pocs/` which match the new finding IDs:
- `reports/phoenix-vault-04/audit/pocs/H-01-poc.t.sol`
- `reports/phoenix-vault-04/audit/pocs/H-02-poc.t.sol`
- `reports/phoenix-vault-04/audit/pocs/H-03-poc.t.sol`
- `reports/phoenix-vault-04/audit/pocs/M-01-poc.t.sol`
- `reports/phoenix-vault-04/audit/pocs/M-02-poc.t.sol`
- `reports/phoenix-vault-04/audit/pocs/M-03-poc.t.sol`

### PoC verification

All 10 tests across 6 files pass against `lib/reflax-yield-vault @ f328d52`:

```
Ran 6 test suites: 10 tests passed, 0 failed, 0 skipped (10 total tests)
```

To re-run from the workspace:

```bash
cd workspace/phoenix-vault-04
forge test --match-path "test/poc-*" -vvv
```

### Validation reports
- `reports/phoenix-vault-04/audit/REPORT-VALIDATION.md` (mechanical validation; issues fixed)
- `reports/phoenix-vault-04/audit/SEVERITY-AUDIT.md` (second-opinion severity review; downgrades applied)
- `reports/phoenix-vault-04/audit/VALIDITY-CHECK.md` (C4 known-invalid filter; all 6 valid)

## C4 Form Mapping

For each H/M finding, when filling out the C4 form:

| Form Field | Source |
|------------|--------|
| Title | `Title:` line in submission.md metadata header |
| Root Cause Link | `Root Cause Link:` line in submission.md metadata header |
| Details | submission.md body (after metadata HTML comment) |
| PoC | corresponding `audit/pocs/*-poc.t.sol` file |

## Action items before submission

1. **Review the cross-finding cluster (H-01, H-02, H-03)** to confirm you want to submit all three. Each is independently exploitable, but a C4 judge may merge them if you don't make the differentiation clear in each writeup. The submission texts already include explicit differentiation sections.
2. **Decide whether to manually develop H-04 (sandwich economics)** as a separate submission. Likely best framed as defence-in-depth for M-02.
3. **Optionally drop M-04 (first-depositor donation)** — analysis suggests it isn't cleanly exploitable.
4. **Severity caveat on M-01:** the validity-checker recommended reframing M-01 to lead with the accounting-skew prong rather than the delay-bypass prong, to avoid being collapsed into a Centralization finding by the judge. The current report does emphasize both bugs but begins with the delay-bypass framing. Consider re-ordering the body if you want to be conservative.
