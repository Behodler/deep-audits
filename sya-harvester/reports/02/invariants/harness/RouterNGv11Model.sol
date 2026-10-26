// SPDX-License-Identifier: MIT
// AUDIT-AUTHORED (sya-harvester-02 invariant-generator). Not part of the upstream suite.
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Interfaces exactly as Router NG v1.1 declares them (reports/02/profiles/evidence/RouterNG-v1.1-0x16C6.vy).
/// Every call below is a high-level call without return data, so Solidity performs the same extcodesize
/// check Vyper's `extcall` performs (a codeless "pool" reverts, exactly like the deployed router).
interface IStablePool {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable;
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable;
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external;
}

interface ICryptoPool {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable;
    function exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable;
    function remove_liquidity_one_coin(uint256 token_amount, uint256 i, uint256 min_amount) external;
}

interface ICryptoPoolETH {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy, bool use_eth) external payable;
}

interface ILendingBasePoolMetaZap {
    function exchange_underlying(address pool, int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface ICryptoMetaZap {
    function exchange(address pool, uint256 i, uint256 j, uint256 dx, uint256 min_dy, bool use_eth) external payable;
}

interface IStableNgPool {
    function add_liquidity(uint256[] memory _amounts, uint256 _min_mint_amount) external returns (uint256);
}

interface IPool2 {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external payable;
}

interface IPool3 {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external payable;
}

interface IPool4 {
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) external payable;
}

interface IPool5 {
    function add_liquidity(uint256[5] memory amounts, uint256 min_mint_amount) external payable;
}

interface ITriCryptoNgETH {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount, bool use_eth) external payable;
    function remove_liquidity_one_coin(uint256 token_amount, uint256 i, uint256 min_amount, bool use_eth) external;
}

interface ILendingStablePool3Coins {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount, bool use_underlying) external payable;
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount, bool use_underlying)
        external;
}

