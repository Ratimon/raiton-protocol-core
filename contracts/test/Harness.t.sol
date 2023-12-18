//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {Groth16Verifier as DepositGroth16Verifier} from "@main/verifiers/DepositVerifier.sol";


contract SharedHarness is Test {

    string mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1); //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

    address deployer = vm.addr(deployerPrivateKey);
    address alice = makeAddr("Alice");

    IDepositVerifier depositVerifier;
    Core core;

    function setUp() public virtual {
        startHoax(deployer,  1 ether);

        vm.label(deployer, "Deployer");

        depositVerifier = IDepositVerifier(address(new DepositGroth16Verifier()));
        core = new Core(depositVerifier, 20, 1 ether, 4);
        vm.label(address(core), "Core");

        vm.stopPrank();
    }

    function deployAccounts(address user, bytes32 commitment)
        internal
        returns (address[] memory accounts)
    {
        // startHoax(user, amount);
        vm.startPrank(user);
        accounts = core.initiate_1stPhase_Account(commitment);

        vm.stopPrank();
    }

    function commitAndAssert(address user, address account, bytes32 commitment, uint256 nonce, uint256 amount)
        internal
        returns (bytes32 returningCommitment)
    {
        startHoax(user, amount);

        assertEq( core.getPendingAccount(commitment, nonce), account);
        assertEq( core.pendingCommitment(user), bytes32(0));
        assertEq( core.submittedCommitments(commitment), false);

        returningCommitment = IAccount(account).commit_2ndPhase{value: amount}();
        assertEq( returningCommitment, commitment);

        assertEq( core.getPendingAccount(returningCommitment, nonce), address(0));
        assertEq( core.pendingCommitment(user), returningCommitment);
        assertEq( core.submittedCommitments(returningCommitment), true);

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