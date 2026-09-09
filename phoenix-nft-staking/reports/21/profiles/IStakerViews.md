# Contract profile — `src/IStakerViews.sol` (NEW)

- Run: `phoenix-nft-staking-21`; HEAD `c881a42`; added at `f3b92c0` (story-023)
- Solidity `^0.8.20`; 31 LOC; **interface only — no state, no code, no deployed bytecode**

## Surface

| Declaration | Line | Mutability | Compiles to |
|---|---|---|---|
| `rewardToken() returns (IERC20)` | `:26` | `external view` | **STATICCALL** at every call site |
| `pendingReward(address account) returns (uint256)` | `:30` | `external view` | **STATICCALL** at every call site |

Callers: `NFTStakerMigrator.sol:133,:137,:215` and `InPlaceNFTStakerMigrator.sol:168,:312`.

## Local properties

- No state, no loops, no arithmetic, no external calls of its own — the whole checklist is
  vacuously satisfied.
- Both members are `view`, so a hostile/buggy staker cannot mutate migrator state at either
  snapshot read. This is the compile-time basis for guarantee G12 in
  `MIGRATOR-FORWARDING-PROFILE.md`.

## Local findings

**LOCAL-401 — conformance is unchecked at compile time.** The migrators hard-cast
(`IStakerViews(address(staker))`) rather than typing the staker as `IStakerViews`, so a target
that does not implement these selectors fails at **runtime, mid-batch**, not at deploy time.
Partially mitigated: both constructors probe `rewardToken()`
(`NFTStakerMigrator.sol:133-140`, `InPlaceNFTStakerMigrator.sol:167-170`). **`pendingReward`
is never probed** — a staker with `rewardToken()` but no `pendingReward` deploys cleanly and
reverts on the first `migrate`/`migrateIn`. Severity: local **informational**; a one-line
constructor probe closes it.

## Design note (D-5)

`:11-22` justifies keeping these off `INFTStakerMigratable`: that interface is the minimal
migration contract (`initiateMigration`, `batchMigrate`, `depositFor`), and `rewardToken` /
`pendingReward` are incidental public getters. Widening the shared interface would force a
change on every implementer for a migrator-local concern. **Assessed sound.**

The comment's conformance claim is verified against source: `rewardToken` at
`NFTStakerDepletion.sol:95` and `NFTStakerPriceScaledMigrateReady.sol:116`; `pendingReward` at
`:799` and `:947` respectively — matching the line references in the NatSpec exactly.
