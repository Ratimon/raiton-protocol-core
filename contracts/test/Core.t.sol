//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

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
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        // //todo: adding assert for deployAccounts
        deployAndAssertCore(alice, commitment);
    }

    function test_commit_2ndPhase_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        address[] memory accounts = deployAndAssertCore(alice, commitment);

        // It is single premium just needs to abstract four payments into single one via router
        // to do fix amount
        // //todo: assert emit
        commitAndAssertCore(alice, accounts[0], commitment, 0, denomination);
        commitAndAssertCore(alice, accounts[1], commitment, 1, denomination);
        commitAndAssertCore(alice, accounts[2], commitment, 2, denomination);
        commitAndAssertCore(alice, accounts[3], commitment, 3, denomination);

        address[] memory topAccounts = core.getTop(2);
        assertEq(topAccounts[0], accounts[0]);
        assertEq(topAccounts[1], accounts[1]);

        address lowestAccount = core.getBottom();
        assertEq(lowestAccount, accounts[3]);
    }

    function test_clear_commitment_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        address[] memory accounts = deployAndAssertCore(alice, commitment);
        uint256 nonce = 0;
        commitAndAssertCore(alice, accounts[0], commitment, nonce, denomination);

        clearAndAssertCore(alice, accounts[0], bob, denomination);

        vm.expectRevert(bytes("SortedList: k must be > than list size"));
        core.getTop(2);
    }

    function test_deposit() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment,, bytes32 nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));
        bytes32[] memory pushedCommitments = new bytes32[](0);

        address[] memory accounts = deployAndAssertCore(alice, commitment);

        commitAndAssertCore(alice, accounts[0], commitment, 0, denomination);
        depositAndAssertCore(alice, newLeafIndex, nullifier, commitment, denomination, pushedCommitments);
    }
    

    function test_partial_withdraw() external {

        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;

        //TODO refactor to harness
        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));
        bytes32[] memory pushedCommitments = new bytes32[](0);

        address[] memory accounts = deployAndAssertCore(alice, commitment);
        commitAndAssertCore(alice, accounts[0], commitment, 0, denomination);
        depositAndAssertCore(alice, newLeafIndex, nullifier, commitment, denomination, pushedCommitments);

        uint256 nextLeafIndex = 1;
        (bytes32 newCommitment, , bytes32 newNullifier) =
            abi.decode(getDepositCommitmentHash(nextLeafIndex, denomination - (denomination / core.paymentNumber() ) ), (bytes32, bytes32, bytes32));

        pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;

        Core.Proof memory partialWithdrawProof;
        bytes32 root;
        bytes32 newRoot;
        {
            (partialWithdrawProof, root, newRoot) = abi.decode(
                getPartialWithdrawProve(
                    GetPartialWithdrawProveStruct(
                        newLeafIndex,
                        nextLeafIndex,
                        nullifier, 
                        newNullifier, // new nullifier
                        nullifierHash,
                        newCommitment, // new commitment
                        denomination,
                        alice,
                        (denomination / core.paymentNumber()), // amount = denomination / payment number
                        relayer_signer,
                        0, // fee
                        pushedCommitments
                    )

                ),
                (Core.Proof, bytes32, bytes32)
            );
        }

        assertEq(core.getWithdrawnAmount(nullifierHash), 0);
        assertEq(core.getIsNullified(nullifierHash), false);

        core.withdraw(
            partialWithdrawProof,
            root, 
            nullifierHash,
            newCommitment,
            newRoot,
            payable(alice),
            payable(relayer_signer),
            0 // fee
        );

        assertEq(core.getWithdrawnAmount(nullifierHash), 0.25 ether);
        assertEq(core.getIsNullified(nullifierHash), false);


    }

}
