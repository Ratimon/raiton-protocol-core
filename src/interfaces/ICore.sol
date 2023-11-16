//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface ICore {

    function stats()
        external
        view
        returns (
            uint256 averageLiquidityCoverageRatio,
            uint256 totalAccountTurnOver
        );  

}