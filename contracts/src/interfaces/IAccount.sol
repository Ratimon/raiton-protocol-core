//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IAccount {
    // ----------- Events -----------
    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);

    event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);

    // ----------- State changing api -----------

    function commitNew_2ndPhase() external payable returns (uint256);

    function commitExisting_2ndPhase(address sender, bytes32 _commmitment) external payable returns (uint256);

    function clear_commitment(address payable to) external;

    function withdraw_callback(address caller, address to, uint256 amountOut) external;

    // ----------- Getters -----------

    function commitment() external view returns (bytes32);

    function denomination() external view returns (uint256);

    function cashInflows() external view returns (uint256);

    function cashOutflows() external view returns (uint256);

    function nonce() external view returns (uint256);
}
