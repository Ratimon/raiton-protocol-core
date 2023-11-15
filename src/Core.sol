//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import  {NoDelegateCall} from "@main/NoDelegateCall.sol";
import  {AccountDeployer} from "@main/AccountDeployer.sol";

contract Core is AccountDeployer, NoDelegateCall {

    // store all states
    // add a redeployable stateless router to query the address

    mapping(bytes32 => address) public getAccountByCommitment;


    function createAccount(
        bytes32 commitment
    ) external noDelegateCall returns (address account) {

        //sanity check for commitment
        account = deploy(address(this), commitment);
        getAccountByCommitment[commitment] = account;
        

    }

    // set
    // 1) insert
    // 2) withdraw

    // get
    // 1) stat (loop)
    // 2) balance


    


}
