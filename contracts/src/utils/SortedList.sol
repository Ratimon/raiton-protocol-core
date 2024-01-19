//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

contract SortedList {
    mapping(address => uint256) private balances;
    mapping(address => address) private _nextAccounts;
    address private lowestAccount;
    uint256 private listSize;
    address constant GUARD = address(99);


    constructor() {
        _nextAccounts[GUARD] = GUARD;
        lowestAccount = GUARD;
    }

    /**
     * @notice find the right place, between balances of previous and next accounts, then insert the new account
     */
    function _addAccount(address account, uint256 balance) internal virtual {
        require(_nextAccounts[account] == address(0), "SortedList: must be empty");
        address index = _findIndex(balance);
        balances[account] = balance;

        _nextAccounts[account] = _nextAccounts[index];
        _nextAccounts[index] = account;

        if (_nextAccounts[account] == GUARD || balances[account] <= balances[lowestAccount]) {
            lowestAccount = account;
        }

        listSize++;
    }

    function _removeAccount(address account) internal virtual {
        require(_nextAccounts[account] != address(0), "SortedList: must be not  empty");
        address prevAccount = _findPrevAccount(account);
        _nextAccounts[prevAccount] = _nextAccounts[account];
        _nextAccounts[account] = address(0);
        balances[account] = 0;

        if (_nextAccounts[prevAccount] == GUARD || balances[prevAccount] <= balances[lowestAccount]) {
            lowestAccount = prevAccount;
        }

        listSize--;
    }

    function _increaseBalance(address account, uint256 amount) internal {
        _updateBalance(account, balances[account] + amount);
    }

    function _reduceBalance(address account, uint256 amount) internal {
        _updateBalance(account, balances[account] - amount);
    }

    function _updateBalance(address account, uint256 newBalance) internal {
        require(_nextAccounts[account] != address(0), "SortedList: must be not  empty");
        address prevAccount = _findPrevAccount(account);
        address nextAccount = _nextAccounts[account];
        if (_verifyIndex(prevAccount, newBalance, nextAccount)) {
            balances[account] = newBalance;
        } else {
            _removeAccount(account);
            _addAccount(account, newBalance);
        }
    }

    function getBalance(address account) public view returns (uint256) {
        return balances[account];
    }

    function getTopAccount(uint256 k) public view returns (address[] memory) {
        require(k <= listSize, "SortedList: k must be > than list size");
        address[] memory accountLists = new address[](k);
        address currentAddress = _nextAccounts[GUARD];
        for (uint256 i = 0; i < k; ++i) {
            accountLists[i] = currentAddress;
            currentAddress = _nextAccounts[currentAddress];
        }
        return accountLists;
    }

    // todo add test suites
    function isAccountEmpty(address addr) public view returns (bool) {
        return _nextAccounts[addr] == address(0);
    }

    //todo revert if no account?
    function getBottomAccount() public view virtual returns (address) {
        return lowestAccount;
    }

    function _findIndex(uint256 newValue) internal view returns (address candidateAddress) {
        candidateAddress = GUARD;
        while (true) {
            if (_verifyIndex(candidateAddress, newValue, _nextAccounts[candidateAddress])) return candidateAddress;
            candidateAddress = _nextAccounts[candidateAddress];
        }
    }

    function _verifyIndex(address prevAccount, uint256 newValue, address nextAccount) internal view returns (bool) {
        return (prevAccount == GUARD || balances[prevAccount] >= newValue)
            && (nextAccount == GUARD || newValue > balances[nextAccount]);
    }

    function _isPrevAccount(address account, address prevAccount) internal view returns (bool) {
        return _nextAccounts[prevAccount] == account;
    }

    function _findPrevAccount(address account) internal view returns (address currentAddress) {
        currentAddress = GUARD;
        while (_nextAccounts[currentAddress] != GUARD) {
            if (_isPrevAccount(account, currentAddress)) {
                return currentAddress;
            }
            currentAddress = _nextAccounts[currentAddress];
        }
        return address(0);
    }
}
