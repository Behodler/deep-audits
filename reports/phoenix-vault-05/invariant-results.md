# Invariant Test Results — phoenix-vault (reflax-yield-vault)

- Project: phoenix-vault (maps to `lib/reflax-yield-vault`)
- Run timestamp: 2026-05-25
- Target: `src/concreteYieldStrategies/ERC4626MarketYieldStrategy.sol` (+ `src/AMMAdapters/CurveAMMAdapter.sol` via mock)
- Harness: deterministic, mock-based (no mainnet fork). Mocks used:
  `test/mocks/MockERC4626Vault.sol`, `test/mocks/MockAMMAdapter.sol`, `src/mocks/MockERC20.sol`.
- Runners: **forge** (invariant) = yes, **Medusa** v1.5.1 = yes, **Echidna** = not installed (skipped).

## Files produced (workspace, all absolute)

- Stateful invariant harness (Foundry): `workspace/phoenix-vault/test/invariant/PhoenixVaultInvariant.t.sol`
- Deterministic isolation PoC (Foundry): `workspace/phoenix-vault/test/invariant/CODE001_Poc.t.sol`
- Medusa fuzz target: `workspace/phoenix-vault/test/invariant/MedusaPhoenixVault.sol`
- Medusa config: `workspace/phoenix-vault/medusa.json`
- Foundry invariant profile added to `workspace/phoenix-vault/foundry.toml` (`[invariant] runs=256 depth=50 fail_on_revert=false`)

## Harness design notes (fidelity)

- The MockAMMAdapter is kept in lock-step with the vault NAV before every swap
  (`_syncAdapterToNav`): swap execution price == fair NAV. This deliberately removes
  slippage/sandwich economics so that any divergence between held-share backing and
  recorded principal is a **pure accounting defect**, not a price effect. This isolates
  CODE-001 from ECON-01/02 (which are separate slippage findings).
- `slippageToleranceBps = 0` is safe in this harness precisely because minOut == fair value
  == received (no price impact in the mock once synced).
- The adapter is funded with both tokens before each op so swaps never revert for lack of reserves.
- 1:1-NAV vault seeded at setUp; `accrueYield` raises NAV to create skimmable surplus.

## Results summary

| Invariant | Type | Runner(s) | Result |
|---|---|---|---|
| `invariant_INV1_principalAccounting` | conservation (INV-1) | forge + medusa | **HELD** |
| `invariant_shareBackingCoversPrincipal` | solvency / share-backing (CODE-001, ECON-03) | forge + medusa | **BROKE** |
| `invariant_skimCannotUnderbackPrincipal` | solvency / skim-backing (CODE-001) | forge | **BROKE** |
| `test_CODE001_duplicateClientsOverSkim` (PoC) | deterministic exploit | forge | **PASS (exploit reproduced)** |
| `test_CODE001_uniqueListIsSafe` (control) | deterministic control | forge | **PASS (no break with unique list)** |

Foundry: 1 invariant passed, 2 invariants broke, 2 PoC tests passed.
Medusa: 14 tests passed, 1 property failed (`property_shareBackingCoversPrincipal`); `property_inv1_principal` passed.

### INV-1 HELD (expected)

`totalDeposited == Σ clientBalances` held across 256 runs / 12,800 calls under Foundry and across
~170k+ Medusa calls. Confirms principal accounting is internally consistent and that CODE-001's
loss is **silent** — it does not show up in principal, only in backing. Matches profiles.md INV-1.

### CODE-001 CONFIRMED — duplicate `clients[]` in `skimSurplusBatch` over-skims, under-backing principal

Both the share-backing invariants broke, and **every shrunk counterexample (Foundry and Medusa)
terminates with a `skimBatchDuplicate` call**, i.e. a `skimSurplusBatch` invoked with a clients
array containing duplicate entries. This is the confirmation evidence requested for CODE-001.

#### Medusa shrunk counterexample (primary fuzzer)

```
Property Test: MedusaPhoenixVault.property_shareBackingCoversPrincipal()  => FAILED
[Call Sequence]
 1) fuzzDeposit(...)            // client deposits principal
 2) fuzzAccrueYield(...)        // NAV rises -> surplus exists
 3) fuzzSkimBatchDuplicate(...) // skimSurplusBatch(token, [c,c,c,c], recipient)
=> property_shareBackingCoversPrincipal() now false (held-share value < recorded principal)
   property_inv1_principal() remains true (principal accounting intact)
```

#### Foundry shrunk counterexample (`invariant_skimCannotUnderbackPrincipal`)

```
[Sequence] (shrunk: 6)
  skimBatchUnique()
  deposit(uint256,uint256)
  withdraw(uint256,uint256)
  skimBatchUnique()
  accrueYield(uint256)
  skimBatchDuplicate(uint256)   // <-- the breaking call: duplicated clients[] over-skim
=> FAIL: held-share value (760907679634278669265802) < recorded principal (760908136179069066749155)
```

#### Deterministic isolation PoC (clean numbers — the headline evidence)

`test_CODE001_duplicateClientsOverSkim`:
- A and B each deposit **100,000 USDe** → `totalDeposited = 200,000 USDe`.
- +20% NAV yield → each client surplus = 20,000; **true aggregate surplus = 40,000 USDe**.
- `skimSurplusBatch(token, [A, A, B, B], recipient)` (each client duplicated once):
  - value actually skimmed = **79,999.99… USDe ≈ 2 × true surplus** (each client counted twice).
  - `totalDeposited` unchanged at **200,000 USDe** (surplus-only semantics → loss is silent).
  - held-share value drops 240,000 → **160,000 USDe** — now **below** the 200,000 recorded principal.
  - downstream harm: client B's proportional claim falls to **80,000 USDe**, i.e. **20,000 below B's
    100,000 principal**. B can no longer be made whole.

Control `test_CODE001_uniqueListIsSafe`: the same deposit/yield with a **unique** `[A, B]` list leaves
principal fully backed and both clients recoverable — confirming duplication is the root cause, not the
skim mechanism itself.

## Root cause (matches CODE-001)

`_skimSurplusBatch` (`ERC4626MarketYieldStrategy.sol:462-488`) iterates the caller-supplied
`clients[]` with no deduplication. A client appearing `k` times has its surplus shares added to
`totalShares` `k` times. The only ceiling is `availableShares` (the strategy's entire held balance,
which backs principal + surplus), not the true aggregate surplus. The single aggregate swap therefore
sells past the legitimate surplus into the principal-backing share pool; principal accounting is left
untouched (INV-1 holds), so the shortfall surfaces only later as an under-collateralized withdrawal.
The single-client `_skimSurplus` path is correctly bounded (`require(amount <= surplus)`); the batch
path drops that per-client invariant.

## Severity note

The caller is `onlyAuthorizedWithdrawer` (trusted role), so this is not an arbitrary-attacker path —
it is an accounting-correctness defect triggerable by a benign operator passing an accidentally-
duplicated list (e.g. an off-chain script unioning two client groups), causing real loss to
third-party clients. Consistent with the code-scanner's Medium estimate; final HM-vs-QA call is the
severity-classifier's. Recommended fix: enforce uniqueness (strictly-increasing input or in-loop
seen-set), or bound `totalShares` by an independently recomputed aggregate surplus rather than by
`availableShares`.

## Reproduce

```bash
cd workspace/phoenix-vault
# Foundry: stateful invariants (2 break) + deterministic PoC (passes)
forge test --match-path 'test/invariant/*' -vv
# Medusa: primary stateful fuzzer (property_shareBackingCoversPrincipal fails)
medusa fuzz --config medusa.json
```
