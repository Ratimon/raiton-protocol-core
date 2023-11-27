//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {Core} from "@main/Core.sol";

contract CoreTest is Test {

    string mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1); //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

    address deployer = vm.addr(deployerPrivateKey);
    address alice = makeAddr("Alice");

    Core core;

    function setUp() public {
        vm.startPrank(deployer);

        vm.deal(deployer, 1 ether);
        vm.label(deployer, "Deployer");

        core = new Core(1 ether, 4);
        vm.label(address(core), "ECOperations");

        vm.stopPrank();
    }

    function test_initiate_1stPhase_Account() external {
        vm.startPrank(alice);

        vm.deal(alice, 1 ether);

        //commitment hash =  poseidonHash(nullifier, 0, denomination)
        //nullifer hash =  poseidonHash(nullifier, 1, leafIndex, denomination)

        bytes32 commitment;

        core.initiate_1stPhase_Account(commitment);


    }



}