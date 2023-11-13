//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IAccountDeployer {

    function parameters()
        external
        view
        returns (
            address factory,
            bytes32 commitment
        );
}