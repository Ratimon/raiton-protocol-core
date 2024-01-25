//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IPartialWithdrawVerifier} from "@main/interfaces/IPartialWithdrawVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

// import {BalanceAccountAddress} from "@main/libraries/AccountAddress.sol";

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

    uint256 public staticTime;

    //todo refactor to deployment script
    function setUp() public virtual {
        startHoax(deployer, 1 ether);

        vm.label(deployer, "Deployer");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
        vm.label(dave, "Dave");

        depositVerifier = IDepositVerifier(address(new DepositGroth16Verifier()));
        partialWithdrawVerifier = IPartialWithdrawVerifier(address(new PartialWithdrawVerifier()));

        core = new Core(depositVerifier, partialWithdrawVerifier, 20, 1 ether, 4);
        vm.label(address(core), "Core");

        staticTime = block.timestamp;
        vm.warp({newTimestamp: staticTime});

        vm.stopPrank();
    }


}
