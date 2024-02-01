// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test, console, console2 } from "@forge-std/Test.sol";

import {IAccount} from "@main/interfaces/IAccount.sol";


import {Core} from "@main/Core.sol";

import {AddressSet, LibAddressSet} from "@test/invariant/helpers/AddressSet.sol";
import {ByteSet, LibByteSet} from "@test/invariant/helpers/ByteSet.sol";

import {CoreHarness} from "@test/harness/Core.harness.t.sol";


uint256 constant ETH_SUPPLY = 100_000_000 ether;

contract MixerHandler is CoreHarness {

    using LibAddressSet for AddressSet;
    using LibByteSet for ByteSet;

    Core internal _core;

    mapping(bytes32 => uint256) public calls;

    AddressSet internal _actors;
    address internal currentActor;

    ByteSet internal _nullifierHashes;
    bytes32 internal currentnullifierHash;

    AddressSet internal _accounts;

    bytes32[] internal currentExistingCommitments;

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
        uint256 denomination = 1 ether;

        _pay(currentActor, denomination);

        vm.startPrank(currentActor);

        // init
        uint256 newLeafIndex = 0;
        (bytes32 commitment,, bytes32 nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex, denomination), (bytes32, bytes32, bytes32));
        
        address[] memory accounts = _core.init_1stPhase_Account(commitment);

        //commit
        for (uint256 i = 0; i < accounts.length; i++) {
            IAccount(accounts[i]).commitNew_2ndPhase{value: 0.25 ether}();

            // add to accounts
            _accounts.add(accounts[i]);
        }

        //deposit

        Core.Proof memory depositProof;
        bytes32 newRoot;
        {
            (depositProof, newRoot) = abi.decode(
                getDepositProve(
                    GetDepositProveStruct(
                        newLeafIndex,
                        _core.roots(_core.currentRootIndex()),
                        denomination,
                        nullifier, //secret
                        commitment,
                        currentExistingCommitments
                    )
                ),
                (Core.Proof, bytes32)
            );
        }

        //
        currentExistingCommitments.push(commitment);
        _core.deposit(depositProof, newRoot);

        vm.stopPrank();

    }

    function withdraw() public createActor countCall("withdraw") {

        
    }

    function reduceActors(uint256 acc, function(uint256,address) external returns (uint256) func)
        public
        returns (uint256)
    {
        return _actors.reduce(acc, func);
    }

    function reduceAccounts(uint256 acc, function(uint256,address) external returns (uint256) func)
        public
        returns (uint256)
    {
        return _accounts.reduce(acc, func);
    }

    function callSummary() external view {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("deposit", calls["deposit"]);
        console.log("withdraw", calls["withdraw"]);
        console.log("-------------------");

    }

    function _pay(address to, uint256 amount) internal {
        (bool s,) = to.call{value: amount}("");
        require(s, "pay() failed");
    }

    receive() external payable {}

}