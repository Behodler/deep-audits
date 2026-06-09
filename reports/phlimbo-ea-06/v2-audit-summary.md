# PhlimboV2 / MigratorV1V2 Audit Summary — run `phlimbo-ea-06`

- **Project:** phlimbo-ea
- **Run:** phlimbo-ea-06
- **Commit (HEAD):** `6cb0bc0c2c26982a09d9dba2a01a9819bf65190c`
- **Scope:** `src/PhlimboV2.sol`, `src/MigratorV1V2.sol` (new V2 surface; V1 `src/Phlimbo.sol` is deprecated and all 25 V1 findings remain `acknowledged`)
- **Mode:** V2 audit — inherited-issue verification (which V1 issues carry into V2) + new-surface discovery
- **Tally:** Medium 3 · Centralization 4 · Low 10 · QA 2 · Faithfulness 1 · Resolved-from-V1 6

All V2 findings are NEW entries against the V2 contracts, with a `V2-` label prefix to disambiguate from V1 ledger labels. Because `contract` differs from V1 (`src/PhlimboV2.sol` / `src/MigratorV1V2.sol` vs `src/Phlimbo.sol`), the `sha256(contract:function:rootCauseClass)` fingerprints do not collide with any V1 entry. No V1 entry was modified or re-opened.

`inheritedFrom` = the V1 ledger label whose root cause carries into V2. `newSurface` = true means the issue arises from V2-specific code (migrator, hook, explicit-user/migrator-role) with no V1 antecedent.

---

## Findings

### Medium

