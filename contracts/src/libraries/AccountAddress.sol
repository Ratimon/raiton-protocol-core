//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

library BalanceAccountAddress {
    bytes32 internal constant ACCOUNT_INIT_CODE_HASH =
        hex"ea84f673a1fd557b23719fee1001b0cca22b80c440c3a959e3ab979c19ebac88";

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
