// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2} from "@forge-std/Test.sol";
import {StdInvariant} from "@forge-std/StdInvariant.sol";

import {Core} from "@main/Core.sol";

// import {BalanceAccountHarness} from "@test/harness/BalanceAccount.harness.t.sol";
import {CoreHarness} from "@test/harness/Core.harness.t.sol";

import {MixerHandler, ETH_SUPPLY} from "@test/invariant/handler/MixerHandler.sol";


contract PoolsCounterBalancerInvariants is StdInvariant, Test, CoreHarness {

    // Core public core;
    MixerHandler public handler;

    // todo: define invaraint that it wont excees threshold
    function setUp() public virtual override( CoreHarness ) {
        super.setUp();
        vm.label(address(this), "CorPoolsCounterBalancerInvariantseTest");

        console2.log("core",address(core));

        handler = new MixerHandler(address(core));

        bytes4[] memory selectors = new bytes4[](1);

        selectors[0] = MixerHandler.deposit.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    // ETH can only be deposited into Core, WETH can only
    // be withdrawn back into recepient. The sum of the Handler's
    // ETH balance plus the Core balance  state should always
    // equal the total ETH_SUPPLY.
    function invariant_conservationOfETH() public {
        assertEq(ETH_SUPPLY, address(handler).balance );
    }


     // totalAccount Number x totalAccount Balance = total ETH_SUPPLY

    //  function invariant_csolvencyDeposits() public {
    // }


}

