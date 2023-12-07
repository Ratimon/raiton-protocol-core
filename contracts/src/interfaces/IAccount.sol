//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IAccount {
    
    // ----------- Events -----------
    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);

    event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);

    // ----------- State changing api -----------
    function deposit(
        // bytes calldata _proof,
        bytes32 newRoot
    ) external; 

    // ignoring _proof now
    function withdraw(
        // bytes calldata _proof,
        bytes32 _root,
        bytes32 _nullifierHash,
        address payable _recipient,
        uint256 _amount,
        address payable _relayer,
        uint256 _fee
    ) external;

    // ----------- Getters -----------

    function commitment() external view returns (bytes32);

    function denomination() external view returns (uint256);

    function cashInflows() external view returns (uint256);

    function cashOutflows() external view returns (uint256);

    function nonce() external view returns (uint256);

}