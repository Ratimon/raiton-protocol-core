//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IAccount} from "@main/interfaces/IAccount.sol";
// import {ICore} from "@main/interfaces/ICore.sol";
import {IPoolsCounterBalancer} from "@main/interfaces/IPoolsCounterBalancer.sol";


/**
 * @title Router
 * @notice query rotating set of addresses to optimize and balance the system
 */
contract Router {

    address factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function getPoolsCounterBalancer() private view returns (IPoolsCounterBalancer) {
        return IPoolsCounterBalancer(factory);
    }

    function getBottomAccount() private view returns (IAccount) {
        return IAccount(IPoolsCounterBalancer(factory).getBottom());
    }


    function commitExisting( bytes32 newCommmitment) external payable {
        //todo sanity check for  _commmitment

        // ICore core = getCore();
        IAccount bottomAccount = getBottomAccount();

        //todo define invariant

        // eg. 1 time of 1 ether  - currentContractRate = 0, currentAmountIn = 1 ether
        //  if
        bottomAccount.commitExisting_2ndPhase(msg.sender , newCommmitment);

        // ? just new not existing
        // eg. 2 time of 0.5 ether  - currentContractRate = 0, currentAmountIn = 0.5 ether, contractNumber = 2 
        // eg. 4 time of 0.25 ether  - currentContractRate = 0, currentAmountIn = 0.25 ether, , contractNumber = 4
       

    }

    
}
