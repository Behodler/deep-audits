# Profile: src/V2/dispatchers/BalancerPoolerV2.sol

- solidityVersion: ^0.8.20
- inheritanceChain: ATokenDispatcherV2 (Pausable, Ownable, ReentrancyGuard), IUnlockCallback
- LOC: 318 | PRIMARY

## Verified Local Properties
- checkedArithmetic: true. `donationSUSDS = sUSDSAmount*batchDonationSize/100` with batchDonationSize<=100 (enforced in setter) cannot overflow.
- accessControlled: setPool/setAuthorizedPooler/incrementAuthVersion/setBatchDonationSize/setBatchMinter/setSwapConfig/withdrawBPT/rescueERC20 (onlyOwner); pool() (onlyAuthorizedPooler whenNotPaused nonReentrant).
- reentrancyGuarded: `dispatch` (inherited nonReentrant), `pool` (nonReentrant). `unlockCallback` gated to `msg.sender == _vault`.
- Pooler auth via authVersion epoch: `incrementAuthVersion` mass-revokes all poolers (version mismatch). Verified: a pooler authorized at version N is invalid after increment.
- FOT-safe transfers to vault use balance-before/after (`actualInVault`) in the LP phase.
- `_primeToken = IERC4626(sUSDS).asset()` (immutable) — primeToken is the sUSDS underlying (USDS); cannot be spoofed.

## Local Findings

### LOCAL-007 — Donation-phase sUSDS->waUSDC swap has no slippage floor on the swap leg (local-low/medium; verify intent)
- function: unlockCallback donation phase (lines 214-243)
- The `VaultSwapParams.limitRaw = 0` (EXACT_IN) means the Balancer swap accepts ANY waUSDC output. Slippage is only enforced AFTER the waUSDC->USDC unwrap via `require(usdcReceived >= minUSDC)`. This is intentional per the comment ("final slippage enforced on USDC after unwrap") and minUSDC is supplied by the authorized pooler. Because the final USDC floor is checked, an adverse swap is bounded by minUSDC — provided the pooler sets minUSDC correctly. If a pooler passes minUSDC=0, the donation leg is fully exposed to swap manipulation/MEV. Pooler is a semi-trusted role; locally this is a parameter-hygiene concern. DEFER MEV/manipulation reachability to interaction/econ analysis; note the limitRaw=0 here.

### LOCAL-008 — pool() processes the ENTIRE sUSDS balance, including FOT/airdrop dust and donation skim ordering (note)
- `pool()` pulls `IERC20(_sUSDS).balanceOf(address(this))` — all accumulated sUSDS from many dispatches. Donation size is a % of that whole batch. No per-mint attribution. By design (batch). Note for econ: the phUSD mint debt accrued by the hook is per-dispatch (per `amount`), but pooling/donation is on the aggregate sUSDS — accounting bases differ. DEFER.

### LOCAL-009 — rescueERC20 / withdrawBPT can move pool/sUSDS assets (owner power, note)
- `rescueERC20(token,to,amount)` is not pause-gated and can transfer ANY ERC20 incl. _sUSDS and BPT. `withdrawBPT` likewise. Owner trust (OOS). Documented escape hatch. Note only.

## Interface Abstraction
- `_dispatch(_, amount, _)` — `forceApprove(sUSDS, amount)` then `IERC4626(sUSDS).deposit(amount, this)`. Wraps USDS->sUSDS held on this contract. (Then base calls hook.onDispatch.)
- `pool(uint256 minBPT, uint256 minUSDC) external onlyAuthorizedPooler whenNotPaused nonReentrant` — requires sUSDS balance>0; calls `vault.unlock(unlockCallback data)`.
- `unlockCallback(bytes) external` — only vault. Optional donation: transfer donationSUSDS to vault, swap sUSDS->waUSDC (limitRaw 0), settle, sendTo, redeem waUSDC->USDC, require>=minUSDC, transfer USDC to batchMinter. Then LP add-liquidity of remaining sUSDS (single-sided), settle.
- `getIdealBPT() external` — queries router (non-view; state-changing query function).
- owner setters: setPool, setAuthorizedPooler, incrementAuthVersion, setBatchDonationSize(<=100), setBatchMinter, setSwapConfig, withdrawBPT, rescueERC20.
- views: primeToken, sUSDS, vault, pool, authVersion, poolerAuthVersion, batchDonationSize, batchMinter, swapPool, waUsdc, usdc.

## External Calls / Trust Boundaries
- Balancer V3 Vault (`_vault`, immutable): unlock, swap, settle, sendTo, addLiquidity. UNTRUSTED external protocol (semi-trusted; standard Balancer V3). unlockCallback authenticated by msg.sender==vault.
- Balancer Router (`_router`, immutable): queryAddLiquidityUnbalanced.
- sUSDS (IERC4626): deposit, balanceOf, transfer; waUsdc (IERC4626): redeem.
- USDS (primeToken), USDC: standard ERC20 transfers.
- Authorized poolers: trigger pool() and choose minBPT/minUSDC.

## Trust Assumptions
- Balancer V3 vault behaves per spec (unlock/settle accounting). External dependency — interaction scanner must model swap/addLiquidity return values and the settle invariants.
- sUSDS and waUSDC are honest ERC4626 wrappers (deposit/redeem). Token risk OOS but ERC4626 share-price/donation behaviour is an econ concern.
- Owner sets pool/swap config; poolers are semi-trusted operators. batchMinter receives donated USDC.
- DOWNSTREAM: this is the dispatcher that the BalancerPoolerMintDebtHook is bound to (immutable `dispatcher`). USDS dispatched here is wrapped to sUSDS and either pooled as LP or skimmed to USDC for batchMinter; the phUSD debt minted by the hook is NOT collateralized out of this flow. Econ-scanner: assess phUSD backing.
