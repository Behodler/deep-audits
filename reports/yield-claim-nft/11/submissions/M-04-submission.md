<!--
ID: ycn11m4
C4 Submission Metadata
Title: [M-04] Unwired-dispatch zero-debt value leak: default empty hook accrues no phUSD debt if owner forgets setHook (Law-3 footgun)
Severity: Medium
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/ATokenDispatcherV2.sol#L51
PoC File: M-04-poc.t.sol
Classification: operational hazard / non-obvious owner footgun (in scope per three-law hierarchy)
-->

## Finding description and impact

### Summary

`ATokenDispatcherV2`'s constructor defaults `hook = new DefaultDispatchHook()`, an empty no-op hook. `NudgeRatchet` inherits this dispatch path. The `NudgeRatchetMintDebtHook` that accrues phUSD mint-debt is only consulted once an owner calls `dispatcher.setHook(nudgeHook)`. If the owner deploys `NudgeRatchet` + `NudgeRatchetMintDebtHook` but omits that `setHook` wiring step, every dispatch still forwards USDC to the `batchMinter` while accruing **zero** phUSD mint-debt — with no revert, no event, and no backfill path to recover the un-accrued debt.

### Vulnerability details

The dispatcher base seeds a null-object hook at construction ([ATokenDispatcherV2.sol#L50-L52](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/ATokenDispatcherV2.sol#L50-L52)):

```solidity
constructor(address initialOwner) Ownable(initialOwner) {
    hook = new DefaultDispatchHook();   // L51 — empty no-op default
}
```

`DefaultDispatchHook.onDispatch` does nothing ([DefaultDispatchHook.sol#L12](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/hooks/DefaultDispatchHook.sol#L12)):

```solidity
function onDispatch(address, uint256, bytes calldata) external {}
```

The non-virtual `dispatch` entry point always forwards the USDC via `_dispatch` and then calls `hook.onDispatch(...)` unconditionally ([ATokenDispatcherV2.sol#L118-L126](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/ATokenDispatcherV2.sol#L118-L126)), where `NudgeRatchet._dispatch` performs the actual USDC transfer to the sink ([NudgeRatchet.sol#L59-L61](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/NudgeRatchet.sol#L59-L61)):

```solidity
function _dispatch(address, uint256 amount, bytes calldata) internal override {
    IERC20(_token).safeTransfer(batchMinter, amount);   // L60 — USDC leaves the system
}
```

If `setHook(nudgeHook)` was never called, `hook` is still the default `DefaultDispatchHook`. A full mint/dispatch therefore succeeds — USDC ships to `batchMinter` — but `NudgeRatchetMintDebtHook.onDispatch` is never invoked, so `mintDebt()` stays `0`. USDC leaves with no corresponding phUSD debt recorded, there is no revert and no event signalling the miss, and there is no retroactive backfill path to accrue the missed debt for amounts already dispatched.

This is a **non-obvious owner footgun**, in scope per the three-law hierarchy (Law-3): a competent, non-malicious owner would be surprised that dispatches silently succeed with zero debt accrual when the dedicated mint-debt hook is deployed but not wired. The strongest evidence that the consequence is hidden is that the project's **own integration test** `NudgeRatchet.t.sol:160-182` exercises this exact path **without** calling `setHook` and passes silently, asserting only the USDC flow. The unwired zero-debt path is undetectable from the existing suite. The condition also breaks story-035's intended invariant that USDC dispatched out is matched by phUSD mint-debt accrued in.

### Impact

A value leak / protocol-function loss bounded by operator configuration: under the stated condition (mint-debt hook deployed but not wired via `setHook`), USDC is forwarded to the `batchMinter` while the corresponding phUSD mint-debt is never recorded, with no on-chain signal and no retroactive backfill for amounts already dispatched.

The direction fails **safe** with respect to phUSD solvency — no unbacked phUSD is minted — but the protocol's intended debt accounting is silently skipped for the entire unwired window. Because the precondition is an operator misconfiguration and the situation is recoverable going forward by wiring the hook, this is **Medium** (a value-leak operational hazard with an external configuration requirement), not High. There is no direct theft or drain.

## Recommended mitigation steps

Make an unwired dispatch fail loud and/or self-document rather than silently accruing no debt:

- For debt-bearing dispatchers, revert on dispatch while the hook is the default sentinel — e.g. guard `_dispatch`/`dispatch` against the `DefaultDispatchHook` sentinel, or require an explicitly-wired non-default hook before dispatches are permitted:

```solidity
// reject the default no-op hook for a debt-bearing dispatcher
require(address(hook) != address(_defaultHookSentinel), "NudgeRatchet: mint-debt hook not wired");
```

- Fix the silently-passing integration test `NudgeRatchet.t.sol:160-182` to call `setHook(nudgeHook)` and assert that phUSD mint-debt is accrued, so the unwired path can no longer pass the suite undetected.

### Safe-config guidance

Operationally, always call `dispatcher.setHook(nudgeHook)` immediately after deploying `NudgeRatchet` + `NudgeRatchetMintDebtHook`, and verify debt accrual (e.g. dispatch a probe amount and confirm `mintDebt() > 0`) before opening dispatches to users. The code-level guard above is preferred because it removes the operator's ability to leave the path silently unwired.

## Proof of Concept

The following Foundry test mirrors the project's own integration wiring (`NudgeRatchet.t.sol:160-182`) but deliberately omits `setHook`. It performs a full NFT mint and proves USDC ships to the `batchMinter` while `nudgeHook.mintDebt()` stays `0`. Place the file under `test/` in the `yield-claim-nft` repo; it reuses the existing `MockMintable` mock.

Run:

```
forge test --match-path test/M-04-poc.t.sol -vvv
```

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NudgeRatchet} from "../src/V2/dispatchers/NudgeRatchet.sol";
import {NudgeRatchetMintDebtHook} from "../src/V2/hooks/NudgeRatchetMintDebtHook.sol";
import {NFTMinterV2} from "../src/V2/NFTMinterV2.sol";
import {IDispatchHook} from "../src/V2/interfaces/IDispatchHook.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockMintable} from "./mocks/MockMintable.sol";

/// @dev USDC-like 6-decimal mock (mirrors MockUSDC in NudgeRatchet.t.sol).
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title M-04 PoC: unwired NudgeRatchetMintDebtHook leaks USDC with zero phUSD debt
/// @dev Mirrors the project's own integration test NudgeRatchet.t.sol:160-182, which
///      itself omits setHook. Vulnerable wiring:
///        src/V2/dispatchers/ATokenDispatcherV2.sol#L51 (default hook) + #L94 (setHook is the only wire-in)
contract M04PoCTest is Test {
    NudgeRatchet internal ratchet;
    NudgeRatchetMintDebtHook internal nudgeHook;
    NFTMinterV2 internal nftMinter;
    MockUSDC internal usdc;
    MockMintable internal phUSD;

    address internal owner = address(this);
    address internal batchMinterAddr = address(0xCAFE);

    function setUp() public {
        usdc = new MockUSDC();
        phUSD = new MockMintable();

        // Deploy NudgeRatchet (default DefaultDispatchHook is auto-seeded).
        ratchet = new NudgeRatchet(address(usdc), batchMinterAddr, owner);

        // Deploy the mint-debt hook pointed at the ratchet...
        nudgeHook = new NudgeRatchetMintDebtHook(owner, address(ratchet), address(phUSD));
        nudgeHook.setRecipient(address(0xFEED));

        // ...but DELIBERATELY DO NOT call ratchet.setHook(nudgeHook).
        // The ratchet keeps its default no-op DefaultDispatchHook.

        // Register the dispatcher on the NFT minter + set minter (mirrors
        // NudgeRatchet.t.sol:160-182 integration wiring).
        nftMinter = new NFTMinterV2(owner);
        uint256 initialPrice = 10e6; // 10 USDC per NFT
        nftMinter.registerDispatcher(address(ratchet), initialPrice, 0);
        ratchet.setMinter(address(nftMinter));
    }

    /// @notice A full NFT mint ships USDC to the batchMinter but records zero phUSD debt.
    function test_M04_unwiredHook_shipsUSDCWithZeroDebt() public {
        address user = address(0xBEEF);
        address nftRecipient = address(0xFACE);

        usdc.mint(user, 100e6);
        vm.prank(user);
        usdc.approve(address(nftMinter), type(uint256).max);

        uint256 batchBefore = usdc.balanceOf(batchMinterAddr);
        uint256 debtBefore = nudgeHook.mintDebt();
        assertEq(debtBefore, 0, "no debt before");

        vm.prank(user);
        bool success = nftMinter.mint(1, nftRecipient);
        assertTrue(success, "mint should succeed even with the hook unwired");

        uint256 dispatched = 10e6; // 1 NFT * 10 USDC price

        // USDC actually shipped to the batchMinter sink.
        assertEq(
            usdc.balanceOf(batchMinterAddr) - batchBefore,
            dispatched,
            "batchMinter received the dispatched USDC"
        );
        assertEq(usdc.balanceOf(address(ratchet)), 0, "ratchet holds no USDC");
        assertEq(nftMinter.balanceOf(nftRecipient, 1), 1, "NFT was minted to recipient");

        // BUG: the NudgeRatchetMintDebtHook never saw onDispatch -> zero phUSD debt.
        assertEq(nudgeHook.mintDebt(), 0, "mint-debt hook accrued ZERO debt despite USDC shipping");

        // Make the leak explicit: USDC > 0 left the system, debt == 0.
        assertGt(usdc.balanceOf(batchMinterAddr) - batchBefore, 0, "USDC left the system");
        emit log_named_uint("USDC dispatched to batchMinter", dispatched);
        emit log_named_uint("phUSD debt recorded by hook", nudgeHook.mintDebt());
    }
}
```
