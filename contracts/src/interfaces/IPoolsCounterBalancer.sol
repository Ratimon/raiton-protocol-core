//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IPoolsCounterBalancer {
    function initiate_1stPhase_Account(bytes32 commitment) external returns (address[] memory accounts);

    function commitNew_2ndPhase_Callback(
        address caller,
        address account,
        bytes32 commitment,
        uint256 nonce,
        uint256 amountIn
    ) external payable;

    function clear_commitment_Callback(address caller, address account, uint256 nonce) external;
}
