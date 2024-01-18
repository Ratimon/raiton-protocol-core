//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {console2} from "@forge-std/console2.sol";
import {CallbackValidation} from "@main/libraries/CallbackValidation.sol";

import {IAccount} from "@main/interfaces/IAccount.sol";
import {ICore} from "@main/interfaces/ICore.sol";
import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IPartialWithdrawVerifier} from "@main/interfaces/IPartialWithdrawVerifier.sol";
import {IPoolsCounterBalancer} from "@main/interfaces/IPoolsCounterBalancer.sol";

import {NoDelegateCall} from "@main/NoDelegateCall.sol";
import {AccountDeployer} from "@main/AccountDeployer.sol";

import {SortedList} from "@main/utils/SortedList.sol";

contract Core is ICore, SortedList, IPoolsCounterBalancer, AccountDeployer, NoDelegateCall {
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

    //todo use listSize Instead
    uint256 public accountCurrentNumber = 0;
    uint256 public accountSchellingNumber = 1;
    uint256 public accountNumberCumulativeLast;

    uint256 public contractBirthRate = 4;
    // uint256 public contractBirthRate = 0;

    uint256 public denomination;
    uint256 public paymentNumber;

    // TODO ? adding new struct of Accountkey
    // TODO ? add getter to get address then connect with router, so we can commit via account
    mapping(bytes32 => mapping(uint256 => address)) public getPendingAccountToCommit;

    // Deposit Side:
    mapping(address => BalanceData) private pendingBalance;
    mapping(address => DepositData) public ownerToDeposit;
    // TODO review another data field submittiedDeposit
    mapping(bytes32 => bool) public submittiedCommitments;

    // Withdraw Side:
    mapping(address => WithdrawData) ownerToWithdraw;

    mapping(bytes32 => bool) public pendingNullifierHashes;
    // todo remove
    mapping(bytes32 => bool) public nullifierHashes;

    mapping(address => address) public accountToOracle;

    uint256 public liquidityCoverageSchellingRatio;

    uint256 rotateCounter;
    uint256 rotateCounterCumulativeLast;

    event Commit(bytes32 indexed commitment, address indexed account, uint256 amountIn, uint256 timestamp);
    event Clear(bytes32 indexed commitment, address indexed account, uint256 timestamp);
    event Insert(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);

    // TODO Add Deposit & Withdrawal events

    struct BalanceData {
        bytes32 commitment;
        uint256 committedAmount;
        address account;
    }

    // TODO Add isCommitSettle?
    // TODO change committedAmount to just Counter
    // TOFIX Add state to prevent withdrawing when not deposit yet (ie. alternatively move addAccount to deposit code block)
    struct DepositData {
        bytes32 commitment;
        uint256 committedAmount;
        address[] accounts;
    }

    // TODO change withdrawnAmount to just Counter
    // TODO addd owner?
    struct WithdrawData {
        uint256 withdrawnAmount;
        bytes32 previousNullifierHash;
        // bytes32 nullifierHash;
        uint256 lastUpdateTime;
        // bool isNullified;
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

        require(accountCurrentNumber <= accountSchellingNumber, "Core: Account already exceeds");

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
        // TODO hardcoded fix it
        // uint256 cap = 2;

        // todo fix as it is hardcoded
        // for different tyoe of annuity
        contractNumber = paymentNumber;

        accounts = new address[](contractNumber);

        for (uint256 i = 0; i < contractNumber; i++) {
            //sanity check for commitment

            // TODO : now hardcoded inflow and outflow as 1 and paymentNumber respectively
            // TODO : denomination should be 1 / 4 ?
            // case 1  : denomination should be 1 / 4 ?
            address account = deploy(address(this), commitment, denomination, paymentNumber, 1, i);
            // address account = deploy(address(this), commitment, denomination, contractNumber, 4, i);
            require(getPendingAccountToCommit[commitment][i] == address(0), "Core: Account Already Created");

            // TODO : do some optimization to query balanceAccount address? like mapping address to getPendingAccountToCommit
            // TODO : like getAccountTOCommit(commitment)
            getPendingAccountToCommit[commitment][i] = account;

            BalanceData storage balanceData = pendingBalance[account];
            balanceData.commitment = commitment;
            balanceData.account = account;

            accounts[i] = account;

            // TODO emit event
        }
        // return accounts;
    }

    /**
     * @dev only callable from child contract
     */
    function commitNew_2ndPhase_Callback(
        address caller,
        address account,
        bytes32 commitment,
        uint256 nonce,
        uint256 amountIn
    ) external payable override {
        require(uint256(commitment) < FIELD_SIZE, "Core: Commitment Out of Range");
        // ??
        require(commitment != bytes32(0), "Core: Invalid commitment");
        require(accountCurrentNumber < accountSchellingNumber, "Core: Schelling < CurrentNumber : Do commit via router");

        BalanceData storage balanceData = pendingBalance[account];
        // TODO check again
        require(balanceData.commitment == commitment, "Core: Wrong Commitment or Account");
        // still needed to prevent redundant hash from the same sender
        //  TODO another mechanism to prevent from redundant deposit
        //  TODO ie must be 0.25 ether?
        require(balanceData.committedAmount < denomination, "Core: Commited Amount already exceeded");
        require(balanceData.account == account, "Core: Wrong Account");

        require(!submittiedCommitments[commitment], "Core: Commitment already deposited");

        // DepositData storage ownerToDepositData = ownerToDeposit[caller];

        // only callable by child account(  ie deployer must be factory - address(this))
        // TODO check if we need to include denomination
        // TODO return ?
        CallbackValidation.verifyCallback(address(this), commitment, nonce);
        delete getPendingAccountToCommit[commitment][nonce];

        balanceData.committedAmount += amountIn;

        ownerToDeposit[caller].commitment = commitment;
        ownerToDeposit[caller].committedAmount += amountIn;

        //todo refactor to private funtion
        address[] storage accounts = ownerToDeposit[caller].accounts;
        bool isAddrRedundant;
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == account) {
                isAddrRedundant = true;
            }
        }
        if (!isAddrRedundant) accounts.push(account);

        emit Commit(commitment, account, amountIn, block.timestamp);
    }

    /**
     * @dev add depositData to already deployed account (pendingDeposit) called by router
     */
    function commitExisting_2ndPhase_Callback(
        address caller,
        address account,
        bytes32 existingCommitment,
        bytes32 newCommitment,
        uint256 nonce,
        uint256 amountIn
    ) external payable override {
        // todo add rule to use whether getBottomAccount() or getTop()
        require(account == getBottomAccount(), "Core: Only callable from bottom account");

        require(uint256(existingCommitment) < FIELD_SIZE, "Core: Commitment Out of Range");
        require(existingCommitment != bytes32(0), "Core: Invalid commitment");
        require(uint256(newCommitment) < FIELD_SIZE, "Core: Commitment Out of Range");
        require(newCommitment != bytes32(0), "Core: Invalid commitment");

        require(accountCurrentNumber > 0, "Core: Schelling > No Account added");
        require(
            accountCurrentNumber >= accountSchellingNumber, "Core: Schelling >= CurrentNumber : Do commit via router"
        );

        // TODO Remove this block? as we may only need `ownerToDeposit`
        BalanceData storage balanceData = pendingBalance[account];
        require(balanceData.commitment == bytes32(0), "Core: No Pending Commitment");
        require(balanceData.committedAmount == 0, "Core: Amount already Commited");
        require(balanceData.account == address(0), "Core: No Pending Address");

        require(submittiedCommitments[existingCommitment], "Core: 1stCommitment not made");
        require(!submittiedCommitments[newCommitment], "Core: Commitment already deposited");

        CallbackValidation.verifyCallback(address(this), existingCommitment, nonce);

        balanceData.commitment = newCommitment;
        balanceData.committedAmount += amountIn;
        balanceData.account = account;

        ownerToDeposit[caller].commitment = newCommitment;
        ownerToDeposit[caller].committedAmount += amountIn;

        //todo refactor to private funtion
        address[] storage accounts = ownerToDeposit[caller].accounts;
        bool isAddrRedundant;
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == account) {
                isAddrRedundant = true;
            }
        }
        if (!isAddrRedundant) accounts.push(account);

        emit Commit(newCommitment, account, amountIn, block.timestamp);
    }

    function clear_commitment_Callback(address caller, address account, uint256 nonce) external override {
        BalanceData memory balanceData = pendingBalance[account];
        bytes32 _pendingCommitment = balanceData.commitment;
        require(_pendingCommitment != bytes32(0), "Core: Not Commited Yet");
        require(balanceData.committedAmount != 0, "Core: Not Amount to Clear");
        require(balanceData.account == account, "Core: Wrong Account");

        CallbackValidation.verifyCallback(address(this), _pendingCommitment, nonce);

        delete pendingBalance[account].commitment;
        delete pendingBalance[account].committedAmount;
        delete pendingBalance[account].account;

        delete ownerToDeposit[caller].commitment;
        delete ownerToDeposit[caller].committedAmount;
        delete ownerToDeposit[caller].accounts;

        emit Clear(_pendingCommitment, account, block.timestamp);
    }

    /**
     * @dev let users update the current merkle root by providing a proof that they added `ownerToDeposit[msg.sender]` to the current merkle tree root `roots[currentRootIndex]` and verifying it onchain
     */
    function deposit(Proof calldata _proof, bytes32 newRoot) external {
        DepositData memory ownerToDepositData = ownerToDeposit[msg.sender];
        bytes32 _pendingCommitment = ownerToDepositData.commitment;
        uint256 _committedAmount = ownerToDepositData.committedAmount;

        require(_pendingCommitment != bytes32(0), "Core: Not Commited Yet");
        require(_committedAmount == denomination, "Core: Amount Commited Not Enough");

        require(!submittiedCommitments[_pendingCommitment], "Core: Commitment already deposited");

        uint256 _currentRootIndex = currentRootIndex;

        // TODO use from pending commitment AND _removeAccount()
        // TODO revisit  hash: Poseidon(nullifier, 0, denomination) : whether we should delete 'denomination'
        require(
            depositVerifier.verifyProof(
                _proof.a,
                _proof.b,
                _proof.c,
                [uint256(roots[_currentRootIndex]), uint256(_pendingCommitment), _committedAmount, uint256(newRoot)]
            ),
            "Core: Invalid deposit proof"
        );

        uint128 newCurrentRootIndex = uint128((_currentRootIndex + 1) % ROOT_HISTORY_SIZE);
        currentRootIndex = newCurrentRootIndex;
        roots[newCurrentRootIndex] = newRoot;
        uint256 _nextIndex = nextIndex;

        nextIndex += 1;

        submittiedCommitments[_pendingCommitment] = true;

        delete ownerToDeposit[msg.sender];

        address[] memory accounts = ownerToDepositData.accounts;
        for (uint256 i = 0; i < accounts.length; i++) {
            BalanceData memory balanceData = pendingBalance[accounts[i]];
            if (isAccountEmpty(accounts[i])) {
                _addAccount(accounts[i], balanceData.committedAmount);
            } else {
                _updateBalance(accounts[i], balanceData.committedAmount);
            }

            delete pendingBalance[accounts[i]];
        }

        emit Insert(_pendingCommitment, _nextIndex, block.timestamp);
    }

    function initWithdrawProcess(bytes32 nullifierHash, address recipient) external {
        WithdrawData storage withdrawData = ownerToWithdraw[recipient];
        // require(!withdrawData.isNullified, "Core: Already Withdraw");

        require(withdrawData.withdrawnAmount == 0, "Core: No Withdrawn Amount Yet");
        require(!pendingNullifierHashes[nullifierHash], "Core: the reference consumned");

        //todo start with full denomination amount
        //todo so, allow double deposit?

        withdrawData.lastUpdateTime = block.timestamp;
        pendingNullifierHashes[nullifierHash] = true;

        //todo inplement charging fee
    }

    /**
     * @dev let users make withdrawals where a note (commitment hash) is consumed and the change is redeposited into a new leaf node which the withdrawer is assumed to know the preimage of the commitment hash of.
     */
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

        WithdrawData storage withdrawData = ownerToWithdraw[_recipient];

        // todo remove/switch lines
        require(!nullifierHashes[_nullifierHash], "Core: The note has been already spent");
        
        require(withdrawData.withdrawnAmount < denomination, "Core: Withdrawn Amount already exceeded");
        require( withdrawData.lastUpdateTime != 0, "Core: Must initiate the process first" );
        require( (block.timestamp - withdrawData.lastUpdateTime > 1 days), "Core: Withdrawal period not reached" );

        // require(!withdrawData.isNullified, "Core: Already Withdraw All");

        //todo if first time withdraw then
        //todo if first 2nd-4th withdraw then check if its data field is still = firstNullifierHash

        uint256 amountOut = denomination / paymentNumber;
        // uint256 amountOut = denomination ;

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

        uint128 newCurrentRootIndex = uint128((currentRootIndex + 1) % ROOT_HISTORY_SIZE);
        currentRootIndex = newCurrentRootIndex;
        roots[newCurrentRootIndex] = _newRoot;
        uint256 _nextIndex = nextIndex;
        nextIndex += 1;

        if(withdrawData.withdrawnAmount  == 0) {
            require ( pendingNullifierHashes[_nullifierHash], "Core: the reference consumned-0");
            
        } else {
            require ( pendingNullifierHashes[withdrawData.previousNullifierHash], "Core: the reference consumned -1");
        }

        // todo: ?
        withdrawData.previousNullifierHash = _nullifierHash;
        pendingNullifierHashes[_nullifierHash] = true;

        withdrawData.withdrawnAmount += amountOut;
        withdrawData.lastUpdateTime = block.timestamp;

        nullifierHashes[_nullifierHash] = true;

        // todo fix sybill or remove as already inited
        // end the cycle (after final withdraw)
        if (withdrawData.withdrawnAmount == denomination) {
            // withdrawData.isNullified = true;
            delete withdrawData.withdrawnAmount;
            delete withdrawData.lastUpdateTime;
            delete withdrawData.previousNullifierHash;
        }

        // todo add rule to use whether getBottomAccount() or getTop()
        address accountToWithdraw = getBottomAccount();

        if (accountToWithdraw.balance == amountOut) {
            _removeAccount(accountToWithdraw);
            // todo add rule to use whether getBottomAccount() or getTop()
        } else {
            _reduceBalance(accountToWithdraw, amountOut);
        }

        IAccount(payable(accountToWithdraw)).withdraw_callback(address(this), _recipient, amountOut);
    }

    function _addAccount(address account, uint256 balance) internal override {
        super._addAccount(account, balance);
        accountCurrentNumber++;
    }

    function _removeAccount(address account) internal override {
        super._removeAccount(account);
        accountCurrentNumber--;
    }

    function getBottomAccount() public view override(IPoolsCounterBalancer, SortedList) returns (address) {
        return super.getBottomAccount();
    }

    function getCurrentAmountIn() external view returns (uint256) {
        return denomination;
    }

    function getPendingCommitmentToDeposit(address account) external view returns (bytes32) {
        return pendingBalance[account].commitment;
    }

    function getPendingCommittedAmountToDeposit(address account) external view returns (uint256) {
        return pendingBalance[account].committedAmount;
    }

    function getPendingAccountToDeposit(address account) external view returns (address) {
        return pendingBalance[account].account;
    }

    function getOwnerCommittedAmount(address owner) external view returns (uint256) {
        return ownerToDeposit[owner].committedAmount;
    }

    function getOwnerCommitment(address owner) external view returns (bytes32) {
        return ownerToDeposit[owner].commitment;
    }

    function getOwnerAccounts(address owner) external view returns (address[] memory) {
        return ownerToDeposit[owner].accounts;
    }

    function getSubmittiedCommitment(bytes32 commitment) external view returns (bool) {
        return submittiedCommitments[commitment];
    }

    function getWithdrawnAmount(address owner) external view returns (uint256) {
        return ownerToWithdraw[owner].withdrawnAmount;
    }

    function getPreviousNullifierHash(address owner) external view returns (bytes32) {
        return ownerToWithdraw[owner].previousNullifierHash;
    }

    function getLastWithdrawTime(address owner) external view returns (uint256) {
        return ownerToWithdraw[owner].lastUpdateTime;
    }

    function getIsNullifierInited(bytes32 nullifier) external view returns (bool) {
        return pendingNullifierHashes[nullifier];
    }

    function getIsNullified(bytes32 nullifier) external view returns (bool) {
        // return ownerToWithdraw[owner].isNullified;
        return nullifierHashes[nullifier];
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
