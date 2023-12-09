//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {console} from "@forge-std/console.sol";

import {IAccount} from "@main/interfaces/IAccount.sol";
import {AccountAddress} from "@main/libraries/AccountAddress.sol";

library CallbackValidation {

    // TODO will separe between annuity and endowmwnt later
    function verifyCallback(
        address factory,
        bytes32 commitment,
        uint256 nonce
    ) internal view returns (IAccount pool) {
        pool = IAccount(AccountAddress.computeAddress(factory, commitment, nonce));

        console.log("pool: %s", address(pool));
        console.log("msg.sender: %s", msg.sender);
        require(msg.sender == address(pool));
    }

}