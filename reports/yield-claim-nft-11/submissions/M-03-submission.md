<!--
ID: ycn11m3
C4 Submission Metadata
Title: [M-03] Decimal-scale mismatch in NudgeRatchetMintDebtHook.onDispatch under-mints phUSD mint-debt by ~1e12x (accrues only dust)
Severity: Medium
Root Cause Link: https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/hooks/NudgeRatchetMintDebtHook.sol#L114-L115
PoC File: M-03-poc.t.sol
Faithfulness Tag: F-02-035
Latent-Hazard: MANDATORY-RE-AUDIT-ON-FIX (over-correction past 1e12 flips to unbacked phUSD over-mint — DEDUP-001 / Law-1 territory)
-->

## Finding description and impact

### Summary

`NudgeRatchetMintDebtHook.onDispatch` computes the accrued phUSD mint-debt as `(amount * ratio) / 100`. This formula was copied verbatim from the 18-decimal USDS sibling `BalancerPoolerMintDebtHook`, but `NudgeRatchet` is deploy-guarded to a **6-decimal** USDC token (`NudgeRatchet.sol:38`), while phUSD is an **18-decimal** token. No `6 -> 18` decimal normalization (`* 1e12`) is applied, so the mint-debt is under-credited by exactly `1e12x` on every dispatch. At the default ratio the accrued `added` equals the raw 6-decimal USDC base units — economically negligible dust (a 5 USDC dispatch accrues `5e6` wei of phUSD = `5e-12` phUSD instead of `5e18`). For the smallest amounts (`amount * ratio < 100`) `added` rounds to literally zero and the `if (added == 0) return;` short-circuit accrues nothing at all. Either way the mint-debt accounting feature introduced by story-035 is rendered economically inert.

### Vulnerability details

