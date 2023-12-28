//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {CallbackValidation} from "@main/libraries/CallbackValidation.sol";

import {IAccount} from "@main/interfaces/IAccount.sol";
import {ICore} from "@main/interfaces/ICore.sol";
import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IPartialWithdrawVerifier} from "@main/interfaces/IPartialWithdrawVerifier.sol";
import {IPoolsCounterBalancer} from "@main/interfaces/IPoolsCounterBalancer.sol";

import {NoDelegateCall} from "@main/NoDelegateCall.sol";
import {AccountDeployer} from "@main/AccountDeployer.sol";

import {SortedList} from "@main/utils/SortedList.sol";

contract Core is ICore, IPoolsCounterBalancer, SortedList, AccountDeployer, NoDelegateCall {
    uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant ROOT_HISTORY_SIZE = 30;

    bytes32 constant initialRootZero = 0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb; // Keccak256("Tornado")
    uint256 immutable levels;

    IDepositVerifier immutable depositVerifier;
    IPartialWithdrawVerifier immutable partialWithdrawVerifier;

    // current index of the latest root
    uint128 public currentRootIndex;

    // index which the next deposit commitment hash should go into
    uint128 public nextIndex;

    // fixed size array of past roots to enable withdrawal using any last-ROOT_HISTORY_SIZE root from the past
    bytes32[ROOT_HISTORY_SIZE] public roots;

    // store all states
    // add a redeployable stateless router to query the address

    uint256 public accountCurrentNumber = 0;
    uint256 public accountSchellingNumber = 4;
    uint256 public accountNumberCumulativeLast;

    uint256 public denomination;
    uint256 public paymentNumber;

    // TODO ? adding new struct of Accountkey
    // TODO ? add getter to get address then connect with router, so we can commit via account
    mapping(bytes32 => mapping(uint256 => address)) public getPendingAccount;

    // Deposit Side:
    mapping(address => DepositData) private pendingDeposit;
    mapping(address => DepositData) public ownerToDeposit;

    // Withdraw Side:
    mapping(bytes32 => WithdrawData) private nullifierHashToWithdraw;

    mapping(address => address) public accountToOracle;

    uint256 public liquidityCoverageSchellingRatio;

    uint256 rotateCounter;
    uint256 rotateCounterCumulativeLast;

    event Commit(bytes32 indexed commitment, address indexed account, uint256 amountIn, uint256 timestamp);
    event Clear(bytes32 indexed commitment, address indexed account, uint256 timestamp);
    event Insert(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);

    // TODO Add Deposit & Withdrawal events

    // TODO Add isCommitSettle?
    // TODO change committedAmount to just Counter
    // TOFIX Add state to prevent withdrawing when not deposit yet (ie. alternatively move addAccount to deposit code block)
    struct DepositData {
        bytes32 commitment;
        uint256 committedAmount;
        address account;
    }

    // TODO change withdrawnAmount to just Counter
    struct WithdrawData {
        uint256 withdrawnAmount;
        bool isNullified;
    }

    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    constructor(
        IDepositVerifier _depositVerifier,
        IPartialWithdrawVerifier _partialWithdrawVerifier,
        uint256 _merkleTreeHeight,
        uint256 _denomination,
        uint256 _paymentNumber
    ) SortedList() {
        require(_merkleTreeHeight > 0, "Core: Levels should be greater than zero");
        require(_merkleTreeHeight < 32, "Core: Levels should be less than 32");

        require(_denomination > 0, "Core: Denomination must > than 0");

        levels = _merkleTreeHeight;
        roots[0] = initialRootZero;

        denomination = _denomination;
        paymentNumber = _paymentNumber;
        depositVerifier = _depositVerifier;
        partialWithdrawVerifier = _partialWithdrawVerifier;
    }

    // TODO annuity commit - low level commit
    // TODO  fee entrance to prevent DOS?
    // TODO  pausable / re-entrancy libs ?
    // TODO whoever can create their smart contract and deploy to participate
    /**
     * @dev deploy  numbers of account based on the schelling point
     */
    function initiate_1stPhase_Account(bytes32 commitment)
        external
        noDelegateCall
        returns (address[] memory accounts)
    {
        require(uint256(commitment) < FIELD_SIZE, "Core: Commitment Out of Range");
        require(commitment != bytes32(0), "Core: Invalid commitment");
        // require(pendingDeposit[msg.sender].commitment == bytes32(0), "Core: Already Deployed");

        // TODO : add require when accountCurrentNumber < accountSchellingNumber


        // TODO : the loop number will depends on the schelling point
        // TODO add more scenarios
        // TODO : fix BalanceAccount with recommitabillity
        // TODO : remove outflow to maintain privacy (separating between deposit and withdraw)
        // eg. annuity: single premium, withdraw N time
        // 1) annuity: 4 contracts -(inflow = 4) each of 0.25  -equal single premium of 1 
        // 1) annuity: 4 contracts -(outflow = 1)   each of 0.25 -equal 4 payment of 0.25 ether for 4 contracts

        // 2) annuity: 2 contracts -(inflow = 2) each of 0.5  -equal single premium of 1
        // 2) annuity: 2 contracts -(outflow = 2)   each of 0.25 -equal 2 payment of 0.5 ether for 4 contracts

        // 3) annuity: 1 contracts -(inflow = 1) only 1  - qual single premium of 1
        // 2) annuity: 1 contracts -(outflow = 4)   only 1 -equal 1 payment of 1 ether -equal 1 payment of 1 ether for 1 contract


        // eg. endowment: N premiums, withdraw 1 time
        // 1) endowment: 4 contracts -(inflow = 4) each of 0.25  -equal 4 payments totoal of 1 ether
        // 1) endowment: 4 contracts -(outflow = 1) each of 0.25 -equal 4 payment of 0.25 ether for 4 contracts

        uint256 contractNumber;
        uint256 accountDifferece;
        // TODO hardcoded fix it
        // uint256 cap = 2;

        uint256 inflow;
        
        if( accountCurrentNumber < accountSchellingNumber)  {

            accountDifferece = accountSchellingNumber - accountCurrentNumber;

            // contractNumber = accountDifferece > cap ? 4 : 2;

            // todo fix as it is hardcoded
            contractNumber = paymentNumber;
            inflow = contractNumber;

        } else {
            // todo fix as it is hardcoded handle if no contract is deploy yet
            revert( "Core: Schelling > CurrentNumber : Do commit via router");

        }


        accounts = new address[](contractNumber);

        for (uint256 i = 0; i < contractNumber; i++) {
            //sanity check for commitment

            // TODO : now hardcoded inflow and outflow as 1 and paymentNumber respectively
            // TODO : denomination should be 1 / 4 ?
            // case 1  : denomination should be 1 / 4 ?
            address account = deploy(address(this), commitment, denomination, 1, paymentNumber, i);
            // address account = deploy(address(this), commitment, denomination, contractNumber, 4, i);
            require(getPendingAccount[commitment][i] == address(0), "Core: Account Already Created");

            // TODO : do some optimization to query balanceAccount address? like mapping address to getPendingAccount
            // TODO : like getAccountTOCommit(commitment)
            getPendingAccount[commitment][i] = account;

            DepositData storage depositData = pendingDeposit[account];
            depositData.commitment = commitment;
            depositData.account = account;
            // pendingDeposit[msg.sender] = DepositData({commitment: commitment, commitedAmount: 0});

            accounts[i] = account;

            // TODO emit event
        }
        // return accounts;
    }

    /**
     * @dev add depositData to already deployed account (pendingDeposit) called by router
     */

    function getAccountToCommit() external view returns (address) {
       

        // TODO require accountCurrentNumber > accountSchellingNumber)
        // TODO require have account state (sorted list)
        // TODO connect with router
        // TODO draft with below comment
                
        // if( accountCurrentNumber < accountSchellingNumber)  {

        //     accountDifferece = accountSchellingNumber - accountCurrentNumber;

        //     // contractNumber = accountDifferece > cap ? 4 : 2;

        //     // todo fix as it is hardcoded
        //     contractNumber = paymentNumber;
        //     inflow = contractNumber;

        // } else {
        //     // todo fix as it is hardcoded handle if no contract is deploy yet
        //     revert( "Core: Schelling > CurrentNumber : Do commit via router");
        // }

    }

    /**
     * @dev only callable from child contract
     */
    function commit_2ndPhase_Callback(
        address caller,
        address account,
        bytes32 commitment,
        uint256 nonce,
        uint256 amountIn
    ) external payable override {
        require(uint256(commitment) < FIELD_SIZE, "Core: Commitment Out of Range");
        // ??
        require(commitment != bytes32(0), "Core: Invalid commitment");

        DepositData storage depositData = pendingDeposit[account];
        //TODO check again
        require(depositData.commitment == commitment, "Core: Wrong Commitment or Account");
        // still needed to prevent redundant hash from the same sender
        //  TODO another mechanism to prevent from redundant deposit
        //  TODO ie must be 0.25 ether?
        require(depositData.committedAmount < denomination, "Core: Commited Amount already exceeded");
        require(depositData.account == account, "Core: Wrong Account");

        // DepositData storage ownerToDepositData = ownerToDeposit[caller];

        // only callable by child account(  ie deployer must be factory - address(this))
        // TODO check if we need to include denomination
        // TODO return ?
        CallbackValidation.verifyCallback(address(this), commitment, nonce);
        delete getPendingAccount[commitment][nonce];
        // pendingDeposit[caller] = commitment;

        depositData.committedAmount += amountIn;

        ownerToDeposit[caller].commitment = commitment;
        ownerToDeposit[caller].committedAmount += amountIn;

        // TODO Change to updateAcccount and test _updateBalance(,0) and getTop for SortedList
        _addAccount(account, amountIn);

        emit Commit(commitment, account, amountIn, block.timestamp);
    }

    function clear_commitment_Callback(address caller, address account, uint256 nonce) external override {
        DepositData memory depositData = pendingDeposit[account];
        bytes32 _pendingDeposit = depositData.commitment;
        require(_pendingDeposit != bytes32(0), "Core: Not Commited Yet");
        require(depositData.committedAmount != 0, "Core: Not Amount to Clear");
        require(depositData.account == account, "Core: Wrong Account");

        CallbackValidation.verifyCallback(address(this), _pendingDeposit, nonce);

        delete pendingDeposit[account].commitment;
        delete pendingDeposit[account].committedAmount;
        delete ownerToDeposit[caller].commitment;
        delete ownerToDeposit[caller].committedAmount;

        _removeAccount(account);

        emit Clear(_pendingDeposit, account, block.timestamp);
    }

    /**
     * @dev let users update the current merkle root by providing a proof that they added `ownerToDeposit[msg.sender]` to the current merkle tree root `roots[currentRootIndex]` and verifying it onchain
     */
    function deposit(Proof calldata _proof, bytes32 newRoot) external {
        DepositData memory ownerToDepositData = ownerToDeposit[msg.sender];
        bytes32 _pendingDeposit = ownerToDepositData.commitment;
        uint256 _committedAmount = ownerToDepositData.committedAmount;

        require(_pendingDeposit != bytes32(0), "Core: Not Commited Yet");
        require(_committedAmount == denomination, "Core: Amount Commited Not Enough");

        uint256 _currentRootIndex = currentRootIndex;

        // fix denomination
        // TODO use from pending commitment AND _removeAccount()
        // TODO revisit  hash: Poseidon(nullifier, 0, denomination) : whether we should delete 'denomination'
        require(
            depositVerifier.verifyProof(
                _proof.a,
                _proof.b,
                _proof.c,
                [uint256(roots[_currentRootIndex]), uint256(_pendingDeposit), _committedAmount, uint256(newRoot)]
            ),
            "Core: Invalid deposit proof"
        );

        delete pendingDeposit[ownerToDepositData.account];
        delete ownerToDeposit[msg.sender];

        uint128 newCurrentRootIndex = uint128((_currentRootIndex + 1) % ROOT_HISTORY_SIZE);

        currentRootIndex = newCurrentRootIndex;

        roots[newCurrentRootIndex] = newRoot;
        uint256 _nextIndex = nextIndex;

        // todo  move addAccount to this block

        nextIndex += 1;
        emit Insert(_pendingDeposit, _nextIndex, block.timestamp);
    }

    function withdraw(
        Proof calldata _proof,
        bytes32 _root,
        bytes32 _nullifierHash,
        bytes32 _newCommitmentHash,
        bytes32 _newRoot,
        address payable _recipient,
        address payable _relayer,
        uint256 _fee
    ) external {

        require(isKnownRoot(_root), "Core: No merkle root found"); // Make sure to use a recent one

        WithdrawData storage withdrawData = nullifierHashToWithdraw[_nullifierHash];

        require(!withdrawData.isNullified, "Core: Already ");
        require(withdrawData.withdrawnAmount < denomination, "Core: Withdrawn Amount already exceeded");

        uint256 amountOut = denomination / paymentNumber;

         // TODO if only final full withdraw ?
         // TODO Add time constraint
         require(
            partialWithdrawVerifier.verifyProof(
                _proof.a,
                _proof.b,
                _proof.c,
                [
                    uint256(_root),
                    uint256(_nullifierHash),
                    amountOut,
                    uint256(_newCommitmentHash),
                    uint256(_newRoot),
                    uint256(uint160(address(_recipient))),
                    uint256(uint160(address(_relayer))),
                    _fee
                ]
            ),
            "Invalid withdraw proof"
        );

        withdrawData.withdrawnAmount += amountOut;

        if(withdrawData.withdrawnAmount  == denomination)
            withdrawData.isNullified = true;

        uint128 newCurrentRootIndex = uint128((currentRootIndex + 1) % ROOT_HISTORY_SIZE);
        currentRootIndex = newCurrentRootIndex;
        roots[newCurrentRootIndex] = _newRoot;
        uint256 _nextIndex = nextIndex;
        nextIndex += 1;

        // todo add rule to use whether getBottom() or getTop()
        address accountToWithdraw = getBottom();
        if ( accountToWithdraw.balance == amountOut )
            _removeAccount(accountToWithdraw);
            // todo add rule to use whether getBottom() or getTop()
            // todo  _updateAccount

        IAccount(accountToWithdraw).withdraw_callback(address(this), _recipient, amountOut);
       
    }

    function getPendingCommitment(address account) external view returns (bytes32) {
        return pendingDeposit[account].commitment;
    }

    function getPendingCommittedAmount(address account) external view returns (uint256) {
        return pendingDeposit[account].committedAmount;
    }

    function getOwnerCommitment(address owner) external view returns (bytes32) {
        return ownerToDeposit[owner].commitment;
    }

    function getOwnerCommittedAmount(address owner) external view returns (uint256) {
        return ownerToDeposit[owner].committedAmount;
    }

    function getWithdrawnAmount(bytes32 nullifierHash) external view returns (uint256) {
        return nullifierHashToWithdraw[nullifierHash].withdrawnAmount;
    }

    function getIsNullified(bytes32 nullifierHash) external view returns (bool){
        return nullifierHashToWithdraw[nullifierHash].isNullified;
    }

     function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == 0) return false;

        uint256 i = currentRootIndex;
        do {
            if (_root == roots[i]) return true;
            if (i == 0) i = ROOT_HISTORY_SIZE;
            --i;
        } while (i != currentRootIndex);
        return false;
    }


    // get
    // 1) stat (loop)
    // 2) balance
}
