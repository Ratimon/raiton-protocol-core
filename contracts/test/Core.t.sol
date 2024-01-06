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

        //todo: adding assert for deployAccounts
        deployAndAssertCore(alice, commitment);
    }

    address[] ownerAccounts ;
    function test_commitNew_2ndPhase_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, commitment);

        // It is single premium just needs to abstract four payments into single one via router
        // to do fix amount
        // todo: assert emit
        // todo: check why denomination =  1 ether?, it must be 0.25 ether?

        delete ownerAccounts;
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts,  deployReturns[0].account, commitment, 0, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[1].account, commitment, 1, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[2].account, commitment, 2, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[3].account, commitment, 3, committedAmount);
        delete ownerAccounts;

        // Todo move this block to deposit
        // address[] memory topAccounts = core.getTop(2);
        // assertEq(topAccounts[0], deployReturns[0].account);
        // assertEq(topAccounts[1], deployReturns[1].account);

        // address lowestAccount = core.getBottomAccount();
        // assertEq(lowestAccount, deployReturns[3].account);
    }

    function test_clear_commitment_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, commitment);

        delete ownerAccounts;
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[0].account, commitment, deployReturns[0].nonce, committedAmount);

        clearAndAssertCore(alice, ownerAccounts[0], bob, committedAmount);
        delete ownerAccounts;

        // / Todo move this block to deposit
        // vm.expectRevert(bytes("SortedList: k must be > than list size"));
        // core.getTop(2);
    }

    function test_deposit() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        (bytes32 commitment,, bytes32 nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));
        bytes32[] memory existingCommitments = new bytes32[](0);

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, commitment);
        delete ownerAccounts;
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[0].account, commitment, deployReturns[0].nonce, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[1].account, commitment, deployReturns[1].nonce, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[2].account, commitment, deployReturns[2].nonce, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[3].account, commitment, deployReturns[3].nonce, committedAmount);
        delete ownerAccounts;

        depositAndAssertCore(alice, newLeafIndex, nullifier, commitment, denomination, existingCommitments);
    }
    

    function test_partial_withdraw() external {

        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        // uint256 fee = 0 ether;

        //TODO refactor to harness
        bytes32 commitment;
        bytes32 nullifierHash;
        bytes32 nullifier;
        ( commitment,  nullifierHash, nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));
        bytes32[] memory existingCommitments = new bytes32[](0);

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, commitment);
        delete ownerAccounts;
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[0].account , commitment, deployReturns[0].nonce, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[1].account, commitment, deployReturns[1].nonce, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[2].account, commitment, deployReturns[2].nonce, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[3].account, commitment, deployReturns[3].nonce, committedAmount);
        delete ownerAccounts;

        bytes32[] memory pushedCommitments = depositAndAssertCore(alice, newLeafIndex, nullifier, commitment, denomination, existingCommitments);


        uint256 nextLeafIndex = 1;
        bytes32 newCommitment;
        bytes32 newNullifierHash;
        bytes32 newNullifier;
        ( newCommitment, newNullifierHash, newNullifier) =
            abi.decode(getDepositCommitmentHash(nextLeafIndex, 0.75 ether ), (bytes32, bytes32, bytes32));

        pushedCommitments = partialWithdrawAndAssertCore(
            PartialWithdrawStruct(
                relayer_signer,
                alice,
                newLeafIndex,  //0
                nextLeafIndex, //1
                nullifier,
                newNullifier,
                nullifierHash, // from first commitment
                newCommitment,
                // denomination - (denomination / core.paymentNumber()),
                denomination,
                committedAmount, //amountToWithdraw
                // (denomination / core.paymentNumber()),
                0 ether, //fee
                pushedCommitments
            )
        );

        newLeafIndex = nextLeafIndex;
        nullifier = newNullifier;
        nextLeafIndex = 2;

        ( newCommitment, , newNullifier) =
            abi.decode(getDepositCommitmentHash(nextLeafIndex, 0.5 ether ), (bytes32, bytes32, bytes32));

        partialWithdrawAndAssertCore(
            PartialWithdrawStruct(
                relayer_signer,
                alice,
                newLeafIndex,  //1
                nextLeafIndex, //2
                nullifier,
                newNullifier,
                newNullifierHash,
                newCommitment,
                0.75 ether,
                committedAmount, //amountToWithdraw
                // (denomination / core.paymentNumber()),
                0 ether, //fee
                pushedCommitments
            )
        );

    }

    function test_commitExisting_2ndPhase_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        uint256 committedAmount = 0.25 ether; // 1 / 4  ether;
        (bytes32 newCommitment,, bytes32 newNullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));
        bytes32[] memory existingCommitments = new bytes32[](0);

        DeployReturnStruct[] memory deployReturns = deployAndAssertCore(alice, newCommitment);
        delete ownerAccounts;
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[0].account, newCommitment, deployReturns[0].nonce, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[1].account, newCommitment, deployReturns[1].nonce, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[2].account, newCommitment, deployReturns[2].nonce, committedAmount);
        ownerAccounts = commitNewAndAssertCore(alice, ownerAccounts, deployReturns[3].account, newCommitment, deployReturns[3].nonce, committedAmount);
        delete ownerAccounts;

        depositAndAssertCore(alice, newLeafIndex, newNullifier, newCommitment, denomination, existingCommitments);

        (bytes32 nextCommitment,, ) =
        abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        address committedAccount = commitExistingAndAssertCore(alice, nextCommitment);

        address lowestAccount = core.getBottomAccount();
        assertEq(lowestAccount, committedAccount);

    }

    

}