`NudgeRatchet` enforces a 6-decimal token at deploy time ([NudgeRatchet.sol#L38](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/dispatchers/NudgeRatchet.sol#L38)):

```solidity
// Deploy-time USDC guard: batchMinter only accepts USDC (6-decimal) rewards.
require(IERC20Metadata(token_).decimals() == 6, "NudgeRatchet: token must be 6-decimal USDC");
```

The hook that accrues the phUSD mint-debt for that 6-decimal flow computes the debt without rescaling ([NudgeRatchetMintDebtHook.sol#L112-L118](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/hooks/NudgeRatchetMintDebtHook.sol#L112-L118)):

```solidity
function onDispatch(address minter, uint256 amount, bytes calldata) external {
    if (msg.sender != dispatcher) revert OnlyDispatcher();
    uint256 added = (amount * ratio) / 100;   // L114 — 6-dp `amount`, 18-dp debt, no *1e12
    if (added == 0) return;                    // L115 — silent no-op when debt rounds to 0
    mintDebt += added;
    emit DebtAccrued(minter, amount, added, mintDebt);
}
```

`amount` arrives in 6-decimal USDC base units. `mintDebt` is later realized 1:1 as 18-decimal phUSD wei in `pull()` (`phUSD.mint(recipient, debt)`, [NudgeRatchetMintDebtHook.sol#L128](https://github.com/Behodler/yield-claim-nft/blob/master/src/V2/hooks/NudgeRatchetMintDebtHook.sol#L128)). Because the 6-to-18 scale-up is never applied, the realized phUSD is `1e12x` smaller than intended:

- A dispatch of 5 USDC (`amount = 5_000_000`) at the default 100% ratio accrues `mintDebt = 5_000_000` and `pull()` mints `5_000_000` wei of phUSD = `0.000000000005` phUSD, instead of the intended `5e18` wei = 5 phUSD.
- Even a `$1,000,000` USDC dispatch (`amount = 1e12`) accrues only `1e12` wei of phUSD = `0.000001` phUSD.

For any realistic per-dispatch USDC amount, the under-scaled `added` is dust; combined with the `if (added == 0) return;` guard for the smallest amounts, the mint-debt feature does not perform its job.

This is also a story-faithfulness deviation (faithfulness tag **F-02-035**, cross-referenced in `spec-conformance.md`): story-035 directed a near-verbatim copy of the 18-decimal USDS hook onto a 6-decimal USDC dispatcher, so the intended "accrue phUSD mint-debt proportional to dispatched value" behaviour is not achieved.

### Impact

Total failure of the `NudgeRatchet` phUSD mint-debt / reward accounting: the configured `recipient` is under-credited by `~1e12x`, and for small amounts is credited nothing at all.

The direction of the error is an **under-mint**, which fails **safe** with respect to protocol solvency and phUSD backing: no unbacked phUSD is created, nothing is stolen, and no funds are drained. The harm is a broken accounting / value-tracking feature, not an asset-extraction path. It is therefore reported as **Medium** (protocol function impaired — the feature simply does not work), and explicitly **not** High. There is no theft or drain vector here, and this report does not claim one.

### Latent hazard on fix (mandatory re-audit)

The current bug fails safe precisely because it under-mints. **Any fix that over-corrects past the exact `1e12` factor flips the sign into an unbacked phUSD over-mint** — i.e. minting phUSD with no backing, which is Law-1 / solvency territory and the boundary tracked as the suppressed DEDUP-001 unbacked-phUSD concern. The fix must land at exactly `* 1e12` (USDC 6-dp -> phUSD 18-dp), or derive the factor dynamically as `10 ** (phUSDdecimals - tokenDecimals)`. The eventual fix MUST be re-audited to confirm the scale factor is exactly `1e12` and not larger, and that no unbacked phUSD can be minted.

## Recommended mitigation steps

Normalize the 6-decimal USDC `amount` up to 18 decimals before applying the ratio:

```solidity
// debt is denominated in 18-dp phUSD; amount is 6-dp USDC.
uint256 added = (amount * 1e12 * ratio) / 100;
```

Preferably, derive the scale factor from the token decimals at construction rather than hard-coding `1e12`, so the hook cannot be silently mis-scaled if reused against a token of different precision:

```solidity
uint256 scale = 10 ** (PHUSD_DECIMALS - tokenDecimals); // captured at deploy
uint256 added = (amount * scale * ratio) / 100;
```

Add a unit test asserting non-zero, correctly-scaled mint-debt for representative USDC amounts (e.g. 5 USDC -> `5e18` wei phUSD at 100% ratio).

Because correcting the scale moves the system from a safe under-mint to a state where over-correction would mint unbacked phUSD, the fix must be re-audited to confirm the factor is exactly `1e12` (or the dynamically-derived equivalent).

## Proof of Concept

The following Foundry test drives a real dispatch through `NudgeRatchet -> NudgeRatchetMintDebtHook` and proves the realized phUSD is exactly `1e12x` smaller than intended. It runs against the project's test suite (place the file under `test/` in the `yield-claim-nft` repo; it reuses the existing `MockMintable` mock and a local 6-decimal USDC mock that mirrors the one in `NudgeRatchetMintDebtHook.t.sol`).

Run:

```
forge test --match-path test/M-03-poc.t.sol -vvv
```

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NudgeRatchet} from "../src/V2/dispatchers/NudgeRatchet.sol";
import {NudgeRatchetMintDebtHook} from "../src/V2/hooks/NudgeRatchetMintDebtHook.sol";
import {IDispatchHook} from "../src/V2/interfaces/IDispatchHook.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockMintable} from "./mocks/MockMintable.sol";

/// @dev USDC-like 6-decimal mock (mirrors MockUSDC6 in NudgeRatchetMintDebtHook.t.sol).
contract MockUSDC6 is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title M-03 PoC: NudgeRatchetMintDebtHook decimal under-mint (1e12x shortfall)
/// @dev Vulnerable code:
///        src/V2/hooks/NudgeRatchetMintDebtHook.sol#L114-L115 (onDispatch: (amount*ratio)/100, no *1e12)
///        src/V2/dispatchers/NudgeRatchet.sol#L38 (constructor require decimals()==6)
contract M03PoCTest is Test {
    NudgeRatchet internal ratchet;
    NudgeRatchetMintDebtHook internal hook;
    MockUSDC6 internal usdc;
    MockMintable internal phUSD; // 18-decimal phUSD (mint records raw wei)

    address internal owner = address(this);
    address internal batchMinterAddr = address(0xCAFE);
    address internal dispatcherMinter = address(0xB0BB1E);
    address internal recipient = address(0xFEED);

    function setUp() public {
        usdc = new MockUSDC6();
        phUSD = new MockMintable();

        // 6-dp USDC passes the NudgeRatchet constructor require(decimals()==6) guard.
        ratchet = new NudgeRatchet(address(usdc), batchMinterAddr, owner);
        hook = new NudgeRatchetMintDebtHook(owner, address(ratchet), address(phUSD));

        // Wiring per story: setHook then setMinter; default ratio = 100 (100%).
        ratchet.setHook(IDispatchHook(address(hook)));
        ratchet.setMinter(dispatcherMinter);
        hook.setRecipient(recipient);

        assertEq(hook.ratio(), 100, "ratio default 100%");
    }

    /// @notice Dispatch 5 USDC and prove the realized phUSD is 1e12x too small.
    function test_M03_fiveUSDC_undermintsBy1e12() public {
        uint256 amount = 5_000_000; // 5 USDC in 6-decimal units (5e6 wei)

        // The economically intended phUSD debt for 5 USDC at 100% is 5 phUSD == 5e18 wei.
        uint256 intendedPhUSD = 5e18;

        usdc.mint(address(ratchet), amount);

        // Drive onDispatch through the real dispatch path (dispatcher == ratchet).
        vm.prank(dispatcherMinter);
        ratchet.dispatch(dispatcherMinter, amount, "");

        // USDC actually moved to the batchMinter sink.
        assertEq(usdc.balanceOf(batchMinterAddr), amount, "USDC forwarded to batchMinter");

        // Realize the accrued debt into phUSD.
        hook.pull();

        uint256 realizedPhUSD = phUSD.balanceOf(recipient);

        // BUG: realized phUSD == raw 6-dp amount (5e6 wei) == 0.000000000005 phUSD,
        // NOT the intended 5e18 wei == 5 phUSD.
        assertEq(realizedPhUSD, amount, "realized phUSD == raw 6-dp USDC wei (no 1e12 scale-up)");
        assertEq(realizedPhUSD, 5e6, "realized phUSD is 5e6 wei == 0.000000000005 phUSD");

        // The exact shortfall: intended is 1e12x larger than realized.
        assertEq(intendedPhUSD, realizedPhUSD * 1e12, "intended phUSD is exactly 1e12x the realized amount");
        assertLt(realizedPhUSD, intendedPhUSD, "realized is a tiny fraction of intended");

        emit log_named_uint("intended phUSD (wei)", intendedPhUSD); // 5000000000000000000
        emit log_named_uint("realized phUSD (wei)", realizedPhUSD); // 5000000
        emit log_named_uint("shortfall (wei)", intendedPhUSD - realizedPhUSD);
    }

    /// @notice Even a $1,000,000 USDC dispatch realizes only 1e12 wei phUSD = 0.000001 phUSD.
    function test_M03_oneMillionUSDC_yieldsDustPhUSD() public {
        uint256 amount = 1e12; // 1,000,000 USDC in 6-decimal units (1e6 * 1e6)
        uint256 intendedPhUSD = 1_000_000e18; // 1e24 wei

        usdc.mint(address(ratchet), amount);

        vm.prank(dispatcherMinter);
        ratchet.dispatch(dispatcherMinter, amount, "");

        hook.pull();

        uint256 realizedPhUSD = phUSD.balanceOf(recipient);

        // $1M of USDC mints only 1e12 wei phUSD == 0.000001 phUSD.
        assertEq(realizedPhUSD, 1e12, "realized phUSD is 1e12 wei == 0.000001 phUSD");
        assertEq(intendedPhUSD, realizedPhUSD * 1e12, "intended is exactly 1e12x realized");
    }
}
```
