//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IAccountDeployer {
    // ----------- Getters -----------
    function parameters()
        external
        view
        returns (
            address factory,
            bytes32 commitment,
            uint256 denomination,
            uint256 cashInflows,
            uint256 cashOutflows,
            uint256 nonce
        );
}
