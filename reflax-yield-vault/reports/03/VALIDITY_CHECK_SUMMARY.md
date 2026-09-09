# Validity Check Summary -- reflax-yield-vault-03

**Date**: 2026-03-25
**Checker**: validity-checker agent
**Source contracts verified**:
- `lib/reflax-yield-vault/src/concreteYieldStrategies/ERC4626YieldStrategy.sol` (397 lines)
- `lib/reflax-yield-vault/src/AYieldStrategy.sol` (442 lines)

## Results Overview

| Finding | Severity | Status | Reason |
|---------|----------|--------|--------|
| H-01 | High | VALID | Proportional accounting bug -- surplus withdrawal drains other clients' yield |
| M-01 | Medium | VALID | Code defect -- _totalWithdraw ignores cached amount parameter |
| M-02 | Medium | INVALID | Fee-charging vault = known-invalid pattern + known issue overlap |
| M-03 | Medium | VALID | Code bug -- deprecated balanceOf() used for critical access control |
| M-04 | Medium | VALID | Missing slippage protection -- clear root cause, common attack vector |
| L-01 | Low | VALID | Edge case -- zero-share redemption from capped balance |
| L-02 | Low | VALID | Missing constructor validation -- defensive programming |
| L-03 | Low | INVALID | Feature request, not vulnerability -- no exploit path |

**Total**: 8 findings checked. **6 VALID**, **2 INVALID**.

---

## Detailed Analysis

### H-01: Multi-Client Surplus Withdrawal Drains Other Clients' Yield -- VALID

**Line verification**: ERC4626YieldStrategy.sol lines 368-396 (`_withdrawFrom`). ACCURATE.

**Validity reasoning**: The root cause is a mathematical flaw in the proportional share accounting model. When `_withdrawFrom()` redeems vault shares for one client's surplus, it burns shares from a communal pool. Since `totalBalanceOf()` calculates each client's balance as `(totalVaultValue * principal) / totalDeposited`, burning shared shares proportionally reduces every other client's computed balance. This is not a trust issue (covered by "SurplusWithdrawer clientInternalBalance trust" known issue) -- it is a design-level accounting bug where the data model does not support multi-client surplus extraction without cross-contamination.

**Not admin-driven**: The authorized withdrawer calling `withdrawFrom()` is the intended normal flow. The bug manifests under normal operation with multiple clients.

---

### M-01: Two-Phase totalWithdrawal Includes Deposits During Waiting Period -- VALID

**Line verification**: ERC4626YieldStrategy.sol lines 332-356 (`_totalWithdraw`), AYieldStrategy.sol lines 379-417 (`_initiateWithdrawal` + `_executeWithdrawal`). ACCURATE.

**Validity reasoning**: Clear code defect. `_executeWithdrawal()` (AYieldStrategy line 406) passes `state.balance` (cached at Phase 1) to `_totalWithdraw()` as the `amount` parameter. But `_totalWithdraw()` in ERC4626YieldStrategy (lines 342-343) reads `clientBalances[token][client]` directly and ignores the `amount` parameter entirely. The NatSpec at line 329 documents this parameter as "from cached balance in two-phase flow" yet the implementation ignores it.

**Not purely admin-driven**: While the owner initiates totalWithdrawal, an authorized client contract could independently make deposits during the waiting period. Those deposits would be silently captured by Phase 2, undermining the timelock's community protection purpose without the client's knowledge.

---

### M-02: Fee-Charging ERC4626 Vaults Create Phantom Surplus -- INVALID

**Line verification**: Lines 119-133 (`totalBalanceOf`), lines 236-253 (`_depositInternal`). ACCURATE.

**Invalidity reasoning -- two grounds**:

1. **Fee-on-transfer analog**: The finding describes a vault that charges fees during deposit operations. While technically about ERC4626 deposit fees rather than ERC20 transfer fees, this falls into the same class of "non-standard/weird token behavior" that C4 considers out of scope by default. The contract owner selects the vault at deployment time; choosing a fee-charging vault is a configuration choice, not a code vulnerability in the strategy contract.

2. **Known issue overlap**: The project's known issues include "Token standard compliance assumption." Fee-on-deposit is a valid but uncommon ERC4626 feature. The project has already acknowledged that it assumes standard vault behavior. The finding's root cause falls squarely within this acknowledged assumption.

