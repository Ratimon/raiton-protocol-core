//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {Groth16Verifier as DepositGroth16Verifier} from "@main/verifiers/DepositVerifier.sol";

contract CoreTest is Test {
    string mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1); //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

    address deployer = vm.addr(deployerPrivateKey);
    address alice = makeAddr("Alice");

    IDepositVerifier depositVerifier;
    Core core;

    function setUp() public {
        startHoax(deployer,  1 ether);

        vm.label(deployer, "Deployer");

        depositVerifier = IDepositVerifier(address(new DepositGroth16Verifier()));
        core = new Core(depositVerifier, 20, 1 ether, 4);
        vm.label(address(core), "ECOperations");

        vm.stopPrank();
    }

    function test_initiate_1stPhase_Account() external {
        startHoax(alice,  1 ether);

        //commitment hash =  poseidonHash(nullifier, 0, denomination)
        //nullifer hash =  poseidonHash(nullifier, 1, leafIndex, denomination)

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        assertEq( core.getPendingAccount(commitment, 0), accounts[0]);
        assertEq( core.getPendingAccount(commitment, 1), accounts[1]);
        assertEq( core.getPendingAccount(commitment, 2), accounts[2]);
        assertEq( core.getPendingAccount(commitment, 3), accounts[3]);


        vm.stopPrank();
    }

    function test_commit_2ndPhase_Callback() external {
        startHoax(alice,  1 ether);

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        IAccount account_1 = IAccount(accounts[0]);

        assertEq( core.getPendingAccount(commitment, 1), accounts[1]);
        assertEq( core.pendingCommitment(alice), bytes32(0));
        assertEq( core.submittedCommitments(commitment), false);

        //todo: assert emit
        bytes32 returningCommitment = account_1.commit_2ndPhase{value: 1 ether}();
        assertEq( returningCommitment, commitment);
        assertEq( core.getPendingAccount(returningCommitment, 0), address(0));
        assertEq( core.pendingCommitment(alice), returningCommitment);
        assertEq( core.submittedCommitments(returningCommitment), true);

        address[] memory topAccounts = core.getTop(1);
        assertEq(topAccounts[0], address(account_1));

        address lowestAccount = core.getBottom();
        assertEq(lowestAccount, address(account_1));

        vm.stopPrank();
    }

    function test_clear_commitment_Callback() external {
        startHoax(alice,  1 ether);

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        IAccount account_1 = IAccount(accounts[0]);

        account_1.commit_2ndPhase{value: 1 ether}();
         //todo: assert emit
        account_1.clear_commitment(payable(alice));

        assertEq( core.pendingCommitment(alice), bytes32(0));
        assertEq( core.submittedCommitments(commitment), false);
        vm.stopPrank();
    }

    function test_deposit() external {
        startHoax(alice,  1 ether);

        uint256 newLeafIndex = 0;
        (bytes32 commitment, , bytes32 nullifier) = abi.decode(getDepositCommitmentHash(newLeafIndex, 1 ether), (bytes32, bytes32, bytes32));
        bytes32[] memory pushedCommitments = new bytes32[](0) ;

        // console2.log("commitment");
        // console2.logBytes32(commitment);

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
                    nullifier,
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
    ) private returns (bytes memory) {
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
        private
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
