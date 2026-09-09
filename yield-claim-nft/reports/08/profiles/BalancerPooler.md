# Profile: src/dispatchers/BalancerPooler.sol  (V1 — CONTEXT)

- ^0.8.20 | ATokenDispatcher, IUnlockCallback

## Verified Local Properties
- `dispatch` onlyMinter whenNotPaused; decodes optional minBptAmountOut from extraData; calls vault.unlock.
- `unlockCallback` gated msg.sender==vault; FOT balance-before/after; single-sided add-liquidity then settle.
- NO nonReentrant (V1 base lacks it); dispatch is the only entry and is minter-gated + driven by NFTMinter mint flow.
- withdrawBPT onlyOwner.

## Local Findings (context)
- V1 pools synchronously DURING dispatch (every mint adds liquidity), whereas V2 splits wrap (dispatch) from pool (separate owner/pooler call) — this is the H-02 redesign. No new local finding; behavioural difference noted for diff-aware scanners.

## Interface Abstraction
- `dispatch(_,amount,extraData)` onlyMinter whenNotPaused -> vault.unlock.
- `unlockCallback(data)` only vault -> transfer prime to vault, addLiquidity (single-sided), settle.
- `withdrawBPT(recipient,amount)` onlyOwner. `primeToken()/vault()` views.

## Trust / External
- Balancer V3 Vault (unlock/addLiquidity/settle). primeToken standard ERC20 (FOT-safe). Owner/minter trusted.
