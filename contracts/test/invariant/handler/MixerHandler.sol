// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test} from "@forge-std/Test.sol";


import {Core} from "@main/Core.sol";

import {AddressSet, LibAddressSet} from "@test/invariant/helpers/AddressSet.sol";
import {ByteSet, LibByteSet} from "@test/invariant/helpers/ByteSet.sol";


uint256 constant ETH_SUPPLY = 100_000_000 ether;

contract MixerHandler is Test {

    using LibAddressSet for AddressSet;
    using LibByteSet for ByteSet;


    Core internal _core;

    mapping(bytes32 => uint256) public calls;

    AddressSet internal _actors;
    address internal currentActor;

    ByteSet internal _nullifierHashes;
    bytes32 internal currentnullifierHash;

    modifier createActor() {
        currentActor = msg.sender;
        _actors.add(msg.sender);
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actors.rand(actorIndexSeed);
        _;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }


    // todo: config scalling point
    constructor(address core_) {
        _core = Core(core_);
        deal(address(this), ETH_SUPPLY);

    }

    function deposit() public createActor countCall("deposit") {
        // amount_ = bound(amount_, 1, 1e29); // 100 billion at WAD precision
        uint256 amount = 1 ether;

        _pay(currentActor, amount);

        vm.prank(currentActor);

        // init
        // core.init_1stPhase_Account(commitment);

        //commit
        
        //deposit
        
    }

    function withdraw() public createActor countCall("withdraw") {

        
    }

    function _pay(address to, uint256 amount) internal {
        (bool s,) = to.call{value: amount}("");
        require(s, "pay() failed");
    }

    receive() external payable {}

}