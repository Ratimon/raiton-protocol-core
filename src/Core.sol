//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import  {NoDelegateCall} from "@main/NoDelegateCall.sol";
import  {AccountDeployer} from "@main/AccountDeployer.sol";

contract Core is AccountDeployer, NoDelegateCall {


    mapping(bytes32 => address) public getAccount;


    function createAccount(
        bytes32 commitment
    ) external noDelegateCall returns (address account) {

        //sanity check for commitment
        account = deploy(address(this), commitment);
        getAccount[commitment] = account;
    }
    


}
