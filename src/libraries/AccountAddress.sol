//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

library AccountAddress {
    // hardcoded
    bytes32 internal constant ACCOUNT_INIT_CODE_HASH = bytes32(0);

    function computeAddress(address factory, bytes32 commitment, uint256 paymentOrder) internal pure returns (address account) {

        account = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            factory,
                            keccak256(abi.encode(commitment,paymentOrder)),
                            ACCOUNT_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

}