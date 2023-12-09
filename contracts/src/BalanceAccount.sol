//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// import {CallbackValidation} from "@main/libraries/CallbackValidation.sol";
import {IPoolsCounterBalancer} from "@main/interfaces/IPoolsCounterBalancer.sol";
import {IAccountDeployer} from "@main/interfaces/IAccountDeployer.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// import  {ICore} from "@main/interfaces/ICore.sol";

// TODO abstract into 2 types annuoty and endowmwnt
/**
 * @title Account
 * @notice the bottom layer with dependency inversion of callback
 */
contract BalanceAccount {
    enum State {
        UNCOMMITED,
        COMMITED,
        TERMINATED
    }

    State public currentState = State.UNCOMMITED;

    //call relevant states from factory which store merkle roots
    /**
     * @notice the bottom layer with dependency inversion of callback
     */
    address public immutable factory;

    bytes32 public immutable commitment;
    uint256 public immutable denomination;
    uint256 public immutable cashInflows;
    uint256 public immutable cashOutflows;
    uint256 public immutable nonce;

    // mapping(address => bytes32) pendingCommit;

    event Withdrawal(address indexed _caller, address indexed _to, uint256 _amount);

    constructor() {
        (factory, commitment, denomination, cashInflows, cashOutflows, nonce) =
            IAccountDeployer(msg.sender).parameters();

        // if we do atomic commit here, it reduce ...
        // commit(commitment, paymentOrder);
    }

    modifier inState(State state) {
        require(state == currentState, "current state does not allow");
        _;
    }

    function commit_2ndPhase() external payable inState(State.UNCOMMITED) {
        require(msg.value == denomination, "Incorrect denomination");

        // pendingCommit[msg.sender] = _commitment;
        currentState = State.COMMITED;
        IPoolsCounterBalancer(factory).commit_2ndPhase_Callback(msg.sender, address(this), commitment, nonce);

        _processDeposit();
    }

    // TODO adding param `to` as receiver address
    function clear_commitment(address payable to) external inState(State.COMMITED) {
        // require(pendingCommit[msg.sender].commitment != bytes32(0), "not committed");
        // uint256 denomination = pendingCommit[msg.sender].denomination;
        // delete pendingCommit[msg.sender];
        currentState = State.UNCOMMITED;
        IPoolsCounterBalancer(factory).clear_commitment_Callback(msg.sender, nonce);

        // TODO deal with precision
        _processWithdraw(to, denomination);
    }

    // TODO fill missed arguments
    function _processDeposit() internal {
        // do nothing as already mrk payable
    }

    function _processWithdraw(address payable to, uint256 amountOut) internal {
        Address.sendValue(to, amountOut);

        emit Withdrawal(msg.sender, to, amountOut);
    }
}
