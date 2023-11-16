//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import  {NoDelegateCall} from "@main/NoDelegateCall.sol";
import  {AccountDeployer} from "@main/AccountDeployer.sol";

import { IHasher, MerkleTreeWithHistory } from "@main/MerkleTreeWithHistory.sol";

contract Core is MerkleTreeWithHistory, AccountDeployer, NoDelegateCall {

    // store all states
    // add a redeployable stateless router to query the address

    uint256 public accountCurrentNumber = 0;
    uint256 public accountSchellingNumber = 4;
    uint256 public accountNumberCumulativeLast;

    uint256 public denomination;
    uint256 public paymentNumber;

    mapping(bytes32 => address) public getAccountByCommitment;

    /// @notice Array of all Accounts held in the Protocol. Used for iteration on accounts
    address[] private accountsInPool;

    mapping(address => address) public accountToOracle;

    uint256 public liquidityCoverageSchellingRatio;


    uint256 rotateCounter;
    uint256 rotateCounterCumulativeLast;

    constructor(
        IHasher _hasher,
        uint32 _merkleTreeHeight,
        uint256 _denomination,
        uint256 _paymentNumber
    ) MerkleTreeWithHistory(_merkleTreeHeight, _hasher) {
        require(_denomination > 0, "must be > than 0");
        denomination = _denomination;
        paymentNumber = _paymentNumber;
    }


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
