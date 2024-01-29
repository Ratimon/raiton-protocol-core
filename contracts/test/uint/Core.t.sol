//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {BalanceAccountHarness} from "@test/harness/BalanceAccount.harness.t.sol";
import {CoreHarness} from "@test/harness/Core.harness.t.sol";

contract CoreTest is BalanceAccountHarness, CoreHarness {

    function setUp() public virtual override(BalanceAccountHarness, CoreHarness ) {
        super.setUp();
        vm.label(address(this), "CoreTest");
    }

    function test_init_1stPhase_Account() external {
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

    function test_init_1stPhase_Withdraw() external {
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

        init_1stPhase_WithdrawAndAssertCore( relayer_signer, alice, nullifierHash);

    }

    function test_RevertWhen_() external {

    }

    function test_twotimes_withdraw() external {
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

        init_1stPhase_WithdrawAndAssertCore( relayer_signer, alice, nullifierHash);
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
                pushedCommitments,
                core.getBottomAccount()
            )
        );

        nullifierHash = newNullifierHash;
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
                nullifierHash,
                newCommitment,
                0.75 ether, // amount left
                committedAmount, //amountToWithdraw
                0 ether, //fee
                pushedCommitments,
                core.getBottomAccount()
            )
        );

        //todo abstract committedAmount
        assertEq(alice.balance - preWithdrawToBalance, committedAmount + committedAmount);

        
    }

    function test_fourtimes_withdraw() external {
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

        init_1stPhase_WithdrawAndAssertCore( relayer_signer, alice, nullifierHash);
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
                pushedCommitments,
                core.getBottomAccount()
            )
        );

        nullifierHash = newNullifierHash;
        nullifier = newNullifier;
        // nextLeafIndex = 2;
        (newCommitment,newNullifierHash, newNullifier) = abi.decode(getDepositCommitmentHash(2, 0.5 ether), (bytes32, bytes32, bytes32));

        vm.warp({newTimestamp: staticTime + 4 days});
        
        pushedCommitments = partialWithdrawAndAssertCore(
            PartialWithdrawStruct(
                relayer_signer,
                alice,
                1, //newLeafIndex = 1
                2, //nextLeafIndex = 2
                nullifier,    // from first commitment
                newNullifier, // from second commitment
                nullifierHash,
                newCommitment,
                0.75 ether, // amount left
                committedAmount, //amountToWithdraw
                0 ether, //fee
                pushedCommitments,
                core.getBottomAccount()
            )
        );

        nullifierHash = newNullifierHash;
        nullifier = newNullifier;
        (newCommitment,newNullifierHash, newNullifier) = abi.decode(getDepositCommitmentHash(3, 0.25 ether), (bytes32, bytes32, bytes32));

        vm.warp({newTimestamp: staticTime + 6 days});
        
        pushedCommitments = partialWithdrawAndAssertCore(
            PartialWithdrawStruct(
                relayer_signer,
                alice,
                2, //newLeafIndex = 2
                3, //nextLeafIndex = 3
                nullifier,    // from second commitment
                newNullifier, // from third commitment
                nullifierHash,
                newCommitment,
                0.50 ether, // amount left
                committedAmount, //amountToWithdraw
                0 ether, //fee
                pushedCommitments,
                core.getBottomAccount()
            )
        );

        nullifierHash = newNullifierHash;
        nullifier = newNullifier;
        (newCommitment, newNullifierHash, newNullifier) = abi.decode(getDepositCommitmentHash(4, 0 ether), (bytes32, bytes32, bytes32));

        vm.warp({newTimestamp: staticTime + 8 days});
        
        partialWithdrawAndAssertCore(
            PartialWithdrawStruct(
                relayer_signer,
                alice,
                3, //newLeafIndex = 2
                4, //nextLeafIndex = 3
                nullifier,    // from third commitment
                newNullifier, // from forth commitment
                nullifierHash,
                newCommitment,
                0.25 ether, // amount left
                committedAmount, //amountToWithdraw
                0 ether, //fee
                pushedCommitments,
                core.getBottomAccount()
            )
        );

        assertEq(alice.balance - preWithdrawToBalance, totalDepositAmount);


    }

    //todo: adding case when accountNumberGotozero then increase again

}