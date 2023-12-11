//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface ICore {

    function getPendingAccount(bytes32 account, uint256 nonce) external returns (bytes32);

    function pendingCommitment(address account) external returns (bytes32);

    function stats() external view returns (uint256 averageLiquidityCoverageRatio, uint256 totalAccountTurnOver);
}
