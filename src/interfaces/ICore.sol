//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Account} from "@main/Account.sol";

contract Core {

    

    function accountCodeHash() external pure returns (bytes32) {
        return keccak256(type(Account).creationCode);
    }

    function createPool() private {

        // check if address(this) is not blacklist

        // deposit();

        // checkIfETHalreadydposited


    }

}