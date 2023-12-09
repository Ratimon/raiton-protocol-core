//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface ICore {
    function getPendingCommitment(address cup) external returns (bytes32);

    function stats() external view returns (uint256 averageLiquidityCoverageRatio, uint256 totalAccountTurnOver);
}
