//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IDepositVerifier} from "@main/interfaces/IDepositVerifier.sol";
import {IPartialWithdrawVerifier} from "@main/interfaces/IPartialWithdrawVerifier.sol";
import {IAccount} from "@main/interfaces/IAccount.sol";

import {Core} from "@main/Core.sol";
import {BalanceAccount} from "@main/BalanceAccount.sol";

import {Groth16Verifier as DepositGroth16Verifier} from "@main/verifiers/DepositVerifier.sol";
import {Groth16Verifier as PartialWithdrawVerifier} from "@main/verifiers/PartialWithdrawVerifier.sol";

import {SharedHarness} from "@test/harness/Shared.harness.t.sol";

contract BalanceAccountHarness is SharedHarness {
    //todo refactor to deployment script
    function setUp() public virtual override {
        super.setUp();
        vm.label(address(this), "BalanceAccountHarness");
    }

    function assertAccount(
        address user,
        address account,
        bytes32 commitment,
        uint256 amount,
        uint256 nonce,
        uint256 inflow,
        uint256 outflow
    ) internal {
        vm.startPrank(user);

        IAccount balanceAccount = IAccount(account);

        assertEq32(balanceAccount.commitment(), commitment);
        assertEq(balanceAccount.denomination(), amount);
        assertEq(balanceAccount.cashInflows(), inflow);
        assertEq(balanceAccount.cashOutflows(), outflow);
        assertEq(balanceAccount.nonce(), nonce);

        vm.stopPrank();
    }

}
