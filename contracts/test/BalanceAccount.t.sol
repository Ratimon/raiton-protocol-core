//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {Groth16Verifier as DepositGroth16Verifier} from "@main/verifiers/DepositVerifier.sol";

import {BalanceAccountHarness} from "@test/BalanceAccount.harness.t.sol";
import {CoreHarness} from "@test/Core.harness.t.sol";

contract BalanceAccountTest is BalanceAccountHarness, CoreHarness {
    function setUp() public virtual override(BalanceAccountHarness, CoreHarness ) {
        super.setUp();
        vm.label(address(this), "BalanceAccountTest");
    }

    function test_new_BalanceAccount() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        uint256 inflow = 4;
        uint256 outflow = 1;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, commitment);

        assertAccount(
            alice, deployReturns[0].account, commitment, denomination, deployReturns[0].nonce, inflow, outflow
        );
        assertAccount(bob, deployReturns[1].account, commitment, denomination, deployReturns[1].nonce, inflow, outflow);
        assertAccount(
            carol, deployReturns[2].account, commitment, denomination, deployReturns[2].nonce, inflow, outflow
        );
        assertAccount(dave, deployReturns[3].account, commitment, denomination, deployReturns[3].nonce, inflow, outflow);

        vm.stopPrank();
    }

    function test_commitNew_2ndPhase() external {
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        startHoax(alice, committedAmount);

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        BalanceAccount balanceAccount = BalanceAccount(accounts[0]);

        assertEq(address(balanceAccount).balance, 0 ether);
        assertEq(uint256(balanceAccount.currentStatus()), uint256(BalanceAccount.Status.UNCOMMITTED));
        assertEq(balanceAccount.currentBalance(), 0 ether);

        balanceAccount.commitNew_2ndPhase{value: committedAmount}();

        assertEq(address(balanceAccount).balance, committedAmount);
        assertEq(uint256(balanceAccount.currentStatus()), uint256(BalanceAccount.Status.COMMITTED));
        assertEq(balanceAccount.currentBalance(), committedAmount);

        vm.stopPrank();
    }

    function test_clear_commitment() external {
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        startHoax(alice, committedAmount);

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        BalanceAccount balanceAccount = BalanceAccount(accounts[0]);
        balanceAccount.commitNew_2ndPhase{value: committedAmount}();

        assertEq(address(balanceAccount).balance, committedAmount);
        assertEq(alice.balance, 0 ether);
        assertEq(uint256(balanceAccount.currentStatus()), uint256(BalanceAccount.Status.COMMITTED));
        assertEq(balanceAccount.currentBalance(), committedAmount);

        balanceAccount.clear_commitment(payable(alice));

        assertEq(address(balanceAccount).balance, 0 ether);
        assertEq(alice.balance, committedAmount);
        assertEq(uint256(balanceAccount.currentStatus()), uint256(BalanceAccount.Status.UNCOMMITTED));
        assertEq(balanceAccount.currentBalance(), 0 ether);

        vm.stopPrank();
    }
}
