//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import  {NoDelegateCall} from "./NoDelegateCall.sol";


contract Account is NoDelegateCall {

    

    function createAccount(
        bytes32 commitment
    ) external noDelegateCall returns (address pool) {

        // deploy()
    }

    

}

