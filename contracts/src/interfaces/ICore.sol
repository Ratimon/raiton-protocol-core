//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface ICore {
    // function getPendingAccount(bytes32 commitment, uint256 nonce) external returns (bytes32);

    function getPendingCommitment(address account) external returns (bytes32);

    function getPendingCommittedAmount(address account) external view returns (uint256);

    function getOwnerCommitment(address account) external view returns (bytes32);

    function getOwnerCommittedAmount(address account) external view returns (uint256);

    function getWithdrawnAmount(bytes32 nullifierHash) external view returns (uint256);

    function getIsNullified(bytes32 nullifierHash) external view returns (bool);

    // function stats() external view returns (uint256 averageLiquidityCoverageRatio, uint256 totalAccountTurnOver);
}
