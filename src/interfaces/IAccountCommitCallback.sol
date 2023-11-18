//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;


interface IAccountCommitCallback {

    function commit_2ndPhase_Callback(address caller, bytes32 _commitment, uint256 paymentOrder) external payable;

    function clear_commitment_Callback(address caller, uint256 paymentOrder) external;


}