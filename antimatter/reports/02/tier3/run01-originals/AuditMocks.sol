// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev Audit-authored yield strategy for the Tier-3 invariant harness.
///
///      Deliberately NOT a never-failing stub. It carries real guarded state and will revert:
///        - if the caller is not an authorised client (AYieldStrategy.onlyAuthorizedClient),
///        - if the strategy is paused,
///        - on a zero-amount deposit,
///        - if the token it actually received differs from the amount it was told to take
///          (fee-on-transfer / rebase tripwire).
///      It also books principal per (token, recipient), which the harness reads back as the
///      *collateral* side of the backing invariant. If this contract silently accepted
///      everything, the backing invariant would degenerate into 0 == 0.
contract GuardedYieldStrategy {
    using SafeERC20 for IERC20;

    error NotAuthorizedClient(address caller);
    error StrategyPaused();
    error ZeroDeposit();
    error ShortReceipt(uint256 expected, uint256 actual);

    mapping(address => bool) public authorizedClients;
    mapping(address => mapping(address => uint256)) public principal; // token => recipient => amount
    mapping(address => uint256) public totalPrincipal; // token => amount
    uint256 public depositCount;
    bool public paused;

    function setClient(address client, bool ok) external {
        authorizedClients[client] = ok;
    }

    function setPaused(bool p) external {
        paused = p;
    }

    function deposit(address token, uint256 amount, address recipient) external {
        if (!authorizedClients[msg.sender]) revert NotAuthorizedClient(msg.sender);
        if (paused) revert StrategyPaused();
        if (amount == 0) revert ZeroDeposit();

        uint256 before = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - before;
        if (received != amount) revert ShortReceipt(amount, received);

        principal[token][recipient] += amount;
        totalPrincipal[token] += amount;
        depositCount += 1;
    }
}
