# QA Report for stable-staker

Audit run: `stable-staker-06` — submodule `lib/stable-staker` @ `7e9ef80`
In scope: `src/StableStaker.sol`, `src/StableStakerMigrator.sol`

## Summary

| ID | Title | Severity |
|----|-------|----------|
| L-01 | `depositFor` missing `require(credited > 0)` guard | Low |
| I-01 | Reentrancy CEI-deviation on guarded, trusted-external paths | Informational |
| I-02 | Unused return values on `EnumerableSet.add`/`remove` | Informational |
| I-03 | External calls inside a loop in batch migration paths | Informational |

| Severity | Count |
|----------|-------|
| Low Risk | 1 |
| Centralization | 0 |
| Informational (QA group) | 3 |
| **Total** | **4** |

An automated QA/gas baseline (4naly3er) is attached as an appendix — see [Appendix A](#appendix-a-automated-report-4naly3er).

---

## Low Risk Findings

### [L-01] `depositFor` missing `require(credited > 0)` guard <!-- id: ss6l1 -->

**Location**: [`src/StableStaker.sol#L516-L537`](../../../lib/stable-staker/src/StableStaker.sol#L516) (contrast `stake`'s guard at [`#L250`](../../../lib/stable-staker/src/StableStaker.sol#L250)).

**Description**: `depositFor` omits the `require(credited > 0)` guard that `stake` enforces. With a haircutting (market) `IYieldStrategy` adopted, a dust deposit can route to `credited == 0`, while `_stakers[token].add(user)` still inserts the user, creating a zero-position entry.

`stake` protects against this:

```solidity
uint256 credited = _routeDeposit(token, received);
require(credited > 0, "StableStaker: nothing credited"); // L250
user.amount += credited;
```

`depositFor` does not:

```solidity
uint256 received = _pullToken(token, msg.sender, amount);
uint256 credited = _routeDeposit(token, received); // no credited>0 check
info.amount += credited;
pool.totalStaked += credited;
info.rewardDebt = (info.amount * pool.accPhusdPerShare) / ACC_PRECISION;
_stakers[token].add(user); // zero-position entry can be inserted
```

**Impact**: No fund loss and no reward-accounting impact (`info.amount`/`totalStaked` increment by zero). The caller is the trusted migrator (`onlyMigrator`), so this is not externally reachable. The only consequence is set pollution: a zero-position entry pollutes `getStakers` / `getStakersRange` / `stakerCount` and inflates future migration batch sizes. Each zero entry is harmlessly skipped by `_exitPosition`'s `amt == 0` early-return, so migrations still settle correctly.

**Recommendation**: Mirror `stake`'s guard in `depositFor`:

```solidity
uint256 credited = _routeDeposit(token, received);
require(credited > 0, "StableStaker: nothing credited");
info.amount += credited;
```

---

## Informational (QA Group Note)

The following are automated static-analysis observations retained as defense-in-depth notes. Each was reviewed and found non-exploitable; none should be elevated above informational.

### [I-01] Reentrancy CEI-deviation on guarded, trusted-external paths

**Source**: Slither `reentrancy-no-eth`.

**Locations**: `initiateMigration`, `stake`, `depositFor`.

**Description**: These functions perform external calls before completing all state writes (a checks-effects-interactions deviation). However, all three are `nonReentrant`-guarded and reach only trusted externals — the phUSD minter and the owner-set yield strategy. No untrusted reentrancy surface exists.

**Recommendation**: For robustness, consider tightening to strict checks-effects-interactions ordering. Defense-in-depth only; no action required.

### [I-02] Unused return values on `EnumerableSet.add` / `remove`

**Source**: Slither / Aderyn `unused-return`.

**Description**: Calls to `EnumerableSet.add` / `remove` ignore the boolean return value. The operations are idempotent and the ignored result is benign in every call site.

**Recommendation**: No action required.

### [I-03] External calls inside a loop in batch migration paths

**Source**: Slither `calls-loop`.

**Locations**: `batchMigrate`, `StableStakerMigrator.migrate`.

**Description**: Both iterate a staker batch making external calls per element. The batches are operator-controlled and off-chain batchable via `getStakersRange`, so gas/DoS exposure is bounded by the trusted caller.

**Recommendation**: No action required; continue to size batches via `getStakersRange`.

---

## Appendix A: Automated Report (4naly3er)

The canonical C4-style automated QA/gas report was generated with **4naly3er** against the in-scope source and is attached in full at:

`reports/stable-staker-06/submissions/4naly3er-report.md`

Tool outcome: **succeeded** (scope: `StableStaker.sol`, `StableStakerMigrator.sol`, `interfaces/IStableStaker.sol`).

Issue-class summary from the automated run:

| Class | Distinct issue types |
|-------|----------------------|
| Gas Optimizations | 13 (GAS-1 … GAS-13) |
| Non-Critical | 18 (NC-1 … NC-18) |
| Low | 9 (L-1 … L-9) |

These are machine-generated baseline observations (style, gas micro-optimizations, generic checklist items such as two-step ownership, zero-value-transfer tokens, `PUSH0` chain compatibility, precision/rounding notes). They are provided for completeness and are not individually triaged into the manual findings above; the manual L-01 above is the only Low-severity issue judged report-worthy for this run.
