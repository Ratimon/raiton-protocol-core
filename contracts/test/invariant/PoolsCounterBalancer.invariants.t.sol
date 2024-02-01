// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2} from "@forge-std/Test.sol";
import {StdInvariant} from "@forge-std/StdInvariant.sol";

import {Core} from "@main/Core.sol";

import {CoreHarness} from "@test/harness/Core.harness.t.sol";

import {MixerHandler, ETH_SUPPLY} from "@test/invariant/handler/MixerHandler.sol";


contract PoolsCounterBalancerInvariants is StdInvariant, Test, CoreHarness {

    // Core public core;
    MixerHandler public handler;

    // todo: define invaraint that it wont excees threshold
    function setUp() public virtual override( CoreHarness ) {
        super.setUp();
        vm.label(address(this), "CorPoolsCounterBalancerInvariantseTest");

        handler = new MixerHandler(address(core));

        bytes4[] memory selectors = new bytes4[](1);

        selectors[0] = MixerHandler.deposit.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    // ETH can only be deposited into Core, WETH can only
    // be withdrawn back into recepient. The sum of the Handler's
    // ETH balance plus the Core balance state ( sum of each of account state ) should always
    // equal the total ETH_SUPPLY.
    function invariant_conservationOfETH() public {
        uint256 sumOfAccountState = handler.reduceAccounts(0, this.accumulateState);
        console2.log("ETH_SUPPLY", ETH_SUPPLY);
        console2.log("sumOfAccountState", sumOfAccountState);
        console2.log("handler", address(handler).balance);
        assertEq(ETH_SUPPLY, address(handler).balance + sumOfAccountState );
    }

    // 1) aggregator of all accounts balance ()
    // 2) aggregator of all accounts state ()

    //TODO
    // totalAccount Number x totalAccount Balance = total ETH_SUPPLY

    //TODO
    // The sum of individual Account balances should always be
    // at least as much as the sum of individual deposits
    //  function invariant_solvencyDeposits() public {
    // }

    // The sum of individual Account balances  should always be
    // at least as much as the sum of individual accounts state
    function invariant_solvencyBalances() public {
        uint256 sumOfAccountBalanceOf = handler.reduceAccounts(0, this.accumulateBalanceOf);
        uint256 sumOfAccountState = handler.reduceAccounts(0, this.accumulateState);
        assertEq(sumOfAccountBalanceOf , sumOfAccountState);
    }


    function accumulateBalanceOf(uint256 balance, address account) external view returns (uint256) {
        return balance + account.balance;
    }

    function accumulateState(uint256 balance, address account) external view returns (uint256) {
        return balance + core.getBalance(account) ;
    }

}

