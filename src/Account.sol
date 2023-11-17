//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// import {CallbackValidation} from "@main/libraries/CallbackValidation.sol";
import {IAccountCommitCallback} from "@main/interfaces/IAccountCommitCallback.sol";

import {IAccountDeployer} from "@main/interfaces/IAccountDeployer.sol";

import  {ICore} from "@main/interfaces/ICore.sol";


contract Account  {

    enum State {
        UNCOMMITED,
        COMMITED,
        DEPOSITED,
        TERMINATED
    }

    State public currentState = State.UNCOMMITED;

    //call relevant states from factory which store merkle roots
    address public immutable factory;

    uint256 public denomination;
    uint256 public paymentNumber;

    // mapping(address => bytes32) pendingCommit;

    constructor() {
        // may remove commitment or replace with new one
        bytes32 commitment;
        uint256 paymentOrder;
        ( factory, commitment, denomination, paymentNumber, paymentOrder) = IAccountDeployer(msg.sender).parameters();

        // if we do atomic commit here, it reduce ...
        // commit(commitment, paymentOrder);

    }

    modifier inState(State state) {
        require(state == currentState, 'current state does not allow');
        _;
    }
    
    function commit_2ndPhase(bytes32 _commitment, uint256 _paymentOrder) external payable inState(State.UNCOMMITED) {

        require(msg.value == denomination, "Incorrect denomination");
        
        // pendingCommit[msg.sender] = _commitment;

        currentState = State.COMMITED;
        IAccountCommitCallback(factory).commit_2ndPhase_Callback(msg.sender, _commitment, _paymentOrder);


        _processDeposit();
    }



    function _processDeposit() internal {
        // do nothing as already mrk payable
    }

    

}

