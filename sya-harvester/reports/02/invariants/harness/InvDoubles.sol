// SPDX-License-Identifier: MIT
// AUDIT-AUTHORED (sya-harvester-01 invariant-generator). Not part of the upstream suite.
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SYAHarvester} from "../../../src/SYAHarvester.sol";

/// @notice OZ ERC20 with mint and configurable decimals. OZ (not solmate) so that an allowance
///         shortfall reverts with the named ERC20InsufficientAllowance error rather than Panic(0x11),
///         which would be indistinguishable from the harvester's own intended surplus underflow.
contract InvToken is ERC20 {
    uint8 private immutable _dec;

    constructor(string memory n, uint8 d) ERC20(n, n) {
        _dec = d;
    }

    function decimals() public view override returns (uint8) {
        return _dec;
    }

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

/// @notice Curve Router NG behavioural model.
/// @dev Mirrors Router NG `exchange` (0x16C6521D...): pull `_amount` of `_route[0]`, then for hop i
///      read pool `_route[2i+1]` and output token `_route[2i+2]`, and STOP after hop i when
///      `i == 4 || _route[2i+3] == address(0)`. The FINAL output is `_route[2i+2]` of the last hop
///      executed, NOT the last non-zero entry of the path. That first-empty-slot break is exactly the
///      semantics the upstream MockCurveRouter does not model (CODE-001 / CODE-007(2)).
///      A pool slot of address(0) reverts (Router NG would call into address(0)); an unknown pair
///      reverts; a hop that rounds to zero reverts "Received nothing" (dust behaviour, CODE-002).
contract RouterNGModel {
    /// pool => tokenIn => tokenOut => output units per 1e18 input units
    mapping(address => mapping(address => mapping(address => uint256))) public rate;

    function setRate(address pool, address tokenIn, address tokenOut, uint256 r) external {
        rate[pool][tokenIn][tokenOut] = r;
    }

    function exchange(
        address[11] calldata _route,
        uint256[5][5] calldata,
        uint256 _amount,
        uint256 _expected,
        address[5] calldata,
        address _receiver
    ) external payable returns (uint256 amount) {
        require(_receiver != address(0), "Receiver must be non-zero");
        address input = _route[0];
        address output;
        require(IERC20(input).transferFrom(msg.sender, address(this), _amount), "transferFrom");
        amount = _amount;
        for (uint256 i = 0; i < 5; i++) {
            address pool = _route[2 * i + 1];
            output = _route[2 * i + 2];
            require(pool != address(0), "RouterNG: call to empty pool");
            require(output != address(0), "RouterNG: empty output token");
            uint256 r = rate[pool][input][output];
            require(r != 0, "RouterNG: pool cannot swap pair");
            amount = amount * r / 1e18;
            require(amount > 0, "Received nothing");
            if (i == 4 || _route[2 * i + 3] == address(0)) break;
            input = output;
        }
        require(amount >= _expected, "Slippage");
        require(IERC20(output).transfer(_receiver, amount), "transfer");
    }

    /// @notice Token Router NG would deliver for `_route` (address(0) if the route cannot execute)
    function resolveOutput(address[11] memory _route) public pure returns (address output) {
        for (uint256 i = 0; i < 5; i++) {
            if (_route[2 * i + 1] == address(0)) return address(0);
            output = _route[2 * i + 2];
            if (output == address(0)) return address(0);
            if (i == 4 || _route[2 * i + 3] == address(0)) break;
        }
    }
}

/// @notice Yield strategy double whose REPORTED surplus (what SYA.calculateClaimAmount sees) can differ
///         from the amount DELIVERED by skimSurplus (what SYA charges on). Upstream MockYieldStrategy
///         delivers exactly `surplus`, so estimate == delivered by construction (CODE-007(3)).
contract InvStrategy {
    address public immutable token;
    uint256 public surplus; // reported
    uint256 public deliverBps = 10000; // delivered = surplus * deliverBps / 10000

    constructor(address _token) {
        token = _token;
    }

    function set(uint256 _surplus, uint256 _deliverBps) external {
        surplus = _surplus;
        deliverBps = _deliverBps;
        uint256 need = pendingDelivery();
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal < need) InvToken(token).mint(address(this), need - bal);
    }

    function pendingDelivery() public view returns (uint256) {
        return surplus * deliverBps / 10000;
    }

    function skimSurplus(address _token, address recipient) external returns (uint256 amount) {
        require(_token == token, "WrongToken");
        amount = pendingDelivery();
        surplus = 0;
        if (amount > 0) IERC20(token).transfer(recipient, amount);
    }
}

/// @notice Harvest caller. A contract (not a prank) so that the same harness runs unchanged under Medusa.
contract InvActor is ERC1155Holder {
    function approveNft(address nft, address op) external {
        IERC1155(nft).setApprovalForAll(op, true);
    }

    function doHarvest(SYAHarvester h, address[] calldata ex, uint256 idx, uint256 minOut)
        external
        returns (bool ok, bytes memory ret, uint256 out)
    {
        try h.harvest(ex, idx, minOut) returns (uint256 o) {
            return (true, "", o);
        } catch (bytes memory r) {
            return (false, r, 0);
        }
    }

    receive() external payable {}
}

/// @notice Forces ETH into the harvester (bypasses its receive() guard) via SELFDESTRUCT in the creation tx.
contract ForceSend {
    constructor(address payable to) payable {
        selfdestruct(to);
    }
}
