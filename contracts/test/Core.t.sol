//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {Groth16Verifier as DepositGroth16Verifier} from "@main/verifiers/DepositVerifier.sol";

import {SharedHarness} from "@test/Harness.t.sol";


contract CoreTest is SharedHarness {

    function setUp() public virtual override {
        super.setUp();
        vm.label(address(this), "CoreTest");
    }

    function test_initiate_1stPhase_Account() external {

        //commitment hash =  poseidonHash(nullifier, 0, denomination)
        //nullifer hash =  poseidonHash(nullifier, 1, leafIndex, denomination)

        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment, , ) = abi.decode(getDepositCommitmentHash(newLeafIndex,denomination), (bytes32, bytes32, bytes32));

        // //todo: adding assert for deployAccounts
        address[] memory accounts = deployAccounts(alice, commitment);

        assertEq( core.getPendingAccount(commitment, 0), accounts[0]);
        assertEq( core.getPendingAccount(commitment, 1), accounts[1]);
        assertEq( core.getPendingAccount(commitment, 2), accounts[2]);
        assertEq( core.getPendingAccount(commitment, 3), accounts[3]);
    }

    function test_commit_2ndPhase_Callback() external {

        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment, , ) = abi.decode(getDepositCommitmentHash(newLeafIndex,denomination), (bytes32, bytes32, bytes32));

        address[] memory accounts = deployAccounts(alice, commitment);

        // It is single premium just needs to abstract four payments into single one via router
        // to do fix amount
        // //todo: assert emit
        commitAndAssert(alice, accounts[0], commitment, 0, denomination);
        commitAndAssert(alice, accounts[1], commitment, 1, denomination);
        commitAndAssert(alice, accounts[2], commitment, 2, denomination);
        commitAndAssert(alice, accounts[3], commitment, 3, denomination);

        address[] memory topAccounts = core.getTop(2);
        assertEq(topAccounts[0], accounts[0]);
        assertEq(topAccounts[1], accounts[1]);
        assertEq(topAccounts[2], accounts[2]);

        address lowestAccount = core.getBottom();
        assertEq(lowestAccount, accounts[3]);
    }

    function test_clear_commitment_Callback() external {
        startHoax(alice,  1 ether);

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        IAccount account_1 = IAccount(accounts[0]);
        account_1.commit_2ndPhase{value: 1 ether}();
         //todo: assert emit
        account_1.clear_commitment(payable(alice));

        assertEq( core.getCommitment(accounts[0]), bytes32(0));
        vm.stopPrank();
    }

    function test_deposit() external {
        startHoax(alice,  1 ether);

        uint256 newLeafIndex = 0;
        (bytes32 commitment, , bytes32 nullifier) = abi.decode(getDepositCommitmentHash(newLeafIndex, 1 ether), (bytes32, bytes32, bytes32));
        bytes32[] memory pushedCommitments = new bytes32[](0) ;

        uint256 preDepositUserBalance = alice.balance;

        address[] memory accounts = core.initiate_1stPhase_Account(commitment);
        IAccount account_1 = IAccount(accounts[0]);
        account_1.commit_2ndPhase{value: 1 ether}();
        // account_1.clear_commitment(payable(alice));

        Core.Proof memory depositProof;
        bytes32 newRoot;

        {
            (depositProof, newRoot) = abi.decode(
                getDepositProve(
                    newLeafIndex,
                    core.roots(core.currentRootIndex()),
                    1 ether, //amount
                    nullifier, //secret
                    commitment,
                    pushedCommitments
                ),
                (Core.Proof, bytes32)
            );
        }

        
        //todo: assert emit
        core.deposit(depositProof, newRoot);

        assertEq(preDepositUserBalance - alice.balance , 1 ether);

        {
            // assert tree root and elements are correct
            (bytes32 preDepositRoot, uint256 elements, bytes32 postDepositRoot) = getJsTreeAssertions(pushedCommitments, commitment);
            assertEq(preDepositRoot, core.roots(newLeafIndex));
            assertEq(elements, core.nextIndex());
            assertEq(postDepositRoot, core.roots(newLeafIndex + 1));
        }

        vm.stopPrank();
    }
}
