//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {CallbackValidation} from "@main/libraries/CallbackValidation.sol";

import {IAccountCommitCallback} from "@main/interfaces/IAccountCommitCallback.sol";


import  {NoDelegateCall} from "@main/NoDelegateCall.sol";
import  {AccountDeployer} from "@main/AccountDeployer.sol";

import { IHasher, MerkleTreeWithHistory } from "@main/MerkleTreeWithHistory.sol";


contract Core is IAccountCommitCallback, MerkleTreeWithHistory, AccountDeployer, NoDelegateCall {

    // store all states
    // add a redeployable stateless router to query the address

    uint256 public accountCurrentNumber = 0;
    uint256 public accountSchellingNumber = 4;
    uint256 public accountNumberCumulativeLast;

    uint256 public denomination;
    uint256 public paymentNumber;

    mapping(address => bytes32) pendingCommit;

    mapping(bytes32 => address) public getAccountByCommitment;

    /// @notice Array of all Accounts held in the Protocol. Used for iteration on accounts
    address[] private accountsInPool;

    mapping(address => address) public accountToOracle;

    uint256 public liquidityCoverageSchellingRatio;


    uint256 rotateCounter;
    uint256 rotateCounterCumulativeLast;

    constructor(
        IHasher _hasher,
        uint32 _merkleTreeHeight,
        uint256 _denomination,
        uint256 _paymentNumber
    ) MerkleTreeWithHistory(_merkleTreeHeight, _hasher) {
        require(_denomination > 0, "must be > than 0");
        denomination = _denomination;
        paymentNumber = _paymentNumber;
    }


    function createAccount(
        bytes32 commitment
    ) external noDelegateCall returns (address account) {

        //sanity check for commitment
        account = deploy(address(this), commitment, paymentNumber);
        getAccountByCommitment[commitment] = account;
        
    }

    // set
    // 1) insert
    // 2) withdraw

    // function commit(bytes32 _commitment) external payable {


    //     IAccountCommitCallback(msg.sender).accountCommitCallback(_commitment);
    // }

    function accountCommitCallback(address _caller, bytes32 _commitment) external payable override {

        require(pendingCommit[msg.sender] == bytes32(0), "Pending commitment hash");
        require(uint256(_commitment) < FIELD_SIZE, "_commitment not in field");

        // only callable by account (msg.sender)
        // TODO check if we need to include denomination
        CallbackValidation.verifyCallback(msg.sender, _commitment, paymentNumber);

        pendingCommit[_caller] = _commitment;
    }

    // get
    // 1) stat (loop)
    // 2) balance

    


}
