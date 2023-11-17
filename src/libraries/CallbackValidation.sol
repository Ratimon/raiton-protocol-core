//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IAccount} from "@main/interfaces/IAccount.sol";
import {AccountAddress} from "@main/libraries/AccountAddress.sol";


library CallbackValidation {

    function verifyCallback(
        address factory,
        bytes32 commitment,
        uint256 paymentOrder
    ) internal view returns (IAccount pool) {
        pool = IAccount(AccountAddress.computeAddress(factory, commitment, paymentOrder));
        require(msg.sender == address(pool));
    }

}