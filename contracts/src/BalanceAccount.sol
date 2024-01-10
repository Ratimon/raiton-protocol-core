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
        UNCOMMITTED,
        COMMITTED,
        TERMINATED
    }

    Status public currentStatus = Status.UNCOMMITTED;

    //call relevant states from factory which store merkle roots
    /**
     * @notice the bottom layer with dependency inversion of callback
     */
    address public immutable factory;

    bytes32 public commitment;

    // TODO  check if we need to store them
    uint256 public immutable denomination;
    uint256 public immutable cashInflows;
    uint256 public immutable cashOutflows;
    uint256 public nonce;

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
        require(status == currentStatus, "BalanceAccount: Current Status does't allow");
        _;
    }

    /**
     * @dev add deposit to another "balanceAccount", callable from router
     */
    function commitExisting_2ndPhase(address sender, bytes32 newCommmitment)
        external
        payable
        inStatus(Status.COMMITTED)
        returns (uint256)
    {
        // address router;
        // require(msg.sender == router, "BalanceAccount:  only callable from router ");

        //TODO sanity check for amountIn;
        IPoolsCounterBalancer core = IPoolsCounterBalancer(factory);
        // denomination?
        uint256 currentAmountIn = core.getCurrentAmountIn();

        require(msg.value == currentAmountIn, "BalanceAccount: Incorrect amountIn");
        currentBalance += currentAmountIn;

        bytes32 existingCommitment = commitment;
        core.commitExisting_2ndPhase_Callback(
            sender, address(this), existingCommitment, newCommmitment, nonce, currentAmountIn
        );

        // _updateparams();
        commitment = newCommmitment;
        nonce = 0;

        _processDeposit();

        return currentAmountIn;
    }

    function commitNew_2ndPhase() external payable inStatus(Status.UNCOMMITTED) returns (uint256) {
        //TODO handle ERC20 case
        uint256 amountIn = denomination / cashInflows; // 1 ether/4 = 0.25 ether
        // uint256 amountIn = denomination/cashOutflows; // 1 ether/4 = 0.25 ether
        require(msg.value == amountIn, "BalanceAccount: Incorrect amountIn");

        // pendingCommit[msg.sender] = _commitment;
        currentStatus = Status.COMMITTED;
        currentBalance += amountIn;
        IPoolsCounterBalancer(factory).commitNew_2ndPhase_Callback(
            msg.sender, address(this), commitment, nonce, amountIn
        );
        _processDeposit();

        return amountIn;
    }

    // TODO adding param `to` as receiver address
    function clear_commitment(address payable to) external inStatus(Status.COMMITTED) {
        // require(pendingCommit[msg.sender].commitment != bytes32(0), "not committed");
        // uint256 denomination = pendingCommit[msg.sender].denomination;
        // delete pendingCommit[msg.sender];
        currentStatus = Status.UNCOMMITTED;
        uint256 amountOut = currentBalance;
        currentBalance -= amountOut;
        // TODO deal with precision
        _processWithdraw(to, amountOut);

        IPoolsCounterBalancer(factory).clear_commitment_Callback(msg.sender, address(this), nonce);
    }

    function withdraw_callback(address caller, address payable to, uint256 amountOut) external {
        require(caller == factory, "BalanceAccount: Caller is not factory");
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
