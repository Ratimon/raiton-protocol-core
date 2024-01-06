//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

//todo move ti another interface
interface ICore {
    // function getPendingAccount(bytes32 commitment, uint256 nonce) external returns (bytes32);

    // function getCurrentAmountIn() external returns (uint256);

    function getPendingCommitmentToDeposit(address account) external returns (bytes32);

    function getPendingCommittedAmountToDeposit(address account) external view returns (uint256);

    function getOwnerCommitment(address owner) external view returns (bytes32);

    function getOwnerCommittedAmount(address owner) external view returns (uint256);

    function getOwnerAccounts(address owner) external view returns (address[] memory);

    function getWithdrawnAmount(bytes32 nullifierHash) external view returns (uint256);

    function getIsNullified(bytes32 nullifierHash) external view returns (bool);

    // function getBottomAccount() external view returns (address);

    // function stats() external view returns (uint256 averageLiquidityCoverageRatio, uint256 totalAccountTurnOver);
}
