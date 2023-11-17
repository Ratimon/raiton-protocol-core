//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

// import {CallbackValidation} from "@main/libraries/CallbackValidation.sol";
import {IAccountCommitCallback} from "@main/interfaces/IAccountCommitCallback.sol";

import {IAccountDeployer} from "@main/interfaces/IAccountDeployer.sol";

import  {ICore} from "@main/interfaces/ICore.sol";


contract Account  {

    //call relevant states from factory which store merkle roots
    address public immutable factory;

    uint256 public denomination;
    uint256 public paymentNumber;

    // mapping(address => bytes32) pendingCommit;

    constructor() {
        // may remove commitment or replace with new one
        bytes32 commitment;
        ( factory, commitment, denomination, paymentNumber) = IAccountDeployer(msg.sender).parameters();
    }
    
    // function commit(
    //     // bytes calldata _proof,
    //     bytes32 newRoot
    // ) external {
    //     CallbackValidation.verifyCallback(msg.sender, decoded.poolKey);
    // }

    function commit(bytes32 _commitment) external payable {
        
        require(msg.value == denomination, "Incorrect denomination");

        // pendingCommit[msg.sender] = _commitment;

        IAccountCommitCallback(factory).accountCommitCallback(msg.sender, _commitment);


        _processDeposit();
    }

    function _processDeposit() internal {}

    

}

