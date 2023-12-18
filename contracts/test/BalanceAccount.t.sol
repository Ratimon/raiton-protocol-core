//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {Groth16Verifier as DepositGroth16Verifier} from "@main/verifiers/DepositVerifier.sol";

import {SharedHarness} from "@test/Harness.t.sol";


contract BalanceAccountTest is SharedHarness {

    function setUp() public virtual override {
        super.setUp();
        vm.label(address(this), "BalanceAccountTest");
    }

    function test_new_BalanceAccount() external {

        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment, , ) = abi.decode(getDepositCommitmentHash(newLeafIndex,denomination), (bytes32, bytes32, bytes32));

        address[] memory accounts = deployAccounts(alice, commitment);

        assertEq32(IAccount(accounts[0]).commitment(), commitment);
        assertEq32(IAccount(accounts[1]).commitment(), commitment);
        assertEq32(IAccount(accounts[2]).commitment(), commitment);
        assertEq32(IAccount(accounts[3]).commitment(), commitment);

        assertEq(IAccount(accounts[0]).denomination(), 1 ether);
        assertEq(IAccount(accounts[1]).denomination(), 1 ether);
        assertEq(IAccount(accounts[2]).denomination(), 1 ether);
        assertEq(IAccount(accounts[3]).denomination(), 1 ether);

        assertEq(IAccount(accounts[0]).cashInflows(), 1);
        assertEq(IAccount(accounts[1]).cashInflows(), 1);
        assertEq(IAccount(accounts[2]).cashInflows(), 1);
        assertEq(IAccount(accounts[3]).cashInflows(), 1);

        assertEq(IAccount(accounts[0]).cashOutflows(), 4);
        assertEq(IAccount(accounts[1]).cashOutflows(), 4);
        assertEq(IAccount(accounts[2]).cashOutflows(), 4);
        assertEq(IAccount(accounts[3]).cashOutflows(), 4);

        assertEq(IAccount(accounts[0]).nonce(), 0);
        assertEq(IAccount(accounts[1]).nonce(), 1);
        assertEq(IAccount(accounts[2]).nonce(), 2);
        assertEq(IAccount(accounts[3]).nonce(), 3);

        vm.stopPrank();
    }

    function test_commit_2ndPhase() external {
        startHoax(alice,  1 ether);

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        BalanceAccount account_1 = BalanceAccount(accounts[0]);

        assertEq( address(account_1).balance, 0 ether);
        assertEq( uint256(account_1.currentStatus()),  uint256(BalanceAccount.Status.UNCOMMITED));
        assertEq( account_1.currentBalance(), 0 ether);

        account_1.commit_2ndPhase{value: 1 ether}();

        assertEq( address(account_1).balance, 1 ether);
        assertEq( uint256(account_1.currentStatus()),  uint256(BalanceAccount.Status.COMMITED));
        assertEq( account_1.currentBalance(), 1 ether);

        vm.stopPrank();
    }

    function test_clear_commitment() external {
        startHoax(alice,  1 ether);

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        BalanceAccount account_1 = BalanceAccount(accounts[0]);
        account_1.commit_2ndPhase{value: 1 ether}();

        assertEq( address(account_1).balance, 1 ether);
        assertEq(alice.balance, 0 ether);
        assertEq( uint256(account_1.currentStatus()),  uint256(BalanceAccount.Status.COMMITED));
        assertEq( account_1.currentBalance(), 1 ether);

        account_1.clear_commitment(payable(alice));

        assertEq( address(account_1).balance, 0 ether);
        assertEq(alice.balance, 1 ether);
        assertEq( uint256(account_1.currentStatus()),  uint256(BalanceAccount.Status.UNCOMMITED));
        assertEq( account_1.currentBalance(), 0 ether);

        vm.stopPrank();
    }
}