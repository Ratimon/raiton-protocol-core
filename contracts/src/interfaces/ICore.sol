//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface ICore {

    struct DepositData {
        bytes32 commitment;
        uint256 committedAmount;
        address account;
    }

    function getPendingAccount(bytes32 commitment, uint256 nonce) external returns (bytes32);

    function getPendingCommitment(address account) external returns (bytes32);

    function getPendingCommittedAmount(address account) external view returns (uint256);

    function stats() external view returns (uint256 averageLiquidityCoverageRatio, uint256 totalAccountTurnOver);
}