**Additional note**: The described impact is limited. Surplus becomes unextractable until yield overcomes the fee deficit (not a loss, just delayed access), and clients receiving less than deposited is expected behavior when using a fee-charging vault (the fee is the vault's business model).

---

### M-03: withdrawFrom() Balance Check Caps Surplus at Principal -- VALID

**Line verification**: AYieldStrategy.sol lines 280-299 (`withdrawFrom`), specifically line 292. ACCURATE.

**Validity reasoning**: Concrete code bug with clear logic chain:
1. `withdrawFrom()` line 292: `this.balanceOf(token, client)` returns `principalOf()` (per ERC4626YieldStrategy line 143-144 which delegates to `principalOf`).
2. Line 293: `require(clientBalance >= amount)` -- amount must be <= principal.
3. Child `_withdrawFrom()` line 376-381: `require(amount <= surplus)` -- amount must be <= (totalBalance - principal).
4. When surplus > principal (e.g., principal=1000, totalBalance=2500, surplus=1500), the parent check at line 293 reverts (1500 > 1000) before the child check is reached.
5. Result: surplus beyond 100% of principal is permanently locked via `withdrawFrom()`.

The finding also correctly identifies that `balanceOf()` is marked DEPRECATED in the interface (IYieldStrategy line 30-31) but is used for a critical access-control decision.

**Not a known issue**: "SurplusWithdrawer clientInternalBalance trust" concerns trust of the withdrawer role, not this logic bug.

---

### M-04: No Slippage Protection on Deposits and Withdrawals -- VALID

**Line verification**: Line 245 (`vault.deposit` with no min shares), lines 276-283 (`convertToShares` + `vault.redeem` with no min assets check). ACCURATE.

**Validity reasoning**: The deposit and withdraw functions accept no slippage parameters, perform no return value checks against minimums, and return no values for callers to verify post-hoc. Sandwich attacks on ERC4626 vault interactions are a well-documented and common attack vector. Since authorized clients have no access to vault share information and the strategy functions return void, the strategy contract is the only place slippage protection can be enforced.

**Not speculation**: The attack vector (sandwich attacks) is well-documented and routinely exploited on mainnet.

---

### L-01: Zero-Share Redemption on Clients With Empty Balances -- VALID

**Line verification**: ERC4626YieldStrategy.sol lines 264-291 (`_withdrawInternal`). ACCURATE.

**Validity reasoning**: Edge case where `amount > 0` check passes on input but amount is subsequently capped to 0 (line 271-273), leading to `vault.redeem(0, ...)` which reverts on many ERC4626 implementations. No fund loss but poor error handling. Low severity is appropriate.

**Not known issue**: "No balance validation in emergency withdrawal" concerns `emergencyWithdraw`, not `_withdrawInternal`.

---

### L-02: Constructor Does Not Validate vault.asset() == underlyingToken -- VALID

**Line verification**: ERC4626YieldStrategy.sol lines 79-88 (constructor). ACCURATE.

**Validity reasoning**: Standard defensive programming recommendation. The constructor accepts two parameters that must match (the vault's asset must equal the underlying token) but does not enforce this invariant. A misconfigured deployment would silently create a broken strategy. Adding `require(IERC4626(_erc4626Vault).asset() == _underlyingToken)` is a one-line fix. Low severity is appropriate.

---

### L-03: No Atomic Migration Mechanism Between Strategies -- INVALID

**Line verification**: N/A (architectural). No specific lines claimed. ACCURATE.

**Invalidity reasoning**: This is a feature request, not a security finding. The two-phase withdrawal timelock exists specifically to protect communities from rugpulls (per AYieldStrategy NatSpec at lines 239-240). Suggesting that migration should bypass or batch this mechanism contradicts its security purpose. There is no demonstrated exploit path, no fund loss scenario, and no protocol function failure. The "slow migration" (N * 24h) is the intended security tradeoff. Additionally, the finding references `AutoPoolYieldStrategy.sol` which may be out of scope for this particular audit.

---

## Recommendations

1. **Remove M-02** from submission -- fee-charging vault behavior is a known-invalid pattern and overlaps with "Token standard compliance assumption" known issue.
2. **Remove L-03** from submission -- architectural improvement suggestions without security impact do not meet C4 criteria.
3. **All other findings (H-01, M-01, M-03, M-04, L-01, L-02)** pass validity checks and should proceed.
4. All line number references verified accurate against source contracts.
