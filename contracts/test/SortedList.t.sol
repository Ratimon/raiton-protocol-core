//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {SortedList} from "@main/utils/SortedList.sol";

contract MockSortedList is SortedList{
    constructor() SortedList() {}

    function addAccount(address account, uint256 amount) external {
        _addAccount(account, amount);
    }
}


contract SortedListTest is Test {

    string mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1); //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

    address deployer = vm.addr(deployerPrivateKey);
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");

    MockSortedList list;

    function setUp() public {
        vm.startPrank(deployer);

        vm.deal(deployer, 1 ether);
        vm.label(deployer, "Deployer");

        list = new MockSortedList();
        vm.label(address(list), "MockSortedList");

        vm.stopPrank();
    }

    function test_add_Account() external {
        vm.startPrank(deployer);

        list.addAccount(alice, 1 ether);
        list.addAccount(bob, 2 ether);

        vm.stopPrank();

    }

}
