//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IPartialWithdrawVerifier} from "@main/interfaces/IPartialWithdrawVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {Groth16Verifier as DepositGroth16Verifier} from "@main/verifiers/DepositVerifier.sol";
import {Groth16Verifier as PartialWithdrawVerifier} from "@main/verifiers/PartialWithdrawVerifier.sol";

import {SharedHarness} from "@test/harness/Shared.harness.t.sol";

contract CoreHarness is SharedHarness {

    function setUp() public virtual override {
        super.setUp();
        vm.label(address(this), "CoreHarness");
    }

    struct DeployReturnStruct {
        address account;
        uint256 nonce;
    }

    event Create(bytes32 indexed commitment, uint256 cashInflows, uint256 cashOutflows, uint256 nonce);
    function deployAndAssertCore(address user, bytes32 commitment)
        internal
        returns (DeployReturnStruct[] memory deployReturns)
    {
        vm.startPrank(user);

        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: false,
            checkTopic3: false,
            checkData: true,
            emitter: address(core)
        });
        emit Create(commitment, 1, 4, 0);
        emit Create(commitment, 1, 4, 1);
        emit Create(commitment, 1, 4, 2);
        emit Create(commitment, 1, 4, 3);
        address[] memory accounts = core.init_1stPhase_Account(commitment);

        deployReturns = new DeployReturnStruct[](accounts.length);
        IAccount account;
        for (uint256 i = 0; i < accounts.length; i++) {
            account = IAccount(accounts[i]);

            deployReturns[i] = DeployReturnStruct(accounts[i], account.nonce());
        }

        assertEq(core.getPendingAccountToCommit(commitment, deployReturns[0].nonce), deployReturns[0].account);
        assertEq(core.getPendingAccountToCommit(commitment, deployReturns[1].nonce), deployReturns[1].account);
        assertEq(core.getPendingAccountToCommit(commitment, deployReturns[2].nonce), deployReturns[2].account);
        assertEq(core.getPendingAccountToCommit(commitment, deployReturns[3].nonce), deployReturns[3].account);

        for (uint256 i = 0; i < accounts.length; i++) {
            assertEq(core.getPendingCommitmentToDeposit(accounts[i]), commitment);
            assertEq(core.getPendingAccountToDeposit(accounts[i]), deployReturns[i].account);
        }

        vm.stopPrank();
    }

    event Commit(bytes32 indexed commitment, address indexed account, uint256 amountIn, uint256 timestamp);
    function commitNewAndAssertCore(
        address user,
        address[] memory preAccounts,
        address newAccount,
        bytes32 commitment,
        uint256 nonce,
        uint256 amount
    ) internal returns (address[] memory postAccounts) {
        startHoax(user, amount);

        assertEq(core.getPendingAccountToCommit(commitment, nonce), newAccount);
        assertEq(core.getPendingCommitmentToDeposit(newAccount), commitment);

        uint256 prePendingCommittedAmount = core.getPendingCommittedAmountToDeposit(newAccount);
        uint256 preOwnerCommittedAmount = core.getOwnerCommittedAmount(user);

        assertEq(core.getOwnerAccounts(user), preAccounts);

        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: false,
            checkData: true,
            emitter: address(core)
        });
        emit Commit(commitment,newAccount, amount, block.timestamp);
        uint256 returningAmount = IAccount(newAccount).commitNew_2ndPhase{value: amount}();
        assertEq(returningAmount, amount);

        assertEq(core.getPendingAccountToCommit(commitment, nonce), address(0));

        assertEq(core.getPendingCommitmentToDeposit(newAccount), commitment);
        assertEq(core.getPendingCommittedAmountToDeposit(newAccount), prePendingCommittedAmount + amount);

        assertEq(core.getOwnerCommitment(user), commitment);
        assertEq(core.getOwnerCommittedAmount(user), preOwnerCommittedAmount + amount);

        postAccounts = new address[](preAccounts.length + 1);
        for (uint256 i = 0; i < preAccounts.length; i++) {
            postAccounts[i] = preAccounts[i];
        }
        postAccounts[postAccounts.length - 1] = newAccount;
        assertEq(core.getOwnerAccounts(user), postAccounts);

        vm.stopPrank();

        return postAccounts;
    }

    function commitExistingAndAssertCore(address user, address[] memory preAccounts, bytes32 newCommitment)
        internal
        returns (address[] memory postAccounts)
    {
        address bottomAccount = core.getBottomAccount();
        uint256 amountToCommit = core.getCurrentAmountIn();

        startHoax(user, amountToCommit);

        assertEq(core.getPendingCommitmentToDeposit(bottomAccount), bytes32(0));

        uint256 prePendingCommittedAmount = core.getPendingCommittedAmountToDeposit(bottomAccount);
        uint256 preOwnerCommittedAmount = core.getOwnerCommittedAmount(user);

        assertEq(core.getOwnerAccounts(user), preAccounts);

        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: false,
            checkData: true,
            emitter: address(core)
        });
        emit Commit(newCommitment, bottomAccount, amountToCommit, block.timestamp);
        uint256 returningAmount =
            IAccount(bottomAccount).commitExisting_2ndPhase{value: amountToCommit}(alice, newCommitment);
        assertEq(returningAmount, amountToCommit);

        assertEq(core.getPendingCommitmentToDeposit(bottomAccount), newCommitment);
        assertEq(core.getPendingCommittedAmountToDeposit(bottomAccount), prePendingCommittedAmount + amountToCommit);

        assertEq(core.getOwnerCommitment(user), newCommitment);
        assertEq(core.getOwnerCommittedAmount(user), preOwnerCommittedAmount + amountToCommit);

        postAccounts = new address[](preAccounts.length + 1);
        for (uint256 i = 0; i < preAccounts.length; i++) {
            postAccounts[i] = preAccounts[i];
        }
        postAccounts[postAccounts.length - 1] = bottomAccount;
        assertEq(core.getOwnerAccounts(user), postAccounts);

        vm.stopPrank();

        return postAccounts;
    }

    event Clear(bytes32 indexed commitment, address indexed account, uint256 timestamp);

    address[] emptyArrays;
    function clearAndAssertCore(address user, address[] memory preAccounts, address account, address to) internal {
        vm.startPrank(user);

        assertTrue(core.getPendingCommitmentToDeposit(account) != bytes32(0));
        assertTrue(core.getPendingCommittedAmountToDeposit(account) != 0);

        assertTrue(core.getOwnerCommitment(user) != bytes32(0));
        assertTrue(core.getOwnerCommittedAmount(user) != 0);

        assertEq(core.getOwnerAccounts(user), preAccounts);

        IAccount balanceAccount = IAccount(account);

        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: false,
            checkData: true,
            emitter: address(core)
        });
        emit Clear(core.getPendingCommitmentToDeposit(account) , account, block.timestamp);
        balanceAccount.clear_commitment(payable(to));

        assertEq(core.getPendingCommitmentToDeposit(account), bytes32(0));
        assertEq(core.getPendingCommittedAmountToDeposit(account), 0);

        assertEq(core.getOwnerCommitment(user), bytes32(0));
        assertEq(core.getOwnerCommittedAmount(user), 0);

        delete emptyArrays;
        assertEq(core.getOwnerAccounts(user), emptyArrays);

        vm.stopPrank();
    }

    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);

    struct DepositStruct {
        address user;
        address[] preAccounts;
        uint256 newLeafIndex;
        bytes32 nullifier;
        bytes32 commitment;
        uint256 committedAmount;
        uint256 totalDepositAmount;
        bytes32[] existingCommitments;
    }

    function depositAndAssertCore(DepositStruct memory depositStruct)
        internal
        returns (bytes32[] memory pushedCommitments)
    {
        vm.startPrank(depositStruct.user);

        Core.Proof memory depositProof;
        bytes32 newRoot;
        {
            (depositProof, newRoot) = abi.decode(
                getDepositProve(
                    GetDepositProveStruct(
                        depositStruct.newLeafIndex,
                        core.roots(core.currentRootIndex()),
                        depositStruct.totalDepositAmount,
                        depositStruct.nullifier, //secret
                        depositStruct.commitment,
                        depositStruct.existingCommitments
                    )
                ),
                (Core.Proof, bytes32)
            );
        }

        uint128 _preRootIndex = core.currentRootIndex();
        //initialRootZero
        // todo: handle case when it is not 'initialRootZero'
        assertEq(core.roots(_preRootIndex), 0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb);
        assertEq(core.roots(_preRootIndex + 1), bytes32(0));

        assertFalse(core.getSubmittiedCommitment(depositStruct.commitment));

        assertTrue(core.getOwnerCommitment(depositStruct.user) != bytes32(0));
        assertTrue(core.getOwnerCommittedAmount(depositStruct.user) != 0);
        assertEq(core.getOwnerAccounts(depositStruct.user), depositStruct.preAccounts);

        uint256[] memory preDepositAccountBalances = new uint256[](depositStruct.preAccounts.length);
        for (uint256 i = 0; i < depositStruct.preAccounts.length; i++) {
            preDepositAccountBalances[i] = core.getBalance(depositStruct.preAccounts[i]);
        }

        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: false,
            checkTopic3: false,
            checkData: true,
            emitter: address(core)
        });
        emit Deposit(depositStruct.commitment, _preRootIndex, block.timestamp);
        core.deposit(depositProof, newRoot);

        assertTrue(core.getSubmittiedCommitment(depositStruct.commitment));

        assertEq(core.roots(core.currentRootIndex()), newRoot);
        assertEq(core.currentRootIndex(), _preRootIndex + 1);

        {
            // assert tree root and elements are correct
            (bytes32 preDepositRoot, uint256 elements, bytes32 postDepositRoot) =
                getJsTreeAssertions(depositStruct.existingCommitments, depositStruct.commitment);
            assertEq(preDepositRoot, core.roots(depositStruct.newLeafIndex));
            assertEq(elements, core.nextIndex());
            assertEq(postDepositRoot, core.roots(depositStruct.newLeafIndex + 1));
        }

        assertEq(core.getOwnerCommitment(depositStruct.user), bytes32(0));
        assertEq(core.getOwnerCommittedAmount(depositStruct.user), 0);
        delete emptyArrays;
        assertEq(core.getOwnerAccounts(depositStruct.user), emptyArrays);

        for (uint256 i = 0; i < depositStruct.preAccounts.length; i++) {
            assertEq(
                core.getBalance(depositStruct.preAccounts[i]),
                preDepositAccountBalances[i] + depositStruct.committedAmount
            );
        }
        delete preDepositAccountBalances;
        vm.stopPrank();

        pushedCommitments = new bytes32[](depositStruct.existingCommitments.length + 1);
        for (uint256 i = 0; i < depositStruct.existingCommitments.length; i++) {
            pushedCommitments[i] = depositStruct.existingCommitments[i];
        }
        pushedCommitments[pushedCommitments.length - 1] = depositStruct.commitment;
        return pushedCommitments;
    }

    event Showtime(bytes32 nullifierHash, address recipient, uint256 timestamp);
    function init_1stPhase_WithdrawAndAssertCore(address relayer, address user, bytes32 nullifierHash) internal {

        vm.startPrank(relayer);

        assertTrue(!core.getIsNullifierInited(nullifierHash));
        assertEq(core.getLastWithdrawTime(user) , 0);

        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: false,
            checkTopic3: false,
            checkData: true,
            emitter: address(core)
        });
        emit Showtime(nullifierHash, user, block.timestamp);
        core.init_1stPhase_Withdraw( nullifierHash, user);

        assertTrue(core.getIsNullifierInited(nullifierHash));
        assertEq(core.getLastWithdrawTime(user) , block.timestamp);

        vm.stopPrank();
        
    }

    event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);

    struct PartialWithdrawStruct {
        address relayer;
        address user;
        uint256 newLeafIndex;
        uint256 nextLeafIndex;
        bytes32 nullifier;
        bytes32 newNullifier;
        bytes32 nullifierHash;
        bytes32 commitment;
        uint256 denomination;
        uint256 amountToWithdraw;
        uint256 fee;
        bytes32[] pushedCommitments;
        address accountToWithdraw;
    }

    bytes32[] commitments;
    function partialWithdrawAndAssertCore(PartialWithdrawStruct memory partialWithdrawStruct)
        internal
        returns (bytes32[] memory)
    {
        vm.startPrank(partialWithdrawStruct.relayer);

        Core.Proof memory partialWithdrawProof;
        bytes32 root;
        bytes32 newRoot;
        {
            (partialWithdrawProof, root, newRoot) = abi.decode(
                getPartialWithdrawProve(
                    GetPartialWithdrawProveStruct(
                        partialWithdrawStruct.newLeafIndex,
                        partialWithdrawStruct.nextLeafIndex,
                        partialWithdrawStruct.nullifier,
                        partialWithdrawStruct.newNullifier, // new nullifier
                        partialWithdrawStruct.nullifierHash,
                        partialWithdrawStruct.commitment, // new commitment
                        partialWithdrawStruct.denomination, // amount = denomination
                        partialWithdrawStruct.user, //recipient
                        partialWithdrawStruct.amountToWithdraw, // amount = denomination / payment number
                        relayer_signer, //todo refactor
                        partialWithdrawStruct.fee, // fee
                        partialWithdrawStruct.pushedCommitments
                    )
                ),
                (Core.Proof, bytes32, bytes32)
            );
        }

       
        uint256 preWithdrawAmount = core.getWithdrawnAmount(partialWithdrawStruct.user);
        // 0 ether for 1st time, 0.25 ether for 2nd time
        assertEq(preWithdrawAmount, 1 ether - partialWithdrawStruct.denomination);
        assertEq(core.getIsNullified(partialWithdrawStruct.nullifierHash), false);

        assertEq(core.roots(core.currentRootIndex()), root);
        assertEq(core.roots(core.currentRootIndex() + 1), bytes32(0));

        uint256 preWithdrawAccountBalance = core.getBalance(partialWithdrawStruct.accountToWithdraw);
        
        vm.expectEmit({
            checkTopic1: false,
            checkTopic2: false,
            checkTopic3: true,
            checkData: true,
            emitter: address(core)
        });
        emit Withdrawal(partialWithdrawStruct.user, partialWithdrawStruct.nullifierHash, partialWithdrawStruct.relayer, partialWithdrawStruct.fee);
        emit Deposit(partialWithdrawStruct.commitment, core.currentRootIndex(), block.timestamp);
        core.withdraw(
            partialWithdrawProof,
            root,
            partialWithdrawStruct.nullifierHash,
            partialWithdrawStruct.commitment,
            newRoot,
            payable(partialWithdrawStruct.user),
            payable(partialWithdrawStruct.relayer),
            partialWithdrawStruct.fee // fee
        );

        assertEq(core.roots(core.currentRootIndex() - 1), root);
        assertEq(core.roots(core.currentRootIndex()), newRoot);

        if ( preWithdrawAmount + partialWithdrawStruct.amountToWithdraw ==  1 ether) {
            assertEq(core.getWithdrawnAmount(partialWithdrawStruct.user), 0);
            assertEq(core.getPreviousNullifierHash(partialWithdrawStruct.user), bytes32(0));
            assertEq(core.getLastWithdrawTime(partialWithdrawStruct.user) , 0);
        } else {
            assertEq(core.getWithdrawnAmount(partialWithdrawStruct.user), preWithdrawAmount + partialWithdrawStruct.amountToWithdraw);
            assertEq(core.getPreviousNullifierHash(partialWithdrawStruct.user), partialWithdrawStruct.nullifierHash);
            assertEq(core.getLastWithdrawTime(partialWithdrawStruct.user) , block.timestamp);
        }

        // todo add pre state transition
        // assertEq(core.getPreviousNullifierHash(partialWithdrawStruct.user), partialWithdrawStruct.nullifierHash);
        // assertEq(core.getLastWithdrawTime(partialWithdrawStruct.user) , block.timestamp);

        // TODO fix when scenario of 4 time partial withdrawn
        assertEq(core.getIsNullified(partialWithdrawStruct.nullifierHash), true);
        assertEq(preWithdrawAccountBalance - core.getBalance(partialWithdrawStruct.accountToWithdraw), partialWithdrawStruct.amountToWithdraw);

        vm.stopPrank();

        delete commitments;
        commitments =  partialWithdrawStruct.pushedCommitments;
        commitments.push(partialWithdrawStruct.commitment);

        return commitments;

    }

    function getDepositCommitmentHash(uint256 leafIndex, uint256 denomination) internal returns (bytes memory) {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "test/utils/getCommitment.cjs";
        inputs[2] = vm.toString(leafIndex);
        inputs[3] = vm.toString(denomination);

        return vm.ffi(inputs);
    }

    struct GetDepositProveStruct {
        uint256 leafIndex;
        bytes32 oldRoot;
        uint256 denomination;
        bytes32 nullifier;
        bytes32 commitmentHash;
        bytes32[] pushedCommitments;
    }

    function getDepositProve(GetDepositProveStruct memory getDepositProveStruct) internal returns (bytes memory) {
        string[] memory inputs = new string[](9);
        inputs[0] = "node";
        inputs[1] = "test/utils/getDepositProve.cjs";
        inputs[2] = "20";
        inputs[3] = vm.toString(getDepositProveStruct.leafIndex);
        inputs[4] = vm.toString(getDepositProveStruct.oldRoot);
        inputs[5] = vm.toString(getDepositProveStruct.commitmentHash);
        inputs[6] = vm.toString(getDepositProveStruct.denomination);
        inputs[7] = vm.toString(getDepositProveStruct.nullifier);
        inputs[8] = vm.toString(abi.encode(getDepositProveStruct.pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    function getFullWithdrawProve(
        uint256 leafIndex,
        bytes32 nullifier,
        bytes32 nullifierHash,
        address recipient,
        uint256 amount,
        address relayer,
        uint256 fee,
        bytes32[] memory pushedCommitments
    ) internal returns (bytes memory) {
        string[] memory inputs = new string[](11);
        inputs[0] = "node";
        inputs[1] = "test/utils/getFullWithdrawProve.cjs";
        inputs[2] = "20";
        inputs[3] = vm.toString(leafIndex);
        inputs[4] = vm.toString(nullifier);
        inputs[5] = vm.toString(nullifierHash);
        inputs[6] = vm.toString(recipient);
        inputs[7] = vm.toString(amount);
        inputs[8] = vm.toString(relayer);
        inputs[9] = vm.toString(fee);
        inputs[10] = vm.toString(abi.encode(pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    struct GetPartialWithdrawProveStruct {
        uint256 leafIndex;
        uint256 changeLeafIndex;
        bytes32 nullifier;
        bytes32 changeNullifier;
        bytes32 nullifierHash;
        bytes32 changeCommitmentHash;
        uint256 denomination;
        address recipient;
        uint256 amount;
        address relayer;
        uint256 fee;
        bytes32[] pushedCommitments;
    }

    // todo adding @ notice
    function getPartialWithdrawProve(GetPartialWithdrawProveStruct memory getPartialWithdrawProveStruct)
        internal
        returns (bytes memory)
    {
        string[] memory inputs = new string[](15);
        inputs[0] = "node";
        inputs[1] = "test/utils/getPartialWithdrawProve.cjs";
        inputs[2] = "20";
        inputs[3] = vm.toString(getPartialWithdrawProveStruct.leafIndex);
        inputs[4] = vm.toString(getPartialWithdrawProveStruct.changeLeafIndex);
        inputs[5] = vm.toString(getPartialWithdrawProveStruct.nullifier);
        inputs[6] = vm.toString(getPartialWithdrawProveStruct.changeNullifier);
        inputs[7] = vm.toString(getPartialWithdrawProveStruct.nullifierHash);
        inputs[8] = vm.toString(getPartialWithdrawProveStruct.changeCommitmentHash);
        inputs[9] = vm.toString(getPartialWithdrawProveStruct.denomination);
        inputs[10] = vm.toString(getPartialWithdrawProveStruct.recipient);
        inputs[11] = vm.toString(getPartialWithdrawProveStruct.amount);
        inputs[12] = vm.toString(getPartialWithdrawProveStruct.relayer);
        inputs[13] = vm.toString(getPartialWithdrawProveStruct.fee);
        inputs[14] = vm.toString(abi.encode(getPartialWithdrawProveStruct.pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    function getJsTreeAssertions(bytes32[] memory pushedCommitments, bytes32 newCommitment)
        internal
        returns (bytes32 root_before_commitment, uint256 height, bytes32 root_after_commitment)
    {
        string[] memory inputs = new string[](5);
        inputs[0] = "node";
        inputs[1] = "test/utils/tree.cjs";
        inputs[2] = "20";
        inputs[3] = vm.toString(abi.encode(pushedCommitments));
        inputs[4] = vm.toString(newCommitment);

        bytes memory result = vm.ffi(inputs);
        (root_before_commitment, height, root_after_commitment) = abi.decode(result, (bytes32, uint256, bytes32));
    }
}
