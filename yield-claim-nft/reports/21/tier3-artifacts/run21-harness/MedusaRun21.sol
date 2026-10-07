// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// run-21 Medusa targets over the same engine-neutral Run21Core the Foundry suites drive.
// Medusa calls every public act_* mutator and evaluates property_* views (must return true).

import {Run21Core, Run21CoreReal} from "./Run21Core.sol";
import {Run21CoreM1} from "./Run21MutantCores.sol";

abstract contract Run21MedusaProps is Run21Core {
    function property_INV1_L25_noStrand() public view returns (bool) { return ok_inv1(); }
    function property_INV1b_repoAbsoluteDustBound() public view returns (bool) { return zapsAboveRepoAbsTol == 0; }
    function property_INV2_quoteExecuteConsistent() public view returns (bool) { return ok_inv2(); }
    function property_INV3_L21_hookGuard() public view returns (bool) { return ok_inv3(); }
    function property_INV4_lpNoLeak() public view returns (bool) { return ok_inv4(); }
}

contract MedusaRun21RealA is Run21CoreReal, Run21MedusaProps {
    constructor() Run21CoreReal(true, 1_000_000e18, 1_050_000e18) {}
}

contract MedusaRun21RealB is Run21CoreReal, Run21MedusaProps {
    constructor() Run21CoreReal(false, 20_000e18, 2_000e18) {}
}

/// Tripwire: Medusa must falsify INV1/INV2 on the no-sync mutant.
contract MedusaRun21MutM1 is Run21CoreM1, Run21MedusaProps {
    constructor() Run21CoreM1(true, 1_000_000e18, 1_050_000e18) {}
}
