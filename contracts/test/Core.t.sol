//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/Account.sol";


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

        depositVerifier =  IDepositVerifier(address(new DepositGroth16Verifier()));
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

        assertEq32(IAccount(accounts[0]).commitment(), commitment);
        assertEq32(IAccount(accounts[1]).commitment(), commitment);
        assertEq32(IAccount(accounts[2]).commitment(), commitment);
        assertEq32(IAccount(accounts[3]).commitment(), commitment);


        assertEq(IAccount(accounts[0]).denomination(), 1 ether );
        assertEq(IAccount(accounts[1]).denomination(), 1 ether );
        assertEq(IAccount(accounts[2]).denomination(), 1 ether );
        assertEq(IAccount(accounts[3]).denomination(), 1 ether );

        assertEq(IAccount(accounts[0]).cashInflows(), 1);
        assertEq(IAccount(accounts[1]).cashInflows(), 1);
        assertEq(IAccount(accounts[2]).cashInflows(), 1);
        assertEq(IAccount(accounts[3]).cashInflows(), 1);

        assertEq(IAccount(accounts[0]).cashOutflows(), 4);
        assertEq(IAccount(accounts[1]).cashOutflows(), 4);
        assertEq(IAccount(accounts[2]).cashOutflows(), 4);
        assertEq(IAccount(accounts[3]).cashOutflows(), 4);

        assertEq(IAccount(accounts[0]).nonce(), 0);
        assertEq(IAccount(accounts[1]).nonce(), 1);
        assertEq(IAccount(accounts[2]).nonce(), 2);
        assertEq(IAccount(accounts[3]).nonce(), 3);

        vm.stopPrank();


    }

    function test_commit_2ndPhase_Callback() external {

        vm.startPrank(alice);

        vm.deal(alice, 1 ether);


        bytes32 commitment = bytes32(uint256(1));

        address[] memory accounts = core.initiate_1stPhase_Account(commitment);

        assertEq32(IAccount(accounts[0]).commitment(), commitment);

        IAccount account1 = IAccount(accounts[0]);

        account1.commit_2ndPhase{value : 1 ether}();



        vm.stopPrank();

    }


}