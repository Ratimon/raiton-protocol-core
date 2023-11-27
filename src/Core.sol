//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {CallbackValidation} from "@main/libraries/CallbackValidation.sol";

import {IPoolsCounterBalancer} from "@main/interfaces/IPoolsCounterBalancer.sol";


import  {NoDelegateCall} from "@main/NoDelegateCall.sol";
import  {AccountDeployer} from "@main/AccountDeployer.sol";

import { SortedList } from "@main/utils/SortedList.sol";


contract Core is IPoolsCounterBalancer, SortedList, AccountDeployer, NoDelegateCall {

    uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant ROOT_HISTORY_SIZE = 30;
    bytes32 constant initialRootZero = 0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb; // Keccak256("Tornado")

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


    mapping(address => address) public accountToOracle;

    uint256 public liquidityCoverageSchellingRatio;


    uint256 rotateCounter;
    uint256 rotateCounterCumulativeLast;

    event Commit(bytes32 indexed commitment, uint256 timestamp);
    event Clear(bytes32 indexed commitment, uint256 timestamp);
    event Insert(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);

    constructor(
        uint256 _denomination,
        uint256 _paymentNumber
    ) {
        require(_denomination > 0, "must be > than 0");
        denomination = _denomination;
        paymentNumber = _paymentNumber;
    }


    // TODO annuity commit - low level commit
    // TODO  fee entrance to prevent DOS?
    // TODO  pausable / re-entrancy libs ? 
    // TODO whoever can create their smart contract and deploly to participate 
    function initiate_1stPhase_Account(
        bytes32 commitment
    ) external noDelegateCall returns (address account) {

        require(uint256(commitment) < FIELD_SIZE, "commitment not in field");

        // TODO : the loop number will depends on the schelling point
        for (uint256 i = 0; i < paymentNumber; i++) {
            //sanity check for commitment

            // TODO : now hardcoded inflow and out flow as 1 and paymentNumber
            account = deploy(address(this), commitment, denomination, 1, paymentNumber , i);

            getAccountByCommitment[commitment] = account;
            getCommitmentByAccount[account] = commitment;
            addAccount(account, 1);
        
            // TODO emit event
            
        }
        
    }

    // set
    // 1) insert
    // 2) withdraw

    // call from child contract
    function commit_2ndPhase_Callback(address caller, address account, bytes32 commitment, uint256 nonce) external payable override {

        require(uint256(commitment) < FIELD_SIZE, "commitment not in field");
        require( commitment != bytes32(0), "invalid commitment");
        // require(getCommitmentByDepositor[caller] == commitment, "ensure caller == deployer ");

        require(pendingCommit[msg.sender] == bytes32(0), "Pending commitment hash");
        
        // still needed to prevent redundant hash from the same sender
        require(!submittedCommitments[commitment], "The commitment has been submitted");

        // only callable by child account(  ie deployer must be factory - address(this))
        // TODO check if we need to include denomination
        // TODO return ?
        CallbackValidation.verifyCallback(address(this), commitment, nonce);
        pendingCommit[caller] = commitment;
        submittedCommitments[commitment] = true;

        getAccountByCommitment[commitment] = account;
        getCommitmentByAccount[account] = commitment;
        addAccount(account, 1);

    }

    function clear_commitment_Callback(address caller, uint256 nonce) external override {

        bytes32 _pendingCommit = pendingCommit[caller];

        require(_pendingCommit!= bytes32(0), "not committed");
       
        CallbackValidation.verifyCallback(address(this), _pendingCommit, nonce);
        delete pendingCommit[caller];
        delete submittedCommitments[_pendingCommit];

        address account = getAccountByCommitment[_pendingCommit];
        delete getAccountByCommitment[_pendingCommit];
        delete getCommitmentByAccount[account];
        removeAccount(account);

        emit Clear(_pendingCommit, block.timestamp);

    }

    // get
    // 1) stat (loop)
    // 2) balance

    


}
