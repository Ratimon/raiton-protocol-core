//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {ICore} from "@main/interfaces/ICore.sol";
import {AccountAddress} from "@main/libraries/AccountAddress.sol";



library CallbackValidation {

    function verifyCallback(
        address factory,
        bytes32 commitment,
        uint256 paymentNumber
    ) internal view returns (ICore pool) {
        pool = ICore(AccountAddress.computeAddress(factory, commitment, paymentNumber));
        require(msg.sender == address(pool));
    }

}