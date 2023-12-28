//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

library BalanceAccountAddress {
    bytes32 internal constant ACCOUNT_INIT_CODE_HASH =
        hex"5799abb12735592cef6783a0fa3a81513bbe251e488c3d3ac635f5c3e556417e";

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
