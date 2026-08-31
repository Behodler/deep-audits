# Static analysis — stable-staker run-10 (REGRESSION)

**Setup:** scope commit `125f585`; changed range `93b7ce6..125f585` — single hunk: `src/StableStaker.sol` lines 221–228 (comment + `require(poolInfo[token].totalStaked == 0)` empty-pool gate in `setYieldStrategy`). Tools ran against the writable clone `workspace/stable-staker` (verified at `125f585`, `src/` byte-identical to `lib/stable-staker`); `lib/` untouched.

**Artifacts:**
- `findings.json` (normalized, 28 findings)
- Raw: `slither-output.json`, `aderyn-report.json`, `semgrep-output.json`

## Counts per tool

| Tool | Version | Raw | Kept | Filtered |
|---|---|---|---|---|
| Slither | 0.11.3 | 27 | 24 | 3 (missing-inheritance, missing-zero-check x2) |
| Aderyn | 0.6.8 | 9 issues (~30 instances) | 2 standalone + 8 corroborations | 20 instances (centralization-risk per Law 3, modifier-once, push0, state-no-address-check, pragma) |
| Semgrep | 1.163.0 (`p/smart-contracts`) | 55 | 2 | 53 (performance/style INFO) |
| **Merged** | | | **28** | **76** |

All 5 `timestamp` findings kept per suite policy (time-driven protocol).

## IN-DIFF finding (statement inside lines 221–228)

- **SLITHER-021** `timestamp` (Low) — `src/StableStaker.sol:228`, `setYieldStrategy`. The flagged comparison **is the new story-010 gate itself**: `require(poolInfo[token].totalStaked == 0, "StableStaker: pool not empty")` (flagged as a dangerous strict-equality comparison). Substantive angle for Tier-2: confirm `finalizeAndReset` always zeroes `totalStaked` exactly with no residue path (e.g. emergencyWithdraw rounding) that could permanently strand a pool out of `setYieldStrategy`; the strict `== 0` also means any 1-wei staker keeps the pool gated — intended (forces terminal-migration path) but worth re-confirming as design.

## Function-contains-diff (in `setYieldStrategy`, outside the hunk)

- **SLITHER-002** `reentrancy-no-eth` (Med) — external calls via `_routeExit` before `yieldStrategy[token] = strategy` (line 256). Owner-initiated, trusted strategy; pre-existing shape.
- **ADERYN-002** + **SLITHER-013** `unused-return` (Med) — `_routeExit(token, staked, false)` return ignored (line 249); `strategy.deposit(...)` return ignored (line 266).
- **SLITHER-019** `reentrancy-events` (Low) — `YieldStrategySet` emitted after external calls.
- **Notable by-product for Tier-2:** with the new gate forcing `totalStaked == 0`, the `staked > 0` drain branch at line 249 looks unreachable post-story-010 — possible dead code worth confirming (and if dead, the M-06 underwater-guard at ~line 238 is similarly only ever evaluated on empty positions).

## Other notable (pre-existing)

- **SLITHER-003** `reentrancy-no-eth` (Med) — `initiateMigration` (425–470), state write after `_routeExit` at 448; corroborated by Aderyn HIGH `reentrancy-state-change` @448 (highest cross-tool agreement in the run). onlyOwner + trusted strategy.
- **SLITHER-001/004** `reentrancy-no-eth` (Med) — `stake`/`depositFor`: `_settle` (phUSD.mint) before state writes; phUSD trusted, likely benign.
- **SLITHER-008–012** `unused-return` (Med, Aderyn-corroborated) — EnumerableSet add/remove returns ignored in stake/withdraw/emergencyWithdraw/_exitPosition/depositFor; QA-grade.
- **SLITHER-005–007** `uninitialized-local` (Med) — zero-init accumulators (`total`, `migratedCount`) in `batchMigrate` / `StableStakerMigrator.migrate`; benign pattern.
- **SLITHER-014/015, ADERYN-001** calls/costly-loop (Low) — migration-loop gas-exhaustion surface only.
- **SEMGREP-001/002** `use-ownable2step` (Low) — single-step Ownable on both contracts; QA owner footgun.

## Bottom line

Story-010 introduced **no new tool-detectable issues**. The only in-diff hit flags the gate itself (strict-equality nit + stranded-pool check for Tier-2); the most useful regression by-product is the **likely-dead `staked > 0` drain branch in `setYieldStrategy` (line 249)** now masked by the gate.
