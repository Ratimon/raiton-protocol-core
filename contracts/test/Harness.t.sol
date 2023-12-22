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

    function deployAndAssertCore(address user, bytes32 commitment) internal returns (address[] memory accounts) {
        vm.startPrank(user);

        accounts = core.initiate_1stPhase_Account(commitment);

        assertEq(core.getPendingAccount(commitment, 0), accounts[0]);
        assertEq(core.getPendingAccount(commitment, 1), accounts[1]);
        assertEq(core.getPendingAccount(commitment, 2), accounts[2]);
        assertEq(core.getPendingAccount(commitment, 3), accounts[3]);

        vm.stopPrank();
    }

    function assertAccount(address user, address account, bytes32 commitment, uint256 nonce, uint256 amount) internal {
        vm.startPrank(user);

        IAccount balanceAccount = IAccount(account);

        assertEq32(balanceAccount.commitment(), commitment);
        assertEq(balanceAccount.denomination(), amount);
        assertEq(balanceAccount.cashInflows(), 1);
        assertEq(balanceAccount.cashOutflows(), 4);
        assertEq(balanceAccount.nonce(), nonce);

        vm.stopPrank();
    }

    function commitAndAssertCore(address user, address account, bytes32 commitment, uint256 nonce, uint256 amount)
        internal
        returns (bytes32 returningCommitment)
    {
        startHoax(user, amount);

        assertEq(core.getPendingAccount(commitment, nonce), account);
        assertEq(core.getPendingCommitment(account), commitment);

        uint256 prePendingCommittedAmount = core.getPendingCommittedAmount(account);
        uint256 preOwnerCommittedAmount = core.getOwnerCommittedAmount(user);

        returningCommitment = IAccount(account).commit_2ndPhase{value: amount}();
        assertEq(returningCommitment, commitment);

        assertEq(core.getPendingAccount(returningCommitment, nonce), address(0));

        assertEq(core.getPendingCommitment(account), returningCommitment);
        assertEq(core.getPendingCommittedAmount(account), prePendingCommittedAmount + amount);

        assertEq(core.getOwnerCommitment(user), returningCommitment);
        assertEq(core.getOwnerCommittedAmount(user), preOwnerCommittedAmount + amount);

        vm.stopPrank();
    }

    function clearAndAssertCore(address user, address account, address to, uint256 amount) internal {
        vm.startPrank(user);

        assertTrue(core.getPendingCommitment(account) != bytes32(0));
        assertTrue(core.getPendingCommittedAmount(account) != 0);

        assertTrue(core.getOwnerCommitment(user) != bytes32(0));
        assertTrue(core.getOwnerCommittedAmount(user) != 0);

        uint256 preClearToBalance = to.balance;

        IAccount balanceAccount = IAccount(account);
        balanceAccount.clear_commitment(payable(to));

        assertEq(core.getPendingCommitment(account), bytes32(0));
        assertEq(core.getPendingCommittedAmount(account), 0);

        assertEq(core.getOwnerCommitment(user), bytes32(0));
        assertEq(core.getOwnerCommittedAmount(user), 0);

        assertEq(to.balance - preClearToBalance, amount);

        vm.stopPrank();
    }

    function depositAndAssertCore(
        address user,
        uint256 newLeafIndex,
        bytes32 nullifier,
        bytes32 commitment,
        uint256 amount,
        bytes32[] memory pushedCommitments
    ) internal {
        vm.startPrank(user);

        assertTrue(core.getOwnerCommitment(user) != bytes32(0));
        assertTrue(core.getOwnerCommittedAmount(user) != 0);

        Core.Proof memory depositProof;
        bytes32 newRoot;
        {
            (depositProof, newRoot) = abi.decode(
                getDepositProve(
                    newLeafIndex,
                    core.roots(core.currentRootIndex()),
                    amount,
                    nullifier, //secret
                    commitment,
                    pushedCommitments
                ),
                (Core.Proof, bytes32)
            );
        }

        //todo: assert emit
        core.deposit(depositProof, newRoot);

        assertEq(core.getOwnerCommitment(user), bytes32(0));
        assertEq(core.getOwnerCommittedAmount(user), 0);

        {
            // assert tree root and elements are correct
            (bytes32 preDepositRoot, uint256 elements, bytes32 postDepositRoot) =
                getJsTreeAssertions(pushedCommitments, commitment);
            assertEq(preDepositRoot, core.roots(newLeafIndex));
            assertEq(elements, core.nextIndex());
            assertEq(postDepositRoot, core.roots(newLeafIndex + 1));
        }

        vm.stopPrank();
    }

    function getDepositCommitmentHash(uint256 leafIndex, uint256 denomination) internal returns (bytes memory) {
        string[] memory inputs = new string[](4);
        inputs[0] = "node";
        inputs[1] = "test/utils/getCommitment.cjs";
        inputs[2] = vm.toString(leafIndex);
        inputs[3] = vm.toString(denomination);

        return vm.ffi(inputs);
    }

    function getDepositProve(
        uint256 leafIndex,
        bytes32 oldRoot,
        uint256 denomination,
        bytes32 nullifier,
        bytes32 commitmentHash,
        bytes32[] memory pushedCommitments
    ) internal returns (bytes memory) {
        string[] memory inputs = new string[](9);
        inputs[0] = "node";
        inputs[1] = "test/utils/getDepositProve.cjs";
        inputs[2] = "20";
        inputs[3] = vm.toString(leafIndex);
        inputs[4] = vm.toString(oldRoot);
        inputs[5] = vm.toString(commitmentHash);
        inputs[6] = vm.toString(denomination);
        inputs[7] = vm.toString(nullifier);
        inputs[8] = vm.toString(abi.encode(pushedCommitments));

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

    // todo addinf @ notoce
    // Remove local var error by putting all argument to struct

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
