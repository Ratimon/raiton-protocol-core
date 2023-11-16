//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import  {IAccountDeployer} from "@main/interfaces/IAccountDeployer.sol";
import {Account} from "./Account.sol";


contract AccountDeployer is IAccountDeployer {

    struct Parameters {
        address factory;
        bytes32 commitment;
        uint256 paymentNumber;
    }

    Parameters public override parameters;

    function deploy(
        address factory,
        bytes32 commitment,
        uint256 paymentNumber
    ) internal returns (address account) {
        parameters = Parameters({factory: factory, commitment: commitment, paymentNumber: paymentNumber});
        account = address(new Account{salt: keccak256(abi.encode(commitment, paymentNumber))}());
        delete parameters;
    }

}