/// @notice Curve Router NG v1.1 (`0x16C6521Dff6baB339122a0FE25a9116693265353`) `exchange`, transcribed line by
///         line from the verified Vyper source. Differences from the upstream MockCurveRouter that matter here:
///         - hop i is ALWAYS executed for i = 0 and the loop stops after hop i iff `i == 4 || route[2i+3] == 0`
///           (first-empty-pool-slot break): the delivered token is `route[2k]` of the last executed hop;
///         - swap dispatch on `swap_params[i][2]` in 1..8, otherwise `raise "Bad swap type"` (v1.1 has no 9);
///         - the per-hop amount is the router's WHOLE balance of the output token, and the hop asserts
///           `balance_after - balance_before != 0` ("Received nothing", Vyper checked subtraction);
///         - `amount -= 1` before the final transfer; `__default__` is payable and accepts any calldata;
///         - approvals are `skip_contract_check` + `default_return_value` (a codeless approve "succeeds").
///         Pool behaviour is NOT modelled here: pools are separate contracts (CurvePoolModel) and any pool
///         function a pool does not implement reverts, as it would on-chain.
contract RouterNGv11Model {
    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant STETH_ADDRESS = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant WSTETH_ADDRESS = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant FRXETH_ADDRESS = 0x5E8422345238F34275888049021821E8E08CAa1f;
    address public constant SFRXETH_ADDRESS = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public constant WBETH_ADDRESS = 0xa2E3356610840701BDf5611a53974510Ae27E2e1;
    address public constant USDE_ADDRESS = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address public constant SUSDE_ADDRESS = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    mapping(address => mapping(address => bool)) public is_approved;
    bool private locked;

    /// Vyper `__default__`: payable, accepts any calldata, does nothing.
    fallback() external payable {}

    receive() external payable {}

    function exchange(
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy,
        address[5] calldata _pools,
        address _receiver
    ) external payable returns (uint256) {
        require(!locked, "nonreentrant");
        locked = true;
        address input_token = _route[0];
        address output_token;
        uint256 amount = _amount;

        if (input_token == ETH_ADDRESS) {
            require(msg.value == amount);
        } else {
            require(msg.value == 0);
            require(input_token.code.length > 0); // Vyper extcall extcodesize check
            _defaultTrue(input_token, abi.encodeCall(IERC20.transferFrom, (msg.sender, address(this), amount)));
        }

        address[11] memory route = _route;
        for (uint256 i = 0; i < 5; i++) {
            output_token = route[(i + 1) * 2];
            amount = _hop(route[i * 2 + 1], _pools[i], _swap_params[i], input_token, output_token, amount);
            if (i == 4 || route[i * 2 + 3] == address(0)) break;
            // if there is another swap, the output token becomes the input for the next round
            input_token = output_token;
        }

        amount -= 1;
        require(amount >= _min_dy, "Slippage");

        if (output_token == ETH_ADDRESS) {
            (bool s,) = _receiver.call{value: amount}("");
            s; // Vyper raw_call without revert_on_failure=False reverts on failure
            require(s);
        } else {
            require(output_token.code.length > 0);
            _defaultTrue(output_token, abi.encodeCall(IERC20.transfer, (_receiver, amount)));
        }
        locked = false;
        return amount;
    }

    function _hop(
        address swap,
        address pool,
        uint256[5] memory params,
        address input_token,
        address output_token,
        uint256 amount
    ) internal returns (uint256) {
        uint256 initial = _bal(output_token);
        if (!is_approved[input_token][swap]) {
            // skip_contract_check=True, default_return_value=True
            (bool ok, bytes memory ret) = input_token.call(abi.encodeCall(IERC20.approve, (swap, type(uint256).max)));
            require(ok && (ret.length == 0 || abi.decode(ret, (bool))));
            is_approved[input_token][swap] = true;
        }
        uint256 eth_amount = input_token == ETH_ADDRESS ? amount : 0;
        _dispatch(swap, pool, params, input_token, output_token, amount, eth_amount);
        uint256 after_ = _bal(output_token);
        // Vyper: assert amount - output_token_initial_balance != 0, "Received nothing" (checked sub)
        require(after_ - initial != 0, "Received nothing");
        return after_;
    }

    function _dispatch(
        address swap,
        address pool,
        uint256[5] memory params,
        address input_token,
        address output_token,
        uint256 amount,
        uint256 eth_amount
    ) internal {
        uint256 st = params[2];
        if (st == 1) {
            if (params[3] == 1 || params[3] == 10) {
                IStablePool(swap).exchange{value: eth_amount}(_i128(params[0]), _i128(params[1]), amount, 0);
            } else if (input_token == ETH_ADDRESS || output_token == ETH_ADDRESS) {
                ICryptoPoolETH(swap).exchange{value: eth_amount}(params[0], params[1], amount, 0, true);
            } else {
                ICryptoPool(swap).exchange(params[0], params[1], amount, 0);
            }
        } else if (st == 2) {
            if (params[3] == 1 || params[3] == 10) {
                IStablePool(swap).exchange_underlying{value: eth_amount}(_i128(params[0]), _i128(params[1]), amount, 0);
            } else {
                ICryptoPool(swap).exchange_underlying{value: eth_amount}(params[0], params[1], amount, 0);
            }
        } else if (st == 3) {
            if (params[3] == 1 || params[3] == 10) {
                ILendingBasePoolMetaZap(swap).exchange_underlying(pool, _i128(params[0]), _i128(params[1]), amount, 0);
            } else {
                bool use_eth = input_token == ETH_ADDRESS || output_token == ETH_ADDRESS;
                ICryptoMetaZap(swap).exchange{value: eth_amount}(pool, params[0], params[1], amount, 0, use_eth);
            }
        } else if (st == 4) {
            _addLiquidity(swap, params, amount, eth_amount);
        } else if (st == 5) {
            uint256[3] memory a3;
            a3[params[0]] = amount;
            ILendingStablePool3Coins(swap).add_liquidity{value: eth_amount}(a3, 0, true);
        } else if (st == 6) {
            if (params[3] == 1 || params[3] == 10) {
                IStablePool(swap).remove_liquidity_one_coin(amount, _i128(params[1]), 0);
            } else if (params[3] == 30 && output_token == ETH_ADDRESS) {
                ITriCryptoNgETH(swap).remove_liquidity_one_coin(amount, params[1], 0, true);
            } else {
                ICryptoPool(swap).remove_liquidity_one_coin(amount, params[1], 0);
            }
        } else if (st == 7) {
            ILendingStablePool3Coins(swap).remove_liquidity_one_coin(amount, _i128(params[1]), 0, true);
        } else if (st == 8) {
            bool known = (input_token == ETH_ADDRESS && output_token == WETH_ADDRESS)
                || (input_token == WETH_ADDRESS && output_token == ETH_ADDRESS)
                || (input_token == ETH_ADDRESS && output_token == STETH_ADDRESS)
                || (input_token == ETH_ADDRESS && output_token == FRXETH_ADDRESS)
                || (input_token == STETH_ADDRESS && output_token == WSTETH_ADDRESS)
                || (input_token == WSTETH_ADDRESS && output_token == STETH_ADDRESS)
                || (input_token == FRXETH_ADDRESS && output_token == SFRXETH_ADDRESS)
                || (input_token == SFRXETH_ADDRESS && output_token == FRXETH_ADDRESS)
                || (input_token == ETH_ADDRESS && output_token == WBETH_ADDRESS)
                || (input_token == USDE_ADDRESS && output_token == SUSDE_ADDRESS);
            // None of these mainnet addresses exist in the harness alphabet; a match would call into a
            // codeless address and revert anyway.
            if (!known) {
                revert(
                    "Swap type 8 is only for ETH <-> WETH, ETH -> stETH or ETH -> frxETH, stETH <-> wstETH, frxETH <-> sfrxETH, ETH -> wBETH, USDe -> sUSDe"
                );
            }
            revert("model: swap type 8 target not deployed");
        } else {
            revert("Bad swap type");
        }
    }

    function _addLiquidity(address swap, uint256[5] memory params, uint256 amount, uint256 eth_amount) internal {
        if (params[3] == 10) {
            uint256[] memory a = new uint256[](8);
            a[params[0]] = amount; // DynArray[uint256, 8] index (OOB reverts)
            IStableNgPool(swap).add_liquidity(a, 0);
        } else if (params[3] == 30) {
            uint256[3] memory a3;
            a3[params[0]] = amount;
            if (eth_amount > 0) ITriCryptoNgETH(swap).add_liquidity{value: eth_amount}(a3, 0, true);
            else IPool3(swap).add_liquidity(a3, 0);
        } else if (params[4] == 2) {
            uint256[2] memory a2;
            a2[params[0]] = amount;
            IPool2(swap).add_liquidity{value: eth_amount}(a2, 0);
        } else if (params[4] == 3) {
            uint256[3] memory a3;
            a3[params[0]] = amount;
            IPool3(swap).add_liquidity{value: eth_amount}(a3, 0);
        } else if (params[4] == 4) {
            uint256[4] memory a4;
            a4[params[0]] = amount;
            IPool4(swap).add_liquidity{value: eth_amount}(a4, 0);
        } else if (params[4] == 5) {
            uint256[5] memory a5;
            a5[params[0]] = amount;
            IPool5(swap).add_liquidity{value: eth_amount}(a5, 0);
        }
        // else: Vyper falls through with NO call; the "Received nothing" assert then reverts.
    }

    function _bal(address t) internal view returns (uint256) {
        if (t == ETH_ADDRESS) return address(this).balance;
        return IERC20(t).balanceOf(address(this)); // codeless t: empty returndata -> decode revert
    }

    function _i128(uint256 x) internal pure returns (int128) {
        require(x <= uint256(uint128(type(int128).max)), "convert");
        return int128(int256(x));
    }

    function _defaultTrue(address t, bytes memory data) internal {
        (bool ok, bytes memory ret) = t.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        require(ret.length == 0 || abi.decode(ret, (bool)));
    }
}

