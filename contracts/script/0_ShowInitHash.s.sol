// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {console} from "@forge-std/console.sol";

import {Script} from "@forge-std/Script.sol";

import {BalanceAccount} from "@main/Account.sol";


contract ShowInitHashScript is Script {


    function getInitHash() public pure returns(bytes32){
        bytes memory bytecode = type(BalanceAccount).creationCode;
        return keccak256(abi.encodePacked(bytecode));
    }

    function run() public view {

        console.logBytes32( getInitHash());
    }


}