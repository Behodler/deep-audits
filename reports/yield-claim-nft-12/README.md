# yield-claim-nft — Run 12 (REGRESSION)

- **Project:** yield-claim-nft
- **Run:** yield-claim-nft-12
- **Mode:** REGRESSION
- **Commit range:** `7b86dec..7f5cac1`
- **Audited commit (new HEAD):** `7f5cac1205c14d66bfaf69392b04541fb44bcf2c`
- **Story:** story-039 — pure structural refactor (V1 + NFTMigrator deleted; `src/V2/X` flattened to `src/X`)
- **Date:** 2026-06-23

## Verdict

**Clean structural flatten — nothing to report.**

- **0 new findings**, **0 regressions**, **0 H/M**, **0 new Low/QA**.
- **0 faithfulness deviations** — story-039 is scope-honest (a content-preserving move/rename of files plus deletion of the dead V1 layer; no logic changed).
- Story-faithfulness verified the flatten is content-preserving; wiring confirmed intact via `forge build`.
- Ledger reconciled against the new HEAD.

story-039 deleted the V1 contracts and the `NFTMigrator`, then flattened the `src/V2/` tree up to `src/`. No behavioral surface moved; this run is bookkeeping plus path reconciliation.

## Ledger reconciliation

- `lastRun` → `yield-claim-nft-12`
- `lastAuditedCommit` → `7f5cac1205c14d66bfaf69392b04541fb44bcf2c`
- `updatedAt` → `2026-06-23`
- Path remaps (`src/V2/X` → `src/X`) were applied across 18 carryover/closed entries.
  The `M-01`, `M-02`, `Q-01` (NFTMigrator) paths were **deliberately left as `src/V2/NFTMigrator.sol`** as audit-trail markers, since that file is now deleted.

## Status changes — APPLIED (user-confirmed 2026-06-23)

Three entries targeting the now-deleted `src/V2/NFTMigrator.sol` (removed by story-039, `7f5cac1`) were triaged and **applied** to `reports/ledgers/yield-claim-nft.json`:

| Label | Prior status | New status | Outcome |
|-------|--------------|-----------|---------|
| M-01 — migrate() unbounded per-unit mint loop gas DoS | wont-fix | **fixed** (`fixedAtCommit` `7f5cac1`) | MOOT: gas-DoS code physically removed by NFTMigrator deletion (supersedes prior wont-fix) |
| M-02 — late V1 dispatcher registration bricks migrate() | wont-fix | **fixed** (`fixedAtCommit` `7f5cac1`) | MOOT: index-0 brick code physically removed by NFTMigrator deletion (supersedes prior wont-fix) |
| Q-01 — missing zero-address validation in constructors | qa-bundled | **fixed** (`fixedAtCommit` `7f5cac1`) | SPLIT: NFTMigrator portion moot by deletion; surviving BurnerV2/GatherV2 concern re-scoped to **Q-09** |

The `src/V2/NFTMigrator.sol` path on M-01/M-02/Q-01 was retained as an audit-trail marker.

### Q-01 split → Q-09 (BurnerV2 / GatherV2) — APPLIED, concern is LIVE

Q-01 ("Missing zero-address validation in constructors") originally covered **three** contracts: `NFTMigrator`, `BurnerV2`, and `GatherV2`. Only the `NFTMigrator` portion is moot by deletion. The surviving `BurnerV2` / `GatherV2` concern was **verified live @ `7f5cac1`** and re-scoped to a new ledger entry **Q-09**:

- `BurnerV2.constructor` (`src/dispatchers/BurnerV2.sol:17-20`) validates **neither** `token_` **nor** `burnRecorder_` — no zero-address checks at all.
- `GatherV2.constructor` (`src/dispatchers/GatherV2.sol:26-30`) validates `recipient_` but **not** `token_` (nor `initialOwner`).

**Q-09** — severity `qa`, status `qa-bundled` (original bundled state preserved), fingerprint `3a5c5221a5b4b617f1acbe3569f6819c4b7984fc98c11e6da890b5c05910c56b`, `firstSeenRun` inherited from Q-01 (`yield-claim-nft-08`), `lastSeenRun` `yield-claim-nft-12`, linked back to Q-01 via `splitFrom`.

## Open carryover findings (5)

Re-confirmed still-present at their flattened paths; `lastSeenRun` bumped to `yield-claim-nft-12`. Thin stubs written to `submissions/carryover/`.

| Label | Severity | Location |
|-------|----------|----------|
| L-04 | Low | `src/NFTMinterV2.sol#L206-L214` (`mintFor`) — privileged mintFor/burn ignore paused + disabled flags |
| L-05 | Low | `src/dispatchers/BalancerPoolerV2.sol#L160-L164` (`setBatchDonationSize`) — no batchDonationSize+ratio<=100 invariant |
| L-06 | Low | `src/dispatchers/BalancerPoolerV2.sol#L269-L275` (`pool`) — single-sided LP-add MEV sandwich |
| L-07 | Low | `src/NFTMinterV2.sol#L227-L247` (`replaceDispatcher`) — stale price across differing-decimals primeToken |
| Q-05 | QA | `src/dispatchers/BalancerPoolerV2.sol#L269` (`pool`) — nonReentrant not first modifier |

## Artifacts

- Ledger: `reports/ledgers/yield-claim-nft.json`
- Carryover stubs: `reports/yield-claim-nft-12/submissions/carryover/`
