//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;



interface IPoolsCounterBalancer {

    function initiate_1stPhase_Account(
        bytes32 commitment
    ) external returns (address account);

    function commit_2ndPhase_Callback(address caller, bytes32 commitment, uint256 nonce) external payable;

    function clear_commitment_Callback(address caller, uint256 nonce) external;


}