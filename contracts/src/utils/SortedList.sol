//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

contract SortedList {
    mapping(address => uint256) public balances;
    mapping(address => address) _nextAccounts;
    uint256 public listSize;
    address constant GUARD = address(99);

    constructor() {
        _nextAccounts[GUARD] = GUARD;
      }

    function addAccount(address account, uint256 balance) internal {
        require(_nextAccounts[account] == address(0));
        address index = _findIndex(balance);
        balances[account] = balance;
        _nextAccounts[account] = _nextAccounts[index];
        _nextAccounts[index] = account;
        listSize++;
    }

    function removeAccount(address account) internal {
        require(_nextAccounts[account] != address(0));
        address prevAccount = _findPrevAccount(account);
        _nextAccounts[prevAccount] = _nextAccounts[account];
        _nextAccounts[account] = address(0);
        balances[account] = 0;
        listSize--;
    }


    function increaseBalance(address account, uint256 score) internal {
        updateBalance(account, balances[account] + score);
      }
    
      function reduceBalance(address account, uint256 score) internal {
        updateBalance(account, balances[account] - score);
      }
    

    function updateBalance(address account, uint256 newBalance) internal {
        require(_nextAccounts[account] != address(0));
        address prevAccount = _findPrevAccount(account);
        address nextAccount = _nextAccounts[account];
        if(_verifyIndex(prevAccount, newBalance, nextAccount)){
            balances[account] = newBalance;
        } else {
          removeAccount(account);
          addAccount(account, newBalance);
        }
      }

    function getTop(uint256 k) public view returns(address[] memory) {
        require(k <= listSize);
        address[] memory accountLists = new address[](k);
        address currentAddress = _nextAccounts[GUARD];
        for(uint256 i = 0; i < k; ++i) {
            accountLists[i] = currentAddress;
            currentAddress = _nextAccounts[currentAddress];
        }
        return accountLists;
    }


    function _findIndex(uint256 newValue) internal view returns(address candidateAddress) {
        candidateAddress = GUARD;
        while(true) {
          if(_verifyIndex(candidateAddress, newValue, _nextAccounts[candidateAddress])) return candidateAddress;
            candidateAddress = _nextAccounts[candidateAddress];
        }
    }

    function _verifyIndex(address prevAccount, uint256 newValue, address nextAccount)
      internal
      view
      returns(bool)
    {
        return (prevAccount == GUARD || balances[prevAccount] >= newValue) && 
            (nextAccount == GUARD || newValue > balances[nextAccount]);
    }

    function _isPrevAccount(address account, address prevAccount) internal view returns(bool) {
      return _nextAccounts[prevAccount] == account;
    }

    function _findPrevAccount(address account) internal view returns(address currentAddress) {
        currentAddress = GUARD;
        while(_nextAccounts[currentAddress] != GUARD) {
          if(_isPrevAccount(account, currentAddress))
            return currentAddress;
          currentAddress = _nextAccounts[currentAddress];
        }
        return address(0);
    }
    
}