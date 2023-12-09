//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IAccountDeployer} from "@main/interfaces/IAccountDeployer.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

contract AccountDeployer is IAccountDeployer {
    struct Parameters {
        address factory;
        bytes32 commitment;
        uint256 denomination;
        uint256 cashInflows;
        uint256 cashOutflows;
        uint256 nonce;
    }

    Parameters public override parameters;

    function deploy(
        address factory,
        bytes32 commitment,
        uint256 denomination,
        uint256 cashInflows,
        uint256 cashOutflows,
        uint256 nonce
    ) internal returns (address account) {
        parameters = Parameters({
            factory: factory,
            commitment: commitment,
            denomination: denomination,
            cashInflows: cashInflows,
            cashOutflows: cashOutflows,
            nonce: nonce
        });
        account = address(new BalanceAccount{salt: keccak256(abi.encode(commitment, nonce))}());
        delete parameters;
    }
}
