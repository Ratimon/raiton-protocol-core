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

    function test_commit_2ndPhase_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        DepositReturnStruct[] memory depositReturns = deployAndAssertCore(alice, commitment);

        // It is single premium just needs to abstract four payments into single one via router
        // to do fix amount
        // //todo: assert emit
        commitAndAssertCore(alice, depositReturns[0].account, commitment, 0, denomination);
        commitAndAssertCore(alice, depositReturns[1].account, commitment, 1, denomination);
        commitAndAssertCore(alice, depositReturns[2].account, commitment, 2, denomination);
        commitAndAssertCore(alice, depositReturns[3].account, commitment, 3, denomination);

        address[] memory topAccounts = core.getTop(2);
        assertEq(topAccounts[0], depositReturns[0].account);
        assertEq(topAccounts[1], depositReturns[1].account);

        address lowestAccount = core.getBottom();
        assertEq(lowestAccount, depositReturns[3].account);
    }

    function test_clear_commitment_Callback() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment,,) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));

        DepositReturnStruct[] memory depositReturns = deployAndAssertCore(alice, commitment);

        commitAndAssertCore(alice, depositReturns[0].account, commitment, depositReturns[0].nonce, denomination);

        clearAndAssertCore(alice, depositReturns[0].account, bob, denomination);

        vm.expectRevert(bytes("SortedList: k must be > than list size"));
        core.getTop(2);
    }

    function test_deposit() external {
        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        (bytes32 commitment,, bytes32 nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));
        bytes32[] memory pushedCommitments = new bytes32[](0);

        DepositReturnStruct[] memory depositReturns = deployAndAssertCore(alice, commitment);

        commitAndAssertCore(alice, depositReturns[0].account, commitment, depositReturns[0].nonce, denomination);
        depositAndAssertCore(alice, newLeafIndex, nullifier, commitment, denomination, pushedCommitments);
    }
    

    function test_partial_withdraw() external {

        uint256 newLeafIndex = 0;
        uint256 denomination = 1 ether;
        uint256 fee = 0 ether;

        //TODO refactor to harness
        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));
        bytes32[] memory pushedCommitments = new bytes32[](0);

        DepositReturnStruct[] memory depositReturns = deployAndAssertCore(alice, commitment);
        commitAndAssertCore(alice, depositReturns[0].account , commitment, depositReturns[0].nonce, denomination);
        depositAndAssertCore(alice, newLeafIndex, nullifier, commitment, denomination, pushedCommitments);

        uint256 nextLeafIndex = 1;
        (bytes32 newCommitment, , bytes32 newNullifier) =
            abi.decode(getDepositCommitmentHash(nextLeafIndex, denomination - (denomination / core.paymentNumber() ) ), (bytes32, bytes32, bytes32));

        pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;

        partialWithdrawAndAssertCore(
            PartialWithdrawStruct(
                relayer_signer,
                alice,
                newLeafIndex,
                nextLeafIndex,
                nullifier,
                newNullifier,
                nullifierHash,
                newCommitment,
                denomination,
                fee,
                pushedCommitments
            )
        );

    }

}
