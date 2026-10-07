// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// run-21 tripwire cores: identical harness, pooler swapped for a single-edit mutant (gen-mutants.sh).
import {Run21Core} from "./Run21Core.sol";
import {UniPoolerV2_M1_NoSync} from "./mutants/UniPoolerV2_M1_NoSync.sol";
import {UniPoolerV2_M2_QuoteReserves} from "./mutants/UniPoolerV2_M2_QuoteReserves.sol";
import {UniPoolerV2_M3_NoHookGuard} from "./mutants/UniPoolerV2_M3_NoHookGuard.sol";
import {UniPoolerV2_M4_OpenRescue} from "./mutants/UniPoolerV2_M4_OpenRescue.sol";

contract Run21CoreM1 is Run21Core {
    constructor(bool f, uint256 a, uint256 b) Run21Core(f, a, b) {}
    function _newPooler(address s, address p, address r, address pr) internal override returns (address) {
        return address(new UniPoolerV2_M1_NoSync(s, p, r, pr, address(this)));
    }
}

contract Run21CoreM2 is Run21Core {
    constructor(bool f, uint256 a, uint256 b) Run21Core(f, a, b) {}
    function _newPooler(address s, address p, address r, address pr) internal override returns (address) {
        return address(new UniPoolerV2_M2_QuoteReserves(s, p, r, pr, address(this)));
    }
}

contract Run21CoreM3 is Run21Core {
    constructor(bool f, uint256 a, uint256 b) Run21Core(f, a, b) {}
    function _newPooler(address s, address p, address r, address pr) internal override returns (address) {
        return address(new UniPoolerV2_M3_NoHookGuard(s, p, r, pr, address(this)));
    }
}

contract Run21CoreM4 is Run21Core {
    constructor(bool f, uint256 a, uint256 b) Run21Core(f, a, b) {}
    function _newPooler(address s, address p, address r, address pr) internal override returns (address) {
        return address(new UniPoolerV2_M4_OpenRescue(s, p, r, pr, address(this)));
    }
}
