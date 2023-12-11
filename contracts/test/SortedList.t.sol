//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console2, stdError} from "@forge-std/Test.sol";

import {SortedList} from "@main/utils/SortedList.sol";

contract MockSortedList is SortedList{
    constructor() SortedList() {}

    function addAccount(address account, uint256 amount) external {
        _addAccount(account, amount);
    }

    function removeAccount(address account) external {
        _removeAccount(account);
    }
}


contract SortedListTest is Test {

    string mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1); //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

    address deployer = vm.addr(deployerPrivateKey);
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address carol = makeAddr("Carol");
    address dave = makeAddr("Dave");

    MockSortedList list;

    function setUp() public {
        vm.startPrank(deployer);

        vm.deal(deployer, 1 ether);
        vm.label(deployer, "Deployer");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
        vm.label(dave, "Dave");

        list = new MockSortedList();
        vm.label(address(list), "MockSortedList");

        vm.stopPrank();
    }

    function test_addAccount() external {
        vm.startPrank(deployer);

        list.addAccount(alice, 1 ether);
        list.addAccount(bob, 2 ether);
        list.addAccount(carol, 3 ether);
        list.addAccount(dave, 4 ether);

        address[] memory accounts = list.getTop(4);

        assertEq(accounts[0], dave);
        assertEq(accounts[1], carol);
        assertEq(accounts[2], bob);
        assertEq(accounts[3], alice);

        address lowestAccount = list.getBottom();
        assertEq(lowestAccount, alice);

        vm.stopPrank();
    }

    function test_removeAccount() external {

        vm.startPrank(deployer);

        list.addAccount(alice, 1 ether);
        list.addAccount(bob, 2 ether);
        list.addAccount(carol, 3 ether);
        list.addAccount(dave, 4 ether);

        list.removeAccount(carol);
        list.removeAccount(alice);
        
        address[] memory accounts = list.getTop(2);

        assertEq(accounts[0], dave);
        assertEq(accounts[1], bob);

        address lowestAccount = list.getBottom();
        assertEq(lowestAccount, bob);

        vm.stopPrank();
    }

    function test_getBottom() external {
        vm.startPrank(deployer);

        list.addAccount(alice, 1 ether);
        list.addAccount(bob, 2 ether);
        list.addAccount(carol, 3 ether);
        list.addAccount(dave, 4 ether);

        address lowestAccount = list.getBottom();
        assertEq(lowestAccount, alice);

        vm.stopPrank();
    }

}
