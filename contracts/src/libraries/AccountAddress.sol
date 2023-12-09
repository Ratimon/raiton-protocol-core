//SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

library BalanceAccountAddress {

    bytes32 internal constant ACCOUNT_INIT_CODE_HASH = hex"923fac2921b3ad96a7206a1f8269d8c569b1332f532a374c1cd78c918da96ee6";

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