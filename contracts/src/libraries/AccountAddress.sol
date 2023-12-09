//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

library AccountAddress {
    // hardcoded
    bytes32 internal constant ACCOUNT_INIT_CODE_HASH = hex"1a228f81705cc3ef2ad6098b3a6d17d64582242f69cefd9ffa2a8a482b67cf50";

    // TODO will separe between annuity and endowmwnt later
    function computeAddress(address factory, bytes32 commitment, uint256 nonce) internal pure returns (address account) {

        account = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            factory,
                            keccak256(abi.encode(commitment,nonce)),
                            ACCOUNT_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

}