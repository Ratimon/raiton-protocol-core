//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// import {CallbackValidation} from "@main/libraries/CallbackValidation.sol";
import {IAccountCommitCallback} from "@main/interfaces/IAccountCommitCallback.sol";
import {IAccountDeployer} from "@main/interfaces/IAccountDeployer.sol";

// import  {ICore} from "@main/interfaces/ICore.sol";

/**
 * @title Account
 * @notice the bottom layer with dependency inversion of callback
 */
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

    bytes32 public commitment;
    uint256 public denomination;
    uint256 public paymentNumber;
    uint256 public paymentOrder;

    // mapping(address => bytes32) pendingCommit;

    constructor() {
        ( factory, commitment, denomination, paymentNumber, paymentOrder) = IAccountDeployer(msg.sender).parameters();

        // if we do atomic commit here, it reduce ...
        // commit(commitment, paymentOrder);

    }

    modifier inState(State state) {
        require(state == currentState, 'current state does not allow');
        _;
    }
    
    function commit_2ndPhase() external payable inState(State.UNCOMMITED) {

        require(msg.value == denomination, "Incorrect denomination");
        
        // pendingCommit[msg.sender] = _commitment;

        currentState = State.COMMITED;
        IAccountCommitCallback(factory).commit_2ndPhase_Callback(msg.sender, commitment, paymentOrder);


        _processDeposit();
    }

    // TODO adding param `to` as receiver address
    function clear_commitment() external inState(State.COMMITED) {

        // require(pendingCommit[msg.sender].commitment != bytes32(0), "not committed");
        // uint256 denomination = pendingCommit[msg.sender].denomination;
        // delete pendingCommit[msg.sender];

        currentState = State.UNCOMMITED;
        IAccountCommitCallback(factory).clear_commitment_Callback(msg.sender, paymentOrder);
        _processWithdraw();

    }



    // TODO fill missed arguments
    function _processDeposit() internal {
        // do nothing as already mrk payable
    }

    function _processWithdraw() internal {
        // mock as empty now
    }

    

}

