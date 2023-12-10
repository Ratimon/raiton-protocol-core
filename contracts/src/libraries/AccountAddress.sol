//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

library BalanceAccountAddress {
    bytes32 internal constant ACCOUNT_INIT_CODE_HASH =
        hex"8acf6f26ad26d0c22ae4ab70e934a32c5bead666200109b1fea8f1ce660db85d";

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
