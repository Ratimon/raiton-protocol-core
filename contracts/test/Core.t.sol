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
        vm.startPrank(deployer);

        vm.deal(deployer, 1 ether);
        vm.label(deployer, "Deployer");

        depositVerifier = IDepositVerifier(address(new DepositGroth16Verifier()));
        core = new Core(depositVerifier, 1 ether, 4);
        vm.label(address(core), "ECOperations");

        vm.stopPrank();
    }

    function test_initiate_1stPhase_Account() external {
        vm.startPrank(alice);

        vm.deal(alice, 1 ether);

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
        vm.startPrank(alice);

        vm.deal(alice, 1 ether);

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        IAccount account_1 = IAccount(accounts[0]);

        assertEq( core.getPendingAccount(commitment, 1), accounts[1]);
        assertEq( core.pendingCommitment(alice), bytes32(0));
        assertEq( core.submittedCommitments(commitment), false);

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

        vm.deal(alice, 1 ether);

        bytes32 commitment = bytes32(uint256(1));
        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        IAccount account_1 = IAccount(accounts[0]);

        account_1.commit_2ndPhase{value: 1 ether}();
        account_1.clear_commitment(payable(alice));

        assertEq( core.pendingCommitment(alice), bytes32(0));
        assertEq( core.submittedCommitments(commitment), false);

    }
}
