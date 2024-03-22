// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Flags} from "./Types.sol";

library FlagsLib {
    /// @dev Are *all* of the flags in bitMask set?
    function isSet(Flags self, uint24 bitMask) internal pure returns (bool) {
        return (Flags.unwrap(self) & bitMask) == bitMask;
    }

    /// @dev Are *none* of the flags in bitMask set?
    function isNotSet(Flags self, uint24 bitMask) internal pure returns (bool) {
        return (Flags.unwrap(self) & bitMask) == 0;
    }

    function toUint24(Flags self) internal pure returns (uint24) {
        return Flags.unwrap(self);
    }
}
