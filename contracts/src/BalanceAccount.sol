//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// import {CallbackValidation} from "@main/libraries/CallbackValidation.sol";
import {IPoolsCounterBalancer} from "@main/interfaces/IPoolsCounterBalancer.sol";
import {IAccountDeployer} from "@main/interfaces/IAccountDeployer.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";


// TODO Add interface
// TODO abstract into 2 types annuoty and endowmwnt
// TODO define invariant
/**
 * @title Account
 * @notice the bottom layer with dependency inversion of callback
 */
contract BalanceAccount {
    enum Status {
        UNCOMMITED,
        COMMITED,
        TERMINATED
    }

    Status public currentStatus = Status.UNCOMMITED;

    //call relevant states from factory which store merkle roots
    /**
     * @notice the bottom layer with dependency inversion of callback
     */
    address public immutable factory;

    bytes32 public immutable commitment;

    // TODO  check if we need to store them
    uint256 public immutable denomination;
    uint256 public immutable cashInflows;
    uint256 public immutable cashOutflows;
    uint256 public immutable nonce;

    // mapping(address => bytes32) pendingCommit;

    uint256 public currentBalance;

    event Withdrawal(address indexed _caller, address indexed _to, uint256 _amount);

    constructor() {
        (factory, commitment, denomination, cashInflows, cashOutflows, nonce) =
            IAccountDeployer(msg.sender).parameters();

        // if we do atomic commit here, it reduce ...
        // commit(commitment, paymentOrder);
    }

    modifier inStatus(Status status) {
        require(status == currentStatus, "current status does not allow");
        _;
    }

    function commit_2ndPhase() external payable inStatus(Status.UNCOMMITED) returns (bytes32) {
        //TODO handle ERC20 case
        uint256 amountIn = denomination / cashInflows; // 1 ether/
        // uint256 amountIn = denomination/cashOutflows; // 1 ether/4 = 0.25 ether
        require(msg.value == amountIn, "Incorrect amountIn");

        // pendingCommit[msg.sender] = _commitment;
        currentStatus = Status.COMMITED;
        currentBalance += amountIn;
        _processDeposit();
        IPoolsCounterBalancer(factory).commit_2ndPhase_Callback(msg.sender, address(this), commitment, nonce, amountIn);

        return commitment;
    }

    // TODO adding param `to` as receiver address
    function clear_commitment(address payable to) external inStatus(Status.COMMITED) {
        // require(pendingCommit[msg.sender].commitment != bytes32(0), "not committed");
        // uint256 denomination = pendingCommit[msg.sender].denomination;
        // delete pendingCommit[msg.sender];
        currentStatus = Status.UNCOMMITED;
        uint256 amountOut = denomination / cashInflows; // 1 ether/
        currentBalance -= amountOut;
        // TODO deal with precision
        _processWithdraw(to, denomination);

        IPoolsCounterBalancer(factory).clear_commitment_Callback(msg.sender, address(this), nonce);
    }

    function withdraw_callback(address caller, address payable to, uint256 amountOut) external {
        require(caller == factory, "caller is not factory");
        _processWithdraw(to, amountOut);
    }

    // TODO fill missed arguments
    function _processDeposit() internal {
        // do nothing as already mrk payable
    }

    function _processWithdraw(address payable to, uint256 amountOut) internal {
        Address.sendValue(to, amountOut);

        emit Withdrawal(msg.sender, to, amountOut);
    }

    //TODO fallback to handle inflation attack
}
