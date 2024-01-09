//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IPartialWithdrawVerifier} from "@main/interfaces/IPartialWithdrawVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {Groth16Verifier as DepositGroth16Verifier} from "@main/verifiers/DepositVerifier.sol";
import {Groth16Verifier as PartialWithdrawVerifier} from "@main/verifiers/PartialWithdrawVerifier.sol";

contract SharedHarness is Test {
    string mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1); //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

    address deployer = vm.addr(deployerPrivateKey);
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address carol = makeAddr("Carol");
    address dave = makeAddr("Dave");

    address relayer_signer = makeAddr("Relayer");

    IDepositVerifier depositVerifier;
    IPartialWithdrawVerifier partialWithdrawVerifier;
    Core core;

    function setUp() public virtual {
        startHoax(deployer, 1 ether);

        vm.label(deployer, "Deployer");

        depositVerifier = IDepositVerifier(address(new DepositGroth16Verifier()));
        partialWithdrawVerifier = IPartialWithdrawVerifier(address(new PartialWithdrawVerifier()));

        core = new Core(depositVerifier, partialWithdrawVerifier, 20, 1 ether, 4);
        vm.label(address(core), "Core");

        vm.stopPrank();
    }

    struct DeployReturnStruct {
        address account;
        uint256 nonce;
    }
    function deployAndAssertCore(address user, bytes32 commitment) internal returns (DeployReturnStruct[] memory deployReturns) {
        vm.startPrank(user);

        address[] memory accounts = core.initiate_1stPhase_Account(commitment);
       
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

        // todo: add assertion for pendingDeposit

        vm.stopPrank();
    }

    function assertAccount(address user, address account, bytes32 commitment, uint256 amount, uint256 nonce , uint256 inflow, uint256 outflow) internal {
        vm.startPrank(user);

        IAccount balanceAccount = IAccount(account);

        assertEq32(balanceAccount.commitment(), commitment);
        assertEq(balanceAccount.denomination(), amount);
        assertEq(balanceAccount.cashInflows(), inflow);
        assertEq(balanceAccount.cashOutflows(), outflow);
        assertEq(balanceAccount.nonce(), nonce);

        vm.stopPrank();
    }

    function commitNewAndAssertCore(address user, address[] memory preAccounts, address newAccount, bytes32 commitment, uint256 nonce, uint256 amount)
        internal
        returns (address[] memory postAccounts)
    {
        startHoax(user, amount);

        assertEq(core.getPendingAccountToCommit(commitment, nonce), newAccount);
        assertEq(core.getPendingCommitmentToDeposit(newAccount), commitment);

        uint256 prePendingCommittedAmount = core.getPendingCommittedAmountToDeposit(newAccount);
        uint256 preOwnerCommittedAmount = core.getOwnerCommittedAmount(user);

        assertEq(core.getOwnerAccounts(user), preAccounts);

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

        uint256 returningAmount = IAccount(bottomAccount).commitExisting_2ndPhase{value: amountToCommit}(alice, newCommitment);
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

    address[] emptyArrays ;
    function clearAndAssertCore(address user, address[] memory preAccounts, address account, address to, uint256 amount) internal {
        vm.startPrank(user);

        assertTrue(core.getPendingCommitmentToDeposit(account) != bytes32(0));
        assertTrue(core.getPendingCommittedAmountToDeposit(account) != 0);

        assertTrue(core.getOwnerCommitment(user) != bytes32(0));
        assertTrue(core.getOwnerCommittedAmount(user) != 0);

        assertEq(core.getOwnerAccounts(user), preAccounts);

        IAccount balanceAccount = IAccount(account);
        balanceAccount.clear_commitment(payable(to));

        assertEq(core.getPendingCommitmentToDeposit(account), bytes32(0));
        assertEq(core.getPendingCommittedAmountToDeposit(account), 0);

        assertEq(core.getOwnerCommitment(user), bytes32(0));
        assertEq(core.getOwnerCommittedAmount(user), 0);

        delete emptyArrays;
        assertEq(core.getOwnerAccounts(user), emptyArrays);

        vm.stopPrank();
    }

    function depositAndAssertCore(
        address user,
        address[] memory preAccounts,
        uint256 newLeafIndex,
        bytes32 nullifier,
        bytes32 commitment,
        uint256 amount,
        bytes32[] memory existingCommitments
    ) internal returns (bytes32[] memory pushedCommitments)  {
        vm.startPrank(user);

        Core.Proof memory depositProof;
        bytes32 newRoot;
        {
            (depositProof, newRoot) = abi.decode(
                getDepositProve(
                    GetDepositProveStruct(
                        newLeafIndex,
                        core.roots(core.currentRootIndex()),
                        amount,
                        nullifier, //secret
                        commitment,
                        existingCommitments
                    )
                ),
                (Core.Proof, bytes32)
            );
        }

        uint128 _currentRootIndex = core.currentRootIndex();
        //initialRootZero
        // todo: handle case when it is not 'initialRootZero'
        assertEq(core.roots( _currentRootIndex), 0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb );
        assertEq(core.roots( _currentRootIndex + 1 ), bytes32(0));

        assertFalse(core.getSubmittiedCommitment(commitment));

        assertTrue(core.getOwnerCommitment(user) != bytes32(0));
        assertTrue(core.getOwnerCommittedAmount(user) != 0);
        assertEq(core.getOwnerAccounts(user), preAccounts);

        //todo: assert emit
        core.deposit(depositProof, newRoot);

        assertTrue(core.getSubmittiedCommitment(commitment));

        assertEq(core.roots( core.currentRootIndex()), newRoot);
        assertEq( core.currentRootIndex(), _currentRootIndex + 1);

        {
            // assert tree root and elements are correct
            (bytes32 preDepositRoot, uint256 elements, bytes32 postDepositRoot) =
                getJsTreeAssertions(existingCommitments, commitment);
            assertEq(preDepositRoot, core.roots(newLeafIndex));
            assertEq(elements, core.nextIndex());
            assertEq(postDepositRoot, core.roots(newLeafIndex + 1));
        }

        assertEq(core.getOwnerCommitment(user), bytes32(0));
        assertEq(core.getOwnerCommittedAmount(user), 0);
        delete emptyArrays;
        assertEq(core.getOwnerAccounts(user), emptyArrays);

        vm.stopPrank();

        pushedCommitments = new bytes32[](existingCommitments.length + 1);
        for (uint256 i = 0; i < existingCommitments.length; i++) {
            pushedCommitments[i] = existingCommitments[i];
        }
        pushedCommitments[pushedCommitments.length-1] = commitment;
        return pushedCommitments;
    }

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
    }
    function partialWithdrawAndAssertCore(
        PartialWithdrawStruct memory partialWithdrawStruct
    ) internal returns(bytes32[] memory pushedCommitments) {
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
                        // partialWithdrawStruct.denomination, // amount = denomination / payment number
                        relayer_signer,
                        partialWithdrawStruct.fee, // fee
                        partialWithdrawStruct.pushedCommitments
                    )

                ),
                (Core.Proof, bytes32, bytes32)
            );
        }

        assertEq(core.getWithdrawnAmount(partialWithdrawStruct.nullifierHash), 0);
        assertEq(core.getIsNullified(partialWithdrawStruct.nullifierHash), false);

        uint128 _currentRootIndex = core.currentRootIndex();
        assertEq(core.roots( _currentRootIndex  ), root);
        assertEq(core.roots( _currentRootIndex + 1 ), bytes32(0));

        uint256 preWithdrawAccountBalance = core.getBalance(core.getBottomAccount());

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

        assertEq(core.roots( core.currentRootIndex() - 1 ), root);
        assertEq(core.roots(core.currentRootIndex()), newRoot);
        assertEq(core.currentRootIndex(), _currentRootIndex + 1);

        assertEq(core.getWithdrawnAmount(partialWithdrawStruct.nullifierHash), partialWithdrawStruct.amountToWithdraw);
        // TODO fix when scenario of 4 time partial withdrawn
        assertEq(core.getIsNullified(partialWithdrawStruct.nullifierHash), false);

        assertEq( preWithdrawAccountBalance - core.getBalance(core.getBottomAccount()), 0 ether);

        vm.stopPrank();

        pushedCommitments = new bytes32[](partialWithdrawStruct.pushedCommitments.length + 1);

        for (uint256 i = 0; i < partialWithdrawStruct.pushedCommitments.length; i++) {
            pushedCommitments[i] = partialWithdrawStruct.pushedCommitments[i];
        }
        pushedCommitments[pushedCommitments.length-1] = partialWithdrawStruct.commitment;

        return pushedCommitments;

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

    function getDepositProve(
        GetDepositProveStruct memory getDepositProveStruct
    ) internal returns (bytes memory) {
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
    function getPartialWithdrawProve(
        GetPartialWithdrawProveStruct memory getPartialWithdrawProveStruct
    )
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
