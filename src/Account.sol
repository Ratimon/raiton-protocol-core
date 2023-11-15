//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import  {IAccountDeployer} from "@main/interfaces/IAccountDeployer.sol";

contract Account  {

    //call relevant states from factoely which store merkle roots
    address public immutable factory;

    constructor() {

        // may remove commitment or replace with new one
        bytes32 commitment;
        ( factory, commitment) = IAccountDeployer(msg.sender).parameters();

    }

}

