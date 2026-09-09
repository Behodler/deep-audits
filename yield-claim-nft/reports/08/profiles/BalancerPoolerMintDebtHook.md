# Profile: src/V2/hooks/BalancerPoolerMintDebtHook.sol

- solidityVersion: ^0.8.20
- inheritanceChain: IDispatchHook, IBalancerPoolerMintDebtHook, Ownable, ReentrancyGuard
- LOC: 135 | functions: 5 (onDispatch, pull, setRatio, setRecipient, constructor) | stateVars: 4 (+2 immutable, +2 constant)
- PRIMARY (newly added, highest priority)

## Verified Local Properties
- checkedArithmetic: true (0.8.20; `mintDebt += added` cannot overflow in practice; `amount*ratio/100` with ratio<=50 cannot overflow within uint256)
- noUnboundedLoops: true
- accessControlled: `setRatio`/`setRecipient` (onlyOwner), `pull` (onlyOwnerOrRecipient), `onlyDispatcher` gate on `onDispatch`
- reentrancyGuarded: `pull` (nonReentrant). `onDispatch` is NOT guarded but performs only internal accounting (no external calls), so reentrancy is not locally exploitable.
- `dispatcher` and `phUSD` immutable, non-zero enforced in constructor.
- CEI in `pull`: `mintDebt = 0` set before `phUSD.mint(...)` (effects-before-interactions). Combined with nonReentrant, double-pull is not possible.
- onDispatch is gated to `dispatcher`; arbitrary callers cannot inflate `mintDebt`.

## Local Findings

### LOCAL-001 — setRatio off-by-one vs. documented bound (local-low / QA)
- function: setRatio (line 92-97); constant MAX_RATIO=50 (line 30)
- The NatSpec on MAX_RATIO ("Max settable ratio is `MAX_RATIO - 1`"), on `ratio` ("Strictly `< MAX_RATIO`"), and on `setRatio` ("Must be strictly less than `MAX_RATIO` (50)") all state ratio must be strictly below 50. The check is `if (newRatio > MAX_RATIO) revert RatioTooHigh();` which permits `newRatio == 50` (and `== 49`). So the achievable max is 50, not 49. Spec/implementation deviation. Owner-only setter, so impact is limited (owner trust is OOS), but the invariant "ratio < MAX_RATIO" advertised to downstream reasoners does NOT hold — it is `ratio <= MAX_RATIO`.
- recommendation: use `>=` if the strict bound is intended, or correct the NatSpec.
- NOTE for downstream: do not treat `ratio < 50` as an axiom; treat as `ratio <= 50`.

## Interface Abstraction
- `onDispatch(address minter, uint256 amount, bytes) external` — gated to `dispatcher`. State: `mintDebt += amount*ratio/100`. No external calls. Silent no-op if `added==0`. NOT reentrancy-guarded (safe: no external call).
- `pull() external onlyOwnerOrRecipient nonReentrant` — reverts `RecipientUnset` if recipient==0; no-op if mintDebt==0; else zeroes mintDebt and calls `phUSD.mint(recipient, debt)`. External call: phUSD.mint (untrusted-ish; mintable token, trusted contract).
- `setRatio(uint8) onlyOwner` — bound check `<= 50`.
- `setRecipient(address) onlyOwner` — zero allowed (re-arms; pull reverts while zero).
- views: mintDebt, ratio, recipient, dispatcher, phUSD, MAX_RATIO, DEFAULT_RATIO.

## External Calls / Trust Boundaries
- `phUSD.mint(recipient, debt)` — IMintable. phUSD is a trusted protocol mint token. A reverting/misbehaving mint would brick `pull` but not corrupt accounting (effects already applied before the call; a revert rolls them back, preserving debt).
- caller `dispatcher` (immutable BalancerPoolerV2) — the only address that may accrue debt.

## Trust Assumptions
- Owner sets `ratio`, `recipient`, and may call `pull`. Owner/recipient trusted (OOS).
- phUSD honours `mint(to, amount)` and grants this hook mint rights.
- DOWNSTREAM: This hook is installed on BalancerPoolerV2 via `setHook`. When installed, every `BalancerPoolerV2.dispatch` accrues phUSD debt = ratio% of the dispatched USDS `amount`. The dispatched `amount` is the FOT-adjusted USDS the user paid for the mint (forwarded by NFTMinterV2). The hook mints NEW phUSD against this — interaction scanners should reason about whether this phUSD mint is backed/collateralized, since the dispatched USDS is wrapped to sUSDS and pooled, not held against the phUSD debt. Economic backing is an econ-scanner concern.
