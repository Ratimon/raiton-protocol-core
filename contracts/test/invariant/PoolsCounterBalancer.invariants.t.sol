// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test} from "@forge-std/Test.sol";
import {StdInvariant} from "@forge-std/StdInvariant.sol";

// import {BalanceAccountHarness} from "@test/harness/BalanceAccount.harness.t.sol";
import {CoreHarness} from "@test/harness/Core.harness.t.sol";

contract PoolsCounterBalancerInvariants is StdInvariant, Test, CoreHarness {

    // todo: define invaraint that it wont excees threshold
    function setUp() public virtual override( CoreHarness ) {
        super.setUp();
        vm.label(address(this), "CorPoolsCounterBalancerInvariantseTest");
    }



}

