# Phoenix-Vault Audit v03 — Summary

**Date**: 2026-03-25
**Focus**: ERC4626YieldStrategy (new contract)
**Mode**: Regular Audit (no QA report)
**Exclusions**: Owner-driven attacks, QA report

---

## Findings

| ID | Title | Original | Final | PoC |
|----|-------|----------|-------|-----|
| H-01 | Multi-Client Surplus Withdrawal Drains Other Clients' Yield | High | **Medium** (downgraded — no attacker, only yield affected) | poc-H-01.t.sol |
| M-01 | Two-Phase totalWithdrawal Includes Deposits Made During Waiting Period | Medium | **Medium** | poc-M-01.t.sol |
| M-02 | Fee-Charging ERC4626 Vaults Create Phantom Surplus That Drains Earlier Depositors | Medium | **Medium** | poc-M-02.t.sol |
| M-03 | withdrawFrom() Balance Check Caps Surplus Extraction at Principal Amount | Medium | **Medium** | poc-M-03.t.sol |
| M-04 | No Slippage Protection on Deposits and Withdrawals | Medium | **Low** (downgraded — no PoC, design finding) | N/A |
| L-01 | Zero-Share Redemption on Clients With Empty Balances | Low | **Low** | N/A |
| L-02 | Constructor Does Not Validate vault.asset() Matches underlyingToken | Low | **Low** | N/A |
| L-03 | No Atomic Migration Mechanism Between Strategies | Low | **Removed** (feature request, not vulnerability) | N/A |

---

## User Focus Area Answers

### Is ERC4626YieldStrategy exploit-free?

No. The proportional-principal accounting model creates a cross-client yield drain when surplus is extracted (H-01/Medium). This is the most significant finding — it's an architectural issue shared with AutoPoolYieldStrategy.

### Is it faithful to ERC4626?

Partially. It correctly calls `deposit()`, `redeem()`, `convertToShares()`, `convertToAssets()`. But it doesn't handle fee-charging vaults (M-02), which are valid per ERC4626. Missing slippage parameters (M-04) also deviate from best practice for ERC4626 integrations.

### Is it a suitable replacement for AutoPoolYieldStrategy?

Yes, with caveats. It correctly implements all `AYieldStrategy` abstract functions and eliminates the MainRewarder dependency cleanly. The interface is compatible for a drop-in replacement. However, it inherits the same proportional accounting flaw (H-01) and adds the `withdrawFrom` surplus cap bug (M-03) which exists in the base contract.

### Can you migrate existing AutoPoolYieldStrategies?

Yes. ERC4626YieldStrategy has no MainRewarder overhead — deposits are 1 step (vs 2), withdrawals are 1 step (vs 3+restake). Migration requires per-client `totalWithdrawal` + `depositAsOwner`, with a 24h timelock per client. Note the timelock bypass (M-01) during this process.

### Is it faithful to AYieldStrategies in general?

Yes. All abstract functions are implemented. The shared patterns (proportional `totalBalanceOf`, `_withdrawFrom` surplus logic, two-phase `totalWithdrawal`) are identical between ERC4626YieldStrategy and AutoPoolYieldStrategy. The bugs found (H-01, M-03) exist in the base architecture, not specific to ERC4626YieldStrategy.

---

## Architectural Recommendation

The root cause underlying H-01 and M-02 is the same: **proportional-principal accounting with a shared share pool, but the surplus system assumes per-client isolation**. The most robust fix is to track vault shares per-client (`clientShares[token][account]`), which would resolve both findings and inherently handle fee-charging vaults correctly.

---

## File Locations

### Submissions
- `reports/phoenix-vault-03/audit/submissions/H-01-submission.md`
- `reports/phoenix-vault-03/audit/submissions/M-01-submission.md`
- `reports/phoenix-vault-03/audit/submissions/M-02-submission.md`
- `reports/phoenix-vault-03/audit/submissions/M-03-submission.md`
- `reports/phoenix-vault-03/audit/submissions/M-04-submission.md`

### PoCs (workspace — drop into project test/)
- `workspace/reflax-yield-vault/test/poc-H-01.t.sol`
- `workspace/reflax-yield-vault/test/poc-M-01.t.sol`
- `workspace/reflax-yield-vault/test/poc-M-02.t.sol`
- `workspace/reflax-yield-vault/test/poc-M-03.t.sol`

### Findings (JSON)
- `reports/phoenix-vault-03/audit/findings/high/H-01.json`
- `reports/phoenix-vault-03/audit/findings/medium/M-01.json`
- `reports/phoenix-vault-03/audit/findings/medium/M-02.json`
- `reports/phoenix-vault-03/audit/findings/medium/M-03.json`
- `reports/phoenix-vault-03/audit/findings/medium/M-04.json`
- `reports/phoenix-vault-03/audit/findings/low/L-01.json`
- `reports/phoenix-vault-03/audit/findings/low/L-02.json`
- `reports/phoenix-vault-03/audit/findings/low/L-03.json`

### Review Reports
- `reports/phoenix-vault-03/SEVERITY-AUDIT-REPORT.md`
- `reports/phoenix-vault-03/VALIDITY_CHECK_SUMMARY.md`
