//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {SharedHarness} from "@test/Harness.t.sol";

contract CoreTest is SharedHarness {

    uint256 public staticTime;
    function setUp() public virtual override {
        super.setUp();
        vm.label(address(this), "CoreTest");

        staticTime = block.timestamp;

        vm.warp({newTimestamp: staticTime});
    }

    function test_initiate_1stPhase_Account() external {
        //commitment hash =  poseidonHash(nullifier, 0, denomination)
        //nullifer hash =  poseidonHash(nullifier, 1, leafIndex, denomination)

        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        //todo: adding assert for deployAccounts
        deployAndAssertCore(alice, commitment);
    }

    address[] ownerAccounts;

    function test_commitNew_2ndPhase_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, commitment);

        // It is single premium just needs to abstract four payments into single one via router
        // todo fix amount
        // todo: assert emit
        delete ownerAccounts;
        ownerAccounts =
            commitNewAndAssertCore(alice, ownerAccounts, deployReturns[0].account, commitment, 0, committedAmount);
        ownerAccounts =
            commitNewAndAssertCore(alice, ownerAccounts, deployReturns[1].account, commitment, 1, committedAmount);
        ownerAccounts =
            commitNewAndAssertCore(alice, ownerAccounts, deployReturns[2].account, commitment, 2, committedAmount);
        ownerAccounts =
            commitNewAndAssertCore(alice, ownerAccounts, deployReturns[3].account, commitment, 3, committedAmount);
        delete ownerAccounts;
    }

    function test_clear_commitment_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 totalDepositAmount = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, totalDepositAmount), (bytes32, bytes32, bytes32));

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, commitment);

        delete ownerAccounts;
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[0].account, commitment, deployReturns[0].nonce, committedAmount
        );

        uint256 preClearToBalance = bob.balance;

        clearAndAssertCore(alice, ownerAccounts, ownerAccounts[0], bob);
        delete ownerAccounts;

        assertEq(bob.balance - preClearToBalance, committedAmount);

        // / Todo move this block to deposit
        // vm.expectRevert(bytes("SortedList: k must be > than list size"));
        // core.getTop(2);
    }

    function test_commitExisting_2ndPhase_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 totalDepositAmount = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        (bytes32 newCommitment,, bytes32 newNullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, totalDepositAmount), (bytes32, bytes32, bytes32));
        bytes32[] memory existingCommitments = new bytes32[](0);

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, newCommitment);
        delete ownerAccounts;
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[0].account, newCommitment, deployReturns[0].nonce, committedAmount
        );
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[1].account, newCommitment, deployReturns[1].nonce, committedAmount
        );
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[2].account, newCommitment, deployReturns[2].nonce, committedAmount
        );
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[3].account, newCommitment, deployReturns[3].nonce, committedAmount
        );

        depositAndAssertCore(
            DepositStruct(
                alice,
                ownerAccounts,
                newLeafIndex,
                newNullifier,
                newCommitment,
                committedAmount,
                totalDepositAmount,
                existingCommitments
            )
        );

        (bytes32 nextCommitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, totalDepositAmount), (bytes32, bytes32, bytes32));

        delete ownerAccounts;
        address[] memory committedAccount = commitExistingAndAssertCore(alice, ownerAccounts, nextCommitment);
        delete ownerAccounts;

        assertEq(core.getBottomAccount(), committedAccount[0]);
    }

    function test_deposit() external {
        uint256 newLeafIndex = 0;
        uint256 totalDepositAmount = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        (bytes32 commitment,, bytes32 nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, totalDepositAmount), (bytes32, bytes32, bytes32));
        bytes32[] memory existingCommitments = new bytes32[](0);

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, commitment);
        delete ownerAccounts;
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[0].account, commitment, deployReturns[0].nonce, committedAmount
        );
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[1].account, commitment, deployReturns[1].nonce, committedAmount
        );
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[2].account, commitment, deployReturns[2].nonce, committedAmount
        );
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[3].account, commitment, deployReturns[3].nonce, committedAmount
        );

        depositAndAssertCore(
            DepositStruct(
                alice,
                ownerAccounts,
                newLeafIndex,
                nullifier,
                commitment,
                committedAmount,
                totalDepositAmount,
                existingCommitments
            )
        );

        delete ownerAccounts;
    }

    function test_partial_withdraw() external {
        uint256 newLeafIndex = 0;
        uint256 totalDepositAmount = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;

        //TODO refactor to harness
        bytes32 commitment;
        bytes32 nullifierHash;
        bytes32 nullifier;
        (commitment, nullifierHash, nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, totalDepositAmount), (bytes32, bytes32, bytes32));
        bytes32[] memory existingCommitments = new bytes32[](0);

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, commitment);
        delete ownerAccounts;
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[0].account, commitment, deployReturns[0].nonce, committedAmount
        );
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[1].account, commitment, deployReturns[1].nonce, committedAmount
        );
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[2].account, commitment, deployReturns[2].nonce, committedAmount
        );
        ownerAccounts = commitNewAndAssertCore(
            alice, ownerAccounts, deployReturns[3].account, commitment, deployReturns[3].nonce, committedAmount
        );

        bytes32[] memory pushedCommitments = depositAndAssertCore(
            DepositStruct(
                alice,
                ownerAccounts,
                newLeafIndex,
                nullifier,
                commitment,
                committedAmount,
                totalDepositAmount,
                existingCommitments
            )
        );
        delete ownerAccounts;

        bytes32 newCommitment;
        bytes32 newNullifierHash;
        bytes32 newNullifier;
        // uint256 nextLeafIndex = 1;
        (newCommitment, newNullifierHash, newNullifier) =
            abi.decode(getDepositCommitmentHash(1, 0.75 ether), (bytes32, bytes32, bytes32));

        uint256 preWithdrawToBalance = alice.balance;

        vm.startPrank(alice);
        core.init_withdrawProcess( nullifierHash, alice);
        vm.stopPrank();

        vm.warp({newTimestamp: staticTime + 2 days});

        pushedCommitments = partialWithdrawAndAssertCore(
            PartialWithdrawStruct(
                relayer_signer,
                alice,
                0, //newLeafIndex 0
                1, //nextLeafIndex 1
                nullifier,
                newNullifier,
                nullifierHash, // from first commitment
                newCommitment,
                totalDepositAmount, // amount left
                committedAmount, // amountToWithdraw
                0 ether, //fee
                pushedCommitments
            )
        );

        nullifier = newNullifier;
        // nextLeafIndex = 2;
        (newCommitment,, newNullifier) = abi.decode(getDepositCommitmentHash(2, 0.5 ether), (bytes32, bytes32, bytes32));

        vm.warp({newTimestamp: staticTime + 4 days});
        
        partialWithdrawAndAssertCore(
            PartialWithdrawStruct(
                relayer_signer,
                alice,
                1, //newLeafIndex = 1
                2, //nextLeafIndex = 2
                nullifier,    // from first commitment
                newNullifier, // from second commitment
                newNullifierHash,
                newCommitment,
                0.75 ether, // amount left
                committedAmount, //amountToWithdraw
                0 ether, //fee
                pushedCommitments
            )
        );

        //todo abstract committedAmount
        assertEq(alice.balance - preWithdrawToBalance, committedAmount + committedAmount);
    }
}
