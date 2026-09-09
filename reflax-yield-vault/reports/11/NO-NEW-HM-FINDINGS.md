# reflax-yield-vault-11 — No new valid High/Medium findings

**Run:** reflax-yield-vault-11 (REGRESSION)
**Commit:** a65dbf0 → 2306719
**Date:** 2026-06-06

## Outcome

This regression run surfaced **no valid High or Medium findings**.

The only in-scope code change since the last audited commit (run-08) was **story-044**,
which added a `uint256 creditedPrincipal` return value to `deposit()` across
`IYieldStrategy`, `AYieldStrategy`, and `ERC4626MarketYieldStrategy`. The change is
ABI-backward-compatible and surfaces an already-computed value; it introduces no new
logic, state writes, or external-call patterns. Regression risk: benign.

The analysis pipeline raised five High/Medium candidates. **All five were
rejected or downgraded on manual review** — they were over-weighted owner-privilege
findings (the system is self-owned / all-protocol-owned-client, so owner-gated actions
whose funds flow to the owner are centralization characteristics, not vulnerabilities)
or PoCs whose mocks decoupled from real on-chain behaviour.

Full reasoning: [`submissions/rejected/REJECTION-RATIONALE.md`](submissions/rejected/REJECTION-RATIONALE.md)

| Candidate | Pipeline | Disposition |
|---|---|---|
| H-01 emergencyWithdraw accounting desync | High | → **C-01** (open hardening rec) |
| H-02 _totalWithdraw live-balance read | High | **rejected** (inert; residual = L-06) |
| H-03 withdrawAsOwner timelock bypass | High | → **C-01** (acknowledged by-design) |
| M-01 slippage MAX_BPS / zero-default | Medium | MAX_BPS → **C-01**; zero-default → **L-13** |
| M-02 vault-price donation DoS | Medium | **rejected** (false-positive) |

## Run-11 deliverables

- **QA bundle:** `submissions/qa-report.md` — 13 Low + 1 Info + 4naly3er appendix
- **Centralization:** `submissions/C-01-submission.md` — 3 owner-power sub-items
- **Carryover (still-open from prior runs):** `submissions/carryover/` — L-03–L-07, C-01
- **Rejected/downgraded HM:** `submissions/rejected/` — with per-finding rationale

## Action items

- **C-01.1** (emergencyWithdraw accounting desync) is the one item worth actively
  fixing — a good-faith *partial* emergency withdraw followed by continued operation
  corrupts client accounting. The other centralization items are owner-key trust
  surface to document/accept.