/// @notice Minimal Curve pool: `exchange` (stable int128 and crypto uint256 variants) and, if enabled,
///         `exchange_underlying` over the SAME coins. Output = dx scaled by decimals x (1 - 4 bps). No
///         add/remove liquidity, no zap, no ETH variant: those Router NG dispatches revert (function absent).
///         The pool sends coins[j] -- which need NOT equal the route's declared output token; Router NG's
///         balance-delta check is what catches a mismatch.
contract CurvePoolModel {
    address[] public coins;
    uint8[] internal dec;
    bool public immutable hasUnderlying;
    uint256 public feeBps = 4;

    constructor(address[] memory _coins, uint8[] memory _dec, bool _underlying) {
        coins = _coins;
        dec = _dec;
        hasUnderlying = _underlying;
    }

    function nCoins() external view returns (uint256) {
        return coins.length;
    }

    function coinIndex(address t) external view returns (bool found, uint256 idx) {
        for (uint256 i = 0; i < coins.length; i++) {
            if (coins[i] == t) return (true, i);
        }
    }

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable {
        require(i >= 0 && j >= 0);
        _swap(uint256(int256(i)), uint256(int256(j)), dx, min_dy);
    }

    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable {
        _swap(i, j, dx, min_dy);
    }

    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable {
        require(hasUnderlying && i >= 0 && j >= 0);
        _swap(uint256(int256(i)), uint256(int256(j)), dx, min_dy);
    }

    function exchange_underlying(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable {
        require(hasUnderlying);
        _swap(i, j, dx, min_dy);
    }

    function _swap(uint256 i, uint256 j, uint256 dx, uint256 min_dy) internal {
        require(msg.value == 0, "no eth");
        require(i < coins.length && j < coins.length && i != j, "bad index");
        require(IERC20(coins[i]).transferFrom(msg.sender, address(this), dx));
        uint256 dy = dx * (10 ** dec[j]) / (10 ** dec[i]) * (10000 - feeBps) / 10000;
        require(dy >= min_dy, "slippage");
        require(IERC20(coins[j]).transfer(msg.sender, dy));
    }
}
