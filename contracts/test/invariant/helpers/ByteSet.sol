// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

struct ByteSet {
    bytes32[] byts;
    mapping(bytes32 => bool) saved;
}

library LibByteSet {
    function add(ByteSet storage s, bytes32 byt) internal {
        if (!s.saved[byt]) {
            s.byts.push(byt);
            s.saved[byt] = true;
        }
    }

    function contains(ByteSet storage s, bytes32 byt) internal view returns (bool) {
        return s.saved[byt];
    }

    function count(ByteSet storage s) internal view returns (uint256) {
        return s.byts.length;
    }

    function rand(ByteSet storage s, uint256 seed) internal view returns (bytes32) {
        if (s.byts.length > 0) {
            return s.byts[seed % s.byts.length];
        } else {
            return bytes32(0);
        }
    }

    function forEach(ByteSet storage s, function(bytes32) external func) internal {
        for (uint256 i; i < s.byts.length; ++i) {
            func(s.byts[i]);
        }
    }

    function reduce(ByteSet storage s, uint256 acc, function(uint256,bytes32) external returns (uint256) func)
        internal
        returns (uint256)
    {
        for (uint256 i; i < s.byts.length; ++i) {
            acc = func(acc, s.byts[i]);
        }
        return acc;
    }
}