//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IAccount} from "@main/interfaces/IAccount.sol";
import {BalanceAccountAddress} from "@main/libraries/AccountAddress.sol";

library CallbackValidation {
    // TODO will separe between annuity and endowmwnt later
    function verifyCallback(address factory, bytes32 commitment, uint256 nonce) internal view returns (IAccount pool) {
        pool = IAccount(BalanceAccountAddress.computeAddress(factory, commitment, nonce));

        require(msg.sender == address(pool));
    }
}