| Label | Title | Contract / Function | Lines | inheritedFrom | newSurface |
|-------|-------|---------------------|-------|---------------|------------|
| V2-M-01 | MigratorV1V2 strict-`==` balance precondition DoS (1 wei bricks chunkable migration; withdrawAll doesn't reset → re-griefable). Fix: use `>=`. | `MigratorV1V2.sol` `settleDebt`/`migrateDeposits` | L155-239 | — | yes |
| V2-M-02 | phUSD mint authority load-bearing for solvency; revocation/pause/cap bricks claim/stake/withdraw. AMPLIFIED in V2: `MigratorV1V2.settleDebt` (L181) also mints → mid-migration revocation bricks settlement. | `PhlimboV2.sol` `_claimRewards` | L486-507 | M-03 | no |
| V2-M-03 | `pauseWithdraw`→unpause phUSD over-mint: stale `phUSDPerSecond` accrues over shrunken stake (over-mint ≈ S0/S1). Zero-APY (KI-10) immunizes → Medium; **conditional-High**. | `PhlimboV2.sol` `pauseWithdraw` | L280-291 | M-05 | no (footgun) |

### Centralization

| Label | Title | Contract / Function | Lines | inheritedFrom | newSurface |
|-------|-------|---------------------|-------|---------------|------------|
| V2-C-01 | `emergencyTransfer` drains without zeroing accounting then `_pause()`; with `setPauser(0)` (no zero-guard) the auto-pause is an irreversible permanent lock. | `PhlimboV2.sol` `emergencyTransfer` | L251-263 | C-02 | no (footgun) |
| V2-C-02 | Uncapped `desiredAPYBps` → unbounded phUSD mint pressure; two-step gate is delay-only. | `PhlimboV2.sol` `setDesiredAPY` | L172-190 | C-03 | no |
| V2-C-03 | `setDepletionDuration` no floor / no two-step → flash distribution of entire `rewardBalance` to whoever is staked at that instant. | `PhlimboV2.sol` `setDepletionDuration` | L196-211 | C-01 | no |
| V2-C-04 | Residual migrator custody: migrator role not auto-revoked post-migration; can call withdraw/claim on behalf of any user, routing principal+rewards to itself (L373/L392/L424). Faithful to story-020 but a footgun. Recommend `setMigrator(0)` after migration; migrator must be the contract, never an EOA. | `PhlimboV2.sol` `setMigrator`/`withdraw`/`claim` | L232-236, L363-432 | — | yes (footgun) |

### Low

| Label | Title | Contract / Function | Lines | inheritedFrom | newSurface |
|-------|-------|---------------------|-------|---------------|------------|
| V2-L-01 | `pauseWithdraw` stale-debt underflow brick (self-inflicted, principal recoverable via re-pause; only rewards/normal paths stuck). | `PhlimboV2.sol` `pauseWithdraw`/`_claimRewards` | L280-291 | M-01 | no |
| V2-L-02 | `pendingPhUSD`/`pendingStable` view underflow after `pauseWithdraw`. | `PhlimboV2.sol` `pendingPhUSD`/`pendingStable` | L526-558 | L-14 | no |
| V2-L-03 | `pauseWithdraw` bypasses the MINIMUM_STAKE dust rule. | `PhlimboV2.sol` `pauseWithdraw` | L280-291 | L-15 | no |
| V2-L-04 | `setPauser` no event, no zero-guard (the missing zero-guard feeds V2-C-01). | `PhlimboV2.sol` `setPauser` | L224-226 | L-04 | no |
| V2-L-05 | `setDesiredAPY` commit doesn't clear `pendingAPYBps`/`pendingAPYBlockNumber`. | `PhlimboV2.sol` `setDesiredAPY` | L182-189 | L-03 | no |
| V2-L-06 | Stable per-share rounding stranding: `rewardBalance` debited in full while `accStablePerShare` floors → remainder uncredited. | `PhlimboV2.sol` `_updatePool` | L459-463 | L-16 | no |
| V2-L-07 | phUSD is stake-token AND minted reward → compounding spiral. | `PhlimboV2.sol` `_claimRewards` | L486-507 | L-11 | no |
| V2-L-08 | `_updatePhUSDEmissionRate` truncates `phUSDPerSecond` to 0 at low stake×APY. | `PhlimboV2.sol` `_updatePhUSDEmissionRate` | L512-519 | L-13 | no |
| V2-L-09 | Reverting/gas-heavy hook bricks stake/withdraw/claim (no try/catch); `pauseWithdraw` is hook-exempt so a principal exit survives. Recommend monitoring; consider try/catch. | `PhlimboV2.sol` `stake`/`withdraw`/`claim` | L353/L398/L429 | — | yes (footgun) |
| V2-L-10 | Migrator auto-claims a pre-existing V2 staker's rewards to itself: if a user self-stakes before the migrator acts, `migrateDeposits`→`stake` auto-claims their pending rewards to the migrator. Mitigate: complete migration before users can self-stake. | `PhlimboV2.sol` `stake` | L336-338 | — | yes |

### QA (routed to the QA bundle)

| Label | Title | Contract / Function | Lines | inheritedFrom | newSurface |
|-------|-------|---------------------|-------|---------------|------------|
| V2-Q-01 | `pauseWithdraw` silent reward forfeiture + orphan residue. Blessed by KI-4 (forfeiture by design); QA only. | `PhlimboV2.sol` `pauseWithdraw` | L280-291 | L-06 | no |
| V2-Q-02 | Declared event `RateUpdated` never emitted. | `PhlimboV2.sol` event declaration | L126 | L-01 | no |

### Spec-conformance (faithfulness — routed to spec-conformance report, NOT the QA bundle)

| Label | Title | Contract / Function | Lines | inheritedFrom | newSurface |
|-------|-------|---------------------|-------|---------------|------------|
| V2-F-01 | `emergencyTransfer` breaks story-008 HIGH-5's safe-`pauseWithdraw`-exit promise: post-drain `pauseWithdraw` reverts for everyone (no balance). | `PhlimboV2.sol` `emergencyTransfer`/`pauseWithdraw` | L251-291 | F-01 | no (faithfulness) |

---

## Resolved in V2

Seven V1 issues are no longer present on the V2 surface. Six are recorded in the ledger `v2ResolvedFromV1[]` array for the regression trail; the seventh (Linear-Depletion) is the V2 raison d'être and is listed there too.

| V1 label | Root cause | Disposition |
|----------|------------|-------------|
| M-04 | Linear-Depletion implemented as exponential decay (rate re-anchored on every interaction) | **FIXED**: rate recompute removed from `_updatePool` (V2 raison d'être; excluded per owner). |
| M-02 | `collectReward` re-anchor griefing | **RESOLVED**: re-anchor removed; `collectReward` requires a real `rewardToken` transfer (`amount > 0`). |
| L-07 | `collectReward` sandwich-MEV staker theft | **RESOLVED/negligible**: `_updatePool` runs before balance add; streamed rewards. |
| L-08 | `collectReward` zero-`totalStaked` funder leak | **RESOLVED**: `rewardBalance` preserved when `totalStaked == 0`; no leak. |
| L-09 | CEI cross-fn reentrancy | **RESOLVED**: all entrypoints `nonReentrant`; hook fires post-state inside the guard. |
| L-10 | stake-for-victim griefing (forced reward-debt re-anchor) | **RESOLVED**: V2 `stake` gated `msg.sender == user || migrator` (L326). |

---

## Severity adjudication

The severity-auditor adjudicated the final severities. Notable adjustments versus the code-scanner's initial proposals:

- **Downgrade — V2-L-01 (`pauseWithdraw` stale-debt brick):** code-scanner proposed **High**; adjudicated **Low**. It is self-inflicted (`pauseWithdraw` is `msg.sender`-only), principal is recoverable via re-pause, and only rewards / normal paths are stuck.
- **Downgrade — V2-M-03 (over-mint on unpause):** code-scanner proposed **High**; adjudicated **Medium**, *held conditionally*. The live zero-APY config (KI-10) immunizes the phUSD stream, so the over-mint cannot fire today.
- **Held conditional — V2-M-03:** **RE-CLASSIFY HIGH** the moment any non-zero-APY config ships. The mechanism (over-mint ≈ S0/S1) is real; only the current zero-APY parameterization keeps it at Medium.

---

## Open questions / next steps

1. **Confirm on-chain migration status — caps V2-M-01 practical severity.** V2-M-01 (strict-`==` migrator DoS) is only exploitable while the migration is in progress. If the on-chain migration is already complete (both iterators at `-1`), the surface is closed for this deployment and the finding is effectively dormant; it is held at contract-level Medium pending confirmation.
2. **V2-M-03 escalates to High under any non-zero-APY config.** Treat the Medium classification as conditional on the live zero-APY parameterization. Any governance action that sets a non-zero `desiredAPYBps` must re-trigger severity review and PoC.
3. **PoCs pending for the 3 Mediums.** V2-M-01, V2-M-02, and V2-M-03 each need a runnable Foundry PoC (currently `poc.status: pending` in the ledger) before report submission: the 1-wei migrator brick (V2-M-01), the mock mint-revert bricking claim/settlement (V2-M-02), and the `S0/S1` over-mint witness on unpause under a non-zero-APY harness (V2-M-03).
