//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

library BalanceAccountAddress {
    bytes32 internal constant ACCOUNT_INIT_CODE_HASH =
        hex"73af5adbb7c4425b0f33adfc2c8243e99636ff3500065a7326be06aa2708700f";

    // TODO will separe between annuity and endowmwnt later
    function computeAddress(address factory, bytes32 commitment, uint256 nonce)
        internal
        pure
        returns (address account)
    {
        account = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff", factory, keccak256(abi.encode(commitment, nonce)), ACCOUNT_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
