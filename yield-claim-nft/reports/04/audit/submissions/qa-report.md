# QA Report — yield-claim-nft (V2)

**Audit run**: yield-claim-nft-04
**Submodule commit**: `lib/yield-claim-nft @ 69357d4`
**Scope**: V2 hook surface and V2 dispatcher refactor (stories 025 / 026)

## Summary

| Severity         | Count |
|------------------|-------|
| Low Risk         | 2     |
| Centralization   | 0     |
| **Total**        | **2** |

---

## Low Risk Findings

### [L-01] `NFTMinterV2` lacks a contract-level reentrancy guard; hooks and ERC1155 receiver callbacks enable cross-dispatcher re-entry

**Location**: `src/V2/NFTMinterV2.sol#L170-L201` (`_executeMint`)

**Description**:

`_executeMint` performs the following sequence inside a single user call:

1. `IERC20(token).safeTransferFrom(msg.sender, config.dispatcher, price)` (L183)
2. `config.price = price + (price * config.growthBasisPoints) / 10000` — price ratchet (L188)
3. `ATokenDispatcherV2(config.dispatcher).dispatch(address(this), actualReceived, extraData)` (L191) — runs `hook.onDispatch` under the dispatcher's `nonReentrant` lock
4. `_mint(recipient, resolvedTokenId, 1, "")` (L196) — invokes `ERC1155Utils.onERC1155Received` on contract recipients

Two untrusted callbacks fire inside this sequence:

- The dispatcher's `nonReentrant` lock is **per-dispatcher**, so a hook is free to call back into `NFTMinterV2.mint(differentIndex, ...)` or `NFTMinterV2.mintFor(...)`, hitting a *different* dispatcher.
- ERC1155 receiver callbacks on contract recipients can re-enter `NFTMinterV2.mint(...)` after the initiating mint's price has already been ratcheted but before the outer call completes.

`NFTMinterV2` itself has no `ReentrancyGuard`. The per-dispatcher lock and the in-place CEI ordering on `config.price` mean this is **not currently exploitable** for theft or double-ratchet abuse on the outer call (each nested mint must be self-funded by `safeTransferFrom` on the nested `msg.sender`). However, any invariant that should hold **across dispatchers within a single user transaction** has no enforcement boundary today. Future hooks (the explicit purpose of the V2 hook surface), future authorized-minter integrations, or rate-limit / cumulative-accounting checks added later will silently break.

This finding composes with the existing `mintFor` reentrancy concerns around authorized minters such as `NFTMigrator`: `mintFor` is reachable from ERC1155 receiver callbacks today, and a contract-level guard on `NFTMinterV2` is the natural boundary that closes both surfaces simultaneously.

**Recommendation**:

Inherit OpenZeppelin's `ReentrancyGuard` on `NFTMinterV2` and apply `nonReentrant` to both `mint()` overloads, `mintFor()`, and `burn()`. Cost is one SSTORE per call; the guard is complementary to (not redundant with) the per-dispatcher `nonReentrant`.

```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTMinterV2 is /* existing parents, */ ReentrancyGuard {
    function mint(uint256 index, address recipient) external nonReentrant returns (bool) {
        return _executeMint(index, recipient, "");
    }

    function mint(uint256 index, address recipient, bytes calldata extraData)
        external nonReentrant returns (bool)
    {
        return _executeMint(index, recipient, extraData);
    }

    function mintFor(uint256 index, address recipient) external nonReentrant {
        // ...
    }

    function burn(/* ... */) external nonReentrant {
        // ...
    }
}
```

---

### [L-02] `BalancerPoolerV2` never sweeps dispatcher-held USDS into sUSDS — orphaned USDS earns no DSR yield for NFT holders

**Location**: `src/V2/dispatchers/BalancerPoolerV2.sol#L111-L117` (`_dispatch`), `src/V2/dispatchers/BalancerPoolerV2.sol#L121-L127` (`pool`)

**Description**:

Story-025 makes USDS the mint currency and wraps to sUSDS in `_dispatch`. The wrap is sized by the per-mint `amount` argument — the FOT-adjusted `actualReceived` from `NFTMinterV2._executeMint` — rather than the dispatcher's full USDS balance:

```solidity
// BalancerPoolerV2.sol L111-L117
function _dispatch(address, uint256 amount, bytes calldata /*extraData*/)
    internal
    override
{
    IERC20(_primeToken).forceApprove(_sUSDS, amount);
    IERC4626(_sUSDS).deposit(amount, address(this));
}
```

`pool(minBPT)` later pools only the dispatcher's current sUSDS balance and never inspects USDS:

```solidity
// BalancerPoolerV2.sol L121-L127
function pool(uint256 minBPT) external onlyAuthorizedPooler whenNotPaused {
    uint256 sUSDSAmount = IERC20(_sUSDS).balanceOf(address(this));
    require(sUSDSAmount > 0, "BalancerPoolerV2: nothing to pool");
    // ...
}
```

As a result, any USDS that arrives on `BalancerPoolerV2` outside the exact `_executeMint -> dispatch(amount)` path is never wrapped and never reaches Balancer as BPT. Sources of orphaned USDS include:

1. Direct transfers (accidental or grief) sent to the dispatcher's public address once registered.
2. USDS left behind by a failed downstream integration.
3. Any future code path that lands USDS on this dispatcher without going through `NFTMinterV2`.

USDS itself is non-yield-bearing — only sUSDS accrues DSR. Every block of delay before a sweep is foregone yield to NFT holders. Recovery today requires owner `rescueERC20`, which routes value to a single owner-chosen address rather than back into the BPT that credits all NFT holders.

**Attack / occurrence path**:

1. Anyone transfers `X` USDS directly to the `BalancerPoolerV2` address (zero attacker cost; equally reachable by accident).
2. Subsequent mints call `_dispatch(minter, amount, ...)` with `amount` = only the new mint's FOT-adjusted USDS.
3. `IERC4626.deposit(amount, ...)` wraps only `amount`, leaving `X` USDS idle.
4. `pool(minBPT)` reads only the sUSDS balance; `X` USDS never reaches Balancer.
5. `X` USDS accrues 0 DSR yield until owner manually `rescueERC20`s it (and `rescueERC20` does not return value to NFT holders).

**Recommendation**:

In `_dispatch`, wrap the dispatcher's full USDS balance instead of only the `amount` argument:

```solidity
function _dispatch(address, uint256 /*amount*/, bytes calldata /*extraData*/)
    internal
    override
{
    uint256 toWrap = IERC20(_primeToken).balanceOf(address(this));
    if (toWrap == 0) return;
    IERC20(_primeToken).forceApprove(_sUSDS, toWrap);
    IERC4626(_sUSDS).deposit(toWrap, address(this));
}
```

This guarantees any stray USDS is swept into sUSDS on every mint. As an alternative or complement, add a permissionless `sweepUSDS()` entry point — no privileges are required because no value leaves the dispatcher:

```solidity
function sweepUSDS() external whenNotPaused {
    uint256 toWrap = IERC20(_primeToken).balanceOf(address(this));
    require(toWrap > 0, "BalancerPoolerV2: nothing to sweep");
    IERC20(_primeToken).forceApprove(_sUSDS, toWrap);
    IERC4626(_sUSDS).deposit(toWrap, address(this));
}
```

Either fix removes the orphaned-USDS surface entirely and aligns the wrap step with the existing balance-based `pool()` accounting.

---
