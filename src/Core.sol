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

    // TODO ?
    mapping(bytes32 => bool) public submittedCommitments;
     // TODO ? do we need?
    mapping(bytes32 => address) public getAccountByCommitment;

    // TODO ?
    mapping(address => bytes32) public getCommitmentByAccount;
    // TODO ?
    mapping(address => bytes32) public pendingCommit;

    // TODO  new sorted array by balance of account

    /// @notice Array of all Accounts held in the Protocol. Used for iteration on accounts
    address[] private accountsInPool;

    mapping(address => address) public accountToOracle;

    uint256 public liquidityCoverageSchellingRatio;


    uint256 rotateCounter;
    uint256 rotateCounterCumulativeLast;

    event Commit(bytes32 indexed commitment, uint256 timestamp);
    event Clear(bytes32 indexed commitment, uint256 timestamp);
    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);


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


    // TODO  fee entrance to prevent DOS?
    // TODO  pausaable / re-entrancy libs ? 
    // TODO whoever can create their smart contract and deploly to participate 
    function commit_1stPhase_Account(
        bytes32 _commitment
    ) external noDelegateCall returns (address account) {

        require(uint256(_commitment) < FIELD_SIZE, "_commitment not in field");

        // TODO : the loop number will depends on the schelling point
        for (uint256 i = 0; i < paymentNumber; i++) {
            //sanity check for commitment
            account = deploy(address(this), _commitment, denomination, paymentNumber, i);

            getAccountByCommitment[_commitment] = account;
            getCommitmentByAccount[account] = _commitment;
           
            // TODO emit event
            
        }
        
        
    }

    // set
    // 1) insert
    // 2) withdraw

    // call from child contract
    function commit_2ndPhase_Callback(address caller, bytes32 _commitment, uint256 paymentOrder) external payable override {

        require(uint256(_commitment) < FIELD_SIZE, "_commitment not in field");
        require( _commitment != bytes32(0), "invalid commitment");
        // require(getCommitmentByDepositor[caller] == _commitment, "ensure caller == deployer ");


        require(pendingCommit[msg.sender] == bytes32(0), "Pending commitment hash");
        
        // still needed to prevent redundant hash from the same sender
        require(!submittedCommitments[_commitment], "The commitment has been submitted");

        // only callable by child account(  ie deployer must be factory - address(this))
        // TODO check if we need to include denomination
        // TODO return ?
        CallbackValidation.verifyCallback(address(this), _commitment, paymentOrder);

        pendingCommit[caller] = _commitment;
        submittedCommitments[_commitment] = true;

        // //sanity check for commitment
        // account = deploy(address(this), _commitment, denomination, paymentNumber);
        // getAccountByCommitment[_commitment] = msg.sender;
    }

    function clear_commitment_Callback(address caller, uint256 paymentOrder) external override {

        bytes32 _pendingCommit = pendingCommit[caller];

        require(_pendingCommit!= bytes32(0), "not committed");
       
        CallbackValidation.verifyCallback(address(this), _pendingCommit, paymentOrder);
        delete pendingCommit[caller];
        delete submittedCommitments[_pendingCommit];

        emit Clear(_pendingCommit, block.timestamp);

    }

    // get
    // 1) stat (loop)
    // 2) balance

    


}
