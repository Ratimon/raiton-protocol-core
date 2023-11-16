//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;


interface IAccountCommitCallback {

    function accountCommitCallback(address _caller, bytes32 _commitment) external payable;


}